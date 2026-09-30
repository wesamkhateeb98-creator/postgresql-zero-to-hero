# PgBouncer — Connection Pooling

> Each Postgres connection = one OS process (~5–10 MB). 1000 clients → a small pool of 20 real connections.

```mermaid
flowchart LR
    C1["App ×50 pods<br/>1000 clients"] --> PB["PgBouncer :6432<br/>pool_size=20"] --> PG["Postgres<br/>20 backends"]
```

## Compose

```yaml
  pgbouncer:
    image: edoburu/pgbouncer:latest
    environment:
      DB_HOST: pg
      DB_USER: app
      DB_PASSWORD: ${PG_PASSWORD}
      DB_NAME: shop
      AUTH_TYPE: scram-sha-256
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 20
    ports: ["127.0.0.1:6432:5432"]
    depends_on: [pg]
```
The app connects to `:6432` instead of `:5432`.

## Pool modes

| Mode | Connection returns to the pool after | Note |
|---|---|---|
| session | disconnect | safe, little saving |
| **transaction** | COMMIT/ROLLBACK | most common ✅ |
| statement | each statement | no multi-statement transactions |

## Why — measured without a pooler

| clients | tps | latency |
|---|---|---|
| 10 | 4,997 | 2.0 ms |
| 50 | 3,641 | 13.7 ms |
| 200 | 💥 `FATAL: sorry, too many clients already` | — |

More clients past ~2–3× cores = **less** throughput. Full run: [13-benchmarking/03](../13-benchmarking/03-ramp-and-monitor.md)

## Key Points
- Pool size ≈ `cores × 2–4`
- Transaction mode breaks session `SET` / advisory locks
- Prepared statements supported since PgBouncer 1.21

## Pitfall
❌ `max_connections = 2000`
✅ `max_connections = 100` + PgBouncer

Lab → [labs/08-ops-scaling.sql](../../labs/08-ops-scaling.sql)

Next → [09-ecosystem/01-functions-triggers](../09-ecosystem/01-functions-triggers.md)
