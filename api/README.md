# api/

API FastAPI que expõe as métricas de vendas (stored functions da Etapa 1,
acessadas via `scripts/metricas.py` da Etapa 2) como endpoints HTTP.

| Arquivo/pasta       | Responsabilidade                                                    |
|----------------------|----------------------------------------------------------------------|
| `main.py`            | Instância da app, CORS, handlers de erro e o health check (`GET /`). |
| `routers/vendas.py`  | `/vendas/resumo`, `/vendas/top-produtos`, `/vendas/por-categoria`, `/vendas/resumo/cambio`. |
| `routers/clientes.py`| `/clientes/top`.                                                     |
| `schemas.py`         | Modelos Pydantic das respostas.                                      |
| `dependencies.py`    | Validação dos parâmetros `periodo` e `moeda`, compartilhada pelas rotas. |
| `data_access.py`     | Ponte para `scripts/database.py`, `scripts/metricas.py` e `scripts/cambio.py`. |

## Instalação (mesmo ambiente virtual da Etapa 2)

Se ainda não tiver o `.venv` criado:

```bash
# a partir da raiz do projeto (sales-analytics-platform/)
python -m venv .venv
.venv\Scripts\Activate.ps1      # Windows PowerShell
# source .venv/bin/activate     # Linux/Mac

pip install -r requirements.txt
```

`requirements.txt` já inclui `fastapi` e `uvicorn[standard]` além das
dependências da Etapa 2. Se o `.venv` já existir, só rode o `pip install`
de novo para pegar as novas dependências.

Configure o `.env` (se ainda não tiver): copie `.env.example` para `.env` e
preencha `DATABASE_URL` com a connection string do Neon/Supabase.

## Rodando a API

**Execute sempre a partir da raiz do projeto** (`sales-analytics-platform/`),
não de dentro de `api/` -- é isso que faz o Python enxergar `api` como
pacote e resolver `api.main:app` corretamente:

```bash
uvicorn api.main:app --reload
```

Acesse a documentação interativa (Swagger) em **http://127.0.0.1:8000/docs**
-- todas as rotas abaixo podem ser testadas direto por ali, com formulário
de parâmetros e exemplo de resposta.

## Rotas e como testar

```bash
# Health check
curl http://127.0.0.1:8000/

# Resumo de vendas (periodo aceita: ultimos-Nd, mes-atual, ano-atual ou AAAA-MM-DD:AAAA-MM-DD)
curl "http://127.0.0.1:8000/vendas/resumo?periodo=ultimos-30d"

# Top produtos por faturamento
curl "http://127.0.0.1:8000/vendas/top-produtos?periodo=ano-atual&limite=5"

# Vendas por categoria, com ranking
curl "http://127.0.0.1:8000/vendas/por-categoria?periodo=mes-atual"

# Top clientes por faturamento
curl "http://127.0.0.1:8000/clientes/top?periodo=2025-01-01:2025-12-31&limite=10"

# Resumo de vendas convertido para dolar (Etapa 4 -- integracao com API de cambio)
curl "http://127.0.0.1:8000/vendas/resumo/cambio?periodo=ultimos-30d&moeda=USD"

# Teste de validação: periodo mal formatado deve devolver 422
curl -i "http://127.0.0.1:8000/vendas/resumo?periodo=formato-invalido"

# Teste de validação: codigo de moeda mal formatado deve devolver 422
curl -i "http://127.0.0.1:8000/vendas/resumo/cambio?moeda=xx"
```

Resultado esperado: `GET /` devolve `{"status": "ok", "servico": "sales-analytics-api"}`;
`/vendas/resumo` devolve um único objeto com `periodo`, `total_vendas`,
`faturamento_total`, `ticket_medio` e `total_itens`; `/vendas/top-produtos`,
`/vendas/por-categoria` e `/clientes/top` devolvem uma lista de objetos; o
teste de `periodo` inválido devolve HTTP 422 com o mesmo texto de erro usado
pelo CLI da Etapa 2. `/vendas/resumo/cambio` devolve o resumo de vendas em
BRL e convertido, mais o bloco `cotacao` (`valor`, `de_cache`,
`desatualizada`); um código de moeda mal formatado (ex.: `xx`) devolve 422
antes mesmo de tentar chamar a API externa. Se `DATABASE_URL` não estiver
configurada, qualquer rota que consulte o banco devolve HTTP 500 com uma
mensagem explicando o problema; se a API de câmbio estiver fora do ar e não
houver cotação em cache, `/vendas/resumo/cambio` devolve HTTP 503 -- em
nenhum dos dois casos o processo trava.

## Referência rápida das rotas

| Método | Rota                     | Parâmetros                             |
|--------|---------------------------|------------------------------------------|
| GET    | `/`                       | -                                        |
| GET    | `/vendas/resumo`          | `periodo`                                |
| GET    | `/vendas/top-produtos`    | `periodo`, `limite` (1-100, padrão 10)   |
| GET    | `/vendas/por-categoria`   | `periodo`                                |
| GET    | `/vendas/resumo/cambio`   | `periodo`, `moeda` (padrão `USD`)        |
| GET    | `/clientes/top`           | `periodo`, `limite` (1-100, padrão 10)   |
