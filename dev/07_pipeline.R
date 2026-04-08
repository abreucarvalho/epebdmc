# ============================================================
# 07_pipeline.R — Pipeline orchestrator
# Run date: 2026-04-07
# ============================================================

# --- File: R/pipeline.R ---
# Contains 2 exported functions:
#
# 1. setup_btr1(dbname, sources, overwrite, validate)
#    The "run once" function. Full ETL pipeline in one call:
#      a) Downloads all 6 BTR1 sector files from MCTI (or local)
#      b) Validates state sums vs Brasil totals
#      c) Creates SQLite database + schema + dimension seed data
#      d) Loads all fact data into factEmissions
#    Returns summary: dbname, row count, sectors, years, discrepancies.
#    Uses on.exit() to guarantee connection cleanup on errors.
#    overwrite = TRUE for fresh load; FALSE (default) appends.
#
# 2. get_db(dbname)
#    Opens a connection to the populated database.
#    Used internally by user-facing query/plot functions.
#    Also exported for advanced users who want custom dplyr/SQL.
#    Checks that the database file exists first — gives a clear
#    error message pointing to setup_btr1() if not.
#
# --- USER WORKFLOW ---
#
# Phase 1 (once):
#   setup_btr1()
#
# Phase 2 (daily use — coming next):
#   get_emissions(sector = "Energy", uf = "SP", year = 2010:2022)
#   plot_emissions(sector = "Energy", region = "Sudeste")
#   export_emissions(format = "csv", path = "my_data.csv")
#
# --- DESIGN DECISIONS ---
#
# - setup_btr1() wraps extract_btr1_all() + validate + schema +
#   load into a single call. Users never need to understand the
#   ETL internals.
# - get_db() exists because user-facing functions need a
#   connection but shouldn't each take dbname as a parameter
#   pattern — centralizing it here keeps the API clean.
# - The database is an implementation detail. Users interact
#   with get_emissions() / plot_emissions() — not with SQL or
#   connections.
