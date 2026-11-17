#!/usr/bin/env python3
"""
RAW layer loader  (CSV  ->  Postgres schema `raw`)

"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import hashlib
import os
import sys
import tempfile
import time
import uuid
from pathlib import Path

import psycopg

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONTRACT_FILE = PROJECT_ROOT / "seeds" / "expected_raw_schema.csv"

SOURCES = {
    # source/table name           load mode
    "online_placements_salesforce": "snapshot",
    "teasers_cms": "snapshot",
    "tracking_events": "replace_file",
}
AUDIT_COLS = ["_batch_id", "_loaded_at", "_source_file", "_file_hash", "_row_number"]


def default_dsn() -> str:
    e = os.environ.get
    return (
        f"host={e('POSTGRES_HOST', 'localhost')} port={e('POSTGRES_PORT', '5432')} "
        f"user={e('POSTGRES_USER', 'retail')} password={e('POSTGRES_PASSWORD', 'retail')} "
        f"dbname={e('POSTGRES_DB', 'retail_media')}"
    )


def connect(dsn: str, retries: int = 30) -> psycopg.Connection:
    """Wait for Postgres (docker compose start-up race) instead of failing on the first refused connection."""
    for attempt in range(1, retries + 1):
        try:
            return psycopg.connect(dsn, autocommit=True)
        except psycopg.OperationalError as exc:
            if attempt == retries:
                raise
            print(f"  waiting for Postgres ({attempt}/{retries}): {str(exc).splitlines()[0]}", file=sys.stderr)
            time.sleep(2)
    raise RuntimeError("unreachable")


def load_contract() -> dict[str, list[str]]:
    contract: dict[str, list[str]] = {}
    with open(CONTRACT_FILE, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            contract.setdefault(row["table_name"], []).append(row["column_name"])
    return contract


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sniff_delimiter(header_line: str) -> str:
    counts = {d: header_line.count(d) for d in [",", "\t", ";"]}
    return max(counts, key=counts.get)


def norm_col(name: str) -> str:
    return name.strip().lower().replace(" ", "_").replace("-", "_")


def init_schema(con: psycopg.Connection, contract: dict[str, list[str]]) -> None:
    con.execute("create schema if not exists raw")
    con.execute(
        """create table if not exists raw._load_audit (
            batch_id text, source text, file_name text, file_hash text,
            rows_read bigint, rows_loaded bigint, rows_rejected bigint,
            status text, message text, started_at timestamp, finished_at timestamp)"""
    )
    con.execute(
        """create table if not exists raw._load_rejects (
            batch_id text, source text, file_name text, row_number bigint,
            reason text, raw_line text, rejected_at timestamp)"""
    )
    for table, cols in contract.items():
        col_ddl = ", ".join(f'"{c}" text' for c in cols)
        con.execute(
            f"""create table if not exists raw.{table} ({col_ddl},
                _batch_id text, _loaded_at timestamp, _source_file text,
                _file_hash text, _row_number bigint)"""
        )


def utcnow() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)


def audit(con, batch_id, source, file_name, file_hash, read, loaded, rejected, status, message, started):
    con.execute(
        "insert into raw._load_audit values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
        [batch_id, source, file_name, file_hash, read, loaded, rejected, status, message, started, utcnow()],
    )


def load_file(con, source: str, mode: str, path: Path, contract, batch_id: str, force: bool) -> str:
    started = utcnow()
    file_name = path.name
    file_hash = sha256(path)
    expected = contract[source]

    if not force:
        seen = con.execute(
            "select count(*) from raw._load_audit where source=%s and file_hash=%s and status='SUCCESS'",
            [source, file_hash],
        ).fetchone()[0]
        if seen:
            audit(con, batch_id, source, file_name, file_hash, 0, 0, 0, "SKIPPED", "identical file already loaded", started)
            return "SKIPPED"

    tmp_name = None
    try:
        with open(path, newline="", encoding="utf-8-sig") as f:
            header_line = f.readline()
            delim = sniff_delimiter(header_line)
            f.seek(0)
            reader = csv.reader(f, delimiter=delim, quotechar='"')
            header = [norm_col(c) for c in next(reader)]

            missing = [c for c in expected if c not in header]
            if missing:
                raise ValueError(f"missing required columns: {missing}")
            extra = [c for c in header if c not in expected]
            idx = {c: header.index(c) for c in expected}

            rejects, rows_read, rows_ok = [], 0, 0
            tmp = tempfile.NamedTemporaryFile("w", newline="", suffix=".csv", delete=False, encoding="utf-8")
            tmp_name = tmp.name
            w = csv.writer(tmp)
            loaded_at = utcnow().isoformat(sep=" ")
            for row_no, row in enumerate(reader, start=2):  # header is line 1
                if not any(cell.strip() for cell in row):
                    continue  # blank line
                rows_read += 1
                if len(row) != len(header):
                    rejects.append((batch_id, source, file_name, row_no, f"column_count {len(row)} != {len(header)}",
                                    delim.join(row)[:2000], utcnow()))
                    continue
                w.writerow([row[idx[c]] for c in expected] + [batch_id, loaded_at, file_name, file_hash, row_no])
                rows_ok += 1
            tmp.close()

        cols_sql = ", ".join(f'"{c}"' for c in expected + AUDIT_COLS)
        with con.transaction():  # delete + COPY + rejects commit together or not at all
            if mode == "replace_file":
                con.execute(f"delete from raw.{source} where _source_file = %s", [file_name])
            with con.cursor() as cur:
                with cur.copy(f"copy raw.{source} ({cols_sql}) from stdin with (format csv, null '')") as cp:
                    with open(tmp_name, "rb") as fh:
                        while chunk := fh.read(1 << 20):
                            cp.write(chunk)
                if rejects:
                    cur.executemany("insert into raw._load_rejects values (%s,%s,%s,%s,%s,%s,%s)", rejects)

        msg = f"delimiter={delim!r}" + (f"; ignored extra columns: {extra}" if extra else "")
        audit(con, batch_id, source, file_name, file_hash, rows_read, rows_ok, len(rejects), "SUCCESS", msg, started)
        return "SUCCESS"
    except Exception as exc:  # we want every failure in the audit table
        audit(con, batch_id, source, file_name, file_hash, 0, 0, 0, "FAILED", str(exc)[:1000], started)
        print(f"  !! {source}/{file_name}: {exc}", file=sys.stderr)
        return "FAILED"
    finally:
        if tmp_name and os.path.exists(tmp_name):
            os.unlink(tmp_name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source-dir", default=str(PROJECT_ROOT / "data" / "sample"))
    ap.add_argument("--dsn", default=default_dsn(), help="libpq connection string (default: from POSTGRES_* env vars)")
    ap.add_argument("--only", choices=list(SOURCES), help="load a single source")
    ap.add_argument("--force", action="store_true", help="reload files even if the same hash was loaded")
    args = ap.parse_args()

    contract = load_contract()
    con = connect(args.dsn)
    init_schema(con, contract)
    batch_id = uuid.uuid4().hex[:12]
    failed = False

    for source, mode in SOURCES.items():
        if args.only and args.only != source:
            continue
        files = sorted(glob.glob(os.path.join(args.source_dir, f"{source}*.csv")))
        if not files:
            print(f"[{source}] no files found in {args.source_dir}", file=sys.stderr)
            failed = True
            continue
        for fp in files:
            status = load_file(con, source, mode, Path(fp), contract, batch_id, args.force)
            print(f"[{source}] {Path(fp).name}: {status}")
            failed |= status == "FAILED"

    print("\nLoad audit for this batch:")
    for r in con.execute(
        "select source, file_name, status, rows_read, rows_loaded, rows_rejected from raw._load_audit "
        "where batch_id=%s order by started_at", [batch_id]
    ).fetchall():
        print("  ", r)
    con.close()
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
