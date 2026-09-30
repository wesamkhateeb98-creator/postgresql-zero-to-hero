# SELECT & WHERE

> SQL is written in one order and executed in another — learn the logical order and most errors make sense.

```mermaid
flowchart LR
    F["FROM"] --> W["WHERE"] --> G["GROUP BY"] --> H["HAVING"] --> S["SELECT"] --> O["ORDER BY"] --> L["LIMIT"]
```

## Example

```sql
-- 5 most expensive electronics under 100
SELECT id, name, price
FROM products
WHERE category = 'electronics'
  AND price < 100
ORDER BY price DESC
LIMIT 5;

-- Operators
SELECT * FROM users WHERE country IN ('JO', 'PS');
SELECT * FROM users WHERE email LIKE 'user1%@shop.test';
SELECT * FROM products WHERE price BETWEEN 10 AND 20;
SELECT * FROM orders WHERE created_at >= now() - interval '7 days';
```

## NULL

| Expression | Result |
|---|---|
| `NULL = NULL` | `NULL` (not true!) |
| `NULL IS NULL` | `true` |
| `COALESCE(NULL, 0)` | `0` |

## Key Points
- `WHERE` runs before `SELECT` → no aliases
- `ORDER BY` runs after → aliases work
- `LIMIT` without `ORDER BY` = random order

## Pitfall
❌ `SELECT price * 2 AS p FROM products WHERE p > 100;`
✅ `SELECT price * 2 AS p FROM products WHERE price * 2 > 100;`

Lab → [labs/02-sql-basics.sql](../../labs/02-sql-basics.sql)

Next → [02-crud](02-crud.md)
