-- *********************************************************
-- schemas_sqlite.sql — SQLite table definitions
-- Package: epebdmc
-- *********************************************************

-- Metadata: tracks each extraction run
CREATE TABLE IF NOT EXISTS etl_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    source     TEXT NOT NULL,
    file_name  TEXT,
    rows_in    INTEGER,
    rows_out   INTEGER,
    started_at TEXT NOT NULL,
    finished_at TEXT,
    status     TEXT DEFAULT 'running'
);

-- Example target tables (replace with your actual tables)
CREATE TABLE IF NOT EXISTS raw_data (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    source     TEXT NOT NULL,
    loaded_at  TEXT NOT NULL,
    row_count  INTEGER
);

CREATE TABLE IF NOT EXISTS treated_data (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    source     TEXT,
    key        TEXT,
    value      TEXT,
    treated_at TEXT
);
