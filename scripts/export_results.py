#!/usr/bin/env python
"""Export the small analysis result tables from MySQL to CSV.

These are the aggregated / Top-N tables produced by sql/05-07. They are the
shareable conclusions of stage 1, small enough to archive in the repo and to
drop straight into the report / README. The big tables (user_behavior_raw,
user_behavior_clean) and helper/user-level tables are intentionally NOT exported
here -- query those directly in the database when needed.

Only depends on pymysql + the standard library (no pandas/numpy), so it is
unaffected by the anaconda pandas/numpy binary mismatch.

Usage:
    pip install pymysql            # one-time
    python scripts/export_results.py --user root --password yourpwd
"""

from __future__ import annotations

import argparse
import csv
import getpass
import os
from pathlib import Path

import pymysql


# The 12 small result tables worth archiving (one CSV each).
RESULT_TABLES = [
    "analysis_event_distribution",
    "analysis_funnel_overview",
    "analysis_funnel_user",
    "analysis_funnel_session",
    "analysis_cart_remove_summary",
    "analysis_brand_funnel_top",
    "analysis_retention_cohort_summary",
    "analysis_retention_matrix_30d",
    "analysis_repurchase_retention",
    "analysis_rfm_segment_summary",
    "analysis_rfm_metric_summary",
    "analysis_rfm_top_users",
    "analysis_metrics_overview",
    "analysis_metrics_daily",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export analysis result tables from MySQL to CSV."
    )
    parser.add_argument("--host", default="127.0.0.1", help="MySQL host. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=3306, help="MySQL port. Default: 3306")
    parser.add_argument("--user", default="root", help="MySQL user. Default: root")
    parser.add_argument(
        "--password",
        default=None,
        help="MySQL password. If omitted, read env MYSQL_PWD or prompt.",
    )
    parser.add_argument(
        "--database",
        default="ecommerce_analysis",
        help="Database name. Default: ecommerce_analysis",
    )
    parser.add_argument(
        "--out-dir",
        default="reports/sql_outputs",
        help="Output directory. Default: reports/sql_outputs",
    )
    return parser.parse_args()


def resolve_password(arg_password: str | None) -> str:
    if arg_password is not None:
        return arg_password
    env_password = os.environ.get("MYSQL_PWD")
    if env_password is not None:
        return env_password
    return getpass.getpass("MySQL password: ")


def export_table(cursor: pymysql.cursors.Cursor, table: str, out_dir: Path) -> int:
    cursor.execute(f"SELECT * FROM {table}")
    columns = [desc[0] for desc in cursor.description]
    rows = cursor.fetchall()

    csv_path = out_dir / f"{table}.csv"
    # utf-8-sig so Excel opens the Chinese segment labels without garbling.
    with csv_path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(columns)
        writer.writerows(rows)
    print(f"{table:<35} {len(rows):>6} rows -> {csv_path}")
    return len(rows)


def main() -> None:
    args = parse_args()
    password = resolve_password(args.password)

    connection = pymysql.connect(
        host=args.host,
        port=args.port,
        user=args.user,
        password=password,
        database=args.database,
        charset="utf8mb4",
    )

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        with connection.cursor() as cursor:
            for table in RESULT_TABLES:
                export_table(cursor, table, out_dir)
    finally:
        connection.close()

    print(f"\nDone. {len(RESULT_TABLES)} tables exported to {out_dir}")


if __name__ == "__main__":
    main()
