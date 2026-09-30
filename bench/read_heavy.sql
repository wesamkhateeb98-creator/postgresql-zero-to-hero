-- pgbench script: last 20 orders of a random user (read path)
\set uid random(1, 100000)
SELECT o.id, p.name, o.qty, o.created_at
FROM orders o
JOIN products p ON p.id = o.product_id
WHERE o.user_id = :uid
ORDER BY o.created_at DESC
LIMIT 20;
