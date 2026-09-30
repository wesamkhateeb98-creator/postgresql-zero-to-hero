# How INSERT · SELECT · UPDATE · DELETE Work

> Postgres **never overwrites a row in place**. INSERT adds a version, UPDATE adds a new version and retires the old one, DELETE only retires. VACUUM reclaims later.

## Life of one row

```mermaid
stateDiagram-v2
    direction LR
    Live: live version<br/>xmin = creator, xmax = 0
    Dead: dead version<br/>xmax = updater/deleter (committed)
    Free: free slot<br/>reusable by new INSERTs
    [*] --> Live: INSERT
    Live --> Dead: UPDATE (plus a new live version)
    Live --> Dead: DELETE
    Dead --> Free: VACUUM
    Free --> [*]
```

## INSERT

```mermaid
sequenceDiagram
    autonumber
    participant B as Backend
    participant FSM as Free space map
    participant SB as shared_buffers
    participant WB as WAL buffers
    participant WD as pg_wal (disk)
    participant X as pg_xact (commit log)
    B->>FSM: which page has 30 free bytes?
    FSM-->>B: page 0
    B->>SB: write tuple into page 0 (xmin = 2415), page becomes dirty
    B->>SB: add index entry: key 1 points to (0,1)
    B->>WB: WAL records for the heap and index changes
    Note over B: COMMIT
    B->>WD: flush WAL up to the commit record (fsync)
    B->>X: transaction 2415 = committed
    Note over SB: the dirty page reaches the data file later (bgwriter / checkpointer)
```

Steps 1–5 are memory only; step 6 is the one disk write COMMIT waits for.

## SELECT — find the row, then check visibility

```mermaid
flowchart TB
    Q["SELECT * FROM demo WHERE id = 2"] --> P{"planner"}
    P -->|"Seq Scan"| S["read every page,<br/>every tuple"]
    P -->|"Index Scan"| I["index: key 2 → (0,2)"]
    I --> H["page 0, line pointer 2<br/>(follow HOT chain if redirected)"]
    S --> V{"visible to my snapshot?"}
    H --> V
    V -->|"yes"| R["return row"]
    V -->|"no"| K["skip this version"]
```

| A version is visible if | Checked via |
|---|---|
| `xmin` committed **and** started before my snapshot | `pg_xact` + snapshot |
| `xmax` is 0, **or** aborted, **or** after my snapshot | `pg_xact` + snapshot |

The first reader stores the commit result in the tuple (**hint bits**), so later readers skip `pg_xact` — that's why a plain `SELECT` can dirty pages.

## UPDATE and DELETE (measured)

```sql
UPDATE demo SET name = 'B' WHERE id = 2;     -- transaction 2416
DELETE FROM demo WHERE id = 3;               -- transaction 2417

SELECT lp, t_xmin, t_xmax, t_ctid FROM heap_page_items(get_raw_page('demo', 0));
--  lp | t_xmin | t_xmax | t_ctid
--   1 |   2415 |      0 | (0,1)   ← untouched
--   2 |   2415 |   2416 | (0,4)   ← old 'b': retired, points to the new version
--   3 |   2415 |   2417 | (0,3)   ← deleted: only xmax was set
--   4 |   2416 |      0 | (0,4)   ← new 'B'

SELECT ctid, * FROM demo;      -- (0,1) a · (0,4) B      (row 3 is invisible)
```

```mermaid
flowchart LR
    subgraph P0["page 0 after UPDATE + DELETE"]
        L1["lp1 · (1,'a')<br/>live"]
        L2["lp2 · (2,'b')<br/>dead, xmax 2416"]
        L3["lp3 · (3,'c')<br/>dead, xmax 2417"]
        L4["lp4 · (2,'B')<br/>live, xmin 2416"]
    end
    L2 -->|"t_ctid"| L4
```

| Command | What physically happens |
|---|---|
| INSERT | new tuple, `xmin = my transaction` |
| UPDATE | old tuple gets `xmax`; a **full new copy** of the row is written |
| DELETE | old tuple gets `xmax`; nothing is removed |
| ROLLBACK | nothing undone — `pg_xact` says "aborted", so those versions are simply invisible |

## VACUUM and HOT (measured)

```sql
VACUUM demo;
SELECT lp, lp_flags, t_ctid FROM heap_page_items(get_raw_page('demo', 0));
--  1 | 1 normal   | (0,1)
--  2 | 2 redirect |          ← kept as a pointer: index still says (0,2)
--  3 | 0 unused   |          ← space free for new rows
--  4 | 1 normal   | (0,4)
```

```mermaid
flowchart LR
    IX["index demo_pkey<br/>key 2 → (0,2)"] --> R2["lp2: redirect"] --> T4["lp4: (2,'B')"]
```

**HOT update** (Heap-Only Tuple): when the new version fits on the **same page** and no indexed column changed, no new index entry is written — the index keeps pointing to lp2, which redirects to lp4. Index `demo_pkey` still has only 2 entries: `(0,1)` and `(0,2)`.

## Key Points
- UPDATE = retire old + write new
- ROLLBACK is instant (no undo log)
- Dead tuples = bloat until VACUUM
- Free space on the page (`fillfactor`) → more HOT updates

Deeper: [06-transactions-mvcc/03-mvcc](../06-transactions-mvcc/03-mvcc.md) · [07-internals/03-vacuum](../07-internals/03-vacuum.md)

Next → [01-setup/01-docker-setup](../01-setup/01-docker-setup.md)
