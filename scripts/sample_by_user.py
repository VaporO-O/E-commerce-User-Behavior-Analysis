#!/usr/bin/env python
"""Sample ecommerce behavior CSV files by user_id.

The raw Kaggle files are too large for first-round local SQL work. This script
keeps complete behavior histories for sampled users across all input months.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import time
from pathlib import Path


EXPECTED_COLUMNS = [
    "event_time",
    "event_type",
    "product_id",
    "category_id",
    "category_code",
    "brand",
    "price",
    "user_id",
    "user_session",
]

MONTH_ORDER = {
    "Jan": 1,
    "Feb": 2,
    "Mar": 3,
    "Apr": 4,
    "May": 5,
    "Jun": 6,
    "Jul": 7,
    "Aug": 8,
    "Sep": 9,
    "Oct": 10,
    "Nov": 11,
    "Dec": 12,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a user_id-level sample from large ecommerce CSV files."
    )
    parser.add_argument(
        "--input-dir",
        default="data/raw",
        help="Directory containing raw monthly CSV files. Default: data/raw",
    )
    parser.add_argument(
        "--output",
        default="data/sample/user_behavior_sample.csv",
        help="Output sample CSV path. Default: data/sample/user_behavior_sample.csv",
    )
    parser.add_argument(
        "--summary",
        default="data/sample/user_behavior_sample_summary.json",
        help="Output summary JSON path. Default: data/sample/user_behavior_sample_summary.json",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=0.01,
        help="User-level sampling rate. 0.01 means about 1%% of users. Default: 0.01",
    )
    parser.add_argument(
        "--seed",
        default="stage-0-sampling",
        help="Stable seed for repeatable user selection. Default: stage-0-sampling",
    )
    parser.add_argument(
        "--encoding",
        default="utf-8",
        help="CSV encoding. Default: utf-8",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=1_000_000,
        help="Print progress every N input rows. Default: 1000000",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan files and count selected rows/users without writing the sample CSV.",
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=None,
        help="Optional row limit for smoke tests. Default: no limit.",
    )
    args = parser.parse_args()

    if not 0 < args.rate <= 1:
        raise SystemExit("--rate must be in the range (0, 1].")

    return args


def find_input_files(input_dir: str) -> list[Path]:
    files = sorted(Path(input_dir).glob("*.csv"), key=csv_sort_key)
    if not files:
        raise SystemExit(f"No CSV files found in {input_dir!r}.")
    return files


def csv_sort_key(path: Path) -> tuple[int, int, str]:
    parts = path.stem.split("-")
    if len(parts) == 2 and parts[0].isdigit() and parts[1] in MONTH_ORDER:
        return int(parts[0]), MONTH_ORDER[parts[1]], path.name
    return 9999, 99, path.name


def is_selected_user(user_id: str, rate: float, seed: str) -> bool:
    key = f"{seed}:{user_id}".encode("utf-8")
    digest = hashlib.sha256(key).digest()
    bucket = int.from_bytes(digest[:8], "big") / 2**64
    return bucket < rate


def validate_header(fieldnames: list[str] | None, path: Path) -> None:
    if fieldnames != EXPECTED_COLUMNS:
        raise SystemExit(
            f"{path} has unexpected columns.\n"
            f"Expected: {EXPECTED_COLUMNS}\n"
            f"Actual:   {fieldnames}"
        )


def main() -> None:
    args = parse_args()
    input_files = find_input_files(args.input_dir)
    output_path = Path(args.output)
    summary_path = Path(args.summary)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.parent.mkdir(parents=True, exist_ok=True)

    started_at = time.time()
    total_rows = 0
    sampled_rows = 0
    sampled_users: set[str] = set()
    input_stats: list[dict[str, int | str]] = []

    writer = None
    out_handle = None

    try:
        if not args.dry_run:
            out_handle = output_path.open("w", newline="", encoding=args.encoding)
            writer = csv.DictWriter(out_handle, fieldnames=EXPECTED_COLUMNS)
            writer.writeheader()

        for input_file in input_files:
            file_rows = 0
            file_sampled_rows = 0

            with input_file.open("r", newline="", encoding=args.encoding) as in_handle:
                reader = csv.DictReader(in_handle)
                validate_header(reader.fieldnames, input_file)

                for row in reader:
                    if args.max_rows is not None and total_rows >= args.max_rows:
                        break

                    total_rows += 1
                    file_rows += 1

                    user_id = row["user_id"]
                    if is_selected_user(user_id, args.rate, args.seed):
                        sampled_rows += 1
                        file_sampled_rows += 1
                        sampled_users.add(user_id)
                        if writer is not None:
                            writer.writerow(row)

                    if args.progress_every and total_rows % args.progress_every == 0:
                        elapsed = time.time() - started_at
                        print(
                            f"processed={total_rows:,} sampled_rows={sampled_rows:,} "
                            f"sampled_users={len(sampled_users):,} elapsed={elapsed:.1f}s",
                            flush=True,
                        )

            input_stats.append(
                {
                    "file": str(input_file),
                    "rows": file_rows,
                    "sampled_rows": file_sampled_rows,
                }
            )

            if args.max_rows is not None and total_rows >= args.max_rows:
                break

    finally:
        if out_handle is not None:
            out_handle.close()

    elapsed = time.time() - started_at
    summary = {
        "method": "stable_hash_by_user_id",
        "rate": args.rate,
        "seed": args.seed,
        "dry_run": args.dry_run,
        "max_rows": args.max_rows,
        "input_files": input_stats,
        "output": None if args.dry_run else str(output_path),
        "total_rows": total_rows,
        "sampled_rows": sampled_rows,
        "sampled_users": len(sampled_users),
        "elapsed_seconds": round(elapsed, 2),
    }

    summary_path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
