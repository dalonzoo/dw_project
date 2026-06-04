from __future__ import annotations

from pathlib import Path

from sqlalchemy import text

from build_reconciled import print_rows, run_sql_script, validation_statements
from load_staging import PROJECT_ROOT, engine


SQL_DIR = PROJECT_ROOT / "sql" / "dw"


def run_validation() -> None:
    validation_path = SQL_DIR / "02_validate_warehouse_schema.sql"
    with engine().connect() as conn:
        for index, statement in enumerate(validation_statements(validation_path), start=1):
            result = conn.execute(text(statement))
            if result.returns_rows:
                rows = result.fetchall()
                print_rows(f"warehouse schema validation {index}", list(result.keys()), rows)


def main() -> None:
    create_path: Path = SQL_DIR / "01_create_warehouse_tables.sql"

    print(f"Running {create_path.relative_to(PROJECT_ROOT)}")
    run_sql_script(create_path)
    print("Created/verified warehouse schema.")

    run_validation()


if __name__ == "__main__":
    main()

