# PgBouncer — Connection Pooling

> كل connection بـ Postgres = process (~5-10 MB). 1000 client → pool صغير من 20 connection حقيقية.

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
App يتصل على `:6432` بدل `:5432`.

## Pool Modes

| Mode | Connection بترجع للـ pool بعد | ملاحظة |
|---|---|---|
| session | disconnect | آمن، توفير قليل |
| **transaction** | COMMIT/ROLLBACK | الأشهر ✅ |
| statement | كل statement | بدون transactions |

## Numbers — pgbench, 400 clients (توضيحي — قيسها بنفسك)

| Setup | Result |
|---|---|
| مباشر (`max_connections=100`) | `FATAL: too many clients` |
| مباشر (`max_connections=500`) | ~4.5K tps، RAM ↑ |
| PgBouncer pool=20 | ~8K tps |

جرّبها بنفسك: [12-benchmarking/03](../../12-benchmarking/docs/03-ramp-and-monitor.md)

## Key Points
- pool size ≈ `cores × 2-4`
- Transaction mode: `SET` / advisory locks بتنكسر
- Prepared statements: مدعومة من PgBouncer 1.21+

## Pitfall
❌ `max_connections = 2000`
✅ `max_connections = 100` + PgBouncer

Next → [08-ecosystem/01-functions-triggers](../../08-ecosystem/docs/01-functions-triggers.md)
