# Storage — Pages, Heap, TOAST

> Every table is a file split into 8 KB pages; rows (tuples) live inside the pages. Overview first: [00-introduction/04](../00-introduction/04-storage-layout.md).

```mermaid
flowchart LR
    T["table orders"] --> F["file: base/16384/16390"]
    F --> P0["page 0 · 8KB"]
    F --> P1["page 1 · 8KB"]
    F --> PN["page N"]
    P0 --> TU["tuple (0,1) · (0,2) ..."]
    T -.->|"values > 2KB"| TO["TOAST table (compressed)"]
```

## Example (measured)

```sql
SELECT pg_relation_filepath('orders');          -- base/16384/16390
SELECT current_setting('block_size');           -- 8192

SELECT relpages, reltuples::bigint,
       round(reltuples / relpages) AS rows_per_page
FROM pg_class WHERE relname = 'orders';
--  relpages | reltuples | rows_per_page
--    9346   |  1000000  |     107

SELECT ctid, id FROM orders LIMIT 3;            -- (0,1) (0,2) (0,3) = (page, slot)
```

## Sizes

```sql
SELECT pg_size_pretty(pg_relation_size('orders'))        AS heap,      -- 73 MB
       pg_size_pretty(pg_indexes_size('orders'))         AS indexes,
       pg_size_pretty(pg_total_relation_size('orders'))  AS total;
```

| Function | Includes |
|---|---|
| `pg_relation_size` | heap only |
| `pg_indexes_size` | all indexes |
| `pg_total_relation_size` | heap + indexes + TOAST |

## Key Points
- I/O always happens in whole pages (8 KB)
- `ctid` = physical address, changes on UPDATE
- TOAST is automatic for large values

## Pitfall
❌ `SELECT *` on a table with big `jsonb` → reads TOAST for nothing
✅ Select only the columns you need

Next → [02-wal](02-wal.md)
