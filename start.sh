#!/bin/sh
set -e

/app/wait-for-it.sh $DB_HOST:5432 --timeout=30 --strict -- echo "Postgres is up"

echo "run db migration"
source /app/app.env
/app/migrate -path /app/migration -database "$DB_SOURCE" -verbose up

echo "start the app"
exec "$@"
