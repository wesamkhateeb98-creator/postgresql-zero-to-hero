# PostgreSQL Architecture

> **One process per connection** + shared memory + background workers + files on disk.

```mermaid
flowchart TB
    C1["Client 1"] & C2["Client 2"] --> PM["postmaster (PID 1)<br/>listens :5432, forks"]
    PM --> B1["backend (client 1)"]
    PM --> B2["backend (client 2)"]
    B1 & B2 <--> SM["Shared memory<br/>shared_buffers · WAL buffers · locks · CLOG"]
    SM <--> BG["Background workers<br/>checkpointer · bgwriter · walwriter · autovacuum"]
    BG --> D[("Disk<br/>base/ · pg_wal/ · pg_xact/")]
```

## Processes — real output from this repo's container

```sql
SELECT backend_type, count(*) FROM pg_stat_activity GROUP BY 1;
--  autovacuum launcher          | 1
--  background writer            | 1
--  checkpointer                 | 1
--  client backend               | 1   ← your psql session
--  logical replication launcher | 1
--  walwriter                    | 1
```

| Process | Job |
|---|---|
| postmaster | Accepts connections, forks one backend each, restarts crashed children |
| backend | Parses, plans, executes **your** queries |
| checkpointer | Flushes all dirty pages to disk periodically |
| background writer | Writes some dirty pages early → backends rarely wait |
| walwriter | Flushes WAL buffers to `pg_wal/` |
| autovacuum | Removes dead row versions, updates statistics |
| walsender | Streams WAL to replicas ([12](../12-replication/01-streaming-replication.md)) |

## Memory

| Area | Scope | Default (this repo) |
|---|---|---|
| `shared_buffers` | shared page cache | 128 MB (16384 × 8 KB) |
| `wal_buffers` | shared WAL staging | 4 MB (512 × 8 KB) |
| `work_mem` | **per sort/hash, per backend** | 4 MB |
| `max_connections` | backend limit | 100 |

## Query life cycle

```mermaid
sequenceDiagram
    participant C as Client
    participant B as Backend
    participant SB as shared_buffers
    participant D as Disk
    C->>B: SELECT … WHERE user_id = 42
    B->>B: parse → rewrite → plan (uses statistics)
    B->>SB: need page 7 of orders
    alt page cached
        SB-->>B: hit
    else miss
        SB->>D: read 8 KB page (OS cache / disk)
        D-->>SB: page
    end
    B-->>C: rows
```

## Data directory (`$PGDATA`)

```text
base/16384/16665   ← one table (database oid / file node)
global/            ← cluster-wide catalogs (roles, databases)
pg_wal/            ← WAL segments, 16 MB each
pg_xact/           ← commit status of every transaction (CLOG)
postgresql.conf    ← settings
pg_hba.conf        ← who may connect, how
```

## Key Points
- Connection = OS process (~5–10 MB) → use a pool
- All backends share one page cache
- Crash of one backend → postmaster resets all

Next → [04-storage-layout](04-storage-layout.md)
