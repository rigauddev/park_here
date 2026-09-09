#!/usr/bin/env bash
set -euo pipefail
backup_file="${1:?Provide a trusted ParkHere .sql.gz backup}"
compose_args=()
if [[ -n "${PARKHERE_COMPOSE_FILE:-}" ]]; then
  compose_args+=(-f "$PARKHERE_COMPOSE_FILE")
fi
if [[ -n "${PARKHERE_ENV_FILE:-}" ]]; then
  compose_args+=(--env-file "$PARKHERE_ENV_FILE")
fi
gzip -t "$backup_file"
restore_db="parkhere_restore_check_$(date +%s)_$$"
cleanup() {
  docker compose "${compose_args[@]}" exec -T mysql sh -c \
    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "DROP DATABASE IF EXISTS $1"' sh "$restore_db"
}
trap cleanup EXIT
docker compose "${compose_args[@]}" exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "CREATE DATABASE $1"' sh "$restore_db"
gzip -dc "$backup_file" | docker compose "${compose_args[@]}" exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot "$1"' sh "$restore_db"
docker compose "${compose_args[@]}" exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot "$1" -e "SELECT version_num FROM alembic_version; SELECT COUNT(*) AS reservations FROM reservations; SELECT COUNT(*) AS parkings FROM parkings; CHECK TABLE reservations, parkings, payment_transactions;"' sh "$restore_db"
echo 'Backup restored and queried in an isolated database. Source database unchanged.'
