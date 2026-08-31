"""
Ponto de entrada da automação: chama as stored functions de vendas, salva os
resultados em CSV/JSON e monta um resumo executivo consolidado. Pensado para
rodar via cron/agendador, ex.:

    python gerar_relatorios.py --periodo ultimos-30d --formato ambos

Códigos de saída: 0 = sucesso, 1 = erro de configuração/conexão/consulta,
2 = argumento de linha de comando inválido.
"""

import argparse
import json
import logging
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

import metricas
from database import ConfiguracaoAusente
from periodo import Periodo, resolver_periodo

logger = logging.getLogger("gerar_relatorios")

PASTA_SAIDA_PADRAO = Path(__file__).resolve().parent.parent / "data" / "relatorios"


def montar_resumo_executivo(
    periodo: Periodo,
    resumo: pd.DataFrame,
    top_produtos: pd.DataFrame,
    clientes: pd.DataFrame,
    categorias: pd.DataFrame,
) -> dict:
    """Consolida os quatro relatórios em um único resumo de alto nível."""
    linha_resumo = resumo.iloc[0].to_dict() if not resumo.empty else {}
    produto_destaque = top_produtos.iloc[0].to_dict() if not top_produtos.empty else None
    categoria_destaque = categorias.iloc[0].to_dict() if not categorias.empty else None

    return {
        "periodo": {"inicio": periodo.inicio.isoformat(), "fim": periodo.fim.isoformat()},
        "gerado_em": datetime.now().isoformat(timespec="seconds"),
        "total_vendas": linha_resumo.get("total_vendas"),
        "faturamento_total": linha_resumo.get("faturamento_total"),
        "ticket_medio": linha_resumo.get("ticket_medio"),
        "total_itens": linha_resumo.get("total_itens"),
        "produto_destaque": produto_destaque,
        "categoria_destaque": categoria_destaque,
        "total_clientes_no_periodo": len(clientes),
    }


def salvar(df: pd.DataFrame, caminho_base: Path, formatos: list[str]) -> None:
    if "csv" in formatos:
        caminho = caminho_base.with_suffix(".csv")
        df.to_csv(caminho, index=False, encoding="utf-8")
        logger.info("Relatorio salvo: %s", caminho)
    if "json" in formatos:
        caminho = caminho_base.with_suffix(".json")
        df.to_json(caminho, orient="records", indent=2, force_ascii=False)
        logger.info("Relatorio salvo: %s", caminho)


def executar(args: argparse.Namespace) -> int:
    try:
        periodo = resolver_periodo(args.periodo)
    except ValueError as exc:
        logger.error(str(exc))
        return 2

    formatos = ["csv", "json"] if args.formato == "ambos" else [args.formato]
    pasta_saida = Path(args.saida) if args.saida else PASTA_SAIDA_PADRAO
    pasta_saida.mkdir(parents=True, exist_ok=True)

    try:
        resumo = metricas.resumo_vendas_periodo(periodo.inicio, periodo.fim)
        top_produtos = metricas.top_produtos_faturamento(periodo.inicio, periodo.fim, args.top)
        clientes = metricas.faturamento_ticket_medio_cliente(
            periodo.inicio, periodo.fim, args.cliente_id
        )
        categorias = metricas.vendas_categoria_ranking(periodo.inicio, periodo.fim)
    except ConfiguracaoAusente as exc:
        logger.error(str(exc))
        return 1
    except Exception:
        logger.exception("Falha ao consultar as metricas no banco")
        return 1

    sufixo = f"{periodo.inicio.isoformat()}_a_{periodo.fim.isoformat()}"
    salvar(resumo, pasta_saida / f"resumo_vendas_{sufixo}", formatos)
    salvar(top_produtos, pasta_saida / f"top_produtos_{sufixo}", formatos)
    salvar(clientes, pasta_saida / f"clientes_{sufixo}", formatos)
    salvar(categorias, pasta_saida / f"categorias_{sufixo}", formatos)

    resumo_executivo = montar_resumo_executivo(periodo, resumo, top_produtos, clientes, categorias)
    caminho_resumo = pasta_saida / f"resumo_executivo_{sufixo}.json"
    caminho_resumo.write_text(
        json.dumps(resumo_executivo, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    logger.info("Resumo executivo salvo: %s", caminho_resumo)

    logger.info(
        "Periodo %s a %s: %s venda(s), faturamento R$ %.2f",
        periodo.inicio,
        periodo.fim,
        resumo_executivo["total_vendas"] or 0,
        resumo_executivo["faturamento_total"] or 0.0,
    )
    return 0


def criar_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Gera relatorios de vendas a partir das stored functions do Postgres."
    )
    parser.add_argument(
        "--periodo",
        default="ultimos-30d",
        help="ultimos-Nd, mes-atual, ano-atual ou AAAA-MM-DD:AAAA-MM-DD (padrao: ultimos-30d)",
    )
    parser.add_argument(
        "--formato",
        choices=["csv", "json", "ambos"],
        default="ambos",
        help="Formato de saida dos relatorios (padrao: ambos)",
    )
    parser.add_argument(
        "--top", type=int, default=10, help="Quantidade de produtos no ranking (padrao: 10)"
    )
    parser.add_argument(
        "--cliente-id", type=int, default=None, help="Filtra o relatorio de clientes por um ID especifico"
    )
    parser.add_argument("--saida", help="Pasta de saida (padrao: data/relatorios)")
    parser.add_argument("--verbose", action="store_true", help="Ativa logs em nivel DEBUG")
    return parser


def main() -> None:
    args = criar_parser().parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    sys.exit(executar(args))


if __name__ == "__main__":
    main()
