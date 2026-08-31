-- =============================================================================
-- 03_stored_procedures.sql
-- Rotinas de métricas de negócio. No PostgreSQL, uma rotina que RETORNA um
-- result set é uma FUNCTION (RETURNS TABLE + RETURN QUERY), testada com
-- SELECT * FROM nome(...). CALL é reservado para PROCEDURE, que não devolve
-- linhas dessa forma -- por isso as 4 rotinas abaixo são funções.
--
-- Regra de negócio comum a todas: só entram no cálculo vendas com
-- status = 'concluida' (pendente/cancelada não representam faturamento real).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Resumo de vendas em um período
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_resumo_vendas_periodo(
    p_data_inicio DATE,
    p_data_fim    DATE
)
RETURNS TABLE (
    total_vendas       BIGINT,
    faturamento_total  NUMERIC,
    ticket_medio       NUMERIC,
    total_itens        BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_data_inicio > p_data_fim THEN
        RAISE EXCEPTION 'data_inicio (%) nao pode ser maior que data_fim (%)', p_data_inicio, p_data_fim;
    END IF;

    RETURN QUERY
    SELECT
        COUNT(DISTINCT v.id)::BIGINT,
        COALESCE(SUM(iv.quantidade * iv.preco_unitario), 0)::NUMERIC,
        -- ROUND para 2 casas: ticket_medio e um valor monetario, e a divisao
        -- raramente e exata (sem isso, o JSON sai com dizimas tipo 778.2881481481481).
        ROUND(COALESCE(SUM(iv.quantidade * iv.preco_unitario) / NULLIF(COUNT(DISTINCT v.id), 0), 0)::NUMERIC, 2),
        COALESCE(SUM(iv.quantidade), 0)::BIGINT
    FROM vendas v
    JOIN itens_venda iv ON iv.venda_id = v.id
    WHERE v.status = 'concluida'
      AND v.data_venda::date BETWEEN p_data_inicio AND p_data_fim;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2) Top produtos por faturamento em um período
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_top_produtos_faturamento(
    p_data_inicio DATE,
    p_data_fim    DATE,
    p_limite      INT DEFAULT 10
)
RETURNS TABLE (
    produto_id          INT,
    produto_nome        VARCHAR,
    categoria           VARCHAR,
    quantidade_vendida  BIGINT,
    faturamento         NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_data_inicio > p_data_fim THEN
        RAISE EXCEPTION 'data_inicio (%) nao pode ser maior que data_fim (%)', p_data_inicio, p_data_fim;
    END IF;

    IF p_limite <= 0 THEN
        RAISE EXCEPTION 'limite deve ser maior que zero (recebido: %)', p_limite;
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.nome,
        p.categoria,
        SUM(iv.quantidade)::BIGINT,
        SUM(iv.quantidade * iv.preco_unitario)::NUMERIC
    FROM itens_venda iv
    JOIN vendas v   ON v.id = iv.venda_id
    JOIN produtos p ON p.id = iv.produto_id
    WHERE v.status = 'concluida'
      AND v.data_venda::date BETWEEN p_data_inicio AND p_data_fim
    GROUP BY p.id, p.nome, p.categoria
    ORDER BY SUM(iv.quantidade * iv.preco_unitario) DESC
    LIMIT p_limite;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3) Faturamento e ticket médio por cliente (p_cliente_id NULL = todos)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_faturamento_ticket_medio_cliente(
    p_data_inicio DATE,
    p_data_fim    DATE,
    p_cliente_id  INT DEFAULT NULL
)
RETURNS TABLE (
    cliente_id         INT,
    cliente_nome       VARCHAR,
    total_compras      BIGINT,
    faturamento_total  NUMERIC,
    ticket_medio       NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_data_inicio > p_data_fim THEN
        RAISE EXCEPTION 'data_inicio (%) nao pode ser maior que data_fim (%)', p_data_inicio, p_data_fim;
    END IF;

    IF p_cliente_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM clientes c WHERE c.id = p_cliente_id) THEN
        RAISE EXCEPTION 'cliente_id % nao encontrado', p_cliente_id;
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.nome,
        COUNT(DISTINCT v.id)::BIGINT,
        COALESCE(SUM(iv.quantidade * iv.preco_unitario), 0)::NUMERIC,
        ROUND(COALESCE(SUM(iv.quantidade * iv.preco_unitario) / NULLIF(COUNT(DISTINCT v.id), 0), 0)::NUMERIC, 2)
    FROM clientes c
    JOIN vendas v       ON v.cliente_id = c.id
    JOIN itens_venda iv ON iv.venda_id = v.id
    WHERE v.status = 'concluida'
      AND v.data_venda::date BETWEEN p_data_inicio AND p_data_fim
      AND (p_cliente_id IS NULL OR c.id = p_cliente_id)
    GROUP BY c.id, c.nome
    ORDER BY SUM(iv.quantidade * iv.preco_unitario) DESC;
END;
$$;

-- -----------------------------------------------------------------------------
-- 4) Faturamento por categoria, com ranking via window function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_vendas_categoria_ranking(
    p_data_inicio DATE,
    p_data_fim    DATE
)
RETURNS TABLE (
    categoria          VARCHAR,
    faturamento_total  NUMERIC,
    ranking            BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_data_inicio > p_data_fim THEN
        RAISE EXCEPTION 'data_inicio (%) nao pode ser maior que data_fim (%)', p_data_inicio, p_data_fim;
    END IF;

    RETURN QUERY
    SELECT
        cat.categoria,
        cat.faturamento_total,
        RANK() OVER (ORDER BY cat.faturamento_total DESC) AS ranking
    FROM (
        SELECT
            p.categoria,
            SUM(iv.quantidade * iv.preco_unitario)::NUMERIC AS faturamento_total
        FROM itens_venda iv
        JOIN vendas v   ON v.id = iv.venda_id
        JOIN produtos p ON p.id = iv.produto_id
        WHERE v.status = 'concluida'
          AND v.data_venda::date BETWEEN p_data_inicio AND p_data_fim
        GROUP BY p.categoria
    ) cat
    ORDER BY ranking;
END;
$$;

-- -----------------------------------------------------------------------------
-- Testes rápidos (rodar manualmente no editor SQL após criar as funções acima)
-- -----------------------------------------------------------------------------
-- SELECT * FROM fn_resumo_vendas_periodo('2025-01-01', '2025-12-31');
-- SELECT * FROM fn_top_produtos_faturamento('2025-01-01', '2025-12-31', 5);
-- SELECT * FROM fn_faturamento_ticket_medio_cliente('2025-01-01', '2025-12-31');
-- SELECT * FROM fn_faturamento_ticket_medio_cliente('2025-01-01', '2025-12-31', 1);
-- SELECT * FROM fn_vendas_categoria_ranking('2025-01-01', '2025-12-31');
-- SELECT * FROM fn_resumo_vendas_periodo('2025-12-31', '2025-01-01'); -- deve lançar erro
