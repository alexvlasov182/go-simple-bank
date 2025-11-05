#!/bin/sh
set -e

# Parse DB_SOURCE to get host and port
# Format: postgresql://user:pass@host:port/dbname
DB_HOST=$(echo $DB_SOURCE | sed -E 's#postgresql://[^:]+:[^@]+@([^:/]+):([0-9]+).*#\1#')
DB_PORT=$(echo $DB_SOURCE | sed -E 's#postgresql://[^:]+:[^@]+@([^:/]+):([0-9]+).*#\2#')

echo "Waiting for Postgres at $DB_HOST:$DB_PORT..."
/app/wait-for-it.sh $DB_HOST:$DB_PORT --timeout=30 --strict -- echo "Postgres is up"

echo "Run db migration"
# Migrate the database
/app/migrate -path /app/migration -database "$DB_SOURCE" -verbose up

echo "Start the app"
exec "$@"
