-- =============================================================================
-- 07_staging_exemplo.sql
-- Carga de exemplo para testar a conciliacao (06_conciliacao.sql), cobrindo
-- os tres caminhos que a stored function precisa tratar:
--
--   PED-STG-0001: cliente e produtos JA EXISTENTES no catalogo (Etapa 1)
--                 -> testa o caminho de lookup puro, sem criar nada novo.
--   PED-STG-0002: cliente e produto NOVOS, com dados completos
--                 -> testa a criacao automatica de cliente/produto.
--   PED-STG-0003: cliente NOVO mas SEM NOME informado
--                 -> propositalmente incompleto, testa o bucket de erro.
--
-- Ver instrucoes de teste (incluindo o teste de idempotencia, carregando
-- esta mesma carga duas vezes) no README.md do projeto.
-- =============================================================================

INSERT INTO stg_vendas_pedidos
    (numero_pedido, numero_linha, data_venda, status,
     cliente_cpf, cliente_nome, cliente_email, cliente_cidade, cliente_estado,
     produto_sku, produto_nome, produto_categoria, quantidade, preco_unitario)
VALUES
    -- PED-STG-0001: cliente id=1 (cpf '00000000001') e produtos id=1 e id=6,
    -- todos ja existentes desde o seed da Etapa 1.
    ('PED-STG-0001', 1, NOW(), 'concluida',
     '00000000001', 'Cliente Existente Um', 'cliente1@email.com', 'Sao Paulo', 'SP',
     'SKU-000001', 'Smartphone Galaxy A54', 'Eletronicos', 1, 1899.90),
    ('PED-STG-0001', 2, NOW(), 'concluida',
     '00000000001', 'Cliente Existente Um', 'cliente1@email.com', 'Sao Paulo', 'SP',
     'SKU-000006', 'Notebook 15" i5 8GB', 'Informatica', 1, 3299.00),

    -- PED-STG-0002: cliente e produto novos, com dados completos -- a
    -- conciliacao deve cadastrar os dois automaticamente.
    ('PED-STG-0002', 1, NOW(), 'concluida',
     '11122233344', 'Cliente Novo Dois', 'clientenovo2@email.com', 'Curitiba', 'PR',
     'SKU-NOVO01', 'Produto Novo de Teste', 'Eletronicos', 2, 99.90),

    -- PED-STG-0003: cliente novo SEM NOME -- deve cair no bucket de erro,
    -- sem gerar cliente, venda ou item algum.
    ('PED-STG-0003', 1, NOW(), 'concluida',
     '99988877766', NULL, NULL, NULL, NULL,
     'SKU-000002', 'Fone de Ouvido Bluetooth', 'Eletronicos', 1, 149.90);
