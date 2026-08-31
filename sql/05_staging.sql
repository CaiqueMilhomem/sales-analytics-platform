-- =============================================================================
-- 05_staging.sql
-- Tabela de staging (landing): recebe os dados crus de uma carga externa, uma
-- linha por item de pedido, sem nenhuma regra de negocio aplicada -- de
-- proposito, nao ha FOREIGN KEY para clientes/produtos/vendas aqui. Quem
-- decide o que fazer com cada linha (criar cliente/produto novo, atualizar
-- pedido existente, ou sinalizar erro) e a stored function de conciliacao
-- (06_conciliacao.sql), nao esta tabela.
-- =============================================================================

CREATE TABLE stg_vendas_pedidos (
    id                    BIGSERIAL PRIMARY KEY,

    -- identificacao do pedido/linha na origem (chaves naturais)
    numero_pedido         VARCHAR(20)    NOT NULL,
    numero_linha          INT            NOT NULL,

    -- dados de cabecalho do pedido -- repetidos em cada linha do mesmo
    -- pedido, como costuma vir de um extrato/CSV "achatado" de um sistema
    -- externo (uma linha por item, sem tabelas separadas)
    data_venda            TIMESTAMP      NOT NULL,
    status                VARCHAR(20)    NOT NULL,

    -- dados do cliente como vieram na origem -- podem estar incompletos;
    -- so o CPF (a chave de busca) e exigido aqui
    cliente_cpf           CHAR(11)       NOT NULL,
    cliente_nome          VARCHAR(150),
    cliente_email         VARCHAR(150),
    cliente_cidade        VARCHAR(100),
    cliente_estado        CHAR(2),

    -- dados do produto como vieram na origem -- mesma logica: so o SKU e exigido
    produto_sku           VARCHAR(30)    NOT NULL,
    produto_nome          VARCHAR(150),
    produto_categoria     VARCHAR(80),

    quantidade            INTEGER        NOT NULL,
    preco_unitario        NUMERIC(10, 2) NOT NULL,

    -- controle do processo de ingestao em si (metadado tecnico, nao dado de negocio)
    carregado_em          TIMESTAMP      NOT NULL DEFAULT NOW(),
    processado_em         TIMESTAMP,
    status_processamento  VARCHAR(20)    NOT NULL DEFAULT 'pendente'
                           CHECK (status_processamento IN ('pendente', 'processado', 'erro')),
    mensagem_erro         TEXT
);

CREATE INDEX idx_stg_pedido_status ON stg_vendas_pedidos (numero_pedido, status_processamento);
