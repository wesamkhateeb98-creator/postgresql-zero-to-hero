# Roles & Row-Level Security

> Least privilege: كل app/user بياخد بس اللي بيحتاجه. RLS = فلتر إجباري على مستوى الصف.

```mermaid
flowchart TD
    O["app_owner<br/>(migrations)"] -->|"owns"| T["tables"]
    RW["app_rw<br/>SELECT/INSERT/UPDATE/DELETE"] --> T
    RO["app_ro<br/>SELECT only"] --> T
    API["api user"] -->|"member of"| RW
    BI["reporting user"] -->|"member of"| RO
```

## Roles

```sql
CREATE ROLE app_ro NOLOGIN;
GRANT CONNECT ON DATABASE shop TO app_ro;
GRANT USAGE ON SCHEMA public TO app_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_ro;  -- جداول مستقبلية

CREATE ROLE reporting LOGIN PASSWORD 'change_me' IN ROLE app_ro;
-- reporting: SELECT ✅  ·  DELETE ❌ permission denied
```

## RLS — كل tenant بيشوف بياناته بس

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_owner ON orders
    USING (user_id = current_setting('app.user_id')::bigint);

-- من الـ app بكل request:
SET app.user_id = '42';
SELECT count(*) FROM orders;      -- بس طلبات user 42
```

```mermaid
sequenceDiagram
    participant API
    participant PG
    API->>PG: SET app.user_id = '42'
    API->>PG: SELECT * FROM orders
    PG->>PG: + WHERE user_id = 42 (policy)
    PG-->>API: rows لـ 42 فقط
```

## Key Points
- ما تستخدم superuser بالـ app
- Group roles (`NOLOGIN`) + members
- Superuser بيتجاوز RLS **دايماً**؛ الـ owner كمان إلا مع `FORCE ROW LEVEL SECURITY`
- `app` بهالـ repo = superuser → اختبر RLS بـ `SET ROLE` (زي الـ lab)

## Pitfall
❌ `GRANT ALL ON ALL TABLES TO api;`
✅ `GRANT SELECT, INSERT, UPDATE ON orders TO api;`

Next → [02-backup-restore](02-backup-restore.md)
