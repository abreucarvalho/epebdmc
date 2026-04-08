# ============================================================
# 04_transform_layer.R — Transform functions
# Run date: 2026-04-07
# ============================================================

# --- File: R/transform.R ---
# Contains 5 functions:
#
# 1. transform_clean(data, removeEmptyRows, cleanNames)
#    Trims whitespace, removes empty rows, standardizes column names.
#    Generic — works on any tibble.
#
# 2. transform_filter(data, ...)
#    Thin wrapper around dplyr::filter with logging.
#
# 3. transform_select(data, ...)
#    Thin wrapper around dplyr::select with logging.
#
# 4. transform_enrich(data, ...)
#    Thin wrapper around dplyr::mutate with logging.
#
# 5. transform_exclude_totals(data)
#    Domain-specific: removes ufId = 99 (Brasil aggregation row).
#    Use when computing your own totals to avoid double-counting.
#
# 6. transform_validate_totals(data, tolerance)
#    Domain-specific: compares sum of state emissions vs reported
#    Brasil total per sector x gas x year. Returns discrepancies.
#    Use for data quality checks before loading.
#
# Design decisions:
#    - Generic functions (clean, filter, select, enrich) wrap dplyr
#      with logging only — no added logic, no surprise behavior.
#    - Domain functions (exclude_totals, validate_totals) encode
#      BTR1 business rules (ufId = 99 = Brasil total).
#    - validate_totals uses tolerance = 0.01 kt due to floating
#      point rounding in the source Excel files.
