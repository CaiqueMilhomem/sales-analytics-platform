"""
Demonstra o uso de cambio.py fora da API, para fins de estudo: busca o
resumo de vendas do período informado e mostra o faturamento convertido para
a moeda escolhida.

    python demo_cambio.py --periodo ultimos-30d --moeda USD

Códigos de saída: 0 = sucesso, 1 = erro de configuração/banco/câmbio,
2 = argumento de linha de comando inválido.
"""

import argparse
import logging
import sys

import metricas
from cambio import CambioIndisponivel, obter_cotacao
from database import ConfiguracaoAusente
from periodo import resolver_periodo

logger = logging.getLogger("demo_cambio")


def main() -> int:
    parser = argparse.ArgumentParser(description="Demonstra a integracao com a API de cambio.")
    parser.add_argument("--periodo", default="ultimos-30d")
    parser.add_argument("--moeda", default="USD")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    try:
        periodo = resolver_periodo(args.periodo)
    except ValueError as exc:
        logger.error(str(exc))
        return 2

    try:
        resumo = metricas.resumo_vendas_periodo(periodo.inicio, periodo.fim)
    except ConfiguracaoAusente as exc:
        logger.error(str(exc))
        return 1
    except Exception:
        logger.exception("Falha ao consultar o resumo de vendas no banco")
        return 1

    try:
        cotacao = obter_cotacao(args.moeda)
    except (ValueError, CambioIndisponivel) as exc:
        logger.error(str(exc))
        return 1

    linha = resumo.iloc[0]
    faturamento_convertido = linha["faturamento_total"] / cotacao.valor

    origem = "cache" if cotacao.de_cache else "API"
    aviso = " -- DESATUALIZADA (fallback)" if cotacao.desatualizada else ""

    print(f"Periodo consultado:      {periodo.inicio} a {periodo.fim}")
    print(f"Faturamento (BRL):       R$ {linha['faturamento_total']:.2f}")
    print(f"Cotacao {cotacao.moeda_origem}->BRL:       {cotacao.valor:.4f} (via {origem}){aviso}")
    print(f"Faturamento convertido:  {cotacao.moeda_origem} {faturamento_convertido:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
