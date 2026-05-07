from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import requests


BASE_URL = "https://s3.amazonaws.com/tripdata"
DEFAULT_MONTHS = ["202401"]
ALL_2024_MONTHS = [f"2024{month:02d}" for month in range(1, 13)]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download monthly Citi Bike trip files into data_raw."
    )
    parser.add_argument(
        "--months",
        nargs="+",
        default=DEFAULT_MONTHS,
        help="Months in YYYYMM format, or all-2024. Default: 202401.",
    )
    parser.add_argument("--output-dir", default="data_raw/citibike")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-download files even when they already exist.",
    )
    parser.add_argument(
        "--skip-row-count",
        action="store_true",
        help="Skip row counting inside ZIP files. Useful for faster full-year downloads.",
    )
    return parser.parse_args()


def expand_months(months: list[str]) -> list[str]:
    if len(months) == 1 and months[0].lower() == "all-2024":
        return ALL_2024_MONTHS
    for month in months:
        if len(month) != 6 or not month.isdigit():
            raise ValueError(f"Invalid month '{month}'. Use YYYYMM or all-2024.")
    return months


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def candidate_urls(month: str) -> list[str]:
    year = month[:4]
    month_number = month[4:]
    return [
        f"{BASE_URL}/{month}-citibike-tripdata.zip",
        f"{BASE_URL}/{month}-citibike-tripdata.csv.zip",
        f"{BASE_URL}/{year}-{month_number}-citibike-tripdata.zip",
        f"{BASE_URL}/{year}-{month_number}-citibike-tripdata.csv.zip",
    ]


def resolve_source_url(month: str) -> str:
    checked_urls = []
    for url in candidate_urls(month):
        checked_urls.append(url)
        response = requests.head(url, allow_redirects=True, timeout=30)
        if response.status_code == 200:
            return url
        if response.status_code not in {403, 404, 405}:
            response.raise_for_status()
    raise FileNotFoundError(f"No Citi Bike file found for {month}. Tried: {checked_urls}")


def inspect_zip(path: Path, skip_row_count: bool) -> dict[str, object]:
    with zipfile.ZipFile(path) as archive:
        csv_members = [name for name in archive.namelist() if name.lower().endswith(".csv")]
        if not csv_members:
            raise ValueError(f"Expected at least one CSV in {path}, found none")

        columns = []
        total_row_count = None if skip_row_count else 0
        for csv_member in csv_members:
            with archive.open(csv_member) as csv_file:
                header = csv_file.readline().decode("utf-8-sig").strip()
                member_columns = header.split(",") if header else []
                if not columns:
                    columns = member_columns
                elif member_columns != columns:
                    raise ValueError(f"CSV columns differ inside {path}: {csv_member}")
                if skip_row_count:
                    continue
                line_count = 1
                for chunk in iter(lambda: csv_file.read(1024 * 1024), b""):
                    line_count += chunk.count(b"\n")
                total_row_count += max(0, line_count - 1)

    return {
        "zip_members": csv_members,
        "columns": columns,
        "row_count": total_row_count,
    }


def download_file(url: str, destination: Path) -> None:
    with requests.get(url, stream=True, timeout=60) as response:
        response.raise_for_status()
        temporary_path = destination.with_suffix(destination.suffix + ".part")
        with temporary_path.open("wb") as file:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file.write(chunk)
        temporary_path.replace(destination)


def download_month(month: str, output_dir: Path, force: bool, skip_row_count: bool) -> dict[str, object]:
    url = resolve_source_url(month)
    data_file = output_dir / Path(url).name
    metadata_file = output_dir / f"{month}-citibike-tripdata.metadata.json"

    if force or not data_file.exists():
        download_file(url, data_file)

    zip_info = inspect_zip(data_file, skip_row_count=skip_row_count)
    metadata = {
        "source_name": "Citi Bike System Data",
        "source_url": url,
        "month": month,
        "file_name": data_file.name,
        "file_size_bytes": data_file.stat().st_size,
        "sha256": sha256_file(data_file),
        "extracted_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        **zip_info,
    }
    metadata_file.write_text(json.dumps(metadata, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    return metadata


def main() -> None:
    args = parse_args()
    months = expand_months(args.months)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    total_rows = 0
    for month in months:
        metadata = download_month(
            month=month,
            output_dir=output_dir,
            force=args.force,
            skip_row_count=args.skip_row_count,
        )
        row_count = metadata["row_count"]
        if isinstance(row_count, int):
            total_rows += row_count
        print(
            f"{month}: {metadata['file_size_bytes']} bytes, "
            f"rows={row_count if row_count is not None else 'skipped'}"
        )

    if total_rows:
        print(f"Total counted rows: {total_rows}")


if __name__ == "__main__":
    main()
