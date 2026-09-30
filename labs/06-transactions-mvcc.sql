-- Lab 05 — Transactions & MVCC
-- Run: i /repo/labs/06-transactions-mvcc.sql
-- Demo 4 needs a second terminal: docker compose exec pg psql -U app -d shop

\echo '== 1. Atomicity with SAVEPOINT =='
BEGIN;
CREATE TEMP TABLE acct (id int PRIMARY KEY, balance int CHECK (balance >= 0));
INSERT INTO acct VALUES (1, 100), (2, 0);
SAVEPOINT s;
UPDATE acct SET balance = balance - 150 WHERE id = 1;   -- CHECK fails
ROLLBACK TO s;
UPDATE acct SET balance = balance - 50 WHERE id = 1;
UPDATE acct SET balance = balance + 50 WHERE id = 2;
SELECT * FROM acct;
ROLLBACK;

\echo '== 2. MVCC: xmin / xmax / ctid =='
BEGIN;
CREATE TEMP TABLE t (id int, v text);
INSERT INTO t VALUES (1, 'a');
SELECT ctid, xmin, xmax, * FROM t;
UPDATE t SET v = 'b';
SELECT ctid, xmin, xmax, * FROM t;
ROLLBACK;

\echo '== 3. Dead tuples =='
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'products';
UPDATE products SET stock = stock WHERE id <= 1000;
SELECT pg_sleep(1);
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'products';

-- == 4. Two-session demos (copy/paste manually) ==
-- Isolation:
--   T1: BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT stock FROM products WHERE id = 1;
--   T2: UPDATE products SET stock = stock - 5 WHERE id = 1;
--   T1: SELECT stock FROM products WHERE id = 1;   -- still the old value
--   T1: UPDATE products SET stock = stock - 1 WHERE id = 1;  -- ERROR 40001
-- Deadlock:
--   T1: BEGIN; UPDATE products SET stock = stock WHERE id = 1;
--   T2: BEGIN; UPDATE products SET stock = stock WHERE id = 2;
--   T1: UPDATE products SET stock = stock WHERE id = 2;   -- waits
--   T2: UPDATE products SET stock = stock WHERE id = 1;   -- ERROR: deadlock detected

-- 🏋️ Exercises
-- a) Build a job queue with SKIP LOCKED and run 2 sessions
-- b) Reproduce a lost update with SELECT then UPDATE from 2 sessions
