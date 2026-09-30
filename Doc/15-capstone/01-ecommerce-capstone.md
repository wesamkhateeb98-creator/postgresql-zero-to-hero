# 🏁 Capstone — E-commerce Database

> Put every phase together in one project: schema → performance → security → deploy → replica → benchmark.

```mermaid
erDiagram
    users ||--o{ orders : places
    orders ||--|{ order_items : contains
    products ||--o{ order_items : "sold as"
    products }o--o{ tags : tagged
    users ||--o{ reviews : writes
    products ||--o{ reviews : receives
```

```mermaid
flowchart LR
    S["Schema<br/>03"] --> Q["Queries<br/>04"] --> I["Indexes<br/>05"] --> T["Concurrency<br/>06"]
    T --> O["Security<br/>08"] --> D["Deploy<br/>12"] --> R["Replica<br/>13"] --> B["Benchmark<br/>14"]
```

## Tasks

### 1. Schema (03)
- [ ] `order_items (order_id, product_id, qty, unit_price)` — one order, many products
- [ ] `tags` + `product_tags` (many-to-many)
- [ ] `reviews` with `UNIQUE (user_id, product_id)` and `CHECK rating 1..5`
- [ ] `updated_at` trigger on products

### 2. Queries (04)
- [ ] Top 10 products by revenue, last 30 days
- [ ] Monthly revenue + growth % (`lag`)
- [ ] Cart upsert (`ON CONFLICT`)
- [ ] Product search: FTS on name + jsonb filter

### 3. Performance (05 · 07)
- [ ] Every query above < 10 ms (record `EXPLAIN ANALYZE` before/after)
- [ ] No unused indexes

### 4. Concurrency (06)
- [ ] Checkout never oversells stock under 100 concurrent clients
- [ ] Order-processing queue with `SKIP LOCKED`

### 5. Security & Ops (08)
- [ ] Roles: `app_rw`, `app_ro`, `reporting`
- [ ] RLS: a user sees only their orders
- [ ] `orders` partitioned by month
- [ ] Materialized view `daily_sales` + refresh

### 6. Deploy (11 · 12 · 13)
- [ ] VPS + full security checklist
- [ ] Primary + replica on 2 VPSs
- [ ] Daily backup + successful restore drill
- [ ] Documented failover drill

### 7. Benchmark (14)
- [ ] pgbench scripts for checkout + browse
- [ ] Ramp test → find the sweet spot
- [ ] 3 tuning runs in [bench/results.md](../../bench/results.md)
- [ ] pgTAP tests for every constraint

### 8. Review (16)
- [ ] Walk through [best practices](../16-best-practices/01-best-practices.md) and [anti-patterns](../16-best-practices/02-anti-patterns.md)

## Definition of Done

| Metric | Target |
|---|---|
| Browse query p95 | < 10 ms |
| Checkout TPS (50 clients) | record it |
| Replica lag under load | < 1 s |
| Restore time | < 5 min |
| pgTAP | all green |

Next → [16-best-practices/01-best-practices](../16-best-practices/01-best-practices.md)
