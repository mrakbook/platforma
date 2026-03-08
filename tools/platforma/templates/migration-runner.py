#!/usr/bin/env python3
"""
Lightweight migration runner template.
This template is intentionally minimal for demo workflow parity.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Platforma migration runner template")
    parser.add_argument("--target", required=True, help="Target service key")
    parser.add_argument("--sql", required=True, help="Path to SQL migration file")
    parser.add_argument("--dry-run", action="store_true", help="Print action without executing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    sql_path = Path(args.sql)
    if not sql_path.exists():
        raise SystemExit(f"migration file not found: {sql_path}")

    if args.dry_run:
        print(f"DRY-RUN migration target={args.target} file={sql_path.name}")
        return 0

    # In demo mode this runner only reports the file that would be executed.
    print(f"APPLY migration target={args.target} file={sql_path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
