"""Schemas Pydantic das respostas da API -- o "contrato" de cada endpoint."""

from datetime import date

from pydantic import BaseModel


class PeriodoConsultado(BaseModel):
    inicio: date
    fim: date


class ResumoVendas(BaseModel):
    periodo: PeriodoConsultado
    total_vendas: int
    faturamento_total: float
    ticket_medio: float
    total_itens: int


class ProdutoTop(BaseModel):
    produto_id: int
    produto_nome: str
    categoria: str
    quantidade_vendida: int
    faturamento: float


class ClienteTop(BaseModel):
    cliente_id: int
    cliente_nome: str
    total_compras: int
    faturamento_total: float
    ticket_medio: float


class CategoriaRanking(BaseModel):
    categoria: str
    faturamento_total: float
    ranking: int


class HealthCheck(BaseModel):
    status: str
    servico: str


class CotacaoCambio(BaseModel):
    moeda_origem: str
    moeda_destino: str
    valor: float
    de_cache: bool
    desatualizada: bool


class ResumoVendasCambio(BaseModel):
    periodo: PeriodoConsultado
    total_vendas: int
    faturamento_total_brl: float
    faturamento_total_convertido: float
    ticket_medio_brl: float
    ticket_medio_convertido: float
    total_itens: int
    cotacao: CotacaoCambio
