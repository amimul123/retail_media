# Shortcuts (Linux/macOS/WSL). Windows without make: use the `docker compose ...` commands shown in each line.
DC  = docker compose
RUN = $(DC) run --rm pipeline

.PHONY: up down run load build test docs psql shell reset backfill semantic mf

up:        ## start Postgres (waits until healthy)
	$(DC) up -d --wait postgres

run: up    ## full pipeline: sample data (if none) -> load RAW -> dbt build -> freshness
	$(RUN)

load: up   ## only load CSVs from data/sample into RAW
	$(RUN) python scripts/load_raw.py

build: up  ## only dbt build (models + tests)
	$(RUN) dbt build

test: up   ## only dbt tests
	$(RUN) dbt test

backfill: up  ## reprocess a window:  make backfill FROM=2025-06-03 TO=2025-06-05
	$(RUN) dbt build --vars '{reprocess_start_date: "$(FROM)", reprocess_end_date: "$(TO)"}'

semantic: up  ## validate the semantic layer (MetricFlow) against the warehouse
	$(DC) run --rm -e DBT_TARGET_PATH=target pipeline bash -c "dbt parse -q && mf validate-configs"

mf: up        ## any MetricFlow command:  make mf Q="query --metrics ctr --group-by campaign__gender"
	$(DC) run --rm -e DBT_TARGET_PATH=target pipeline bash -c "dbt parse -q && mf $(Q)"

psql: up   ## SQL shell inside the Postgres container
	$(DC) exec postgres sh -c 'psql -U $$POSTGRES_USER -d $$POSTGRES_DB'

shell: up  ## bash inside the dbt/python container
	$(RUN) bash

down:      ## stop containers (data is kept)
	$(DC) down

reset:     ## stop AND delete the database volume (clean slate)
	$(DC) down -v
