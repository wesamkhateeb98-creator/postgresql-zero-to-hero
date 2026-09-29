-- Shop dataset used by every lesson.
-- 100K users · 5K products · 1M orders
-- ⚠️ No index on orders.user_id on purpose → lesson 04 adds it.

DROP TABLE IF EXISTS orders, products, users CASCADE;

CREATE TABLE users (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       text        NOT NULL UNIQUE,
    name        text        NOT NULL,
    country     char(2)     NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      text          NOT NULL,
    category  text          NOT NULL,
    price     numeric(10,2) NOT NULL CHECK (price > 0),
    stock     int           NOT NULL DEFAULT 0 CHECK (stock >= 0),
    attrs     jsonb         NOT NULL DEFAULT '{}'
);

CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     bigint      NOT NULL,
    product_id  bigint      NOT NULL,
    qty         int         NOT NULL CHECK (qty > 0),
    status      text        NOT NULL DEFAULT 'paid'
                CHECK (status IN ('pending','paid','shipped','cancelled')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO users (email, name, country, created_at)
SELECT 'user' || g || '@shop.test',
       'User ' || g,
       (ARRAY['JO','SA','AE','EG','PS','LB'])[1 + g % 6],
       now() - (g % 730) * interval '1 day'
FROM generate_series(1, 100000) g;

INSERT INTO products (name, category, price, stock, attrs)
SELECT 'Product ' || g,
       (ARRAY['books','electronics','fashion','home','toys'])[1 + g % 5],
       round((5 + random() * 495)::numeric, 2),
       100000,
       jsonb_build_object('color',  (ARRAY['red','black','white'])[1 + g % 3],
                          'rating', 1 + g % 5)
FROM generate_series(1, 5000) g;

INSERT INTO orders (user_id, product_id, qty, status, created_at)
SELECT 1 + floor(random() * 100000)::int,
       1 + floor(random() * 5000)::int,
       1 + floor(random() * 5)::int,
       (ARRAY['pending','paid','shipped','cancelled'])[1 + floor(random() * 4)::int],
       now() - random() * interval '365 days'
FROM generate_series(1, 1000000);

-- FKs after bulk load = one validation pass instead of 1M trigger calls
ALTER TABLE orders
    ADD CONSTRAINT orders_user_fk    FOREIGN KEY (user_id)    REFERENCES users(id),
    ADD CONSTRAINT orders_product_fk FOREIGN KEY (product_id) REFERENCES products(id);

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

ANALYZE;
