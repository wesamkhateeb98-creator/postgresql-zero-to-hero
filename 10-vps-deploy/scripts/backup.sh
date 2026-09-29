#!/usr/bin/env bash
# Daily logical backup with rotation.
# cron (as deploy): 0 3 * * * /opt/pg/10-vps-deploy/scripts/backup.sh >> /opt/pg-backups/backup.log 2>&1
#   (/var/log مش writable لـ deploy → الـ redirect بيفشل والـ job ما بيشتغل)
# Replication stack: COMPOSE_DIR=/opt/pg/11-replication SERVICE=pg-primary backup.sh
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-/opt/pg}"
SERVICE="${SERVICE:-pg}"
DB="${DB:-shop}"
DB_USER="${DB_USER:-app}"
BACKUP_DIR="${BACKUP_DIR:-/opt/pg-backups}"
KEEP_DAYS="${KEEP_DAYS:-7}"

mkdir -p "$BACKUP_DIR"
FILE="$BACKUP_DIR/${DB}_$(date +%F_%H%M).dump"

cd "$COMPOSE_DIR"
# .tmp first → a failed dump never looks like a valid backup
docker compose exec -T "$SERVICE" pg_dump -U "$DB_USER" -Fc "$DB" > "$FILE.tmp"
mv "$FILE.tmp" "$FILE"

find "$BACKUP_DIR" -name "${DB}_*.dump" -mtime +"$KEEP_DAYS" -delete

echo "$(date -Is) OK $FILE $(du -h "$FILE" | cut -f1)"

# Offsite (uncomment after `rclone config`):
# rclone copy "$BACKUP_DIR" b2:my-bucket/pg --max-age 24h
