# pgbench Basics

> أداة benchmark الرسمية، موجودة جوا `postgres:17`. بتشغّل N clients متزامنين وبتقيس TPS + latency.

```mermaid
sequenceDiagram
    participant PB as pgbench (-j 4 threads)
    participant PG as PostgreSQL
    loop كل client (-c 50) لحد -T 60s
        PB->>PG: BEGIN
        PB->>PG: UPDATE / SELECT / INSERT
        PB->>PG: COMMIT
        PG-->>PB: latency مسجّلة
    end
    PB->>PB: TPS = transactions / seconds
```

## Tools Compared

| Tool | النوع | مناسب لـ |
|---|---|---|
| **pgbench** ⭐ | built-in | OLTP + SQL تبعك |
| HammerDB | TPC-C / TPC-H | مقارنة engines رسمياً |
| sysbench | generic | CPU / IO + DB |
| k6 / JMeter | HTTP | الـ app كامل |

## Step 1 — Init

```bash
docker compose exec pg pgbench -U app -i -s 50 shop
```

| `-s` | rows `pgbench_accounts` | Size |
|---|---|---|
| 1 | 100K | 16 MB |
| 50 | 5M | 750 MB |
| 500 | 50M | 7.5 GB |

## Step 2 — Run

```bash
docker compose exec pg pgbench -U app -c 50 -j 4 -T 60 -P 10 -M prepared -r shop
```

| Flag | معناه |
|---|---|
| `-c 50` | clients متزامنين |
| `-j 4` | threads (≈ cores) |
| `-T 60` | ثواني |
| `-P 10` | progress كل 10s |
| `-M prepared` | prepared statements |
| `-r` | latency لكل statement |
| `-S` | SELECT only |
| `-N` | بدون update لـ branches/tellers |
| `-R 500` | rate ثابت |

## Step 3 — Read

```text
progress: 10.0 s, 2410.3 tps, lat 20.7 ms stddev 8.1
latency average = 20.85 ms
tps = 2396.7 (without initial connection time)
statement latencies in milliseconds:
   0.61  UPDATE pgbench_accounts ...
  14.20  UPDATE pgbench_branches ...   ← 🔥 lock contention (50 branch فقط)
```

## Key Points
- `stddev` عالي = spikes (checkpoints)
- `-r` بيحدد الـ statement البطيء
- Default script = TPC-B (write-heavy)

## Pitfall
❌ `-c 50` مع `-s 1` → كلهم عم يتقاتلوا على branch واحد
✅ `-s` ≥ `-c`

Next → [02-custom-scripts](02-custom-scripts.md)
