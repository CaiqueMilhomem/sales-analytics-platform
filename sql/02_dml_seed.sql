-- =============================================================================
-- 02_dml_seed.sql
-- Popula o banco com dados de exemplo: 300 clientes, 40 produtos, 4000 vendas
-- e seus itens (~1 a 4 itens por venda). Rodar DEPOIS de 01_ddl.sql, em um
-- banco vazio -- os geradores abaixo assumem que os IDs de clientes e produtos
-- são sequenciais a partir de 1 (nada mais foi inserido antes).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CLIENTES (300 registros)
-- Combina nome + sobrenome aleatórios e usa o número da linha para garantir
-- e-mail único, mesmo quando a combinação de nomes se repete.
-- -----------------------------------------------------------------------------
INSERT INTO clientes (nome, email, cidade, estado, data_cadastro)
SELECT
    nome_completo,
    lower(regexp_replace(nome_completo, '\s+', '.', 'g')) || '.' || n || '@email.com',
    cidade,
    estado,
    CURRENT_DATE - (random() * 1000)::int
FROM (
    SELECT
        n,
        (ARRAY['Ana','Bruno','Carla','Daniel','Eduarda','Felipe','Gabriela','Henrique',
               'Isabela','Joao','Karina','Lucas','Mariana','Nicolas','Otavio','Patricia',
               'Rafael','Sabrina','Tiago','Vanessa'])[1 + floor(random() * 20)] || ' ' ||
        (ARRAY['Silva','Souza','Oliveira','Santos','Pereira','Costa','Rodrigues','Almeida',
               'Nascimento','Lima','Araujo','Ferreira','Carvalho','Gomes','Martins','Rocha',
               'Ribeiro','Alves','Monteiro','Cardoso'])[1 + floor(random() * 20)] AS nome_completo,
        (ARRAY['Sao Paulo','Rio de Janeiro','Belo Horizonte','Curitiba','Porto Alegre',
               'Salvador','Recife','Fortaleza','Brasilia','Campinas'])[1 + floor(random() * 10)] AS cidade,
        (ARRAY['SP','RJ','MG','PR','RS','BA','PE','CE','DF','SP'])[1 + floor(random() * 10)] AS estado
    FROM generate_series(1, 300) AS n
) sub;

-- -----------------------------------------------------------------------------
-- PRODUTOS (40 registros, catálogo fixo cobrindo 8 categorias)
-- Catálogo explícito (não gerado aleatoriamente) para manter nomes e preços
-- plausíveis, já que "produto aleatório" costuma soar artificial demais.
-- -----------------------------------------------------------------------------
INSERT INTO produtos (nome, categoria, preco_unitario, ativo) VALUES
    ('Smartphone Galaxy A54',        'Eletronicos',       1899.90, TRUE),
    ('Fone de Ouvido Bluetooth',     'Eletronicos',        149.90, TRUE),
    ('Smart TV 50" 4K',              'Eletronicos',       2399.00, TRUE),
    ('Caixa de Som Portatil',        'Eletronicos',        229.90, TRUE),
    ('Carregador Turbo USB-C',       'Eletronicos',         59.90, TRUE),
    ('Notebook 15" i5 8GB',          'Informatica',        3299.00, TRUE),
    ('Mouse Sem Fio',                'Informatica',          69.90, TRUE),
    ('Teclado Mecanico',             'Informatica',         279.90, TRUE),
    ('Monitor 24" Full HD',          'Informatica',         899.00, TRUE),
    ('SSD 480GB',                    'Informatica',         289.90, TRUE),
    ('Webcam Full HD',               'Informatica',         189.90, TRUE),
    ('Roteador Wi-Fi 6',             'Informatica',         349.90, TRUE),
    ('Panela de Pressao Eletrica',   'Casa e Cozinha',      329.90, TRUE),
    ('Jogo de Panelas Antiaderente', 'Casa e Cozinha',      259.90, TRUE),
    ('Liquidificador',               'Casa e Cozinha',      179.90, TRUE),
    ('Cafeteira Eletrica',           'Casa e Cozinha',      219.90, TRUE),
    ('Air Fryer 4L',                 'Casa e Cozinha',      399.90, TRUE),
    ('Aspirador de Po Vertical',     'Casa e Cozinha',      449.90, TRUE),
    ('Jogo de Toalhas',              'Casa e Cozinha',       99.90, TRUE),
    ('Camiseta Basica Algodao',      'Moda',                 49.90, TRUE),
    ('Calca Jeans',                  'Moda',                159.90, TRUE),
    ('Jaqueta Corta-Vento',          'Moda',                189.90, TRUE),
    ('Tenis Casual',                 'Moda',                229.90, TRUE),
    ('Vestido Estampado',            'Moda',                139.90, TRUE),
    ('Bone Aba Reta',                'Moda',                 59.90, TRUE),
    ('Bicicleta Aro 29',             'Esporte e Lazer',    1299.00, TRUE),
    ('Bola de Futebol Oficial',      'Esporte e Lazer',      129.90, TRUE),
    ('Tapete de Yoga',               'Esporte e Lazer',       79.90, TRUE),
    ('Kit de Halteres 10kg',         'Esporte e Lazer',      199.90, TRUE),
    ('Barraca de Camping 4 Pessoas', 'Esporte e Lazer',      459.90, TRUE),
    ('Garrafa Termica 1L',           'Esporte e Lazer',       89.90, TRUE),
    ('Romance Best-Seller',          'Livros',                 44.90, TRUE),
    ('Livro Tecnico de Programacao', 'Livros',                 99.90, TRUE),
    ('Box Colecao Fantasia',         'Livros',                189.90, TRUE),
    ('Perfume Importado 100ml',      'Beleza',                289.90, TRUE),
    ('Kit Skincare Facial',          'Beleza',                159.90, TRUE),
    ('Secador de Cabelo',            'Beleza',                189.90, TRUE),
    ('Boneca Articulada',            'Brinquedos',             89.90, TRUE),
    ('Carrinho de Controle Remoto',  'Brinquedos',            179.90, TRUE),
    ('Quebra-Cabeca 1000 Pecas',     'Brinquedos',             69.90, TRUE);

-- -----------------------------------------------------------------------------
-- VENDAS (4000 registros)
-- cliente_id sorteado entre 1 e 300 (faixa de IDs dos clientes recém-criados),
-- data distribuída nos últimos 2 anos, status majoritariamente "concluida"
-- para simular uma operação real (a maioria fecha, uma fração cancela/pende).
-- -----------------------------------------------------------------------------
INSERT INTO vendas (cliente_id, data_venda, status)
SELECT
    1 + floor(random() * 300)::int,
    NOW() - (random() * INTERVAL '730 days'),
    CASE
        WHEN random() < 0.92 THEN 'concluida'
        WHEN random() < 0.97 THEN 'pendente'
        ELSE 'cancelada'
    END
FROM generate_series(1, 4000);

-- -----------------------------------------------------------------------------
-- ITENS_VENDA (~1 a 4 itens por venda, produto_id entre 1 e 40)
-- LATERAL gera, para cada venda, uma quantidade aleatória de itens; o preço
-- gravado é copiado do catálogo no momento do seed (é o "preço da venda").
-- -----------------------------------------------------------------------------
INSERT INTO itens_venda (venda_id, produto_id, quantidade, preco_unitario)
SELECT
    v.id,
    item.produto_id,
    item.quantidade,
    prod.preco_unitario
FROM vendas v
CROSS JOIN LATERAL (
    SELECT
        1 + floor(random() * 40)::int AS produto_id,
        1 + floor(random() * 5)::int  AS quantidade
    FROM generate_series(1, 1 + floor(random() * 4)::int)
) item
JOIN produtos prod ON prod.id = item.produto_id;

-- Conferência rápida de volume (rodar manualmente após o seed):
-- SELECT
--     (SELECT COUNT(*) FROM clientes)     AS total_clientes,
--     (SELECT COUNT(*) FROM produtos)     AS total_produtos,
--     (SELECT COUNT(*) FROM vendas)       AS total_vendas,
--     (SELECT COUNT(*) FROM itens_venda)  AS total_itens_venda;
