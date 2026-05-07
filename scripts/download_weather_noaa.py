from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode

import requests


SERVICE_URL = "https://www.ncei.noaa.gov/access/services/data/v1"
DEFAULT_DATA_TYPES = [
    "TAVG",
    "TMAX",
    "TMIN",
    "PRCP",
    "SNOW",
    "SNWD",
    "AWND",
    "WSF2",
    "WT01",
    "WT02",
    "WT03",
    "WT08",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download NOAA daily weather summaries for NYC-area stations."
    )
    parser.add_argument("--station", default="USW00094728", help="GHCN station id without GHCND: prefix.")
    parser.add_argument("--station-name", default="NY CITY CENTRAL PARK, NY US")
    parser.add_argument("--start-date", default="2024-01-01")
    parser.add_argument("--end-date", default="2024-12-31")
    parser.add_argument("--output-dir", default="data_raw/weather")
    parser.add_argument("--units", default="metric", choices=["metric", "standard"])
    parser.add_argument("--data-types", nargs="+", default=DEFAULT_DATA_TYPES)
    return parser.parse_args()


def build_url(args: argparse.Namespace) -> str:
    params = {
        "dataset": "daily-summaries",
        "stations": args.station,
        "startDate": args.start_date,
        "endDate": args.end_date,
        "format": "csv",
        "units": args.units,
        "dataTypes": ",".join(args.data_types),
        "includeStationName": "true",
        "includeStationLocation": "true",
    }
    return f"{SERVICE_URL}?{urlencode(params)}"


def count_csv_rows(path: Path) -> tuple[int, list[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        try:
            header = next(reader)
        except StopIteration:
            return 0, []
        row_count = sum(1 for _ in reader)
    return row_count, header


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    station = args.station.upper().replace("GHCND:", "")
    period = f"{args.start_date}_{args.end_date}"
    data_file = output_dir / f"noaa_daily_{station}_{period}.csv"
    metadata_file = output_dir / f"noaa_daily_{station}_{period}.metadata.json"
    url = build_url(args)

    response = requests.get(url, timeout=60)
    response.raise_for_status()
    data_file.write_text(response.text, encoding="utf-8")

    row_count, columns = count_csv_rows(data_file)
    metadata = {
        "source_name": "NOAA NCEI Daily Summaries",
        "source_url": url,
        "dataset": "daily-summaries",
        "station": station,
        "station_name": args.station_name,
        "start_date": args.start_date,
        "end_date": args.end_date,
        "units": args.units,
        "data_types": args.data_types,
        "row_count": row_count,
        "columns": columns,
        "extracted_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "data_file": str(data_file).replace("\\", "/"),
    }
    metadata_file.write_text(json.dumps(metadata, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    print(f"Downloaded {row_count} weather rows")
    print(f"Data file: {data_file}")
    print(f"Metadata file: {metadata_file}")


if __name__ == "__main__":
    main()
