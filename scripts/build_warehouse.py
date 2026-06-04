from __future__ import annotations

import argparse
from pathlib import Path

from sqlalchemy import text

from build_reconciled import print_rows, run_sql_script, validation_statements
from load_staging import PROJECT_ROOT, engine


SQL_DIR = PROJECT_ROOT / "sql" / "dw"


def run_validation() -> None:
    validation_path = SQL_DIR / "04_validate_warehouse_load.sql"
    with engine().connect() as conn:
        for index, statement in enumerate(validation_statements(validation_path), start=1):
            result = conn.execute(text(statement))
            if result.returns_rows:
                rows = result.fetchall()
                print_rows(f"warehouse load validation {index}", list(result.keys()), rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build, populate, and validate the dimensional warehouse.")
    parser.add_argument(
        "--create-only",
        action="store_true",
        help="Create warehouse tables without loading data.",
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        help="Skip validation output after loading.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    create_path: Path = SQL_DIR / "01_create_warehouse_tables.sql"
    load_path: Path = SQL_DIR / "03_load_warehouse.sql"

    print(f"Running {create_path.relative_to(PROJECT_ROOT)}")
    run_sql_script(create_path)

    if args.create_only:
        print("Created/verified warehouse tables.")
        return

    print(f"Running {load_path.relative_to(PROJECT_ROOT)}")
    run_sql_script(load_path)
    print("Loaded warehouse tables.")

    if not args.skip_validation:
        run_validation()


if __name__ == "__main__":
    main()

