-- Lab 07 — Ops & Scaling
-- Run: \i /repo/07-ops-scaling/lab.sql   (كله داخل transaction → rollback بالآخر)
BEGIN;

\echo '== 1. Read-only role =='
CREATE ROLE lab_ro NOLOGIN;
GRANT USAGE ON SCHEMA public TO lab_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lab_ro;
SET ROLE lab_ro;
SELECT count(*) FROM products;               -- ✅
SAVEPOINT s;
DELETE FROM products WHERE id = 1;           -- ❌ permission denied
ROLLBACK TO s;
RESET ROLE;

\echo '== 2. RLS =='
CREATE ROLE lab_api NOLOGIN;
GRANT SELECT ON orders TO lab_api;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY lab_orders_owner ON orders
    USING (user_id = current_setting('app.user_id')::bigint);
SET app.user_id = '42';
SET ROLE lab_api;
SELECT count(*) AS visible_orders, count(DISTINCT user_id) AS users FROM orders;
RESET ROLE;

\echo '== 3. Partitioning + pruning =='
CREATE TABLE events (
    id bigint GENERATED ALWAYS AS IDENTITY,
    user_id bigint NOT NULL,
    type text NOT NULL,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
CREATE TABLE events_2026_08 PARTITION OF events FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE events_2026_09 PARTITION OF events FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE events_default PARTITION OF events DEFAULT;
INSERT INTO events (user_id, type, created_at)
SELECT g % 1000, 'click', '2026-08-01'::timestamptz + (g % 60) * interval '1 day'
FROM generate_series(1, 100000) g;
SELECT tableoid::regclass AS partition, count(*) FROM events GROUP BY 1 ORDER BY 1;
EXPLAIN SELECT * FROM events WHERE created_at >= '2026-09-10';

ROLLBACK;

-- 🏋️ Exercises
-- a) pg_dump لجدول products فقط ثم restore لـ DB جديدة (شوف docs/02)
-- b) partition بالـ LIST على country لجدول users_copy
