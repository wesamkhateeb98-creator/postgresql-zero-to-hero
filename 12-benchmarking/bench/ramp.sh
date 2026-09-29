#!/usr/bin/env bash
# Ramp-up stress test: same workload, growing client count.
# Run inside the container:
#   docker compose exec pg bash /repo/12-benchmarking/bench/ramp.sh
#   CLIENTS="10 50 100" DURATION=60 SCRIPT=/repo/12-benchmarking/bench/order_flow.sql bash ramp.sh
set -uo pipefail

DB="${DB:-shop}"
DB_USER="${DB_USER:-app}"
SCRIPT="${SCRIPT:-$(dirname "$0")/read_heavy.sql}"
CLIENTS="${CLIENTS:-10 25 50 100 200 400}"
DURATION="${DURATION:-30}"
THREADS="${THREADS:-$(nproc)}"

has_index=$(psql -U "$DB_USER" -d "$DB" -Atc \
  "SELECT count(*) FROM pg_indexes WHERE tablename = 'orders' AND indexdef LIKE '%(user_id%'")
if [ "$has_index" = "0" ]; then
  echo "⚠️  No index on orders(user_id) → read_heavy will be very slow."
  echo "    Run: CREATE INDEX orders_user_created_idx ON orders (user_id, created_at DESC);"
fi

echo "script=$(basename "$SCRIPT")  duration=${DURATION}s  threads=$THREADS"
for c in $CLIENTS; do
  j=$(( c < THREADS ? c : THREADS ))
  out=$(pgbench -U "$DB_USER" -n -c "$c" -j "$j" -T "$DURATION" -f "$SCRIPT" "$DB" 2>&1)
  if echo "$out" | grep -q "^tps"; then
    lat=$(echo "$out" | grep "latency average" | awk '{print $4, $5}')
    tps=$(echo "$out" | grep "^tps" | awk '{print $3}')
    printf "clients=%-4s latency=%-12s tps=%s\n" "$c" "$lat" "$tps"
  else
    printf "clients=%-4s 💥 %s\n" "$c" "$(echo "$out" | grep -m1 -iE 'fatal|error')"
  fi
done
