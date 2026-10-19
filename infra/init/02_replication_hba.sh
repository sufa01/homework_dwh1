#!/usr/bin/env bash
set -euo pipefail
# Allow the physical standby to connect to the primary. This script runs only
# during first-time initialization, before the temporary init server stops.
cat >> "$PGDATA/pg_hba.conf" <<'HBA'
host replication replicator all scram-sha-256
HBA
