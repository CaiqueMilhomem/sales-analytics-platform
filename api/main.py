"""
Aplicação FastAPI: expõe as métricas de vendas (Etapa 1 + Etapa 2) como
endpoints HTTP. Rodar com:

    uvicorn api.main:app --reload

a partir da raiz do projeto (ver api/README.md para o passo a passo completo).
"""

import logging
import os

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from api.data_access import CambioIndisponivel, ConfiguracaoAusente
from api.routers import clientes, vendas
from api.schemas import HealthCheck

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("api")

app = FastAPI(
    title="Sales Analytics API",
    description="Métricas de vendas consolidadas a partir das stored functions do Postgres.",
    version="1.0.0",
)

# CORS_ORIGINS aceita uma lista separada por vírgula (ex.: "https://meu-dashboard.com,https://outro.com").
# "*" (padrão) é conveniente para desenvolvimento local, mas deve ser restrito
# a domínios conhecidos em um deploy real. Só GET é exposto pela API hoje, daí
# allow_methods ficar limitado a isso.
_origens = os.getenv("CORS_ORIGINS", "*")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if _origens == "*" else [o.strip() for o in _origens.split(",")],
    allow_methods=["GET"],
    allow_headers=["*"],
)

app.include_router(vendas.router)
app.include_router(clientes.router)


@app.exception_handler(ConfiguracaoAusente)
def _configuracao_ausente_handler(request: Request, exc: ConfiguracaoAusente):
    logger.error(str(exc))
    return JSONResponse(status_code=500, content={"detail": str(exc)})


@app.exception_handler(CambioIndisponivel)
def _cambio_indisponivel_handler(request: Request, exc: CambioIndisponivel):
    # 503 (não 500): o problema é a API externa de câmbio, não um bug local.
    logger.error(str(exc))
    return JSONResponse(status_code=503, content={"detail": str(exc)})


@app.exception_handler(Exception)
def _erro_inesperado_handler(request: Request, exc: Exception):
    logger.exception("Erro nao tratado ao processar %s", request.url.path)
    return JSONResponse(status_code=500, content={"detail": "Erro interno ao consultar os dados."})


@app.get("/", response_model=HealthCheck, tags=["health"])
def health_check():
    return {"status": "ok", "servico": "sales-analytics-api"}
