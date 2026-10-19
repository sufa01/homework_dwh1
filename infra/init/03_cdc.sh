#!/usr/bin/env bash
set -euo pipefail
for db in crm_service_db catalog_service_db pos_service_db wms_service_db; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$db" <<'SQL'
DO $$ DECLARE r record; BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname='cdc_app') THEN
    EXECUTE 'CREATE PUBLICATION cdc_app FOR ALL TABLES';
  END IF;
  FOR r IN SELECT schemaname, tablename FROM pg_tables WHERE schemaname='app' LOOP
    EXECUTE format('ALTER TABLE %I.%I REPLICA IDENTITY FULL', r.schemaname, r.tablename);
  END LOOP;
END $$;
SQL
done
