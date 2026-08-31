"""
Integração com a AwesomeAPI de câmbio (economia.awesomeapi.com.br) -- pública,
gratuita e sem necessidade de chave. Usada tanto pela rota /vendas/resumo/cambio
(Etapa 3) quanto pelo script standalone demo_cambio.py, ambos via a mesma
função obter_cotacao(), para não duplicar a lógica de cache/fallback.
"""

import logging
import os
import re
import threading
import time
from dataclasses import dataclass, replace

import httpx

logger = logging.getLogger(__name__)

_URL_BASE = os.getenv("CAMBIO_API_URL", "https://economia.awesomeapi.com.br/json/last")
_TIMEOUT_SEGUNDOS = float(os.getenv("CAMBIO_TIMEOUT_SEGUNDOS", "5"))
_CACHE_TTL_SEGUNDOS = float(os.getenv("CAMBIO_CACHE_TTL_SEGUNDOS", "300"))

_PADRAO_CODIGO_MOEDA = re.compile(r"[A-Za-z]{3}")


class CambioIndisponivel(RuntimeError):
    """A API externa falhou e não há cotação em cache para usar como fallback."""


@dataclass
class Cotacao:
    moeda_origem: str
    moeda_destino: str
    valor: float
    obtida_em: float  # time.time() de quando a cotação foi buscada na API
    de_cache: bool = False
    desatualizada: bool = False


# Cache em memória por processo: {moeda: Cotacao}. Um Lock porque o FastAPI
# roda rotas síncronas em threads separadas -- sem ele, duas requisições
# concorrentes poderiam ler/escrever o dict ao mesmo tempo.
_cache_lock = threading.Lock()
_cache: dict[str, Cotacao] = {}


def normalizar_codigo_moeda(moeda: str) -> str:
    moeda = moeda.strip().upper()
    if not _PADRAO_CODIGO_MOEDA.fullmatch(moeda):
        raise ValueError(
            f"codigo de moeda invalido: '{moeda}'. Use um codigo ISO de 3 letras, ex.: USD."
        )
    return moeda


def _buscar_na_api(moeda: str) -> Cotacao:
    par = f"{moeda}-BRL"
    resposta = httpx.get(f"{_URL_BASE}/{par}", timeout=_TIMEOUT_SEGUNDOS)
    resposta.raise_for_status()
    dados = resposta.json()

    valor = float(dados[par.replace("-", "")]["bid"])
    return Cotacao(moeda_origem=moeda, moeda_destino="BRL", valor=valor, obtida_em=time.time())


def obter_cotacao(moeda: str) -> Cotacao:
    """
    Devolve a cotação moeda->BRL. Usa cache com TTL configurável
    (CAMBIO_CACHE_TTL_SEGUNDOS, padrão 5 min) para não bater na API a cada
    chamada -- a AwesomeAPI é gratuita, mas ainda assim tem limite de uso.
    Se a API externa falhar e existir uma cotação em cache (mesmo expirada),
    ela é reaproveitada como fallback, marcada como desatualizada.
    """
    moeda = normalizar_codigo_moeda(moeda)

    with _cache_lock:
        cotacao_cache = _cache.get(moeda)
        if cotacao_cache and (time.time() - cotacao_cache.obtida_em) < _CACHE_TTL_SEGUNDOS:
            return replace(cotacao_cache, de_cache=True)

    try:
        cotacao = _buscar_na_api(moeda)
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        logger.warning("Falha ao consultar cotacao de %s na API externa: %s", moeda, exc)
        with _cache_lock:
            cotacao_cache = _cache.get(moeda)
        if cotacao_cache is None:
            raise CambioIndisponivel(
                f"Nao foi possivel obter a cotacao de {moeda} e nao ha valor em cache."
            ) from exc
        return replace(cotacao_cache, de_cache=True, desatualizada=True)

    with _cache_lock:
        _cache[moeda] = cotacao
    return cotacao
