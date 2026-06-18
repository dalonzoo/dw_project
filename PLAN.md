# Urban Night Mobility Data Warehouse Roadmap

## How To Use This File
- This file is the project source of truth. Every contributor working on the project must update it before stopping.
- Status values: `TODO`, `DOING`, `BLOCKED`, `DONE`.
- Before stopping work, update `Current Resume Point`, the relevant phase status, and `Progress Log`.
- Do not mark a task as `DONE` unless its "Done when" checks are satisfied.
- The proposal is approved, so implementation can start.
- If work stops mid-task, leave a short note in `Progress Log` explaining what changed, what was verified, and what should happen next.

## Current Resume Point
- Overall status: `DONE`.
- Next step: project complete; send or present final materials as needed.
- Current phase: Completed project.
- Last updated: 2026-06-18.

## Project Goal And Grade Strategy
Build a PostgreSQL/PostGIS data warehouse that analyzes Citi Bike urban night mobility in NYC, enriched with weather, holidays, and geographic boundaries. The project aims for the highest grade by showing:

- Multiple integrated data sources through documented ETL.
- A reconciled relational layer before the warehouse.
- Mandatory DFM plus physical star/snowflake schema.
- At least 3 non-trivial OLAP dimensions with real hierarchies.
- Detailed SQL OLAP sessions with motivated findings.
- A clear 10-15 minute presentation and 5 minute live demo.

## Fixed Decisions
- Project type: Data Warehousing.
- Main fact grain: one Citi Bike ride in `fact_trip`.
- Performance aggregate: station, day, and hour grain in `fact_station_day_hour`.
- Default data period: full year 2024 for final analysis; use a smaller sample only for development.
- Storage stack: PostgreSQL with PostGIS.
- ETL stack: Python scripts plus SQL scripts.
- Main DB/demo GUI: DBeaver connected to PostgreSQL.
- Backup DB GUI: pgAdmin, mainly as a fallback if DBeaver has issues.
- Diagram tools: diagrams.net/draw.io for DFM and architecture diagrams; DBeaver ERD for live physical-schema browsing.
- Optional analysis/charting layer: Jupyter, Quarto, or exported query results for charts in slides.
- Main non-trivial dimensions:
  - Time: timestamp -> hour -> part of day -> day -> week -> month -> quarter -> season -> year.
  - Calendar/Event: date -> weekday/weekend -> holiday window -> long weekend -> holiday type.
  - Geography: station -> NTA -> CDTA/community district -> borough -> city.
  - Weather: daily observation -> condition class -> severity -> season.
- Safer proposal deadline: July 31, 2026 from the instructions. The FAQ mentions August 31, 2026, so ask the professor only if timing depends on the later date.

## Tooling Strategy
- Use PostgreSQL as the real DBMS for the course deliverable, not only CSV files or notebooks.
- Enable PostGIS because the project needs spatial ETL: station coordinates must be assigned to neighborhood/community district/borough polygons.
- Use Python for downloading, cleaning, and transforming source files, but persist the final staging, reconciled, and warehouse layers in PostgreSQL.
- Use DBeaver during development and presentation to show schemas, tables, saved SQL scripts, query results, and OLAP sessions.
- Keep pgAdmin installed or available as a backup PostgreSQL administration tool.
- Use diagrams in the final explanation: DFM conceptual schema, staging/reconciled/warehouse architecture, and physical star/snowflake schema.
- For presentation, show the professor the database live through DBeaver, plus slides/charts for the most important insights.

## Sources
- Citi Bike System Data: https://citibikenyc.com/system-data
- NOAA GHCN-Daily: https://www.ncei.noaa.gov/products/land-based-station/global-historical-climatology-network-daily
- NOAA README: https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt
- Nager.Date API: https://date.nager.at/Api
- NYC NTAs: https://catalog.data.gov/dataset/2020-neighborhood-tabulation-areas-ntas
- NYC Borough Boundaries: https://catalog.data.gov/dataset/borough-boundaries

## User Actions
- [x] Prepare the single-page PDF proposal with both students' names and matricole.
- [x] Send the proposal email with subject `[DM] Project Proposal`, all group members included, and the PDF attached.
- [x] Receive professor approval before starting implementation.
- [ ] At the end of the project, send slides, repository link, and any useful material with subject `[DM] Project Discussion`.

## Roadmap

### Phase 0 - Proposal Approval
Status: `DONE`

Goal: obtain approval for the project idea before implementation.

Tasks:
- [x] Draft proposal in `project_idea.md`.
- [x] Remove unsupported age-based wording from the proposal.
- [x] Strengthen the proposal around non-trivial dimensional hierarchies.
- [x] Create this roadmap in `PLAN.md`.
- [x] Add real student names and matricole to the submitted proposal PDF.
- [x] Export the proposal as a one-page PDF.
- [x] Send the proposal email and receive approval.

Done when:
- The professor approves the proposal.
- If later feedback arrives, update this roadmap with the requested changes before continuing implementation.

### Phase 1 - Repository And Environment Setup
Status: `DONE`

Goal: make the repository reproducible and ready for ETL, SQL, diagrams, and reports.

Tasks:
- [x] Create a clean folder structure: `data_raw/`, `data_processed/`, `sql/`, `scripts/`, `docs/`, `diagrams/`, `reports/`.
- [x] Add a `README.md` explaining project goal, sources, setup, and execution order.
- [x] Add dependency files, preferably `requirements.txt` for Python and notes for PostgreSQL/PostGIS.
- [x] Add `.gitignore` rules for raw data, processed data, caches, database dumps, and local secrets.
- [x] Decide local database name, schema names, and connection configuration.
- [x] Install or verify PostgreSQL and enable the PostGIS extension.
- [x] Install or verify DBeaver and create a saved connection to the local PostgreSQL database.
- [x] Install or verify pgAdmin as a backup administration tool.
- [x] Decide the diagram tool to use for DFM and schema diagrams.

Done when:
- A new contributor can clone the repo, install dependencies, and understand where each artifact belongs.
- Raw data is not committed to Git.
- DBeaver can connect to the local PostgreSQL database.
- PostgreSQL can run `CREATE EXTENSION IF NOT EXISTS postgis;`.

### Phase 2 - Source Acquisition
Status: `DONE`

Goal: download or document all source datasets needed for the warehouse.

Tasks:
- [x] Download or script download of Citi Bike monthly trip files for 2024.
- [x] Download or script download of NOAA daily weather data for one or more NYC-area stations.
- [x] Fetch or script fetch of US public holidays from Nager.Date for 2024.
- [x] Download NYC NTA/CDTA/community district and borough boundaries.
- [x] Create a source inventory table in the README or `docs/source_inventory.md`.
- [x] Record file names, source URLs, extraction date, row counts, and known limitations.

Done when:
- Every source has a reproducible acquisition method or a documented manual step.
- Every source has a row count and a short semantic description.

### Phase 3 - Staging Layer
Status: `DONE`

Goal: load raw source data into database staging tables with minimal transformation.

Expected staging tables:
- `staging.citibike_trip_raw`
- `staging.weather_raw`
- `staging.holiday_raw`
- `staging.nyc_nta_raw`
- `staging.nyc_borough_raw`
- `staging.stg_station_observations` or an equivalent station observation staging table, if needed after reviewing the raw Citi Bike station fields.

Tasks:
- [x] Write SQL DDL for staging schemas and tables.
- [x] Preserve raw source columns where practical.
- [x] Add load metadata: source file, load timestamp, and source period where applicable.
- [x] Produce staging row-count checks.
- [x] Add Phase 3 staging documentation to the repository.
- [x] Write or finalize loading scripts for CSV/JSON/geospatial files.
- [x] Run staging DDL locally from the repository.
- [x] Verify all staging tables exist in PostgreSQL/PostGIS.
- [x] Load the January 2024 Citi Bike development sample.
- [x] Load weather, holiday, NTA, and borough source files.
- [x] Run validation SQL and compare row counts against source inventory.

Done when:
- All sources load into staging without manual database edits.
- Row counts match the downloaded files or documented filters.


### Phase 4 - Reconciled Layer
Status: `DONE`

Goal: convert raw source tables into clean, semantically consistent relational tables.

Expected reconciled entities:
- Trips with validated timestamps, duration, start/end station references, coordinates, rideable type, and rider type.
- Stations with stable IDs, names, coordinates, and geographic assignment.
- Dates and calendar events with holiday windows and long-weekend flags.
- Daily weather observations with derived condition and severity attributes.
- Geographic areas with NTA/CDTA/community district, borough, and city hierarchy.

Tasks:
- [x] Define cleaning rules for invalid trips: missing timestamps, end before start, impossible coordinates, missing station IDs, and extreme durations.
- [x] Derive trip duration, approximate distance, day/night category, weekend flag, and flow direction.
- [x] Build station reconciliation from observed start/end stations.
- [x] Use PostGIS point-in-polygon joins to assign stations to geographic areas.
- [x] Derive holiday eve, holiday, post-holiday, bridge day, and long-weekend attributes.
- [x] Derive weather class and weather severity score.
- [x] Document every exclusion and transformation rule.

Done when:
- Reconciled tables have primary keys and foreign keys where appropriate.
- Data quality checks explain any excluded or unknown records.
- The reconciled layer can be explained independently from the warehouse.

### Phase 5 - DFM And Warehouse Design
Status: `DONE`

Goal: produce the conceptual DFM and the physical star/snowflake schema.

Tasks:
- [x] Draw the DFM with `fact_trip` at the center.
- [x] Show measures: trip count, duration, approximate distance, late-night indicator, member/casual indicators, and flow contribution.
- [x] Show non-trivial Time, Calendar/Event, Geography, and Weather hierarchies.
- [x] Decide which dimensions are denormalized and which are snowflaked.
- [x] Motivate the star/snowflake choice in `docs/modeling_notes.md`.
- [x] Write SQL DDL for the warehouse schema.
- [x] Add indexes for common OLAP paths.
- [x] Export final diagrams into `diagrams/` and reference them from the README/slides.

Done when:
- The DFM diagram and physical schema are consistent.
- At least 3 dimensions clearly contain OLAP hierarchies.
- The schema choice can be defended during the presentation.

### Phase 6 - Warehouse Population
Status: `DONE`

Goal: populate dimensions and facts from the reconciled layer.

Expected warehouse tables:
- `dim_time`
- `dim_date`
- `dim_calendar_event`
- `dim_weather`
- `dim_station`
- `dim_geography`
- `dim_user_type`
- `dim_rideable_type`
- `fact_trip`
- `fact_station_day_hour`

Tasks:
- [x] Populate dimensions with surrogate keys.
- [x] Populate `fact_trip` at ride grain.
- [x] Populate `fact_station_day_hour` for demo-friendly OLAP.
- [x] Add controlled `unknown` dimension rows where necessary.
- [x] Verify that fact foreign keys resolve correctly.
- [x] Compare staging/reconciled counts against fact counts after exclusions.

Done when:
- Warehouse tables are populated from scripts end to end.
- Fact counts reconcile with documented exclusions.
- OLAP queries can run without scanning raw staging tables.

### Phase 7 - OLAP Analysis
Status: `DONE`

Goal: create SQL analyses that demonstrate meaningful insights and OLAP operations.

Required analysis sessions:
- [x] Nightlife demand by borough/NTA across weekdays, weekends, and holiday windows.
- [x] Weather impact on casual vs member riders.
- [x] Station inflow/outflow imbalance by time of day and geography.
- [x] Electric vs classic bike usage at night and under bad weather.
- [x] Top night mobility corridors using start/end NTA pairs.
- [x] Before/after holiday and long-weekend effects.

Each analysis must include:
- SQL query.
- OLAP operation shown, such as roll-up, drill-down, slice, dice, or pivot.
- Result table or chart.
- Short interpretation of the finding.
- DBeaver-ready SQL file or script section that can be executed during the demo.

Done when:
- There are at least 5 polished OLAP queries.
- Results are non-trivial and tied back to the modeling choices.
- Queries finish fast enough for the live demo.

### Phase 8 - Quality Checks And Reproducibility
Status: `DONE`

Goal: make the project reliable enough to defend.

Checks:
- [x] Raw file row counts match staging row counts.
- [x] Duplicate ride IDs are detected and handled.
- [x] Invalid timestamps and impossible durations are reported.
- [x] Station geographic enrichment coverage is reported.
- [x] Weather and calendar joins have expected coverage.
- [x] Every fact row has valid dimension keys or controlled `unknown` keys.
- [x] Aggregate fact totals match ride-grain fact totals for equivalent filters.

Done when:
- A script or documented SQL file runs the main checks.
- The README explains how to reproduce the checks.

### Phase 9 - Presentation And Demo
Status: `DONE`

Goal: prepare a clear 10-15 minute presentation plus 5 minute live demo.

Slide outline:
- [x] Problem and motivation.
- [x] Data sources and integration challenge.
- [x] ETL architecture: staging, reconciled layer, warehouse.
- [x] DFM and dimensional hierarchies.
- [x] Physical star/snowflake schema.
- [x] OLAP sessions and main insights.
- [x] Limitations and possible extensions.
- [x] Demo instructions.

Demo checklist:
- [x] DBeaver opens and connects to the PostgreSQL database.
- [x] Database starts correctly.
- [x] Warehouse tables are populated.
- [x] Schemas `staging`, `reconciled`, and `dw` are visible in DBeaver.
- [x] Key tables are ready to show: `fact_trip`, `fact_station_day_hour`, `dim_date`, `dim_station`, `dim_geography`, and `dim_weather`.
- [x] Selected OLAP queries run within the available time.
- [x] At least one PostGIS geographic enrichment example is ready to show or explain.
- [x] Results shown in terminal, database client, notebook, or exported report.

Done when:
- Slides fit 10-15 minutes.
- Demo fits 5 minutes.
- Repository link and materials are ready for the discussion email.

## Acceptance Checklist
- [x] Proposal approved.
- [x] Reconciled layer implemented and documented.
- [x] DFM completed.
- [x] Star/snowflake schema implemented in PostgreSQL.
- [x] PostgreSQL/PostGIS environment reproducible.
- [x] DBeaver demo connection configured and tested.
- [x] ETL scripts run end to end.
- [x] At least 3 non-trivial dimensional hierarchies are visible and used.
- [x] At least 5 OLAP analyses are implemented and interpreted.
- [x] README explains setup, data acquisition, ETL, warehouse build, analysis, and quality checks.
- [x] Slides and live demo are ready.

## Progress Log
- 2026-05-05: Initial proposal and roadmap prepared while approval was still pending.
- 2026-05-05: Proposal marked as approved. Current resume point moved to Phase 1: repository and environment setup.
- 2026-05-07: Added Phase 1 repository skeleton, README, dependency file, ignore rules, database setup notes, source inventory, development workflow, and initial PostgreSQL/PostGIS schema bootstrap SQL. `psql` was not found in PowerShell, so local PostgreSQL installation/PATH verification remains the next checkpoint.
- 2026-05-07: Verified Python 3.10.7, created `.venv`, installed Python ETL dependencies, verified PostgreSQL 18, verified pgAdmin and DBeaver executables, confirmed `.env` is ignored by Git, created/initialized database `urban_night_mobility_dw`, enabled PostGIS, and verified schemas `staging`, `reconciled`, `dw`, and `audit`.
- 2026-05-07: Closed Phase 1 after DBeaver verification and selected diagrams.net/draw.io as the main diagram tool. Started Phase 2 with a reproducible Nager.Date holiday acquisition script.
- 2026-05-07: Ran `scripts/download_holidays.py` for 2024 US public holidays. Downloaded 17 rows into ignored raw data files and recorded extraction metadata in `docs/source_inventory.md`.
- 2026-05-07: Added `scripts/download_citibike.py` for Citi Bike monthly files. The script defaults to one development month and supports `--months all-2024` for final full-year acquisition.
- 2026-05-07: Ran `scripts/download_citibike.py --months 202401`. Downloaded January 2024 Citi Bike trip data: 369035302-byte ZIP, 2 CSV members, and 1888085 ride rows. This is sufficient for development; full 2024 remains the final target for stronger seasonality and holiday analysis.
- 2026-05-07: Added and ran `scripts/download_weather_noaa.py`. Downloaded 366 daily NOAA NCEI Daily Summaries rows for Central Park station `GHCND:USW00094728` covering 2024, with temperature, precipitation, snow, wind, and weather-type flag columns.
- 2026-05-07: Added `scripts/download_nyc_boundaries.py` for NYC Open Data GeoJSON boundary downloads: 2020 NTAs and borough boundaries.
- 2026-05-07: Ran `scripts/download_nyc_boundaries.py`. Downloaded 262 NTA MultiPolygon features and 5 borough MultiPolygon features. NTA properties include NTA, CDTA, borough, and county fields needed for the geography hierarchy.
- 2026-05-10: Completed and validated Phase 3 staging implementation locally on PostgreSQL 17/PostGIS 3.6. Ran staging DDL from the repository, loaded January 2024 Citi Bike trips, NOAA 2024 weather, 2024 US holidays, NYC 2020 NTA boundaries, and NYC borough boundaries into PostgreSQL/PostGIS staging tables. Validation confirmed expected row counts: 1,888,085 Citi Bike trips, 366 weather rows, 17 holiday rows, 262 NTA features, and 5 borough features. Duplicate ride IDs, invalid time ranges, invalid NTA geometries, and invalid borough geometries were all zero. The 1,160 Citi Bike rows with missing start coordinates are preserved in staging and deferred to Phase 4 cleaning.
- 2026-05-24: Completed Phase 4 reconciled implementation for the January 2024 development sample. Added `sql/reconciled/01_create_reconciled_tables.sql`, `02_load_reconciled.sql`, `03_validate_reconciled.sql`, `scripts/build_reconciled.py`, and `docs/phase4_reconciled.md`. Local validation confirmed 1,881,951 accepted trips and 6,134 rejected staging trips, accounting for all 1,888,085 Citi Bike staging rows. Built 2,262 reconciled stations, assigned 2,223 to NYC NTAs, classified 39 as outside NYC or unknown, and derived calendar, weather, distance, night-trip, weekend, and flow-direction attributes.
- 2026-06-04: Completed Phase 5 DFM and warehouse design. Added `docs/modeling_notes.md`, `docs/phase5_warehouse_design.md`, `diagrams/phase5_dfm.drawio`, `diagrams/phase5_physical_schema.drawio`, `sql/dw/01_create_warehouse_tables.sql`, `sql/dw/02_validate_warehouse_schema.sql`, and `scripts/build_warehouse_schema.py`. Ran the warehouse schema builder locally and validated 10 `dw` tables, 18 foreign keys, and OLAP indexes. Current resume point moved to Phase 6 warehouse population.
- 2026-06-04: Completed Phase 6 warehouse population for the January 2024 development sample. Added `sql/dw/03_load_warehouse.sql`, `sql/dw/04_validate_warehouse_load.sql`, `scripts/build_warehouse.py`, and `docs/phase6_warehouse_population.md`. Local validation populated 1,881,951 ride-grain facts and 801,443 station-day-hour aggregate facts. Fact counts reconcile exactly with `reconciled.trip`, aggregate starts and ends both sum to 1,881,951, and night-trip totals match at 285,097. Current resume point moved to Phase 7 OLAP analysis.
- 2026-06-05: Completed Phase 7 OLAP analysis on the populated January 2024 dimensional warehouse. Added `sql/olap/01_olap_analysis.sql` with seven DBeaver-ready OLAP analyses covering night demand, weather impact by rider type, station inflow/outflow imbalance, rideable type usage under weather severity, night origin-destination corridors, holiday and long-weekend effects, and hourly night mobility profiles. Executed the OLAP SQL successfully with `ON_ERROR_STOP=1` and documented the main findings in `docs/phase7_olap_analysis.md`. Current resume point moved to Phase 8 quality checks and reproducibility validation.
- 2026-06-05: Completed Phase 8 quality checks and reproducibility support. Added `sql/quality/01_quality_checks.sql`, `scripts/run_quality_checks.py`, and `docs/phase8_quality_reproducibility.md`. The checks cover source/staging row-count reconciliation, accepted/rejected trip accounting, duplicate ride IDs, invalid timestamps and durations, station geographic enrichment coverage, calendar/weather coverage, fact dimension key integrity, aggregate fact reconciliation, and measure sanity. Fixed README formatting around OLAP execution, added quality-check instructions, updated `scripts/README.md`, and moved the current resume point to Phase 9 presentation and demo preparation.
- 2026-06-18: Finalized the roadmap wording, completed Phase 9 presentation and demo tracking, and marked the project as complete.



## Open Questions
- Decide whether final execution will use all 12 months of 2024 or a reduced final subset if local compute becomes too slow.

## Deferred Notes
- Full-year Citi Bike acquisition is intentionally postponed until the DFM and warehouse-loading scripts are stable on the January 2024 development sample.
- Additional NYC-area weather stations, such as airport stations, are optional later if Central Park coverage proves insufficient for borough-level interpretation.
