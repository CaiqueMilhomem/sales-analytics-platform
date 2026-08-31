"""Dependências compartilhadas pelas rotas."""

from typing import Annotated

from fastapi import Depends, HTTPException, Query

from api.data_access import Periodo, cambio, resolver_periodo


def obter_periodo(
    periodo: Annotated[
        str,
        Query(description="ultimos-Nd, mes-atual, ano-atual ou AAAA-MM-DD:AAAA-MM-DD"),
    ] = "ultimos-30d",
) -> Periodo:
    """Valida e converte o parâmetro `periodo` usando a mesma regra do CLI (Etapa 2)."""
    try:
        return resolver_periodo(periodo)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


PeriodoDep = Annotated[Periodo, Depends(obter_periodo)]


def obter_moeda(
    moeda: Annotated[
        str, Query(description="Codigo ISO de 3 letras, ex.: USD, EUR, GBP")
    ] = "USD",
) -> str:
    """Valida o código da moeda antes de qualquer chamada à API externa."""
    try:
        return cambio.normalizar_codigo_moeda(moeda)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


MoedaDep = Annotated[str, Depends(obter_moeda)]
