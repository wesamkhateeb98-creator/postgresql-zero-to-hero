#!/bin/bash
# Runs once on the primary during initdb.
set -euo pipefail

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '${REPL_PASSWORD}';
    -- slot: primary keeps WAL until replica1 consumed it
    SELECT pg_create_physical_replication_slot('replica1');
EOSQL

# allow replication connections (not covered by "host all all all")
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
