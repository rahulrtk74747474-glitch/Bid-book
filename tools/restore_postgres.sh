#!/usr/bin/env sh
set -eu

: "${POSTGRES_HOST:?set POSTGRES_HOST}"
: "${POSTGRES_DB:?set POSTGRES_DB}"
: "${POSTGRES_USER:?set POSTGRES_USER}"
: "${PGPASSWORD:?set PGPASSWORD}"
: "${1:?usage: restore_postgres.sh path/to/backup.dump}"

BACKUP="$1"
if [ ! -f "$BACKUP" ]; then
  echo "Backup not found: $BACKUP" >&2
  exit 1
fi

if [ "${CONFIRM_RESTORE:-}" != "RESTORE_BIDBOOK" ]; then
  echo "Refusing destructive restore. Set CONFIRM_RESTORE=RESTORE_BIDBOOK after taking a fresh backup." >&2
  exit 2
fi

if [ -f "$BACKUP.sha256" ]; then
  sha256sum -c "$BACKUP.sha256"
fi

pg_restore \
  --host "$POSTGRES_HOST" \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  "$BACKUP"

echo "Restore completed. Run application smoke tests before reopening traffic."
