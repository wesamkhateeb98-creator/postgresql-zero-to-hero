#!/usr/bin/env bash
# Restore a dump into a (new) database — use for restore drills.
# Usage: restore.sh <file.dump> [target_db]
set -euo pipefail

DUMP="${1:?usage: restore.sh <file.dump> [target_db]}"
TARGET="${2:-shop_restore}"
COMPOSE_DIR="${COMPOSE_DIR:-/opt/pg}"
SERVICE="${SERVICE:-pg}"
DB_USER="${DB_USER:-app}"

cd "$COMPOSE_DIR"
docker compose exec -T "$SERVICE" dropdb   -U "$DB_USER" --if-exists "$TARGET"
docker compose exec -T "$SERVICE" createdb -U "$DB_USER" "$TARGET"
docker compose exec -T "$SERVICE" pg_restore -U "$DB_USER" -d "$TARGET" --no-owner < "$DUMP"

echo "✅ Restored $DUMP → $TARGET"
