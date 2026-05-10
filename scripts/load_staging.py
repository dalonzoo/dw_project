from __future__ import annotations

import argparse
import json
import os
import zipfile
from pathlib import Path
from typing import Iterable

import geopandas as gpd
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def database_url() -> str:
    load_dotenv(PROJECT_ROOT / ".env")
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "urban_night_mobility_dw")
    user = os.getenv("DB_USER", os.getenv("USER", "postgres"))
    password = os.getenv("DB_PASSWORD", "")

    if password:
        return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{name}"
    return f"postgresql+psycopg2://{user}@{host}:{port}/{name}"


def engine():
    return create_engine(database_url(), future=True)


def run_sql_file(sql_path: Path) -> None:
    sql = sql_path.read_text(encoding="utf-8")
    with engine().begin() as conn:
        conn.execute(text(sql))


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = (
        df.columns.str.strip()
        .str.lower()
        .str.replace(" ", "_", regex=False)
        .str.replace("-", "_", regex=False)
    )
    return df


def append_dataframe(df: pd.DataFrame, table_name: str, chunksize: int = 50_000) -> None:
    df.to_sql(
        table_name,
        con=engine(),
        schema="staging",
        if_exists="append",
        index=False,
        method="multi",
        chunksize=chunksize,
    )


def iter_citibike_csvs(path: Path) -> Iterable[tuple[str, pd.DataFrame]]:
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as archive:
            for member in archive.namelist():
                if member.lower().endswith(".csv"):
                    with archive.open(member) as file:
                        yield member, pd.read_csv(file)
    elif path.suffix.lower() == ".csv":
        yield path.name, pd.read_csv(path)
    else:
        raise ValueError(f"Unsupported Citi Bike file type: {path}")


def load_citibike(input_dir: Path) -> None:
    files = sorted(input_dir.glob("*.zip")) + sorted(input_dir.glob("*.csv"))
    if not files:
        raise FileNotFoundError(f"No Citi Bike .zip or .csv files found in {input_dir}")

    columns = [
        "ride_id",
        "rideable_type",
        "started_at",
        "ended_at",
        "start_station_name",
        "start_station_id",
        "end_station_name",
        "end_station_id",
        "start_lat",
        "start_lng",
        "end_lat",
        "end_lng",
        "member_casual",
        "source_file",
    ]

    for path in files:
        for member_name, df in iter_citibike_csvs(path):
            df = normalize_columns(df)
            df["started_at"] = pd.to_datetime(df["started_at"], errors="coerce")
            df["ended_at"] = pd.to_datetime(df["ended_at"], errors="coerce")
            df["source_file"] = f"{path.name}:{member_name}" if path.suffix.lower() == ".zip" else path.name
            append_dataframe(df[columns], "citibike_trip_raw")
            print(f"Loaded Citi Bike file: {path.name} / {member_name} rows={len(df):,}")


def load_weather(input_dir: Path) -> None:
    files = sorted(input_dir.glob("noaa_daily_*.csv"))
    if not files:
        raise FileNotFoundError(f"No NOAA weather CSV files found in {input_dir}")

    rename_map = {
        "name": "station_name",
        "date": "observation_date",
    }
    columns = [
        "station",
        "station_name",
        "observation_date",
        "latitude",
        "longitude",
        "elevation",
        "tavg",
        "tmax",
        "tmin",
        "prcp",
        "snow",
        "snwd",
        "awnd",
        "wsf2",
        "wt01",
        "wt02",
        "wt03",
        "wt08",
        "source_file",
    ]

    for path in files:
        df = normalize_columns(pd.read_csv(path))
        df = df.rename(columns=rename_map)
        for col in columns:
            if col not in df.columns:
                df[col] = None
        df["observation_date"] = pd.to_datetime(df["observation_date"], errors="coerce").dt.date
        df["source_file"] = path.name
        append_dataframe(df[columns], "weather_raw", chunksize=5_000)
        print(f"Loaded weather file: {path.name} rows={len(df):,}")


def load_holidays(input_dir: Path) -> None:
    files = sorted(input_dir.glob("*_public_holidays_*.json"))
    if not files:
        raise FileNotFoundError(f"No holiday JSON files found in {input_dir}")

    for path in files:
        holidays = json.loads(path.read_text(encoding="utf-8"))
        rows = []
        for item in holidays:
            rows.append(
                {
                    "holiday_date": item.get("date"),
                    "local_name": item.get("localName"),
                    "holiday_name": item.get("name"),
                    "country_code": item.get("countryCode"),
                    "fixed": item.get("fixed"),
                    "global_holiday": item.get("global"),
                    "counties": json.dumps(item.get("counties")) if item.get("counties") is not None else None,
                    "launch_year": item.get("launchYear"),
                    "holiday_types": json.dumps(item.get("types")) if item.get("types") is not None else None,
                    "source_file": path.name,
                }
            )
        df = pd.DataFrame(rows)
        df["holiday_date"] = pd.to_datetime(df["holiday_date"], errors="coerce").dt.date
        append_dataframe(df, "holiday_raw", chunksize=1_000)
        print(f"Loaded holiday file: {path.name} rows={len(df):,}")


def first_existing_column(gdf: gpd.GeoDataFrame, candidates: list[str]) -> str | None:
    lower_to_original = {column.lower(): column for column in gdf.columns}
    for candidate in candidates:
        if candidate.lower() in lower_to_original:
            return lower_to_original[candidate.lower()]
    return None


def load_geojson(path: Path, table_name: str, id_candidates: list[str], name_candidates: list[str], borough_candidates: list[str]) -> None:
    gdf = gpd.read_file(path)
    gdf = gdf.to_crs(epsg=4326)

    id_col = first_existing_column(gdf, id_candidates)
    name_col = first_existing_column(gdf, name_candidates)
    borough_col = first_existing_column(gdf, borough_candidates)

    out = gpd.GeoDataFrame(
        {
            "properties": gdf.drop(columns=[gdf.geometry.name]).apply(lambda row: json.dumps(row.dropna().to_dict()), axis=1),
            "source_file": path.name,
        },
        geometry=gdf.geometry,
        crs="EPSG:4326",
    )

    if table_name == "nyc_nta_raw":
        out["nta_id"] = gdf[id_col].astype(str) if id_col else None
        out["nta_name"] = gdf[name_col].astype(str) if name_col else None
        out["borough_name"] = gdf[borough_col].astype(str) if borough_col else None
        out = out[["nta_id", "nta_name", "borough_name", "properties", "source_file", "geometry"]]
    else:
        out["borough_code"] = gdf[id_col].astype(str) if id_col else None
        out["borough_name"] = gdf[name_col].astype(str) if name_col else None
        out = out[["borough_code", "borough_name", "properties", "source_file", "geometry"]]

    out = out.rename_geometry("geom")
    out.to_postgis(table_name, con=engine(), schema="staging", if_exists="append", index=False)
    print(f"Loaded geography file: {path.name} into staging.{table_name} rows={len(out):,}")


def load_geography(input_dir: Path) -> None:
    nta_file = input_dir / "nyc_nta2020.geojson"
    borough_file = input_dir / "nyc_borough_boundaries.geojson"

    if nta_file.exists():
        load_geojson(
            nta_file,
            "nyc_nta_raw",
            id_candidates=["nta2020", "nta_code", "ntacode", "geoid"],
            name_candidates=["ntaname", "nta_name", "name"],
            borough_candidates=["boroname", "borough", "borough_name", "boro_name"],
        )
    else:
        print(f"Skipped NTA geography; file not found: {nta_file}")

    if borough_file.exists():
        load_geojson(
            borough_file,
            "nyc_borough_raw",
            id_candidates=["boro_code", "borocode", "boro_code", "bcode"],
            name_candidates=["boro_name", "boroname", "borough", "borough_name", "name"],
            borough_candidates=[],
        )
    else:
        print(f"Skipped borough geography; file not found: {borough_file}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load raw source files into the Phase 3 staging schema.")
    parser.add_argument(
        "--create-tables",
        action="store_true",
        help="Run sql/staging/01_create_staging_tables.sql before loading data.",
    )
    parser.add_argument(
        "--dataset",
        choices=["all", "citibike", "weather", "holidays", "geography"],
        default="all",
    )
    parser.add_argument("--citibike-dir", default="data_raw/citibike")
    parser.add_argument("--weather-dir", default="data_raw/weather")
    parser.add_argument("--holidays-dir", default="data_raw/holidays")
    parser.add_argument("--geo-dir", default="data_raw/geo")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.create_tables:
        run_sql_file(PROJECT_ROOT / "sql" / "staging" / "01_create_staging_tables.sql")
        print("Created/verified staging tables.")

    if args.dataset in {"all", "citibike"}:
        load_citibike(PROJECT_ROOT / args.citibike_dir)
    if args.dataset in {"all", "weather"}:
        load_weather(PROJECT_ROOT / args.weather_dir)
    if args.dataset in {"all", "holidays"}:
        load_holidays(PROJECT_ROOT / args.holidays_dir)
    if args.dataset in {"all", "geography"}:
        load_geography(PROJECT_ROOT / args.geo_dir)


if __name__ == "__main__":
    main()
