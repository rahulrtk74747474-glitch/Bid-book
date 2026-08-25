#!/usr/bin/env sh
set -eu

: "${POSTGRES_HOST:?set POSTGRES_HOST}"
: "${POSTGRES_DB:?set POSTGRES_DB}"
: "${POSTGRES_USER:?set POSTGRES_USER}"
: "${PGPASSWORD:?set PGPASSWORD}"

BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="$BACKUP_DIR/bidbook-${STAMP}.dump"

pg_dump \
  --host "$POSTGRES_HOST" \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --format custom \
  --no-owner \
  --no-privileges \
  --file "$TARGET"

sha256sum "$TARGET" > "$TARGET.sha256"
echo "Backup written to $TARGET"
