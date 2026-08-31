"""Rotas de vendas: resumo por período, top produtos e ranking por categoria."""

from fastapi import APIRouter, Query

from api.data_access import cambio, metricas
from api.dependencies import MoedaDep, PeriodoDep
from api.schemas import CategoriaRanking, ProdutoTop, ResumoVendas, ResumoVendasCambio

router = APIRouter(prefix="/vendas", tags=["vendas"])


# As rotas usam `def` comum, não `async def`: metricas.* faz chamadas
# bloqueantes ao banco via psycopg2 (sem suporte a async), e o FastAPI já
# executa rotas síncronas numa threadpool -- usar `async def` aqui bloquearia
# o event loop inteiro a cada consulta.
@router.get("/resumo", response_model=ResumoVendas)
def resumo_vendas(periodo: PeriodoDep):
    df = metricas.resumo_vendas_periodo(periodo.inicio, periodo.fim)
    linha = df.iloc[0].to_dict()
    return {"periodo": {"inicio": periodo.inicio, "fim": periodo.fim}, **linha}


@router.get("/top-produtos", response_model=list[ProdutoTop])
def top_produtos(
    periodo: PeriodoDep,
    limite: int = Query(10, ge=1, le=100, description="Quantidade de produtos retornados"),
):
    df = metricas.top_produtos_faturamento(periodo.inicio, periodo.fim, limite)
    return df.to_dict(orient="records")


@router.get("/por-categoria", response_model=list[CategoriaRanking])
def vendas_por_categoria(periodo: PeriodoDep):
    df = metricas.vendas_categoria_ranking(periodo.inicio, periodo.fim)
    return df.to_dict(orient="records")


@router.get("/resumo/cambio", response_model=ResumoVendasCambio)
def resumo_vendas_cambio(periodo: PeriodoDep, moeda: MoedaDep):
    """Resumo de vendas do período, convertido para `moeda` na cotação atual."""
    df = metricas.resumo_vendas_periodo(periodo.inicio, periodo.fim)
    linha = df.iloc[0].to_dict()

    cotacao = cambio.obter_cotacao(moeda)
    # cotacao.valor é quantos BRL valem 1 unidade da moeda -- por isso a
    # conversão BRL -> moeda estrangeira é uma divisão, não multiplicação.
    fator = cotacao.valor or None

    return {
        "periodo": {"inicio": periodo.inicio, "fim": periodo.fim},
        "total_vendas": linha["total_vendas"],
        "faturamento_total_brl": linha["faturamento_total"],
        "faturamento_total_convertido": round(linha["faturamento_total"] / fator, 2) if fator else 0.0,
        "ticket_medio_brl": linha["ticket_medio"],
        "ticket_medio_convertido": round(linha["ticket_medio"] / fator, 2) if fator else 0.0,
        "total_itens": linha["total_itens"],
        "cotacao": {
            "moeda_origem": cotacao.moeda_origem,
            "moeda_destino": cotacao.moeda_destino,
            "valor": cotacao.valor,
            "de_cache": cotacao.de_cache,
            "desatualizada": cotacao.desatualizada,
        },
    }
