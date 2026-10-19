#!/usr/bin/env bash
set -euo pipefail
for pair in "crm:crm_service_db" "catalog:catalog_service_db" "pos:pos_service_db" "wms:wms_service_db"; do
  service="${pair%%:*}"; db="${pair##*:}"
  echo "Applying $service schema to $db"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db" -f "/migrations/$service/001_schema.sql"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db" <<SQL
GRANT USAGE ON SCHEMA app, contract TO app, checker;
GRANT SELECT ON ALL TABLES IN SCHEMA app, contract TO checker;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO checker;
ALTER DEFAULT PRIVILEGES IN SCHEMA contract GRANT SELECT ON TABLES TO checker;
SQL
done
