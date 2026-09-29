# Benchmark Results

> سجّل كل run هون. نفس `-s -c -j -T` بين الـ runs، وغيّر شي واحد بس.

## Environment

| | |
|---|---|
| Host | e.g. Hetzner CX32 · 4 vCPU · 8 GB · NVMe |
| Postgres | 17.x (docker) |
| Dataset | shop (1M orders) / pgbench `-s 50` |
| Command | `pgbench -U app -n -c 50 -j 4 -T 60 -f .../read_heavy.sql shop` |

## Runs

| # | Date | Change | TPS | avg ms | stddev | Notes |
|---|---|---|---|---|---|---|
| 0 | | baseline | | | | |
| 1 | | | | | | |
| 2 | | | | | | |
