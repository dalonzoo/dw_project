from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlencode

import requests


DATASETS = {
    "nta2020": {
        "source_name": "NYC 2020 Neighborhood Tabulation Areas",
        "socrata_id": "9nt8-h7nd",
        "file_stem": "nyc_nta2020",
        "description": "2020 Neighborhood Tabulation Areas, nesting within Community District Tabulation Areas.",
    },
    "borough": {
        "source_name": "NYC Borough Boundaries",
        "socrata_id": "gthc-hcne",
        "file_stem": "nyc_borough_boundaries",
        "description": "NYC borough boundaries with water areas excluded.",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download NYC geographic boundary GeoJSON files from NYC Open Data."
    )
    parser.add_argument(
        "--datasets",
        nargs="+",
        default=["nta2020", "borough"],
        choices=sorted(DATASETS),
        help="Boundary datasets to download.",
    )
    parser.add_argument("--output-dir", default="data_raw/geo")
    parser.add_argument("--limit", type=int, default=5000)
    return parser.parse_args()


def build_geojson_url(socrata_id: str, limit: int) -> str:
    query = urlencode({"$limit": limit})
    return f"https://data.cityofnewyork.us/resource/{socrata_id}.geojson?{query}"


def summarize_geojson(geojson: dict[str, object]) -> tuple[int, list[str], list[str]]:
    features = geojson.get("features")
    if not isinstance(features, list):
        raise ValueError("Expected GeoJSON FeatureCollection with a features list")
    geometry_types = sorted(
        {
            feature.get("geometry", {}).get("type")
            for feature in features
            if isinstance(feature, dict) and isinstance(feature.get("geometry"), dict)
        }
    )
    property_names: set[str] = set()
    for feature in features:
        if not isinstance(feature, dict):
            continue
        properties = feature.get("properties")
        if isinstance(properties, dict):
            property_names.update(str(key) for key in properties)
    return len(features), geometry_types, sorted(property_names)


def download_dataset(dataset_key: str, output_dir: Path, limit: int) -> dict[str, object]:
    config = DATASETS[dataset_key]
    url = build_geojson_url(config["socrata_id"], limit)
    response = requests.get(url, timeout=120)
    response.raise_for_status()
    geojson = response.json()

    feature_count, geometry_types, property_names = summarize_geojson(geojson)
    data_file = output_dir / f"{config['file_stem']}.geojson"
    metadata_file = output_dir / f"{config['file_stem']}.metadata.json"

    data_file.write_text(json.dumps(geojson, ensure_ascii=True) + "\n", encoding="utf-8")
    metadata = {
        "source_name": config["source_name"],
        "source_url": url,
        "socrata_id": config["socrata_id"],
        "description": config["description"],
        "file_name": data_file.name,
        "file_size_bytes": data_file.stat().st_size,
        "feature_count": feature_count,
        "geometry_types": geometry_types,
        "property_names": property_names,
        "extracted_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "data_file": str(data_file).replace("\\", "/"),
    }
    metadata_file.write_text(json.dumps(metadata, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    return metadata


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for dataset_key in args.datasets:
        metadata = download_dataset(dataset_key, output_dir, args.limit)
        print(
            f"{dataset_key}: {metadata['feature_count']} features, "
            f"{metadata['file_size_bytes']} bytes"
        )


if __name__ == "__main__":
    main()
