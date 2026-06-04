# Phase 5 - DFM And Warehouse Design

## Goal

Phase 5 defines the dimensional model that will be populated in Phase 6.

The phase produces:

- DFM and physical-schema diagrams in `diagrams/`.
- Modeling notes in `docs/modeling_notes.md`.
- Warehouse DDL in `sql/dw/01_create_warehouse_tables.sql`.
- A schema validation script in `sql/dw/02_validate_warehouse_schema.sql`.

## Artifacts

| Artifact | Purpose |
| --- | --- |
| `docs/modeling_notes.md` | Explains grain, measures, dimensions, hierarchies, and star/snowflake choices. |
| `diagrams/phase5_dfm.drawio` | Conceptual DFM diagram for diagrams.net. |
| `diagrams/phase5_physical_schema.drawio` | Physical warehouse overview for diagrams.net. |
| `sql/dw/01_create_warehouse_tables.sql` | Creates the `dw` facts, dimensions, constraints, and indexes. |
| `sql/dw/02_validate_warehouse_schema.sql` | Lists created warehouse tables, columns, and foreign keys. |
| `scripts/build_warehouse_schema.py` | Executes and validates the Phase 5 warehouse schema. |

## Run Order

From the project root:

```powershell
.\.venv\Scripts\python scripts\build_warehouse_schema.py
```

Or use DBeaver:

1. Open the `urban_night_mobility_dw` PostgreSQL connection.
2. Open `sql/dw/01_create_warehouse_tables.sql`.
3. Execute the full script.
4. Refresh `Schemas > dw > Tables`.
5. Open `sql/dw/02_validate_warehouse_schema.sql`.
6. Execute each validation section.

## Visual Walkthrough

Use diagrams.net:

1. Open diagrams.net.
2. Select `File > Open From > Device`.
3. Open `diagrams/phase5_dfm.drawio`.
4. Review `fact_trip` at the center and the surrounding dimensions.
5. Open `diagrams/phase5_physical_schema.drawio`.
6. Compare it with DBeaver's ER diagram for schema `dw`.

Use DBeaver:

1. Refresh the database object tree.
2. Expand `Schemas > dw > Tables`.
3. Select `fact_trip`, `dim_station`, `dim_geography`, `dim_date`, `dim_time`, `dim_weather`, and `dim_calendar_event`.
4. Right-click and open an ER Diagram.
5. Use the visible foreign keys to explain role-playing dimensions and the station-to-geography snowflake edge.

## Design Snapshot

Main fact:

- `dw.fact_trip`, one row per accepted ride.

Aggregate fact:

- `dw.fact_station_day_hour`, one row per station, date, and hour.

Main dimensions:

- `dw.dim_date`
- `dw.dim_time`
- `dw.dim_calendar_event`
- `dw.dim_weather`
- `dw.dim_geography`
- `dw.dim_station`
- `dw.dim_user_type`
- `dw.dim_rideable_type`

The model is a hybrid star/snowflake schema: the facts connect directly to analytical dimensions, while station geography is normalized through `dim_station -> dim_geography`.

