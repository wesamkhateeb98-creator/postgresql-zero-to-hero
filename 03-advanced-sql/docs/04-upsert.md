# UPSERT & MERGE

> Insert إذا مش موجود، update إذا موجود — بعملية atomic وحدة.

```mermaid
flowchart LR
    I["INSERT row"] --> C{"conflict على UNIQUE؟"}
    C -->|"no"| N["insert ✅"]
    C -->|"yes"| U["DO UPDATE / DO NOTHING"]
```

## Example — ON CONFLICT

```sql
CREATE TABLE cart (
    user_id    bigint,
    product_id bigint,
    qty        int NOT NULL,
    PRIMARY KEY (user_id, product_id)
);

-- أضف للسلة: إذا موجود زيد الكمية
INSERT INTO cart (user_id, product_id, qty) VALUES (1, 10, 2)
ON CONFLICT (user_id, product_id)
DO UPDATE SET qty = cart.qty + EXCLUDED.qty;     -- EXCLUDED = الصف الجديد

-- idempotent insert
INSERT INTO cart VALUES (1, 10, 1) ON CONFLICT DO NOTHING;
```

## MERGE (PG15+)

```sql
MERGE INTO cart c
USING (VALUES (1, 10, 0), (1, 11, 3)) AS s(user_id, product_id, qty)
ON c.user_id = s.user_id AND c.product_id = s.product_id
WHEN MATCHED AND s.qty = 0 THEN DELETE
WHEN MATCHED THEN UPDATE SET qty = s.qty
WHEN NOT MATCHED THEN INSERT VALUES (s.user_id, s.product_id, s.qty);
```

## Race condition — Before → After

| Pattern | 2 requests متزامنة |
|---|---|
| `SELECT` ثم `INSERT` من الـ app | ❌ duplicate / 23505 |
| `INSERT ... ON CONFLICT` | ✅ دايماً صح |

## Key Points
- لازم UNIQUE / PK على الأعمدة
- `EXCLUDED.col` = القيمة المقترحة
- `MERGE` للـ sync المعقد

Next → [04-indexes-performance/01-explain](../../04-indexes-performance/docs/01-explain.md)
