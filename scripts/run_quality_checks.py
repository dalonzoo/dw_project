from __future__ import annotations

from pathlib import Path

from sqlalchemy import text

from build_reconciled import print_rows, validation_statements
from load_staging import PROJECT_ROOT, engine


QUALITY_SQL = PROJECT_ROOT / "sql" / "quality" / "01_quality_checks.sql"


def main() -> None:
    if not QUALITY_SQL.exists():
        raise FileNotFoundError(f"Quality SQL file not found: {QUALITY_SQL}")

    with engine().connect() as conn:
        for index, statement in enumerate(validation_statements(QUALITY_SQL), start=1):
            result = conn.execute(text(statement))
            if result.returns_rows:
                rows = result.fetchall()
                print_rows(f"quality check {index}", list(result.keys()), rows)


if __name__ == "__main__":
    main()
