-- pgTAP schema tests. Run:
--   docker compose exec pg pg_prove -U app -d shop /repo/tests/test_schema.sql
BEGIN;
SELECT plan(6);

SELECT has_table('orders');
SELECT col_not_null('orders', 'user_id');
SELECT fk_ok('orders', 'user_id', 'users', 'id');

SELECT throws_ok(
  $$INSERT INTO orders (user_id, product_id, qty) VALUES (1, 1, -5)$$,
  '23514', NULL, 'qty must be positive');

SELECT throws_ok(
  $$INSERT INTO users (email, name, country) VALUES ('user1@shop.test', 'x', 'JO')$$,
  '23505', NULL, 'email is unique');

SELECT lives_ok(
  $$INSERT INTO orders (user_id, product_id, qty) VALUES (1, 1, 1)$$,
  'valid order inserts');

SELECT * FROM finish();
ROLLBACK;
