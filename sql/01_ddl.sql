-- =============================================================================
-- 01_ddl.sql
-- Modelagem do banco de vendas: clientes, produtos, vendas e itens_venda.
-- Rodar este script uma única vez, no editor SQL do Neon/Supabase, para criar
-- o schema do zero. Se precisar recriar do zero, dropar as tabelas na ordem
-- inversa das dependências (itens_venda -> vendas -> produtos -> clientes).
--
-- Este arquivo é a "foto do dia 1" do schema -- não o estado atual. Colunas
-- adicionadas depois (chaves naturais: sku, cpf, numero_pedido, numero_linha)
-- vivem em sql/04_chaves_naturais.sql, aplicado por cima deste. Isso é
-- proposital: um DDL já aplicado em produção não se reescreve, se evolui com
-- um novo script -- ver o comentário no topo de 04_chaves_naturais.sql.
-- =============================================================================

-- Descomente para recriar o banco do zero (cuidado, apaga tudo)
-- DROP TABLE IF EXISTS itens_venda CASCADE;
-- DROP TABLE IF EXISTS vendas CASCADE;
-- DROP TABLE IF EXISTS produtos CASCADE;
-- DROP TABLE IF EXISTS clientes CASCADE;

CREATE TABLE clientes (
    id             SERIAL PRIMARY KEY,
    nome           VARCHAR(150) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    cidade         VARCHAR(100),
    estado         CHAR(2),
    data_cadastro  DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE produtos (
    id              SERIAL PRIMARY KEY,
    nome            VARCHAR(150) NOT NULL,
    categoria       VARCHAR(80) NOT NULL,
    preco_unitario  NUMERIC(10, 2) NOT NULL CHECK (preco_unitario > 0),
    ativo           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE vendas (
    id          SERIAL PRIMARY KEY,
    cliente_id  INTEGER NOT NULL REFERENCES clientes(id),
    data_venda  TIMESTAMP NOT NULL DEFAULT NOW(),
    status      VARCHAR(20) NOT NULL DEFAULT 'concluida'
                CHECK (status IN ('concluida', 'pendente', 'cancelada'))
);

-- preco_unitario aqui é o preço praticado NA VENDA (snapshot), separado do
-- preco_unitario de produtos, que é o preço atual do catálogo. Isso evita que
-- uma alteração futura de preço distorça o faturamento histórico.
CREATE TABLE itens_venda (
    id              SERIAL PRIMARY KEY,
    venda_id        INTEGER NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
    produto_id      INTEGER NOT NULL REFERENCES produtos(id),
    quantidade      INTEGER NOT NULL CHECK (quantidade > 0),
    preco_unitario  NUMERIC(10, 2) NOT NULL CHECK (preco_unitario > 0)
);

-- Índices para as consultas mais comuns: filtro por período, agregação por
-- cliente/produto e join entre vendas e itens_venda.
CREATE INDEX idx_vendas_data_venda ON vendas (data_venda);
CREATE INDEX idx_vendas_cliente_id ON vendas (cliente_id);
CREATE INDEX idx_itens_venda_venda_id ON itens_venda (venda_id);
CREATE INDEX idx_itens_venda_produto_id ON itens_venda (produto_id);
