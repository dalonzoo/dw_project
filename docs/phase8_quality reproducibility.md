# Phase 8 - Quality Checks And Reproducibility

This phase adds a single reproducibility checkpoint for the January 2024 development warehouse. The goal is to show that the source-to-staging, staging-to-reconciled, and reconciled-to-dimensional warehouse transitions are auditable and internally consistent.

The main SQL file is:

```text
sql/quality/01_quality_checks.sql
```

It can be executed directly in DBeaver or through `psql`:

```powershell
.\.venv\Scripts\psql -d urban_night_mobility_dw -v ON_ERROR_STOP=1 -f sql\quality\01_quality_checks.sql
```

A Python wrapper is also available:

```powershell
.\.venv\Scripts\python scripts\run_quality_checks.py
```

---

## Checks included

| Check | Purpose |
|---|---|
| Source inventory vs staging row counts | Confirms that loaded staging counts match the documented January 2024 development sample. |
| Trip accounting | Confirms that every staging Citi Bike row is either accepted into `reconciled.trip` or stored in `reconciled.trip_rejection`. |
| Duplicate ride IDs | Reports duplicate IDs in staging and confirms the reconciled accepted trip table has unique ride IDs. |
| Invalid timestamps and durations | Reports missing timestamps, non-positive ranges, trips over 24 hours, missing stations, and missing coordinates. |
| Rejection reasons | Shows why rows were excluded from the accepted reconciled trip table. |
| Station geographic enrichment | Reports how many stations were assigned to NYC NTAs and how many remained outside or unknown. |
| Calendar and weather coverage | Verifies accepted trips can be matched to calendar and weather dimensions by date. |
| Fact dimension keys | Reports unknown surrogate keys and broken dimension joins in `dw.fact_trip`. |
| Aggregate fact reconciliation | Confirms station-day-hour aggregate totals match ride-grain facts for starts, ends, night trips, member trips, and casual trips. |
| Measure sanity | Checks invalid durations, negative distances, invalid trip counters, and rider indicators. |

---

## Expected January 2024 validation baseline

The current repository baseline is the January 2024 Citi Bike development sample plus full-year 2024 weather, holidays, and geographic boundaries. The expected staging counts are:

| Staging table | Expected rows |
|---|---:|
| `staging.citibike_trip_raw` | 1,888,085 |
| `staging.weather_raw` | 366 |
| `staging.holiday_raw` | 17 |
| `staging.nyc_nta_raw` | 262 |
| `staging.nyc_borough_raw` | 5 |

Previously validated downstream counts are:

| Layer | Expected result |
|---|---:|
| Accepted reconciled trips | 1,881,951 |
| Rejected staging trips | 6,134 |
| Reconciled stations | 2,262 |
| Warehouse ride-grain facts | 1,881,951 |
| Station-day-hour aggregate facts | 801,443 |
| Night trips | 285,097 |

Small differences are acceptable only if the source files are refreshed or the analysis period changes. If that happens, update `docs/source_inventory.md`, this document, and the expected constants in `sql/quality/01_quality_checks.sql`.

---

## Reproducible execution order

From a clean local clone, the intended order is:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

.\.venv\Scripts\python scripts\download_holidays.py --year 2024 --country-code US
.\.venv\Scripts\python scripts\download_citibike.py --months 202401
.\.venv\Scripts\python scripts\download_weather_noaa.py
.\.venv\Scripts\python scripts\download_nyc_boundaries.py

.\.venv\Scripts\python scripts\load_staging.py --create-tables --dataset all
.\.venv\Scripts\python scripts\build_reconciled.py
.\.venv\Scripts\python scripts\build_warehouse_schema.py
.\.venv\Scripts\python scripts\build_warehouse.py
.\.venv\Scripts\python scripts\run_quality_checks.py
```

The quality SQL is intentionally read-only. It does not modify staging, reconciled, or warehouse tables.

---

## Interpretation for the final discussion

The quality checks support three claims for the project defense:

1. The pipeline is reproducible from documented external sources.
2. Invalid or incomplete raw trips are not silently discarded; they are counted and classified in `reconciled.trip_rejection`.
3. The dimensional warehouse preserves the accepted trip population and the aggregate fact table reconciles with the ride-grain fact table.
