-- Objects the .NET samples call. Idempotent: safe to run on every start.

-- Function returning a table (see Doc/10-plpgsql/03-functions.md)
CREATE OR REPLACE FUNCTION top_products(p_category text, p_limit int DEFAULT 3)
RETURNS TABLE (product_id bigint, name text, units bigint)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.name, sum(o.qty)::bigint
    FROM products p JOIN orders o ON o.product_id = p.id
    WHERE p.category = p_category
    GROUP BY p.id, p.name
    ORDER BY 3 DESC
    LIMIT p_limit;
END $$;

-- Procedure with an INOUT parameter (see Doc/10-plpgsql/04-procedures.md)
CREATE OR REPLACE PROCEDURE product_stock(p_product bigint, INOUT p_stock int DEFAULT NULL)
LANGUAGE plpgsql AS $$
BEGIN
    SELECT stock INTO p_stock FROM products WHERE id = p_product;
END $$;

-- Index used by the "orders of a user" queries (see Doc/05-indexes-performance/02-btree.md)
CREATE INDEX IF NOT EXISTS orders_user_created_idx ON orders (user_id, created_at DESC);
