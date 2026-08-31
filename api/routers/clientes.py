"""Rota de clientes: ranking por faturamento no período."""

from fastapi import APIRouter, Query

from api.data_access import metricas
from api.dependencies import PeriodoDep
from api.schemas import ClienteTop

router = APIRouter(prefix="/clientes", tags=["clientes"])


@router.get("/top", response_model=list[ClienteTop])
def top_clientes(
    periodo: PeriodoDep,
    limite: int = Query(10, ge=1, le=100, description="Quantidade de clientes retornados"),
):
    # fn_faturamento_ticket_medio_cliente (Etapa 1) não tem parâmetro de
    # limite -- ela já devolve todos os clientes ordenados por faturamento
    # decrescente, então o corte de "top N" é feito aqui no DataFrame.
    df = metricas.faturamento_ticket_medio_cliente(periodo.inicio, periodo.fim)
    return df.head(limite).to_dict(orient="records")
