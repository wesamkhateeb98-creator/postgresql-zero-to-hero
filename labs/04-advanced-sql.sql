-- Lab 03 — Advanced SQL
-- Run: i /repo/labs/04-advanced-sql.sql
BEGIN;

\echo '== 1. CTE: top 5 buyers last 30 days =='
WITH recent AS (
    SELECT user_id, sum(qty) AS items FROM orders
    WHERE created_at >= now() - interval '30 days' GROUP BY user_id
)
SELECT u.email, r.items FROM recent r JOIN users u ON u.id = r.user_id
ORDER BY r.items DESC LIMIT 5;

\echo '== 2. Recursive tree =='
CREATE TEMP TABLE categories (id int, parent_id int, name text);
INSERT INTO categories VALUES (1,NULL,'All'),(2,1,'Electronics'),(3,1,'Books'),(4,2,'Phones'),(5,4,'Android');
WITH RECURSIVE tree AS (
    SELECT id, name, 0 AS depth, name AS path FROM categories WHERE parent_id IS NULL
  UNION ALL
    SELECT c.id, c.name, t.depth + 1, t.path || ' > ' || c.name
    FROM categories c JOIN tree t ON c.parent_id = t.id
)
SELECT depth, path FROM tree ORDER BY path;

\echo '== 3. Window: top 3 per category =='
SELECT category, name, price FROM (
    SELECT category, name, price,
           row_number() OVER (PARTITION BY category ORDER BY price DESC) AS rn
    FROM products) x
WHERE rn <= 3;

\echo '== 4. JSONB =='
SELECT attrs ->> 'color' AS color, count(*) FROM products GROUP BY 1;
SELECT count(*) AS red FROM products WHERE attrs @> '{"color":"red"}';

\echo '== 5. UPSERT =='
CREATE TEMP TABLE cart (user_id bigint, product_id bigint, qty int NOT NULL,
                        PRIMARY KEY (user_id, product_id));
INSERT INTO cart VALUES (1, 10, 2)
ON CONFLICT (user_id, product_id) DO UPDATE SET qty = cart.qty + EXCLUDED.qty;
INSERT INTO cart VALUES (1, 10, 3)
ON CONFLICT (user_id, product_id) DO UPDATE SET qty = cart.qty + EXCLUDED.qty;
SELECT * FROM cart;   -- qty = 5

ROLLBACK;

-- 🏋️ Exercises
-- a) Per user: first and last order (first_value / last_value)
-- b) Monthly order growth % (lag)
-- c) Products with rating >= 4 and color = black using @>
