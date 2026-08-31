# scripts/

Automação em Python que consulta as stored functions do banco (Etapa 1) e
gera relatórios de vendas em CSV/JSON, incluindo um resumo executivo.

| Arquivo               | Responsabilidade                                              |
|-----------------------|-----------------------------------------------------------------|
| `database.py`         | Conexão com o Postgres (context manager) e execução genérica de `SELECT * FROM fn_...(...)`. |
| `metricas.py`         | Uma função por stored function, já devolvendo `pandas.DataFrame`. |
| `periodo.py`          | Validação do parâmetro de período, compartilhada pelo CLI e pela API. |
| `cambio.py`           | Integração com a API pública de câmbio (cache + fallback), compartilhada pela API e por `demo_cambio.py`. |
| `gerar_relatorios.py` | CLI: resolve o período, chama as métricas, salva os arquivos e monta o resumo executivo. |
| `demo_cambio.py`      | Script standalone que demonstra `cambio.py` fora da API (Etapa 4). |

## Instalação (sem privilégio de administrador)

Não é preciso instalar nada globalmente. Um ambiente virtual (`venv`) é
criado dentro do próprio usuário, sem precisar de permissão elevada:

```bash
# a partir da raiz do projeto (sales-analytics-platform/)
python -m venv .venv

# ativar o ambiente virtual
# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# Windows (cmd):
.venv\Scripts\activate.bat
# Linux/Mac:
source .venv/bin/activate

pip install -r requirements.txt
```

Se a criação do `venv` também for bloqueada pela política da máquina, use
`pip install --user -r requirements.txt` para instalar os pacotes só para o
seu usuário, sem tocar na instalação global do Python.

Depois, configure o `.env` (se ainda não tiver feito na Etapa 1):

```bash
cp ../.env.example ../.env
# edite ../.env e preencha DATABASE_URL com a connection string do Neon/Supabase
```

## Uso

```bash
cd scripts

# relatório dos últimos 30 dias (padrão), em CSV e JSON
python gerar_relatorios.py

# período explícito, só CSV, top 5 produtos
python gerar_relatorios.py --periodo 2025-01-01:2025-12-31 --formato csv --top 5

# atalhos de período
python gerar_relatorios.py --periodo mes-atual
python gerar_relatorios.py --periodo ano-atual

# filtrar o relatório de clientes por um único cliente
python gerar_relatorios.py --cliente-id 42

# logs detalhados (debug)
python gerar_relatorios.py --verbose
```

### Demonstração da integração com câmbio (Etapa 4)

```bash
python demo_cambio.py --periodo ultimos-30d --moeda USD
python demo_cambio.py --periodo mes-atual --moeda EUR
```

Chama a mesma `cambio.py` usada pela rota `/vendas/resumo/cambio` da API,
fora do contexto HTTP -- útil para testar a integração isoladamente ou
entender o fluxo sem precisar subir o servidor.

Os relatórios são salvos em `data/relatorios/` (criada automaticamente):
`resumo_vendas_*`, `top_produtos_*`, `clientes_*`, `categorias_*` (um par
`.csv`/`.json` cada, conforme `--formato`) e `resumo_executivo_*.json`.

### Argumentos

| Argumento       | Padrão          | Descrição                                                        |
|-----------------|-----------------|--------------------------------------------------------------------|
| `--periodo`     | `ultimos-30d`   | `ultimos-Nd`, `mes-atual`, `ano-atual` ou `AAAA-MM-DD:AAAA-MM-DD` |
| `--formato`     | `ambos`         | `csv`, `json` ou `ambos`                                          |
| `--top`         | `10`            | Quantidade de produtos no ranking de faturamento                  |
| `--cliente-id`  | (todos)         | Filtra o relatório de clientes por um ID específico                |
| `--saida`       | `data/relatorios` | Pasta de destino dos relatórios                                 |
| `--verbose`     | desativado      | Ativa logs em nível DEBUG                                          |

### Código de saída (para cron/agendador)

`0` sucesso · `1` erro de configuração, conexão ou consulta ao banco ·
`2` argumento de linha de comando inválido (ex.: `--periodo` mal formatado).

### Agendando a execução

**Linux/Mac (cron)**, todo dia às 7h:

```
0 7 * * * cd /caminho/para/sales-analytics-platform/scripts && /caminho/para/.venv/bin/python gerar_relatorios.py >> /caminho/para/logs/relatorios.log 2>&1
```

**Windows (Agendador de Tarefas)**: criar uma tarefa que executa
`...\.venv\Scripts\python.exe` com argumento
`...\scripts\gerar_relatorios.py --periodo ultimos-30d`, com "Iniciar em"
apontando para a pasta `scripts/`.
