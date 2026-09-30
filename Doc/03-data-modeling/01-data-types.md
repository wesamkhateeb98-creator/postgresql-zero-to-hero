# Data Types

> The right type = correct data + less space + faster indexes.

```mermaid
flowchart TD
    Q{"What are you storing?"} --> M["money"] --> N["numeric(10,2)"]
    Q --> T["time"] --> TZ["timestamptz"]
    Q --> S["text"] --> TX["text"]
    Q --> ID["ID"] --> BI["bigint identity / uuid"]
    Q --> J["flexible shape"] --> JB["jsonb"]
```

## Cheatsheet

| Use | ✅ Type | ❌ Avoid |
|---|---|---|
| Money | `numeric(10,2)` | `float`, `real` |
| Time | `timestamptz` | `timestamp` (no zone) |
| String | `text` (+ `CHECK` for length) | `varchar(255)` by habit |
| PK | `bigint GENERATED ALWAYS AS IDENTITY` | `serial` (legacy) |
| Public ID | `uuid` (`gen_random_uuid()`) | exposed sequential IDs |
| Flags | `boolean` | `int` 0/1 |
| Semi-structured | `jsonb` | `json` (slow to query) |

## Example (measured)

```sql
SELECT 0.1::float + 0.2::float;      -- 0.30000000000000004 ❌
SELECT 0.1::numeric + 0.2::numeric;  -- 0.3 ✅

SELECT '2026-01-01 10:00'::timestamptz AT TIME ZONE 'Asia/Amman';

SELECT pg_column_size(1::int), pg_column_size(1::bigint), pg_column_size(gen_random_uuid());
--  4 | 8 | 16   (bytes)
```

## Numbers — PK index on 1M rows (measured)

| PK | Index size |
|---|---|
| `bigint` | 21 MB |
| `uuid` (random v4) | 30 MB |

## Key Points
- `timestamptz` always stores UTC
- `text` and `varchar` perform the same
- `int` runs out at 2.1 billion

## Pitfall
❌ `price float` → rounding errors on invoices
✅ `price numeric(10,2)`

Next → [02-constraints](02-constraints.md)
