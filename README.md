# Retail Media Performance Pipeline (dbt + PostgreSQL, Docker)


Medallion (raw → bronze → silver → gold) dimensional model for campaign **Impressions, CTR and Benchmark CTR**
across teasers (CMS), online placements (Salesforce sheet) and GA4 tracking. Portable to BigQuery/Snowflake
(Postgres-specific SQL is isolated in `macros/helpers.sql`, `macros/pg_safe_functions.sql` and `models/gold/dim_date.sql`).



## Run it with Docker (Postgres 16 + dbt, nothing else to install)
Requires Docker with Compose v2. From the project folder:
```bash
cp .env.example .env              # optional
docker compose up -d --wait postgres
docker compose run --rm pipeline  # first run builds the image, then: sample data -> load RAW -> dbt build (models + tests) -> freshness
```

| Task | Command |
|---|---|
| Any dbt command | `docker compose run --rm pipeline dbt build` / `dbt test` / `dbt run --select gold` |
| Load CSVs again (e.g. a corrected file) | `docker compose run --rm pipeline python scripts/load_raw.py --force` |
| Backfill a date window | `docker compose run --rm pipeline dbt build --vars '{reprocess_start_date: "2025-06-03", reprocess_end_date: "2025-06-05"}'` |
| Full rebuild | `docker compose run --rm pipeline dbt build --full-refresh` |
| SQL shell | `docker compose exec postgres psql -U retail -d retail_media` |
| Connect a BI/SQL client | host `localhost`, port `5432` (or `POSTGRES_HOST_PORT`), db `retail_media`, user/password `retail` |
| Stop / wipe everything | `docker compose down` / `docker compose down -v` |

Use your own files: put `online_placements_salesforce.csv`, `teasers_cms.csv` and `tracking_events*.csv` in `data/sample/`


## Layout
```
Dockerfile, docker-compose.yml, Makefile, .env.example   (Postgres + dbt in Docker)
scripts/        load_raw.py (RAW loader + audit), generate_sample_data.py
seeds/          expected_raw_schema.csv (schema contract), device_mapping.csv
macros/         cleaning, parsing, keys, incremental window helpers, Postgres safe-cast functions
models/         staging(bronze)/ intermediate(silver)/ mart(gold)/ monitoring/ (+ yml: tests, contracts, docs)
tests/          generic tests + singular tests (reconciliation, thresholds, business rules)
analyses/       dashboard_queries.sql
```
