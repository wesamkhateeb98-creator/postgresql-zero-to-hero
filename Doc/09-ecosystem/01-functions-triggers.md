# Functions & Triggers

> Logic inside the DB: functions = reusable SQL / PL/pgSQL. Triggers = functions that run automatically on INSERT/UPDATE/DELETE.

```mermaid
sequenceDiagram
    participant App
    participant T as products
    participant TR as trigger fn
    participant A as price_audit
    App->>T: UPDATE price = 60
    T->>TR: AFTER UPDATE (OLD, NEW)
    TR->>A: INSERT (OLD.price=50, NEW.price=60)
    TR-->>T: RETURN NEW
```

## Function

```sql
CREATE FUNCTION user_total_spent(p_user bigint)
RETURNS numeric
LANGUAGE sql STABLE
AS $$
    SELECT coalesce(sum(o.qty * p.price), 0)
    FROM orders o JOIN products p ON p.id = o.product_id
    WHERE o.user_id = p_user;
$$;

SELECT user_total_spent(42);       -- 11872.75 (measured)
```

## Trigger — audit price changes

```sql
CREATE TABLE price_audit (
    product_id bigint, old_price numeric, new_price numeric,
    changed_at timestamptz DEFAULT now()
);

CREATE FUNCTION log_price_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.price IS DISTINCT FROM OLD.price THEN
        INSERT INTO price_audit (product_id, old_price, new_price)
        VALUES (OLD.id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER products_price_audit
AFTER UPDATE OF price ON products
FOR EACH ROW EXECUTE FUNCTION log_price_change();

UPDATE products SET price = price + 1 WHERE id = 1;
SELECT * FROM price_audit;         -- 1 | 144.39 | 145.39 | ...
```

## Volatility

| Label | Meaning | Example |
|---|---|---|
| `IMMUTABLE` | same input → same output forever | `lower()` |
| `STABLE` | constant within one query | lookups |
| `VOLATILE` | may change every call | `random()`, writes |

## Key Points
- `updated_at` / audit = classic triggers
- Trigger logic is hidden → document it
- `FOR EACH ROW` on bulk loads = slow

## Pitfall
❌ All business logic in triggers → debugging nightmare
✅ Triggers only for simple invariants

Full PL/pgSQL (loops, procedures, errors, dynamic SQL, trigger internals) → [10-plpgsql](../10-plpgsql/01-basics.md)

Next → [02-views-matviews](02-views-matviews.md)
