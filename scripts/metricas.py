"""
Wrappers em cima das stored functions de vendas (sql/03_stored_procedures.sql).
Cada função aqui chama uma função SQL e devolve o resultado como DataFrame,
já pronto para ser salvo em CSV/JSON ou combinado em outro relatório.
"""

from datetime import date

import pandas as pd

from database import executar_funcao


def resumo_vendas_periodo(data_inicio: date, data_fim: date) -> pd.DataFrame:
    colunas, linhas = executar_funcao("fn_resumo_vendas_periodo", (data_inicio, data_fim))
    return pd.DataFrame(linhas, columns=colunas)


def top_produtos_faturamento(data_inicio: date, data_fim: date, limite: int = 10) -> pd.DataFrame:
    colunas, linhas = executar_funcao(
        "fn_top_produtos_faturamento", (data_inicio, data_fim, limite)
    )
    return pd.DataFrame(linhas, columns=colunas)


def faturamento_ticket_medio_cliente(
    data_inicio: date, data_fim: date, cliente_id: int | None = None
) -> pd.DataFrame:
    colunas, linhas = executar_funcao(
        "fn_faturamento_ticket_medio_cliente", (data_inicio, data_fim, cliente_id)
    )
    return pd.DataFrame(linhas, columns=colunas)


def vendas_categoria_ranking(data_inicio: date, data_fim: date) -> pd.DataFrame:
    colunas, linhas = executar_funcao("fn_vendas_categoria_ranking", (data_inicio, data_fim))
    return pd.DataFrame(linhas, columns=colunas)
