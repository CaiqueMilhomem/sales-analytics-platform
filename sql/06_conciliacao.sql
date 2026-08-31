-- =============================================================================
-- 06_conciliacao.sql
-- Stored function de conciliacao: le as linhas pendentes de
-- stg_vendas_pedidos e aplica as regras de negocio para gravar em
-- clientes/produtos/vendas/itens_venda, pedido por pedido.
--
-- Idempotente: rodar a mesma carga duas vezes nao duplica nada em
-- vendas/itens_venda -- a chave natural (numero_pedido / venda_id+numero_linha)
-- garante isso via INSERT ... ON CONFLICT ... DO UPDATE.
--
-- Cada pedido roda dentro do seu proprio bloco BEGIN/EXCEPTION: se algo dele
-- falhar (cliente novo sem nome, produto novo sem preco, etc.), so aquele
-- pedido e desfeito (via savepoint implicito do PL/pgSQL) e marcado como
-- erro em staging -- os demais pedidos da carga continuam sendo processados
-- normalmente.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_conciliar_staging()
RETURNS TABLE (
    inseridos   INT,
    atualizados INT,
    ignorados   INT,
    erros       INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inseridos       INT := 0;
    v_atualizados     INT := 0;
    v_ignorados       INT := 0;
    v_erros           INT := 0;

    v_pedido          RECORD;
    v_linha           RECORD;
    v_pedidos_tocados TEXT[] := ARRAY[]::TEXT[];

    v_cliente_cpf     CHAR(11);
    v_cliente_nome    VARCHAR(150);
    v_cliente_email   VARCHAR(150);
    v_cliente_cidade  VARCHAR(100);
    v_cliente_estado  CHAR(2);
    v_data_venda      TIMESTAMP;
    v_status_venda    VARCHAR(20);

    v_cliente_id      INT;
    v_produto_id      INT;
    v_venda_id        INT;
    v_venda_ja_existia BOOLEAN;
BEGIN
    FOR v_pedido IN
        SELECT DISTINCT numero_pedido
        FROM stg_vendas_pedidos
        WHERE status_processamento = 'pendente'
    LOOP
        -- marca o pedido como "tocado" nesta execucao antes de tentar
        -- processa-lo, para nao contar de volta como ignorado la embaixo
        -- (uma linha antiga ja 'processado' do mesmo numero_pedido nao pode
        -- inflar o contador de ignorados quando o pedido acabou de ser
        -- reprocessado agora).
        v_pedidos_tocados := array_append(v_pedidos_tocados, v_pedido.numero_pedido);

        BEGIN
            -- dados de cabecalho do pedido: vem da primeira linha pendente
            SELECT cliente_cpf, cliente_nome, cliente_email, cliente_cidade,
                   cliente_estado, data_venda, status
            INTO v_cliente_cpf, v_cliente_nome, v_cliente_email, v_cliente_cidade,
                 v_cliente_estado, v_data_venda, v_status_venda
            FROM stg_vendas_pedidos
            WHERE numero_pedido = v_pedido.numero_pedido
              AND status_processamento = 'pendente'
            ORDER BY numero_linha
            LIMIT 1;

            -- 1) cliente: lookup por CPF (chave natural). Cria se nao existir
            -- e houver dado suficiente; sem nome, sinaliza para revisao.
            SELECT id INTO v_cliente_id FROM clientes WHERE cpf = v_cliente_cpf;

            IF v_cliente_id IS NULL THEN
                IF v_cliente_nome IS NULL OR trim(v_cliente_nome) = '' THEN
                    RAISE EXCEPTION
                        'cliente novo (cpf %) sem nome informado, requer revisao manual',
                        v_cliente_cpf;
                END IF;

                INSERT INTO clientes (nome, email, cidade, estado, cpf)
                VALUES (v_cliente_nome, v_cliente_email, v_cliente_cidade, v_cliente_estado, v_cliente_cpf)
                RETURNING id INTO v_cliente_id;
            END IF;

            -- 2) cabecalho da venda: upsert idempotente pela chave natural
            -- numero_pedido. v_venda_ja_existia so serve para contar
            -- inserido x atualizado no resumo -- quem garante a idempotencia
            -- de fato e o ON CONFLICT logo abaixo.
            SELECT EXISTS (
                SELECT 1 FROM vendas WHERE numero_pedido = v_pedido.numero_pedido
            ) INTO v_venda_ja_existia;

            INSERT INTO vendas (numero_pedido, cliente_id, data_venda, status)
            VALUES (v_pedido.numero_pedido, v_cliente_id, v_data_venda, v_status_venda)
            ON CONFLICT (numero_pedido) DO UPDATE
                SET cliente_id = EXCLUDED.cliente_id,
                    data_venda = EXCLUDED.data_venda,
                    status     = EXCLUDED.status
            RETURNING id INTO v_venda_id;

            -- 3) itens do pedido: cada linha resolve seu produto (mesma
            -- logica de lookup-ou-cria do cliente) e faz upsert do item.
            FOR v_linha IN
                SELECT *
                FROM stg_vendas_pedidos
                WHERE numero_pedido = v_pedido.numero_pedido
                  AND status_processamento = 'pendente'
            LOOP
                SELECT id INTO v_produto_id FROM produtos WHERE sku = v_linha.produto_sku;

                IF v_produto_id IS NULL THEN
                    IF v_linha.produto_nome IS NULL OR v_linha.preco_unitario IS NULL THEN
                        RAISE EXCEPTION
                            'produto sku % desconhecido e sem dados suficientes para cadastro',
                            v_linha.produto_sku;
                    END IF;

                    INSERT INTO produtos (nome, categoria, preco_unitario, sku)
                    VALUES (
                        v_linha.produto_nome,
                        COALESCE(v_linha.produto_categoria, 'Nao categorizado'),
                        v_linha.preco_unitario,
                        v_linha.produto_sku
                    )
                    RETURNING id INTO v_produto_id;
                END IF;

                INSERT INTO itens_venda (venda_id, produto_id, quantidade, preco_unitario, numero_linha)
                VALUES (v_venda_id, v_produto_id, v_linha.quantidade, v_linha.preco_unitario, v_linha.numero_linha)
                ON CONFLICT (venda_id, numero_linha) DO UPDATE
                    SET produto_id     = EXCLUDED.produto_id,
                        quantidade     = EXCLUDED.quantidade,
                        preco_unitario = EXCLUDED.preco_unitario;
            END LOOP;

            -- 4) fecha o pedido: marca staging como processado e atualiza o contador certo
            UPDATE stg_vendas_pedidos
            SET status_processamento = 'processado',
                processado_em = NOW(),
                mensagem_erro = NULL
            WHERE numero_pedido = v_pedido.numero_pedido
              AND status_processamento = 'pendente';

            IF v_venda_ja_existia THEN
                v_atualizados := v_atualizados + 1;
            ELSE
                v_inseridos := v_inseridos + 1;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            -- Desfaz qualquer insercao parcial deste pedido (cliente/produto
            -- novo, venda, itens) via savepoint implicito do PL/pgSQL, e
            -- segue para o proximo pedido -- um registro com problema nao
            -- pode travar o restante da carga.
            UPDATE stg_vendas_pedidos
            SET status_processamento = 'erro',
                mensagem_erro = SQLERRM,
                processado_em = NOW()
            WHERE numero_pedido = v_pedido.numero_pedido
              AND status_processamento = 'pendente';

            v_erros := v_erros + 1;
        END;
    END LOOP;

    -- Pedidos ja processados em uma chamada anterior e que esta execucao
    -- nem tentou tocar (nao havia nada pendente para eles) -- e o caso de
    -- rodar a conciliacao de novo sem recarregar staging: nada muda, e isso
    -- aparece aqui, nao como erro. O filtro "<> ALL (tocados)" exclui os
    -- pedidos que ESTA chamada acabou de reprocessar, para um pedido nunca
    -- ser contado como ignorado e atualizado ao mesmo tempo.
    SELECT COUNT(DISTINCT numero_pedido) INTO v_ignorados
    FROM stg_vendas_pedidos
    WHERE status_processamento = 'processado'
      AND numero_pedido <> ALL (v_pedidos_tocados);

    RETURN QUERY SELECT v_inseridos, v_atualizados, v_ignorados, v_erros;
END;
$$;

-- Teste rapido (rodar manualmente depois de carregar staging -- ver
-- 07_staging_exemplo.sql):
-- SELECT * FROM fn_conciliar_staging();
