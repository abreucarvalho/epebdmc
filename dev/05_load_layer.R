# ============================================================
# 05_load_layer.R — Load functions
# Run date: 2026-04-07
# ============================================================

# --- File: R/load.R ---
# Contains 3 functions:
#
# 1. load_to_db(data, con, tableName, mode)
#    Generic loader. Writes any tibble to any table.
#    mode: "append" (default), "overwrite", or "fail".
#    Uses DBI::dbWriteTable — works with SQLite and SQL Server.
#    Logs row count after write for verification.
#
# 2. load_to_csv(data, path, ...)
#    Simple CSV export via readr::write_csv.
#
# 3. load_btr1(result, con, mode)
#    Domain-specific convenience function.
#    Takes the output of extract_btr1_uf() or extract_btr1_all()
#    and handles both dimYear seeding and factEmissions loading.
#    Detects whether metadata is single-sector or multi-sector.
#
# Design decisions:
#    - load_btr1() exists to simplify the most common workflow.
#      Instead of manually calling db_seed_dim_year + load_to_db,
#      the user calls one function.
#    - Metadata detection: if result$metadata has "inventoryPeriod"
#      directly, it's a single sector. If not, it's a list of
#      metadata objects from extract_btr1_all(), and we use the
#      first one (all sectors share the same year range).
