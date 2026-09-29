-- Lab 02 — Data Modeling
-- Run: \i /repo/02-data-modeling/lab.sql   (كله داخل transaction → ما بيغيّر شي)
BEGIN;

\echo '== 1. float vs numeric =='
SELECT 0.1::float + 0.2::float AS float_sum, 0.1::numeric + 0.2::numeric AS numeric_sum;

\echo '== 2. Type sizes (bytes) =='
SELECT pg_column_size(1::int) AS int, pg_column_size(1::bigint) AS bigint,
       pg_column_size(gen_random_uuid()) AS uuid, pg_column_size(now()) AS timestamptz;

\echo '== 3. Constraints =='
CREATE TABLE reviews (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     bigint NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id  bigint NOT NULL REFERENCES products(id),
    rating      int    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    UNIQUE (user_id, product_id)
);
INSERT INTO reviews (user_id, product_id, rating) VALUES (1, 1, 5);

SAVEPOINT s1;
INSERT INTO reviews (user_id, product_id, rating) VALUES (1, 1, 4);   -- 23505
ROLLBACK TO s1;
INSERT INTO reviews (user_id, product_id, rating) VALUES (1, 2, 9);   -- 23514
ROLLBACK TO s1;
INSERT INTO reviews (user_id, product_id, rating) VALUES (999999, 1, 3); -- 23503
ROLLBACK TO s1;

\echo '== 4. List constraints on reviews =='
SELECT conname, contype FROM pg_constraint WHERE conrelid = 'reviews'::regclass;

ROLLBACK;

-- 🏋️ Exercises
-- a) صمّم tags + product_tags (many-to-many)
-- b) أضف unit_price لـ orders — ليش مش تكرار؟
-- c) أضف CHECK يمنع email بدون '@'
