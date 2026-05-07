# Urban Night Mobility Data Warehouse

PostgreSQL/PostGIS data warehouse project for analyzing NYC Citi Bike night mobility during 2024, enriched with weather, holidays, and geographic boundaries.

The project is organized as a reproducible data warehousing pipeline:

1. Source acquisition into `data_raw/`
2. Minimal loading into PostgreSQL staging tables
3. Cleaning and integration into a reconciled relational layer
4. Dimensional warehouse population
5. OLAP SQL analysis and presentation demo

## Repository Structure

| Path | Purpose |
| --- | --- |
| `data_raw/` | Local downloaded source files. Ignored by Git. |
| `data_processed/` | Local intermediate files produced by scripts. Ignored by Git. |
| `sql/` | DDL, transformations, warehouse loading, checks, and OLAP queries. |
| `scripts/` | Python ETL and helper scripts. |
| `docs/` | Setup notes, source inventory, modeling notes, and demo notes. |
| `diagrams/` | DFM, ERD, and architecture diagrams. |
| `reports/` | Exported checks, query outputs, and presentation support files. |

## Local Stack

Required:

- Python 3.10+
- PostgreSQL 15+ or 16+
- PostGIS extension
- DBeaver for the live demo and development browsing

Recommended backup:

- pgAdmin, in case DBeaver has connection issues during presentation

## Setup Order

From the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Then create the local PostgreSQL database and schemas using the instructions in [docs/database_setup.md](docs/database_setup.md).

## Source Acquisition

Download the small holiday source first:

```powershell
.\.venv\Scripts\python scripts\download_holidays.py --year 2024 --country-code US
```

Download one Citi Bike month for development:

```powershell
.\.venv\Scripts\python scripts\download_citibike.py --months 202401
```

For the final full-year warehouse, use:

```powershell
.\.venv\Scripts\python scripts\download_citibike.py --months all-2024
```

Download NOAA daily weather for Central Park:

```powershell
.\.venv\Scripts\python scripts\download_weather_noaa.py
```

Downloaded files are stored under `data_raw/` and are intentionally ignored by Git. Update [docs/source_inventory.md](docs/source_inventory.md) with the row count after each source is acquired.

## Database Convention

Default local database name: `urban_night_mobility_dw`

Schemas:

- `staging`: raw-ish loaded source tables
- `reconciled`: cleaned integrated relational tables
- `dw`: dimensional warehouse facts and dimensions
- `audit`: row counts, load metadata, and data quality results

## Development Workflow

We will work in small milestones. For each milestone:

1. Decide the goal and demo value.
2. Make one focused code or SQL change.
3. Run the relevant verification command.
4. Review the diff.
5. Commit with a clear message.
6. Push to GitHub when the milestone is stable.

See [docs/development_workflow.md](docs/development_workflow.md) for the exact Git commands we will use together.

## Current Status

Implementation has started with Phase 1: repository and environment setup. The next major milestone is verifying the local PostgreSQL/PostGIS installation and connecting DBeaver to the project database.
