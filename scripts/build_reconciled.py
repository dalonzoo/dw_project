from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

from sqlalchemy import text

from load_staging import PROJECT_ROOT, engine


SQL_DIR = PROJECT_ROOT / "sql" / "reconciled"


def run_sql_script(path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    raw_connection = engine().raw_connection()
    try:
        cursor = raw_connection.cursor()
        cursor.execute(sql)
        raw_connection.commit()
    except Exception:
        raw_connection.rollback()
        raise
    finally:
        raw_connection.close()


def validation_statements(path: Path) -> Iterable[str]:
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("--"):
            continue
        lines.append(line)

    for statement in "\n".join(lines).split(";"):
        statement = statement.strip()
        if statement:
            yield statement


def print_rows(title: str, columns: list[str], rows: list[tuple]) -> None:
    print(f"\n[{title}]")
    if not rows:
        print("(no rows)")
        return

    rendered_rows = [[str(value) if value is not None else "" for value in row] for row in rows]
    widths = [
        max(len(column), *(len(row[index]) for row in rendered_rows))
        for index, column in enumerate(columns)
    ]
    print(" | ".join(column.ljust(widths[index]) for index, column in enumerate(columns)))
    print("-+-".join("-" * width for width in widths))
    for row in rendered_rows:
        print(" | ".join(value.ljust(widths[index]) for index, value in enumerate(row)))


def run_validation() -> None:
    validation_path = SQL_DIR / "03_validate_reconciled.sql"
    with engine().connect() as conn:
        for index, statement in enumerate(validation_statements(validation_path), start=1):
            result = conn.execute(text(statement))
            if result.returns_rows:
                rows = result.fetchall()
                print_rows(f"validation {index}", list(result.keys()), rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build and validate the Phase 4 reconciled layer.")
    parser.add_argument(
        "--create-only",
        action="store_true",
        help="Create reconciled tables without loading data.",
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        help="Skip validation output after loading.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    create_path = SQL_DIR / "01_create_reconciled_tables.sql"
    load_path = SQL_DIR / "02_load_reconciled.sql"

    print(f"Running {create_path.relative_to(PROJECT_ROOT)}")
    run_sql_script(create_path)

    if args.create_only:
        print("Created/verified reconciled tables.")
        return

    print(f"Running {load_path.relative_to(PROJECT_ROOT)}")
    run_sql_script(load_path)
    print("Loaded reconciled tables.")

    if not args.skip_validation:
        run_validation()


if __name__ == "__main__":
    main()
