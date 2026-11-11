#!/bin/sh
set -eu

for db in ngo_db donation_db; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -c "CREATE DATABASE $db"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db" -f "/schemas/$db.sql"
done
