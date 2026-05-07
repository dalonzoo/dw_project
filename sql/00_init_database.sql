CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS reconciled;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.load_event (
    load_event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_name TEXT NOT NULL,
    source_file TEXT,
    source_period TEXT,
    row_count BIGINT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT
);

COMMENT ON SCHEMA staging IS 'Raw source tables loaded with minimal transformation.';
COMMENT ON SCHEMA reconciled IS 'Clean integrated relational layer before dimensional modeling.';
COMMENT ON SCHEMA dw IS 'Dimensional warehouse facts and dimensions.';
COMMENT ON SCHEMA audit IS 'Load metadata, row counts, and data quality checks.';
