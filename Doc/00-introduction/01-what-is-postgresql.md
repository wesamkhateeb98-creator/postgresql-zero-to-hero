# What is PostgreSQL?

> An open-source **object-relational database engine**: it stores data in tables, speaks SQL, guarantees ACID, and can be extended with new types, indexes, and languages.

```mermaid
timeline
    1986 : POSTGRES project at UC Berkeley (Michael Stonebraker)
    1996 : Renamed PostgreSQL — SQL support added
    2005 : 8.0 — native Windows, PITR
    2010 : 9.0 — streaming replication
    2014 : 9.4 — JSONB
    2017 : 10 — logical replication, declarative partitioning
    2024 : 17 — incremental backup, faster VACUUM
    2025 : 18 — async I/O, uuidv7()
```

## What you get

```mermaid
mindmap
  root((PostgreSQL))
    Reliable
      ACID transactions
      WAL crash recovery
      MVCC concurrency
    Rich SQL
      CTE / window functions
      JSONB · arrays · ranges
      Full-text search
    Extensible
      Custom types
      Extensions: PostGIS · pgvector
      PL/pgSQL · PL/Python
    Operable
      Streaming replication
      Partitioning
      PITR backups
```

## Example — one engine, many workloads

```sql
-- Relational
SELECT u.email, count(o.id) FROM users u JOIN orders o ON o.user_id = u.id GROUP BY 1;

-- Document
SELECT name FROM products WHERE attrs @> '{"color": "red"}';

-- Search
SELECT title FROM articles WHERE search @@ websearch_to_tsquery('running shoes');

-- Vector (pgvector)
SELECT body FROM docs ORDER BY embedding <=> '[0.1, 0.9, 0.3]' LIMIT 5;
```

## Numbers

| | |
|---|---|
| License | PostgreSQL License (MIT-like, free for commercial use) |
| Release cycle | 1 major / year, 5 years of support each |
| Max table size | 32 TB (default 8 KB pages) |
| Max row / field size | 1.6 TB / 1 GB |
| Version in this repo | 17.11 (`SELECT version();`) |

## Key Points
- "Postgres" = same thing
- Community-owned, no single vendor
- Default choice for new backends

Next → [02-postgresql-vs-sql-server](02-postgresql-vs-sql-server.md)
