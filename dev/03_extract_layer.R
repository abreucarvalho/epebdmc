# ============================================================
# 03_extract_layer.R — Extract functions
# Run date: 2026-04-07
# ============================================================

# --- File: R/extract.R ---
# Contains 8 functions (3 exported, 5 internal):
#
# EXPORTED:
#
# 1. extract_excel(path, sheet, ...)
#    Generic Excel reader. Returns raw tibble as-is (wide format).
#    No business logic — works with any .xlsx/.xls file.
#
# 2. extract_btr1_uf(source)
#    Domain-specific extractor for any BTR1_UF_*.xlsx file.
#    Accepts a local file path or URL (defaults to MCTI URL).
#    Auto-detects sector from row 4 and gas sheets from the file.
#    Returns list with $data (long-format tibble ready for
#    factEmissions) and $metadata (inventoryPeriod, sectorId,
#    years, sheetNames).
#    Works with all 6 files: Energia, IPPU, Agropecuária,
#    LULUCF, Resíduos, Total_Brasil.
#
# 3. extract_btr1_all(sources)
#    Convenience wrapper that extracts all 6 sector files in one
#    call. Default sources are the official MCTI download URLs.
#    Returns combined $data + list of $metadata per sector.
#
# INTERNAL (@keywords internal, not exported):
#
# 4. resolve_source(source)
#    Resolves a source to a local file path. If it's a URL,
#    downloads to a temp file using httr2. If local, validates
#    it exists. Used by extract_btr1_uf() so users can pass
#    either URLs or file paths interchangeably.
#
# 5. parse_btr1_metadata(path)
#    Reads header rows from the Excel file to extract:
#    - inventoryPeriod: parsed from row 4, e.g. "BTR1 (1990-2022)"
#      Detects report number from Portuguese ordinals (Primeiro,
#      Segundo...) and year range from parentheses pattern.
#    - sectorId + sectorNamePt: detected from row 4 by matching
#      sector keywords (Energia, IPPU, Agropecuária, etc.)
#    - years: read from column headers in row 6
#    - sheetNames: all sheets in the file
#    Future-proof: if MCTI publishes BTR2 with years to 2024,
#    this parses it automatically with no code changes.
#
# 6. gas_id_from_sheet(sheet_name)
#    Maps Excel sheet names to gasId integers matching dimGasType
#    seed data. Handles all 7 known gases:
#      CO2 eq -> 1, CO2 -> 2, CH4 -> 3, N2O -> 4,
#      HFCs -> 5, PFCs -> 6, SF6 -> 7
#    Returns NA for unrecognized sheets (with a warning).
#
# 7. uf_ibge_map()
#    Returns named integer vector mapping state names (as they
#    appear in the spreadsheets) to official IBGE UF codes.
#    Uses Unicode escapes (\u00f4 for ô, etc.) for encoding
#    safety across platforms.
#    NOTE: This duplicates information in dimUf seed data by
#    design — extract functions must work without a database
#    connection, so the mapping lives in code too.
#
# 8. extract_btr1_sheet(path, sheet_name, gas_id, sector_id)
#    Workhorse that reads a single sheet: renames first column,
#    removes empty rows, maps state names to IBGE codes via
#    uf_ibge_map(), and unpivots wide-to-long with
#    tidyr::pivot_longer. Returns tibble with columns:
#    ufId, sectorId, gasId, yearId, emissionKt.
#    Warns on unmapped state names.
#
# --- DATA SOURCE ---
#
# Files come from MCTI's SIRENE platform:
# https://www.gov.br/mcti/pt-br/acompanhe-o-mcti/cgcl/clima/
#   arquivos/arquivos_bi/5-aba/
#
# All 6 files share identical structure:
#   - Rows 1-2: MCTI / SIRENE header
#   - Row 3: empty
#   - Row 4: report description with sector name and year range
#   - Row 5: empty
#   - Row 6: column headers (gas unit + years 1990-2022)
#   - Rows 7-33: 27 states (UFs)
#   - Row 34: Brasil total
#   - Each sheet = one gas type
#
# Files with 4 sheets: Energia, Agropecuária, LULUCF, Resíduos
#   Sheets: CO2 eq, CO2, CH4, N2O
#
# Files with 7 sheets: IPPU, Total_Brasil
#   Sheets: CO2 eq, CO2, CH4, N2O, HFCs, PFCs, SF6
#   F-gas sheets (HFCs, PFCs, SF6) are already in CO2 eq units.
#
# --- DESIGN DECISIONS ---
#
# - Generic vs domain-specific: extract_excel() is reusable for
#   any Excel file. extract_btr1_uf() encodes BTR1 business logic
#   (header parsing, sheet mapping, unpivoting). Kept separate so
#   generic functions stay clean.
#
# - URL as default: extract_btr1_uf() and extract_btr1_all()
#   default to the MCTI download links, so calling with no args
#   fetches the latest data. Local paths still work for offline
#   use and testing.
#
# - Return list not tibble: extract_btr1_uf() returns
#   list(data, metadata) so the pipeline can use metadata to seed
#   dimYear dynamically. Metadata is parsed once, not hardcoded.
#
# - Auto-detection over configuration: sector, report number, and
#   year range are all parsed from the file header. No config file
#   or function arguments needed to specify them.
#
# - purrr::map_dfr for iteration: processes all sheets in a file
#   (and all files in extract_btr1_all) functionally, binding
#   results into a single tibble.
