#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! python3 -c 'import psycopg' >/dev/null 2>&1; then
    python3 -m pip install -q 'psycopg[binary]'
fi

python3 -u scripts/generate_data.py "$@"