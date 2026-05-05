# Urban Night Mobility Data Warehouse

## Summary
Build a PostgreSQL/PostGIS data warehouse that analyzes Citi Bike night and weekend mobility in NYC, enriched with weather, holidays, and geography. The project will target a top grade by emphasizing a clear reconciled layer, a well-motivated DFM, a snowflake/star schema hybrid, and more than 3 non-trivial dimensional hierarchies.

Use a full, stable year of Citi Bike trip data, preferably 2024 for reproducibility unless you later confirm 2025 is complete and easier to use. Official Citi Bike trip files include ride ID, bike type, timestamps, station IDs/names, coordinates, and member/casual status. NOAA GHCN-Daily provides daily weather elements such as precipitation, snow, temperature, and wind. Nager.Date provides public holiday metadata. NYC boundary data should use NTAs/CDTAs plus boroughs, not boroughs alone, to satisfy the professor's hierarchy warning.

Sources: [Citi Bike System Data](https://citibikenyc.com/system-data), [NOAA GHCN-Daily](https://www.ncei.noaa.gov/products/land-based-station/global-historical-climatology-network-daily), [NOAA README](https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt), [Nager.Date API](https://date.nager.at/Api), [NYC NTAs](https://catalog.data.gov/dataset/2020-neighborhood-tabulation-areas-ntas), [NYC Borough Boundaries](https://catalog.data.gov/dataset/borough-boundaries).

## Key Changes
- Use a 3-layer architecture: raw staging, reconciled relational layer, dimensional warehouse.
- Model the main fact as `fact_trip`, at ride grain, with measures: trip count, duration, approximate distance, night flag, weekend flag, holiday-window flag, weather severity score, member/casual indicators, and station flow contribution.
- Add a second aggregate fact, `fact_station_day_hour`, to support OLAP without scanning all rides during the demo.
- Use a snowflaked dimensional model where it improves hierarchy depth:
  - Time: timestamp -> hour -> part of day -> day -> week -> month -> quarter -> season -> year.
  - Calendar/Event: date -> weekday/weekend -> holiday/bridge day/long weekend -> holiday type.
  - Geography: station -> NTA -> CDTA/community district -> borough -> city.
  - Station: station -> docking area role -> neighborhood -> borough, with start/end station roles handled through foreign keys.
  - Weather: daily observation -> weather condition class -> precipitation/wind/temperature severity -> season.
  - Rider/Bike: member/casual and classic/electric/docked bike dimensions.
- Prefer PostgreSQL plus PostGIS because geographic point-in-polygon station enrichment is a strong, defensible modeling/ETL feature.

## Implementation Plan
- Prepare the proposal and scope:
  - User action required: fill in both students' names and matricole.
  - User action required: send the one-page proposal and wait for approval before starting full implementation, as the course instructions require.
  - Use July 31, 2026 as the safer proposal deadline from the instructions; the FAQ mentions August 31, 2026, so ask the professor only if submission timing depends on the later date.
- Build ETL:
  - Download selected Citi Bike monthly ZIP/CSV files.
  - Load raw files into staging tables with minimal transformation.
  - Clean invalid trips: missing timestamps, end before start, unusable station IDs, impossible coordinates, extreme durations.
  - Derive duration, distance approximation, start/end date keys, hour keys, day/night category, weekend flag, and trip direction.
  - Load NOAA daily weather for NYC-area stations, choose one primary station or average selected nearby stations, and document the choice.
  - Load Nager.Date US holidays and derive bridge days, holiday eves, post-holiday days, and long weekends.
  - Load NYC NTA/CDTA/borough boundaries and assign stations by spatial join.
- Design deliverables:
  - DFM diagram with the ride fact centered and all hierarchies visible.
  - Logical reconciled schema.
  - Physical star/snowflake schema in PostgreSQL.
  - SQL scripts for schema creation, ETL loading, constraints, indexes, and OLAP queries.
  - Short slide deck: problem, sources, ETL, reconciled layer, DFM, warehouse schema, OLAP findings, demo.
- OLAP analysis sessions:
  - Nightlife demand by borough/NTA, comparing weekday nights, weekend nights, and holiday windows.
  - Weather impact on casual vs member riders, including rain, cold/heat, snow, and wind severity.
  - Station inflow/outflow imbalance by time of day and geography.
  - Electric vs classic bike usage at night and under bad weather.
  - Top "night mobility corridors" using start/end NTA pairs.
  - Before/after holiday and long-weekend effects.

## Test Plan
- Data quality checks: row counts per month, null rates, duplicate ride IDs, invalid timestamps, coordinate bounds, station enrichment coverage.
- Reconciliation checks: every warehouse fact row has valid date, time, rider, bike, weather, and geography keys or a controlled `unknown` key.
- OLAP checks: aggregate trip counts match staging counts after documented exclusions.
- Demo checks: queries finish within presentation time using indexes and the aggregate fact table.
- Presentation acceptance: 10-15 minute slides plus 5 minute live demo, with SQL queries shown and results interpreted.

## Assumptions
- The project remains a Data Warehousing project, not a NoSQL comparison.
- The default implementation stack is Python for ETL and PostgreSQL/PostGIS for storage and spatial enrichment.
- The default data period is full-year 2024 for stability; switch to full-year 2025 only after confirming all files are available and processing time remains manageable.
- The final submission includes repository link, slides, SQL, ETL scripts, diagrams, and a concise README explaining how to reproduce the warehouse.
