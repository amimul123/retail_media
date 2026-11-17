#!/usr/bin/env bash
# End-to-end run: sample data (only if none) -> RAW load -> dbt build (seeds, models, tests) -> freshness.
# Works inside the container (docker compose run --rm pipeline) and locally (needs POSTGRES_* env vars).
set -euo pipefail
cd "$(dirname "$0")"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-.}"

if ! ls data/sample/*.csv >/dev/null 2>&1; then
    echo ">> no CSVs in data/sample - generating synthetic sample data"
    python scripts/generate_sample_data.py
fi

python scripts/load_raw.py --source-dir data/sample
dbt build                                   # bronze -> silver -> gold + monitoring + all tests (source tests gate everything)
dbt source freshness || true                # informational locally; gating in production

# Backfill example (idempotent; replaces whole business days):
#   python scripts/load_raw.py --source-dir <dir with corrected file> --force
#   dbt build --vars '{reprocess_start_date: 2025-06-03, reprocess_end_date: 2025-06-05}'
# Full rebuild:
#   dbt build --full-refresh
