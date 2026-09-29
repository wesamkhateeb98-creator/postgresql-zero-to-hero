-- pgbench script: checkout transaction (write path)
\set uid random(1, 100000)
\set pid random(1, 5000)
BEGIN;
SELECT price FROM products WHERE id = :pid;
INSERT INTO orders (user_id, product_id, qty) VALUES (:uid, :pid, 1);
UPDATE products SET stock = stock - 1 WHERE id = :pid;
COMMIT;
