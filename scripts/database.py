"""
Camada de conexão com o Postgres (Neon/Supabase). Centralizada aqui para que
nenhum outro módulo precise saber como abrir/fechar conexão ou montar a
chamada SQL das stored functions.
"""

import logging
import os
from contextlib import contextmanager

import psycopg2
import psycopg2.extensions
from dotenv import load_dotenv
from psycopg2 import sql

load_dotenv()

logger = logging.getLogger(__name__)

# NUMERIC do Postgres chega via psycopg2 como decimal.Decimal, que o pandas
# não serializa em JSON. Registrar essa conversão troca por float assim que a
# conexão é criada -- ótimo para relatório, mas não usar essa conexão para
# cálculo financeiro que exija precisão decimal exata.
_DEC2FLOAT = psycopg2.extensions.new_type(
    psycopg2.extensions.DECIMAL.values,
    "DEC2FLOAT",
    lambda valor, cursor: float(valor) if valor is not None else None,
)
psycopg2.extensions.register_type(_DEC2FLOAT)


class ConfiguracaoAusente(RuntimeError):
    """DATABASE_URL não definida no ambiente."""


@contextmanager
def conexao():
    """
    Abre uma conexão com o Postgres e garante o fechamento mesmo se algo
    falhar no meio do caminho.

        with conexao() as conn:
            ...
    """
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise ConfiguracaoAusente(
            "DATABASE_URL nao definida. Copie .env.example para .env e "
            "preencha com a connection string do Neon/Supabase."
        )

    conn = psycopg2.connect(database_url)
    logger.debug("Conexao com o banco estabelecida")
    try:
        yield conn
    except Exception:
        conn.rollback()
        logger.exception("Erro durante o uso da conexao, rollback executado")
        raise
    finally:
        conn.close()
        logger.debug("Conexao com o banco encerrada")


def executar_funcao(nome_funcao: str, parametros: tuple) -> tuple[list[str], list[tuple]]:
    """
    Executa `SELECT * FROM nome_funcao(...)` e devolve (colunas, linhas).
    `nome_funcao` nunca vem de input externo (sempre chamado com literais
    fixos pelos módulos de métricas), mas ainda assim usamos sql.Identifier
    em vez de f-string para montar a query -- é o jeito seguro de compor SQL
    dinamicamente com psycopg2, mesmo quando o risco atual é só teórico.
    """
    query = sql.SQL("SELECT * FROM {funcao}({parametros})").format(
        funcao=sql.Identifier(nome_funcao),
        parametros=sql.SQL(", ").join(sql.Placeholder() for _ in parametros),
    )

    with conexao() as conn:
        with conn.cursor() as cur:
            cur.execute(query, parametros)
            colunas = [descricao[0] for descricao in cur.description]
            linhas = cur.fetchall()

    logger.info("fn %s retornou %d linha(s)", nome_funcao, len(linhas))
    return colunas, linhas
