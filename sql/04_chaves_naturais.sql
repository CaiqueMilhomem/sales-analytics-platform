-- =============================================================================
-- 04_chaves_naturais.sql
-- Adiciona chaves naturais de negocio as tabelas ja existentes (Etapa 1),
-- necessarias para reconciliar uma carga externa sem duplicar registros.
--
-- Como as tabelas ja tem dados (seed da Etapa 1), cada coluna e adicionada
-- SEM NOT NULL, populada com um valor de backfill, e so depois recebe a
-- constraint -- e assim que se adiciona uma coluna obrigatoria a uma tabela
-- que ja esta em uso, sem quebrar o que ja existe.
-- =============================================================================

-- ---- produtos.sku ----
ALTER TABLE produtos ADD COLUMN sku VARCHAR(30);

UPDATE produtos
SET sku = 'SKU-' || LPAD(id::text, 6, '0')
WHERE sku IS NULL;

ALTER TABLE produtos ALTER COLUMN sku SET NOT NULL;
ALTER TABLE produtos ADD CONSTRAINT uq_produtos_sku UNIQUE (sku);

-- ---- clientes.cpf ----
-- O valor de backfill abaixo (ID com zero a esquerda) e so um identificador
-- unico de exemplo -- nao e um CPF real nem passa pelo digito verificador.
-- Numa carga de producao o CPF viria do sistema de origem; aqui ele existe
-- so para dar a tabela uma chave natural de negocio.
ALTER TABLE clientes ADD COLUMN cpf CHAR(11);

UPDATE clientes
SET cpf = LPAD(id::text, 11, '0')
WHERE cpf IS NULL;

ALTER TABLE clientes ALTER COLUMN cpf SET NOT NULL;
ALTER TABLE clientes ADD CONSTRAINT uq_clientes_cpf UNIQUE (cpf);

-- ---- vendas.numero_pedido ----
ALTER TABLE vendas ADD COLUMN numero_pedido VARCHAR(20);

UPDATE vendas
SET numero_pedido = 'PED-' || LPAD(id::text, 8, '0')
WHERE numero_pedido IS NULL;

ALTER TABLE vendas ALTER COLUMN numero_pedido SET NOT NULL;
ALTER TABLE vendas ADD CONSTRAINT uq_vendas_numero_pedido UNIQUE (numero_pedido);

-- ---- itens_venda.numero_linha (unico por venda, nao globalmente) ----
ALTER TABLE itens_venda ADD COLUMN numero_linha INT;

-- Numera as linhas existentes de cada venda na ordem em que foram inseridas
-- (ROW_NUMBER particionado por venda_id), para dar um numero_linha valido a
-- itens que ja existiam antes desta coluna existir.
WITH numerado AS (
    SELECT id, ROW_NUMBER() OVER (PARTITION BY venda_id ORDER BY id) AS linha
    FROM itens_venda
)
UPDATE itens_venda iv
SET numero_linha = numerado.linha
FROM numerado
WHERE iv.id = numerado.id;

ALTER TABLE itens_venda ALTER COLUMN numero_linha SET NOT NULL;
ALTER TABLE itens_venda ADD CONSTRAINT uq_itens_venda_numero_linha UNIQUE (venda_id, numero_linha);

-- Conferencia rapida (rodar manualmente apos o script):
-- SELECT id, sku FROM produtos ORDER BY id LIMIT 5;
-- SELECT id, cpf FROM clientes ORDER BY id LIMIT 5;
-- SELECT id, numero_pedido FROM vendas ORDER BY id LIMIT 5;
-- SELECT venda_id, numero_linha FROM itens_venda ORDER BY venda_id, numero_linha LIMIT 5;
