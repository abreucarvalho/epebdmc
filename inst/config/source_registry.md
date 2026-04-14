# Source Registry — epebdmc

This document tracks all data sources planned or integrated into the
package. It serves as a reference for planning dimensions, avoiding
duplication, and tracking progress.

## How to Use This Registry

When adding a new source:
1. Add an entry below with what you know
2. Inspect the actual data files
3. Check the "Shared Dimensions" column for what already exists
4. Fill in "New Dimensions" only after seeing the real data
5. Update status as you progress

## Dimension Inventory

Dimensions already implemented and available for reuse:

| Dimension    | Key       | Description                                  | Created By |
|--------------|-----------|----------------------------------------------|------------|
| dimUf        | ufId      | 27 states + DF + Brasil total (IBGE codes)   | BTR1       |
| dimYear      | yearId    | Year as integer, tagged by inventory period   | BTR1       |
| dimGasType   | gasId     | CO2 eq, CO2, CH4, N2O, HFCs, PFCs, SF6       | BTR1       |
| dimSector    | sectorId  | IPCC sectors: Energy, IPPU, Agriculture, LULUCF, Waste, Total | BTR1 |

## Source Catalog

### 1. MCTI — BTR1 (Biennial Transparency Report)

| Field              | Value                                            |
|--------------------|--------------------------------------------------|
| **Source**         | MCTI / SIRENE                                    |
| **Dataset**        | BTR1_UF_*.xlsx (6 files)                         |
| **Description**    | GHG emissions by state, sector, and gas (1990–2022) |
| **Grain**          | state × sector × gas × year                     |
| **Fact Table**     | factEmissions                                    |
| **Shared Dims**    | dimUf, dimYear, dimGasType, dimSector            |
| **New Dims**       | —                                                |
| **Files**          | extract_mcti_btr1.R, transform_mcti_btr1.R, load_mcti_btr1.R, pipeline_mcti_btr1.R, query_mcti_btr1.R, plot_mcti_btr1.R, map_mcti_btr1.R, export_mcti_btr1.R |
| **URL**            | https://www.gov.br/mcti/pt-br/acompanhe-o-mcti/cgcl/clima/arquivos/arquivos_bi/5-aba/ |
| **Status**         | ✅ Complete                                      |
| **Notes**          | 4 sheets per file (CO2 eq, CO2, CH4, N2O); IPPU and Total have 3 extra F-gas sheets. Wide format unpivoted to long. Brasil total row included with isBrasilTotal flag. |

---

### 2. MCTI — NIR (National Inventory Report)

| Field              | Value                                            |
|--------------------|--------------------------------------------------|
| **Source**         | MCTI / SIRENE                                    |
| **Dataset**        | NIR_2024_1990-2022_*.xlsx (6 files)              |
| **Description**    | GHG emissions by IPCC subcategory, national level (1990–2022) |
| **Grain**          | category × metric × year                         |
| **Fact Table**     | factNirEmissions                                 |
| **Shared Dims**    | dimYear, dimSector                               |
| **New Dims**       | dimNirCategory (IPCC hierarchy), dimNirMetric (gases + CO2e variants) |
| **Files**          | extract_mcti_nir.R, load_mcti_nir.R, pipeline_mcti_nir.R, query_mcti_nir.R |
| **URL**            | https://www.gov.br/mcti/pt-br/acompanhe-o-mcti/cgcl/clima/arquivos/arquivos_bi/5-aba/ |
| **Status**         | 🔧 In Progress                                  |
| **Notes**          | National totals only (no state breakdown). 166 unique IPCC subcategories across 6 files. Hierarchy up to 7 levels deep. IPPU has 17 sheets (individual F-gases). 'Agropecuaria' sheets have trailing spaces in names. Total file has only 3 CO2e sheets. |
---

### 3. [Source Name]

| Field              | Value                                            |
|--------------------|--------------------------------------------------|
| **Source**         |                                                  |
| **Dataset**        |                                                  |
| **Description**    |                                                  |
| **Grain**          |                                                  |
| **Fact Table**     |                                                  |
| **Shared Dims**    |                                                  |
| **New Dims**       |                                                  |
| **Files**          |                                                  |
| **URL**            |                                                  |
| **Status**         | 🔲 Planned                                      |
| **Notes**          |                                                  |

---

## Status Legend

- ✅ Complete — fully integrated, tested, documented
- 🔧 In Progress — actively being built
- 🔲 Planned — identified but not started
- ⏸️ On Hold — blocked or deprioritized

## Checklist for Adding a New Source

- [ ] &nbsp;&nbsp;Add entry to this registry
- [ ] &nbsp;&nbsp;Obtain and inspect sample data file
- [ ] &nbsp;&nbsp;Identify grain (what does one row represent?)
- [ ] &nbsp;&nbsp;Map columns to existing dimensions
- [ ] &nbsp;&nbsp;Design new dimensions if needed (only after seeing real data)
- [ ] &nbsp;&nbsp;Add schema to `inst/config/schemas_sqlite.sql`
- [ ] &nbsp;&nbsp;Create `extract_{source}_{data}.R`
- [ ] &nbsp;&nbsp;Create `transform_{source}_{data}.R` (if needed)
- [ ] &nbsp;&nbsp;Create `load_{source}_{data}.R`
- [ ] &nbsp;&nbsp;Create `pipeline_{source}_{data}.R` with `setup_{data}()`
- [ ] &nbsp;&nbsp;Create `query_{source}_{data}.R` with user-facing `get_*()` function
- [ ] &nbsp;&nbsp;Create `plot_{source}_{data}.R` (if applicable)
- [ ] &nbsp;&nbsp;Create `map_{source}_{data}.R` (if applicable)
- [ ] &nbsp;&nbsp;Create `export_{source}_{data}.R` (if applicable)
- [ ] &nbsp;&nbsp;Add tests in `tests/testthat/test-{source}-{data}.R`
- [ ] &nbsp;&nbsp;Update `dev/` notes
- [ ] &nbsp;&nbsp;Update vignettes
- [ ] &nbsp;&nbsp;`devtools::document()` + `devtools::check()`
- [ ] &nbsp;&nbsp;Commit and tag new version
