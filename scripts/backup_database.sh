#!/usr/bin/env bash
set -euo pipefail
umask 077
# Optional compose file/env file; defaults are the local development stack.
backup_file="${1:?Provide an output .sql.gz path}"
compose_args=()
if [[ -n "${PARKHERE_COMPOSE_FILE:-}" ]]; then
  compose_args+=(-f "$PARKHERE_COMPOSE_FILE")
fi
if [[ -n "${PARKHERE_ENV_FILE:-}" ]]; then
  compose_args+=(--env-file "$PARKHERE_ENV_FILE")
fi
if [[ -e "$backup_file" ]]; then
  echo 'Backup already exists; choose a new path.' >&2
  exit 1
fi
partial="${backup_file}.partial"
trap 'rm -f "$partial"' EXIT
docker compose "${compose_args[@]}" exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --routines --triggers --no-tablespaces --set-gtid-purged=OFF "$MYSQL_DATABASE"' \
  | gzip > "$partial"
gzip -t "$partial"
mv "$partial" "$backup_file"
echo "Backup created: $backup_file"
