#!/usr/bin/env bash
set -euo pipefail
for hostport in "localhost:5432" "localhost:5434" "localhost:6432"; do
  host="${hostport%:*}"; port="${hostport##*:}"
  echo "Waiting for $host:$port"
  for _ in $(seq 1 90); do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then break; fi
    sleep 2
  done
  (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1 || { echo "Timeout: $hostport" >&2; exit 1; }
done
