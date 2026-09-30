# Anti-Patterns

> Things that work on a laptop with 100 rows and break in production. Each: ❌ what people do → why it hurts → ✅ fix.

```mermaid
flowchart LR
    A["Anti-pattern"] --> S["works in dev<br/>(small data, 1 user)"] --> P["prod: data × 1000<br/>users × 100"] --> F["💥 slow · locked · bloated · leaked"]
```

## Queries

### 1. Deep OFFSET pagination (measured)
```sql
-- ❌ reads and throws away 900,000 rows          Execution Time: 3428.9 ms
SELECT id, qty FROM orders ORDER BY id LIMIT 20 OFFSET 900000;
-- ✅ keyset: jump straight via the index         Execution Time: 0.47 ms
SELECT id, qty FROM orders WHERE id > 900000 ORDER BY id LIMIT 20;
```

### 2. `count(*)` to check existence (measured)
```sql
-- ❌ counts 250K rows                             Execution Time: 287.8 ms
SELECT count(*) > 0 FROM orders WHERE status = 'paid';
-- ✅ stops at the first match                     Execution Time: 0.04 ms
SELECT EXISTS (SELECT 1 FROM orders WHERE status = 'paid');
```

### 3. N+1 queries (ORM loops)
```python
# ❌ 1 + 100 round-trips
for u in db.query("SELECT id FROM users LIMIT 100"):
    db.query("SELECT * FROM orders WHERE user_id = %s", u.id)
# ✅ 1 round-trip
db.query("SELECT u.id, o.* FROM users u JOIN orders o ON o.user_id = u.id WHERE u.id = ANY(%s)", ids)
```

### 4. Functions on indexed columns
```sql
-- ❌ index on created_at unusable
WHERE created_at::date = '2026-01-01'
-- ✅ sargable range
WHERE created_at >= '2026-01-01' AND created_at < '2026-01-02'
```

### 5. `NOT IN` with a nullable subquery
```sql
-- ❌ one NULL → zero rows, silently
WHERE id NOT IN (SELECT user_id FROM orders)
-- ✅
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id)
```

### 6. Read-modify-write in the app
```sql
-- ❌ two requests read 10, both write 9 → one sale lost
SELECT stock FROM products WHERE id = 1;  UPDATE products SET stock = 9 WHERE id = 1;
-- ✅ atomic
UPDATE products SET stock = stock - 1 WHERE id = 1 AND stock > 0 RETURNING stock;
```

## Schema

| ❌ Anti-pattern | Why it hurts | ✅ Fix |
|---|---|---|
| `float` for money | `0.1 + 0.2 = 0.30000000000000004` | `numeric(10,2)` |
| `timestamp` without zone | wrong times across servers/DST | `timestamptz` |
| `tags = 'a,b,c'` | no FK, no index, string parsing | join table |
| EAV (`entity, attribute, value`) | every query = N self-joins, no types | real columns or `jsonb` |
| `"CamelCase"` identifiers | quotes forever | `snake_case` |
| Random `uuid` v4 PK on huge write-heavy tables | 30 MB vs 21 MB index (measured), scattered inserts | `bigint` identity, or `uuidv7()` (PG18) |
| Large files in `bytea` | bloated backups & replication | object storage + URL column |

## Operations

| ❌ Anti-pattern | Why it hurts | ✅ Fix |
|---|---|---|
| `max_connections = 2000` | measured: tps drops past ~2.5× cores | PgBouncer |
| Disabling autovacuum | bloat → XID wraparound → DB stops writes | tune it |
| `VACUUM FULL` on a schedule | exclusive lock on the table | plain VACUUM / `pg_repack` |
| Long / `idle in transaction` sessions | VACUUM blocked, locks held | timeouts |
| `CREATE INDEX` / `ALTER` without `lock_timeout` | queue of blocked queries | `CONCURRENTLY` + `lock_timeout` |
| Replica treated as backup | `DROP TABLE` replicates in ms | pg_dump / PITR offsite |
| Slot with a dead replica | `pg_wal` fills the disk | `max_slot_wal_keep_size` + alerts |
| `postgres:latest` image | surprise major upgrade | pin `postgres:17` |

## Security

| ❌ Anti-pattern | ✅ Fix |
|---|---|
| App connects as superuser | dedicated least-privilege role |
| `ports: "5432:5432"` on a VPS | `127.0.0.1:5432:5432` (Docker bypasses UFW) |
| `POSTGRES_HOST_AUTH_METHOD=trust` | default `scram-sha-256` |
| Building SQL with string concatenation | parameters (`$1`, `%s`) — SQL injection |

## Checklist before production
- [ ] No query in `pg_stat_statements` top 10 without a matching index
- [ ] No `OFFSET` > 1,000 in the codebase
- [ ] App role is not superuser
- [ ] Restore drill passed this month
- [ ] Alerts on lag, slots, disk, connections

🏁 Back to the [README map](../../README.md)
