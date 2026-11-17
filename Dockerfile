
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DBT_SEND_ANONYMOUS_USAGE_STATS=false \
    DBT_PROFILES_DIR=/app \
    DBT_TARGET_PATH=/app/dbt_target \
    DBT_LOG_PATH=/tmp/dbt_logs \
    HOME=/tmp

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["bash", "run_pipeline.sh"]

