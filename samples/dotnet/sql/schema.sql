-- Schema only (no data) — used by the integration tests in a throwaway container.
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
    user_id     bigint      NOT NULL REFERENCES users(id),
    product_id  bigint      NOT NULL REFERENCES products(id),
    qty         int         NOT NULL CHECK (qty > 0),
    status      text        NOT NULL DEFAULT 'paid'
                CHECK (status IN ('pending','paid','shipped','cancelled')),
    created_at  timestamptz NOT NULL DEFAULT now()
);
