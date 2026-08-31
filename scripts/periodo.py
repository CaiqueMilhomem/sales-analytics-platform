"""
Interpretação do parâmetro de período. Extraído de gerar_relatorios.py na
Etapa 3 porque a API passou a precisar da mesma regra de validação usada
pelo CLI -- melhor um único lugar de verdade do que reimplementar o parsing
de datas em dois lugares.
"""

from dataclasses import dataclass
from datetime import date, datetime, timedelta


@dataclass
class Periodo:
    inicio: date
    fim: date


def resolver_periodo(valor: str) -> Periodo:
    """
    Converte o parâmetro de período em um intervalo de datas. Aceita atalhos
    (ultimos-Nd, mes-atual, ano-atual) ou um intervalo explícito
    'AAAA-MM-DD:AAAA-MM-DD'.
    """
    hoje = date.today()

    if ":" in valor:
        inicio_str, fim_str = valor.split(":", 1)
        inicio = datetime.strptime(inicio_str, "%Y-%m-%d").date()
        fim = datetime.strptime(fim_str, "%Y-%m-%d").date()
        return Periodo(inicio, fim)

    if valor == "mes-atual":
        return Periodo(hoje.replace(day=1), hoje)

    if valor == "ano-atual":
        return Periodo(hoje.replace(month=1, day=1), hoje)

    if valor.startswith("ultimos-") and valor.endswith("d"):
        dias = int(valor[len("ultimos-"):-1])
        return Periodo(hoje - timedelta(days=dias), hoje)

    raise ValueError(
        f"periodo invalido: '{valor}'. Use 'ultimos-Nd', 'mes-atual', "
        "'ano-atual' ou 'AAAA-MM-DD:AAAA-MM-DD'."
    )
