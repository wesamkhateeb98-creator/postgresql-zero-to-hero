-- Lab 04 — Indexes & Performance
-- Run: i /repo/labs/05-indexes-performance.sql
-- ⚠️ Creates real indexes; a DROP at the end (commented) restores the original state
\timing on

\echo '== 1. Before: seq scan =='
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE user_id = 42;

\echo '== 2. Add B-Tree =='
CREATE INDEX IF NOT EXISTS orders_user_id_idx ON orders (user_id);
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE user_id = 42;

\echo '== 3. Composite: filter + sort =='
CREATE INDEX IF NOT EXISTS orders_user_created_idx ON orders (user_id, created_at DESC);
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 42 ORDER BY created_at DESC LIMIT 5;

\echo '== 4. Partial index size vs full =='
CREATE INDEX IF NOT EXISTS orders_created_idx ON orders (created_at);
CREATE INDEX IF NOT EXISTS orders_pending_idx ON orders (created_at) WHERE status = 'pending';
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE relname = 'orders' ORDER BY 1;

\echo '== 5. Covering → Index Only Scan =='
CREATE INDEX IF NOT EXISTS orders_user_cov_idx ON orders (user_id) INCLUDE (qty, status);
VACUUM orders;
EXPLAIN ANALYZE SELECT qty, status FROM orders WHERE user_id = 42;

\echo '== 6. Expression index =='
CREATE INDEX IF NOT EXISTS users_email_lower_idx ON users (lower(email));
EXPLAIN ANALYZE SELECT * FROM users WHERE lower(email) = 'user42@shop.test';   -- rows=500 estimate ❌
ANALYZE users;                                                                  -- stats for the expression
EXPLAIN ANALYZE SELECT * FROM users WHERE lower(email) = 'user42@shop.test';   -- rows=1 ✅

-- 🧹 Cleanup (uncomment to reset)
-- DROP INDEX orders_user_id_idx, orders_user_created_idx, orders_created_idx,
--            orders_pending_idx, orders_user_cov_idx, users_email_lower_idx;

-- 🏋️ Exercises
-- a) An index for: last 10 pending orders of one product
-- b) Compare BRIN vs B-Tree on created_at (size + time)
-- c) Find unused indexes (pg_stat_user_indexes)
