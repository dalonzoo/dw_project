from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import requests


API_URL_TEMPLATE = "https://date.nager.at/api/v3/PublicHolidays/{year}/{country_code}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download public holidays from Nager.Date into data_raw."
    )
    parser.add_argument("--year", type=int, default=2024)
    parser.add_argument("--country-code", default="US")
    parser.add_argument("--output-dir", default="data_raw/holidays")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    country_code = args.country_code.upper()
    url = API_URL_TEMPLATE.format(year=args.year, country_code=country_code)
    response = requests.get(url, timeout=30)
    response.raise_for_status()

    holidays = response.json()
    if not isinstance(holidays, list):
        raise ValueError("Expected Nager.Date response to be a JSON list")

    extracted_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    data_file = output_dir / f"{country_code.lower()}_public_holidays_{args.year}.json"
    metadata_file = output_dir / f"{country_code.lower()}_public_holidays_{args.year}.metadata.json"

    data_file.write_text(json.dumps(holidays, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    metadata = {
        "source_name": "Nager.Date Public Holidays API",
        "source_url": url,
        "country_code": country_code,
        "year": args.year,
        "row_count": len(holidays),
        "extracted_at_utc": extracted_at,
        "data_file": str(data_file).replace("\\", "/"),
    }
    metadata_file.write_text(json.dumps(metadata, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    print(f"Downloaded {len(holidays)} holidays")
    print(f"Data file: {data_file}")
    print(f"Metadata file: {metadata_file}")


if __name__ == "__main__":
    main()
