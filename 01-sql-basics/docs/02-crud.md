# CRUD — INSERT / UPDATE / DELETE

> تعديل البيانات. `RETURNING` بترجعلك الصف المعدّل بدون query ثانية.

```mermaid
flowchart LR
    B["BEGIN"] --> I["INSERT ... RETURNING"] --> U["UPDATE ... WHERE"] --> D["DELETE ... WHERE"] --> C{"صح؟"}
    C -->|"yes"| CM["COMMIT"]
    C -->|"no"| RB["ROLLBACK"]
```

## Example

```sql
BEGIN;

INSERT INTO products (name, category, price, stock)
VALUES ('Keyboard', 'electronics', 49.90, 20)
RETURNING id;                       -- → 5001

UPDATE products
SET stock = stock - 1
WHERE id = 5001
RETURNING stock;                    -- → 19

DELETE FROM products WHERE id = 5001;

ROLLBACK;                           -- ولا كأنه صار شي
```

Bulk insert:
```sql
INSERT INTO users (email, name, country)
VALUES ('a@x.io', 'A', 'JO'),
       ('b@x.io', 'B', 'SA');
```

## Numbers

| Method | 10K rows |
|---|---|
| 10K × `INSERT` منفصل (autocommit) | ~3 s |
| 1 × `INSERT ... VALUES (...), (...)` | ~60 ms |
| `COPY` | ~25 ms |

## Key Points
- جرّب جوا `BEGIN ... ROLLBACK`
- `RETURNING` يوفّر round-trip
- Bulk > loop

## Pitfall
❌ `UPDATE products SET price = 0;` (كل الجدول!)
✅ دايماً `WHERE` + جرّب `SELECT` بنفس الـ `WHERE` أول

Next → [03-joins](03-joins.md)
