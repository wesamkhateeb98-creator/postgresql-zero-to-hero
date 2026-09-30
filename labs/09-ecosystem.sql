-- Lab 08 — Ecosystem
-- Run: i /repo/labs/09-ecosystem.sql   (inside a transaction → rolled back at the end)
\timing on
BEGIN;

\echo '== 1. SQL function =='
CREATE FUNCTION user_total_spent(p_user bigint) RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT coalesce(sum(o.qty * p.price), 0)
    FROM orders o JOIN products p ON p.id = o.product_id
    WHERE o.user_id = p_user;
$$;
SELECT user_total_spent(42);

\echo '== 2. Audit trigger =='
CREATE TABLE price_audit (product_id bigint, old_price numeric, new_price numeric,
                          changed_at timestamptz DEFAULT now());
CREATE FUNCTION log_price_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.price IS DISTINCT FROM OLD.price THEN
        INSERT INTO price_audit (product_id, old_price, new_price)
        VALUES (OLD.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER products_price_audit AFTER UPDATE OF price ON products
FOR EACH ROW EXECUTE FUNCTION log_price_change();
UPDATE products SET price = price + 1 WHERE id IN (1, 2);
SELECT * FROM price_audit;

\echo '== 3. Materialized view =='
CREATE MATERIALIZED VIEW daily_sales AS
SELECT o.created_at::date AS day, count(*) AS orders, sum(o.qty * p.price) AS revenue
FROM orders o JOIN products p ON p.id = o.product_id
WHERE o.status <> 'cancelled' GROUP BY 1;
SELECT * FROM daily_sales ORDER BY day DESC LIMIT 7;

\echo '== 4. Top queries (pg_stat_statements) =='
SELECT calls, round(mean_exec_time::numeric, 2) AS avg_ms, left(query, 60) AS query
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 5;

\echo '== 5. Full-text search =='
CREATE TABLE articles (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, title text, body text,
    search tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(body,  '')), 'B')) STORED);
CREATE INDEX ON articles USING gin (search);
INSERT INTO articles (title, body) VALUES
  ('Running shoes guide', 'Best shoes for runners in 2026'),
  ('Postgres indexing', 'B-Tree, GIN and BRIN explained');
SELECT title, ts_rank(search, q) AS rank
FROM articles, websearch_to_tsquery('english', 'running shoe') q
WHERE search @@ q ORDER BY rank DESC;

ROLLBACK;

-- 🏋️ Exercises
-- a) Trigger that blocks stock < 0 with a clear message (RAISE EXCEPTION)
-- b) Materialized view of the top 10 selling products + REFRESH CONCURRENTLY
