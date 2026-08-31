"""
Ponte entre a API e os módulos de acesso a dados da Etapa 2 (scripts/).

scripts/ foi escrito para rodar como scripts soltos (cada módulo importa o
vizinho com `import database`, sem pacote). Em vez de duplicar database.py e
metricas.py dentro de api/, adicionamos a pasta scripts/ ao sys.path uma
única vez, aqui, e reexportamos o que as rotas precisam. Assim a lógica de
conexão e as queries continuam existindo em um só lugar.
"""

import sys
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

import cambio  # noqa: E402
import metricas  # noqa: E402
from cambio import CambioIndisponivel  # noqa: E402
from database import ConfiguracaoAusente  # noqa: E402
from periodo import Periodo, resolver_periodo  # noqa: E402

__all__ = [
    "metricas",
    "cambio",
    "ConfiguracaoAusente",
    "CambioIndisponivel",
    "Periodo",
    "resolver_periodo",
]
