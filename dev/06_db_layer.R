# ============================================================
# 06_db_layer.R — Database connection and schema management
# Run date: 2026-04-07
# ============================================================

# --- File: R/db.R ---
# Contains three functions:
#
# 1. db_connect(backend, config)
#    Opens a DBI connection. SQLite is the active backend (v1).
#    SQL Server block is fully written but commented out.
#    Uses rlang's %||% operator for default values.
#    SQLite creates the .sqlite file automatically on first connect.
#
# 2. db_disconnect(con)
#    Safely closes a connection. Checks dbIsValid() first
#    to avoid errors on already-closed connections.
#
# 3. db_create_schema(con, sql_path)
#    Reads a .sql file, splits on semicolons, and executes each
#    CREATE TABLE IF NOT EXISTS statement.
#    No R-side schema definitions — the .sql file is the single
#    source of truth.

# --- Schema files: inst/config/ ---
#
# schemas_sqlite.sql (ACTIVE)
#   - Uses TEXT, INTEGER, REAL types
#   - AUTOINCREMENT for IDs
#   - Dates stored as TEXT in ISO 8601 format
#   - CREATE TABLE IF NOT EXISTS for safe re-runs
#   - Tables: etl_log, raw_data, treated_data (starter tables)
#   - Add new tables here as the project grows
#
# schemas_sqlserver.sql (FUTURE — fully commented)
#   - Same tables translated to SQL Server dialect
#   - NVARCHAR instead of TEXT, IDENTITY instead of AUTOINCREMENT
#   - DATETIME instead of TEXT for dates
#   - Uses sys.tables check instead of IF NOT EXISTS
#   - Uncomment when ready to migrate

# --- Design decisions ---
#
# Why .sql files instead of YAML:
#   - SQL is the native language for schema definition
#   - DBAs can review/edit without knowing R
#   - Supports FOREIGN KEY, INDEX, DEFAULT, CHECK constraints natively
#   - One less dependency (no yaml package needed)
#   - Migration = maintain two .sql files side by side
#
# Why DBI generics (not database-specific code):
#   - dbConnect, dbDisconnect, dbExecute, dbWriteTable, dbReadTable
#     all work identically across SQLite and SQL Server
#   - Backend swap requires only changing db_connect() config
#   - Transform and load code never touches SQL directly
