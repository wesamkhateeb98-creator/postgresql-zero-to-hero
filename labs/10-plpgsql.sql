-- Lab 10 — PL/pgSQL
-- Run: \i /repo/labs/10-plpgsql.sql
-- Parts 1–3 and 5–7 run inside a transaction and are rolled back.
-- Part 4 (procedure with COMMIT) must run outside a transaction; it cleans up after itself.
\timing off

BEGIN;

\echo '== 1. Basics: DECLARE, %ROWTYPE, IF, CASE =='
DO $$
DECLARE
    v_status text := 'paid';
    v_count  bigint;
    v_user   users%ROWTYPE;
BEGIN
    SELECT count(*) INTO v_count FROM orders WHERE status = v_status;
    SELECT * INTO v_user FROM users WHERE id = 42;
    RAISE NOTICE 'paid orders = %, user 42 = % (%)', v_count, v_user.email, v_user.country;
    IF v_count > 200000 THEN RAISE NOTICE 'busy'; ELSE RAISE NOTICE 'quiet'; END IF;
    CASE v_user.country
        WHEN 'JO', 'PS' THEN RAISE NOTICE 'Levant';
        WHEN 'SA', 'AE' THEN RAISE NOTICE 'Gulf';
        ELSE RAISE NOTICE 'other';
    END CASE;
END $$;

\echo '== 1b. INTO STRICT (expect ERROR: query returned no rows) =='
SAVEPOINT s1;
DO $$ DECLARE v_id bigint; BEGIN
    SELECT id INTO STRICT v_id FROM users WHERE id = -1;
END $$;
ROLLBACK TO s1;

\echo '== 2. Loop vs set-based (50K rows) =='
CREATE TEMP TABLE o_loop AS SELECT id, qty FROM orders WHERE id <= 50000;
CREATE TEMP TABLE o_set  AS SELECT id, qty FROM orders WHERE id <= 50000;
ALTER TABLE o_loop ADD PRIMARY KEY (id);
ALTER TABLE o_set  ADD PRIMARY KEY (id);
\timing on
DO $$ DECLARE r record; BEGIN
    FOR r IN SELECT id FROM o_loop LOOP
        UPDATE o_loop SET qty = qty + 1 WHERE id = r.id;
    END LOOP;
END $$;
UPDATE o_set SET qty = qty + 1;
\timing off
SELECT (SELECT sum(qty) FROM o_loop) = (SELECT sum(qty) FROM o_set) AS same_result;

\echo '== 3. Functions: RETURNS TABLE, OUT params, SETOF =='
CREATE FUNCTION top_products(p_category text, p_limit int DEFAULT 3)
RETURNS TABLE (product_id bigint, name text, units bigint)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.name, sum(o.qty)::bigint
    FROM products p JOIN orders o ON o.product_id = p.id
    WHERE p.category = p_category
    GROUP BY p.id, p.name ORDER BY 3 DESC LIMIT p_limit;
END $$;
SELECT * FROM top_products('books');
SELECT * FROM top_products(p_category => 'toys', p_limit => 2);

CREATE FUNCTION price_stats(p_category text,
    OUT min_price numeric, OUT max_price numeric, OUT avg_price numeric)
LANGUAGE sql STABLE AS $$
    SELECT min(price), max(price), round(avg(price), 2) FROM products WHERE category = p_category;
$$;
SELECT * FROM price_stats('electronics');

CREATE FUNCTION even_numbers(p_max int) RETURNS SETOF int
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    FOR i IN 1..p_max LOOP
        IF i % 2 = 0 THEN RETURN NEXT i; END IF;
    END LOOP;
END $$;
SELECT array_agg(n) FROM even_numbers(10) n;

\echo '== 5. Errors: RAISE with ERRCODE/HINT, EXCEPTION WHEN =='
CREATE FUNCTION place_order(p_user bigint, p_product bigint, p_qty int)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_stock int; v_id bigint;
BEGIN
    SELECT stock INTO v_stock FROM products WHERE id = p_product FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'product % not found', p_product USING ERRCODE = 'no_data_found';
    END IF;
    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'insufficient stock for product %: have %, need %', p_product, v_stock, p_qty
              USING ERRCODE = 'P0001', HINT = 'reduce qty or restock';
    END IF;
    UPDATE products SET stock = stock - p_qty WHERE id = p_product;
    INSERT INTO orders (user_id, product_id, qty) VALUES (p_user, p_product, p_qty) RETURNING id INTO v_id;
    RETURN v_id;
END $$;
SELECT place_order(1, 1, 2) > 0 AS order_placed;
SAVEPOINT s2;
SELECT place_order(1, 1, 10000000);            -- expect ERROR + HINT
ROLLBACK TO s2;

DO $$
DECLARE v_state text; v_detail text; v_constraint text;
BEGIN
    BEGIN
        INSERT INTO users (email, name, country) VALUES ('user1@shop.test', 'dup', 'JO');
    EXCEPTION WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_detail = PG_EXCEPTION_DETAIL,
                                v_constraint = CONSTRAINT_NAME;
        RAISE NOTICE 'caught % on % → %', v_state, v_constraint, v_detail;
    END;
    RAISE NOTICE 'block continues';
END $$;

\echo '== 5b. Cost of EXCEPTION blocks (200K iterations) =='
\timing on
DO $$ DECLARE s bigint := 0; BEGIN
    FOR i IN 1..200000 LOOP s := s + i; END LOOP; END $$;
DO $$ DECLARE s bigint := 0; BEGIN
    FOR i IN 1..200000 LOOP BEGIN s := s + i; EXCEPTION WHEN OTHERS THEN NULL; END; END LOOP; END $$;
\timing off

\echo '== 6. Dynamic SQL: format(%I) + USING vs concatenation =='
CREATE FUNCTION count_where(p_table text, p_column text, p_value text)
RETURNS bigint LANGUAGE plpgsql STABLE AS $$
DECLARE v_n bigint;
BEGIN
    EXECUTE format('SELECT count(*) FROM %I WHERE %I = $1', p_table, p_column) INTO v_n USING p_value;
    RETURN v_n;
END $$;
CREATE FUNCTION count_where_bad(p_table text, p_column text, p_value text)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_n bigint;
BEGIN
    EXECUTE 'SELECT count(*) FROM ' || p_table || ' WHERE ' || p_column || ' = ''' || p_value || ''''
    INTO v_n;
    RETURN v_n;
END $$;
SELECT count_where('users', 'email', $$x' OR '1'='1$$)     AS safe,      -- 0
       count_where_bad('users', 'email', $$x' OR '1'='1$$) AS injected;  -- 100000

\echo '== 7. Triggers: BEFORE normalize/validate, AFTER audit, overhead =='
CREATE TEMP TABLE t_prod AS SELECT id, name, price, stock FROM products;
ALTER TABLE t_prod ADD PRIMARY KEY (id), ADD COLUMN updated_at timestamptz;
CREATE TEMP TABLE audit_log (
    id bigint GENERATED ALWAYS AS IDENTITY, table_name text, op text, row_id bigint,
    old_row jsonb, new_row jsonb, at timestamptz DEFAULT now());

CREATE FUNCTION trg_before_product() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.name := initcap(trim(NEW.name));
    NEW.updated_at := now();
    IF NEW.price <= 0 THEN RAISE EXCEPTION 'price must be > 0 (got %)', NEW.price; END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER t_prod_before BEFORE INSERT OR UPDATE ON t_prod
FOR EACH ROW EXECUTE FUNCTION trg_before_product();
UPDATE t_prod SET name = '  super keyboard ' WHERE id = 1 RETURNING id, name;
SAVEPOINT s3;
UPDATE t_prod SET price = 0 WHERE id = 1;       -- expect ERROR
ROLLBACK TO s3;
DROP TRIGGER t_prod_before ON t_prod;

CREATE FUNCTION trg_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit_log (table_name, op, row_id, old_row, new_row)
    VALUES (TG_TABLE_NAME, TG_OP, COALESCE(NEW.id, OLD.id),
            CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END);
    RETURN NULL;
END $$;

\timing on
UPDATE t_prod SET stock = stock + 1;             -- no trigger
\timing off
CREATE TRIGGER t_prod_audit AFTER INSERT OR UPDATE OR DELETE ON t_prod
FOR EACH ROW EXECUTE FUNCTION trg_audit();
\timing on
UPDATE t_prod SET stock = stock + 1;             -- row-level audit
\timing off
SELECT op, count(*) FROM audit_log GROUP BY op;

ROLLBACK;

\echo '== 4. Procedure with COMMIT per batch (outside a transaction) =='
DROP TABLE IF EXISTS lab_orders_copy, lab_orders_archive;
CREATE TABLE lab_orders_copy AS SELECT * FROM orders WHERE id <= 200000;
CREATE INDEX ON lab_orders_copy (created_at);
CREATE TABLE lab_orders_archive (LIKE orders);

CREATE OR REPLACE PROCEDURE lab_archive_orders(p_before timestamptz, p_batch int DEFAULT 10000)
LANGUAGE plpgsql AS $$
DECLARE v_moved int; v_total int := 0;
BEGIN
    LOOP
        WITH moved AS (
            DELETE FROM lab_orders_copy
            WHERE id IN (SELECT id FROM lab_orders_copy WHERE created_at < p_before LIMIT p_batch)
            RETURNING *
        )
        INSERT INTO lab_orders_archive SELECT * FROM moved;
        GET DIAGNOSTICS v_moved = ROW_COUNT;
        v_total := v_total + v_moved;
        COMMIT;
        RAISE NOTICE 'batch moved %, total %', v_moved, v_total;
        EXIT WHEN v_moved < p_batch;
    END LOOP;
END $$;

\timing on
CALL lab_archive_orders(now() - interval '300 days', 10000);
\timing off
SELECT (SELECT count(*) FROM lab_orders_archive) AS archived,
       (SELECT count(*) FROM lab_orders_copy)    AS remaining;

\echo '== 4b. Same CALL inside BEGIN (expect ERROR: invalid transaction termination) =='
BEGIN;
CALL lab_archive_orders(now() - interval '200 days', 10000);
ROLLBACK;

DROP PROCEDURE lab_archive_orders;
DROP TABLE lab_orders_copy, lab_orders_archive;

-- 🏋️ Exercises
-- a) Function orders_between(p_from date, p_to date) RETURNS TABLE (day date, orders bigint)
-- b) BEFORE trigger on orders that rejects qty > 50 with ERRCODE 'P0001' and a HINT
-- c) Procedure that runs VACUUM ANALYZE on every table in public via EXECUTE format('%I')
--    (hint: VACUUM can't run inside a function or a procedure's transaction — find out why)
