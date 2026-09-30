-- Lab 01 — SQL Basics
-- Run: i /repo/labs/02-sql-basics.sql
\timing on
\echo '== 1. Top 5 cheap electronics =='
SELECT id, name, price FROM products
WHERE category = 'electronics' AND price < 100
ORDER BY price DESC LIMIT 5;

\echo '== 2. CRUD inside a rolled-back transaction =='
BEGIN;
INSERT INTO products (name, category, price, stock)
VALUES ('Keyboard', 'electronics', 49.90, 20) RETURNING id;
UPDATE products SET stock = stock - 1 WHERE name = 'Keyboard' RETURNING stock;
ROLLBACK;

\echo '== 3. Users with zero orders (anti-join) =='
SELECT count(*) AS users_without_orders
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

\echo '== 4. Revenue per status =='
SELECT o.status, count(*) AS orders, sum(o.qty * p.price) AS revenue
FROM orders o JOIN products p ON p.id = o.product_id
GROUP BY o.status ORDER BY revenue DESC;

\echo '== 5. FILTER =='
SELECT count(*) FILTER (WHERE status = 'paid')      AS paid,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled
FROM orders;

-- 🏋️ Exercises
-- a) Top 3 categories by units sold (sum qty)
-- b) Top 10 users by money spent in the last 30 days
-- c) Users per country who signed up in the last year
