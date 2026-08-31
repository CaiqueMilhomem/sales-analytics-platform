# Sales Analytics Platform

Pipeline de dados de vendas de e-commerce cobrindo o fluxo completo:
**SQL (consultas e stored procedures) → automação em Python → API com
FastAPI → integração com API externa → resposta JSON consolidada.**

## Visão geral

Uma loja virtual precisa, rotineiramente, de métricas de vendas: faturamento
por período, produtos mais vendidos, ticket médio por cliente, ranking de
categorias -- e, às vezes, esses números convertidos para outra moeda. Este
projeto resolve isso de ponta a ponta:

- **PostgreSQL** (Neon/Supabase) guarda os dados e concentra a regra de
  negócio (o que conta como faturamento) em stored functions, calculada uma
  única vez no banco.
- **Python** (`scripts/`) chama essas functions, transforma o resultado com
  `pandas` e gera relatórios em CSV/JSON, agendáveis via cron.
- **FastAPI** (`api/`) expõe as mesmas métricas como endpoints HTTP,
  documentados automaticamente, para que um dashboard não precise acessar o
  banco diretamente.
- **API externa** (câmbio, AwesomeAPI) enriquece o resumo de vendas com
  conversão de moeda em tempo real, com cache e fallback.
- **Ingestão e conciliação** (`sql/04` a `sql/07`) recebe cargas externas
  numa tabela de staging e reconcilia com o modelo de vendas por chave
  natural, de forma idempotente -- carregar a mesma carga duas vezes não
  duplica nada.

## Arquitetura

```mermaid
flowchart LR
    Cliente["Cliente HTTP\n(curl / navegador / dashboard)"]

    subgraph API["api/ (FastAPI)"]
        Rotas["/vendas/resumo\n/vendas/top-produtos\n/vendas/por-categoria\n/vendas/resumo/cambio\n/clientes/top"]
    end

    subgraph SCRIPTS["scripts/ (Python)"]
        Metricas["metricas.py"]
        Database["database.py"]
        Cambio["cambio.py"]
        CLI["gerar_relatorios.py\ndemo_cambio.py (CLI standalone)"]
    end

    subgraph DB["PostgreSQL (Neon / Supabase)"]
        Functions["fn_resumo_vendas_periodo\nfn_top_produtos_faturamento\nfn_faturamento_ticket_medio_cliente\nfn_vendas_categoria_ranking"]
    end

    Externa["AwesomeAPI\n(cotação de câmbio)"]

    Cliente --> Rotas
    Rotas --> Metricas
    Rotas -.-> Cambio
    CLI --> Metricas
    CLI -.-> Cambio
    Metricas --> Database --> Functions
    Cambio -.-> Externa
```

Cada camada só conhece a camada logo abaixo: a API não sabe como o Postgres
funciona, só chama `metricas.py`; `metricas.py` não sabe nada de HTTP, só
devolve `DataFrame`; a regra de negócio (o que é uma venda "concluída", como
calcular ticket médio) mora exclusivamente no banco. Essa separação é o que
permite reaproveitar `scripts/` tanto pelo CLI quanto pela API sem duplicar
lógica.

## Estrutura de pastas

```
sales-analytics-platform/
├── sql/                    # DDL, seed, stored functions e ingestão (Etapas 1 e 6)
│   ├── 01_ddl.sql
│   ├── 02_dml_seed.sql
│   ├── 03_stored_procedures.sql
│   ├── 04_chaves_naturais.sql   # chaves de negócio (sku/cpf/numero_pedido/numero_linha)
│   ├── 05_staging.sql           # tabela de landing para cargas externas
│   ├── 06_conciliacao.sql       # stored function de conciliação (upsert idempotente)
│   └── 07_staging_exemplo.sql   # carga de exemplo para testar a conciliação
├── scripts/                # Automação em Python (Etapas 2 e 4)
│   ├── database.py          # conexão com o Postgres
│   ├── metricas.py          # wrappers das stored functions -> DataFrame
│   ├── periodo.py           # validação do parâmetro de período (CLI + API)
│   ├── cambio.py            # integração com API de câmbio (cache + fallback)
│   ├── gerar_relatorios.py  # CLI: gera relatórios em CSV/JSON
│   ├── demo_cambio.py       # CLI: demonstra a integração de câmbio isolada
│   └── README.md
├── api/                     # API HTTP com FastAPI (Etapas 3 e 4)
│   ├── main.py               # app, CORS, handlers de erro, health check
│   ├── data_access.py        # ponte para scripts/
│   ├── dependencies.py       # validação de periodo/moeda (Depends)
│   ├── schemas.py            # modelos Pydantic das respostas
│   ├── routers/
│   │   ├── vendas.py
│   │   └── clientes.py
│   └── README.md
├── data/                    # Relatórios gerados (data/relatorios/, ignorado no git)
├── docs/
│   ├── estudo-completo.docx  # material de estudo completo do projeto
│   └── gerar_estudo.py       # gera o .docx acima a partir do código-fonte
├── requirements.txt
├── .env.example
└── README.md                # este arquivo
```

## Requisitos

- Python 3.11 ou superior.
- Uma conta gratuita no [Neon](https://neon.tech) ou [Supabase](https://supabase.com)
  (Postgres na nuvem -- não é necessário instalar Docker nem Postgres local).
- Não é necessário privilégio de administrador na máquina: tudo roda dentro
  de um ambiente virtual (`venv`) do próprio Python.

## Como executar do zero

### 1. Criar o banco de dados (Neon ou Supabase)

1. Crie uma conta e um novo projeto gratuito em [neon.tech](https://neon.tech)
   ou [supabase.com](https://supabase.com).
2. Abra o **SQL Editor** do navegador do serviço escolhido.
3. Cole e execute, **nesta ordem**, o conteúdo de cada arquivo:
   1. `sql/01_ddl.sql` -- cria as 4 tabelas (`clientes`, `produtos`, `vendas`, `itens_venda`).
   2. `sql/02_dml_seed.sql` -- popula ~300 clientes, 40 produtos, 4000 vendas e seus itens.
   3. `sql/03_stored_procedures.sql` -- cria as 4 stored functions de métricas.
   4. `sql/04_chaves_naturais.sql` -- adiciona sku/cpf/numero_pedido/numero_linha.
   5. `sql/05_staging.sql` -- cria a tabela de landing para cargas externas.
   6. `sql/06_conciliacao.sql` -- cria a stored function de conciliação.
4. Copie a connection string do painel do serviço (formato
   `postgresql://usuario:senha@host/banco?sslmode=require`).

Detalhes e queries de teste de cada function: `sql/03_stored_procedures.sql`.
Ingestão de cargas externas (staging + conciliação): ver seção
[Ingestão e conciliação de dados](#ingestão-e-conciliação-de-dados-etapa-6)
abaixo.

### 2. Configurar o ambiente

```bash
# a partir da raiz do projeto
cp .env.example .env
# edite .env e preencha DATABASE_URL com a connection string copiada acima

python -m venv .venv

# Windows (PowerShell)
.venv\Scripts\Activate.ps1
# Linux/Mac
# source .venv/bin/activate

pip install -r requirements.txt
```

Se a criação do `venv` for bloqueada pela política da máquina, use
`pip install --user -r requirements.txt` no lugar do bloco acima -- instala
os pacotes só para o seu usuário, sem precisar de privilégio de administrador
nem tocar na instalação global do Python.

### 3. Rodar os scripts de automação (Etapas 2 e 4)

```bash
cd scripts

# gera relatorios de vendas em CSV/JSON (ver scripts/README.md para todos os argumentos)
python gerar_relatorios.py --periodo ultimos-30d --formato ambos

# demonstra a integracao com a API de cambio, fora do contexto HTTP
python demo_cambio.py --periodo ultimos-30d --moeda USD
```

Os relatórios são salvos em `data/relatorios/`.

### 4. Subir a API (Etapas 3 e 4)

Execute a partir da **raiz do projeto** (não de dentro de `api/`):

```bash
uvicorn api.main:app --reload
```

Abra **http://127.0.0.1:8000/docs** para a documentação interativa (Swagger),
onde cada rota pode ser testada diretamente pelo navegador.

## Exemplos de uso da API

```bash
# Health check
curl http://127.0.0.1:8000/

# Resumo de vendas do período (aceita: ultimos-Nd, mes-atual, ano-atual, AAAA-MM-DD:AAAA-MM-DD)
curl "http://127.0.0.1:8000/vendas/resumo?periodo=ultimos-30d"

# Top 5 produtos por faturamento
curl "http://127.0.0.1:8000/vendas/top-produtos?periodo=ano-atual&limite=5"

# Vendas por categoria, com ranking
curl "http://127.0.0.1:8000/vendas/por-categoria?periodo=mes-atual"

# Top 10 clientes por faturamento
curl "http://127.0.0.1:8000/clientes/top?periodo=2025-01-01:2025-12-31"

# Resumo de vendas convertido para dolar (integracao com API externa de cambio)
curl "http://127.0.0.1:8000/vendas/resumo/cambio?periodo=ultimos-30d&moeda=USD"
```

**Resposta esperada de `/vendas/resumo/cambio`** (valores variam com o banco
e a cotação do momento):

```json
{
  "periodo": { "inicio": "2026-07-29", "fim": "2026-08-28" },
  "total_vendas": 120,
  "faturamento_total_brl": 45230.5,
  "faturamento_total_convertido": 8719.64,
  "ticket_medio_brl": 376.92,
  "ticket_medio_convertido": 72.66,
  "total_itens": 310,
  "cotacao": {
    "moeda_origem": "USD",
    "moeda_destino": "BRL",
    "valor": 5.1872,
    "de_cache": false,
    "desatualizada": false
  }
}
```

Referência completa das rotas, parâmetros e códigos de erro: `api/README.md`.

## Referência rápida das rotas

| Método | Rota                    | Parâmetros                             |
|--------|--------------------------|------------------------------------------|
| GET    | `/`                      | -                                        |
| GET    | `/vendas/resumo`         | `periodo`                                |
| GET    | `/vendas/top-produtos`   | `periodo`, `limite` (1-100, padrão 10)   |
| GET    | `/vendas/por-categoria`  | `periodo`                                |
| GET    | `/vendas/resumo/cambio`  | `periodo`, `moeda` (padrão `USD`)        |
| GET    | `/clientes/top`          | `periodo`, `limite` (1-100, padrão 10)   |

## Ingestão e conciliação de dados (Etapa 6)

`sql/04` a `sql/07` implementam uma camada de ingestão: uma carga externa cai
crua numa tabela de staging (`stg_vendas_pedidos`, sem regra de negócio
aplicada) e uma stored function de conciliação (`fn_conciliar_staging`)
decide o que fazer com cada linha -- criar cliente/produto novo, atualizar um
pedido já existente, ou sinalizar erro -- usando as chaves naturais de
negócio (`sku`, `cpf`, `numero_pedido`, `numero_linha`) para nunca duplicar.

### Rodar (depois de `01` a `03` já estarem aplicados)

No SQL Editor do Neon/Supabase, nesta ordem:

```sql
-- 1) chaves naturais nas tabelas existentes
--    (colar o conteúdo de sql/04_chaves_naturais.sql)

-- 2) tabela de staging
--    (colar o conteúdo de sql/05_staging.sql)

-- 3) stored function de conciliação
--    (colar o conteúdo de sql/06_conciliacao.sql)

-- 4) carga de exemplo (3 pedidos: cliente/produto existentes, novos, e um
--    incompleto de propósito para testar o caminho de erro)
--    (colar o conteúdo de sql/07_staging_exemplo.sql)

-- 5) rodar a conciliação
SELECT * FROM fn_conciliar_staging();
```

**Resultado esperado da primeira chamada:**
`inseridos = 2, atualizados = 0, ignorados = 0, erros = 1`
(`PED-STG-0001` e `PED-STG-0002` inseridos; `PED-STG-0003` cai em erro por
falta de nome do cliente -- confira com
`SELECT numero_pedido, mensagem_erro FROM stg_vendas_pedidos WHERE status_processamento = 'erro';`).

### Teste 1 -- idempotência ao repetir a mesma carga

```sql
-- quantos pedidos/itens existem antes de repetir a carga
SELECT COUNT(*) FROM vendas WHERE numero_pedido LIKE 'PED-STG-%';       -- 2
SELECT COUNT(*) FROM itens_venda iv JOIN vendas v ON v.id = iv.venda_id
WHERE v.numero_pedido LIKE 'PED-STG-%';                                  -- 3

-- recarrega a MESMA carga (colar sql/07_staging_exemplo.sql de novo)
-- e reconcilia de novo
SELECT * FROM fn_conciliar_staging();
-- esperado: inseridos = 0, atualizados = 2, ignorados = 0, erros = 1

-- os totais em vendas/itens_venda NÃO devem ter mudado:
SELECT COUNT(*) FROM vendas WHERE numero_pedido LIKE 'PED-STG-%';       -- continua 2
SELECT COUNT(*) FROM itens_venda iv JOIN vendas v ON v.id = iv.venda_id
WHERE v.numero_pedido LIKE 'PED-STG-%';                                  -- continua 3
```

### Teste 2 -- chamar a conciliação sem recarregar staging

```sql
SELECT * FROM fn_conciliar_staging();
-- esperado: inseridos = 0, atualizados = 0, ignorados = 2, erros = 0
-- (PED-STG-0003 nao entra em nenhum dos 4 buckets aqui: ele ficou marcado
--  'erro' na tentativa anterior, entao nao esta mais 'pendente' e a funcao
--  nao volta a tentá-lo sozinha. Só é reprocessado quando uma carga NOVA
--  chega para aquele numero_pedido -- por isso "ignorados" conta só pedidos
--  que JA deram certo antes, nunca os que deram erro.)
```

Explicação conceitual completa (chave natural vs surrogada, staging/landing,
upsert, idempotência, CDC simplificado com watermark): `docs/estudo-completo.docx`.

## Documentação de estudo

`docs/estudo-completo.docx` documenta o projeto inteiro etapa a etapa: cada
arquivo, cada bloco de código explicado em linguagem clara, os conceitos de
SQL/PL-pgSQL, automação em Python, FastAPI/Pydantic e integração com API
externa, e o fluxo completo dos dados (banco → stored functions → Python →
FastAPI → API externa → JSON). É gerado por `docs/gerar_estudo.py` -- para
regenerar após uma mudança no código, rode `python docs/gerar_estudo.py` a
partir da pasta `docs/`.

## Documentação por camada

- `sql/03_stored_procedures.sql` -- comentários e queries de teste de cada stored function.
- `sql/06_conciliacao.sql` -- comentários da stored function de conciliação (ingestão/idempotência).
- `scripts/README.md` -- todos os argumentos de CLI, agendamento (cron/Agendador de Tarefas) e códigos de saída.
- `api/README.md` -- todas as rotas, exemplos de `curl` e referência de erros.
