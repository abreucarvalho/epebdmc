test_that("uf_ibge_map returns 28 entries", {
  m <- uf_ibge_map()
  expect_equal(length(m), 28)
  expect_equal(m[["Brasil"]], 99L)
  expect_equal(m[["São Paulo"]], 35L)
})

test_that("gas_id_from_sheet maps known gases", {
  expect_equal(gas_id_from_sheet("CO2 eq"), 1L)
  expect_equal(gas_id_from_sheet("CO2"), 2L)
  expect_equal(gas_id_from_sheet("CH4"), 3L)
  expect_equal(gas_id_from_sheet("N2O"), 4L)
  expect_equal(gas_id_from_sheet("HFCs"), 5L)
  expect_equal(gas_id_from_sheet("PFCs"), 6L)
  expect_equal(gas_id_from_sheet("SF6"), 7L)
})

test_that("gas_id_from_sheet warns on unknown sheet", {
  expect_warning(gas_id_from_sheet("Unknown"), "Unknown sheet")
})

test_that("extract_btr1_uf reads local Energia file correctly", {
  path <- testthat::test_path("..", "..", "inst", "extdata", "BTR1_UF_Energia.xlsx")
  skip_if_not(file.exists(path), "Test file BTR1_UF_Energia.xlsx not found")

  result <- extract_btr1_uf(path)

  # Structure
  expect_type(result, "list")
  expect_named(result, c("data", "metadata"))
  expect_s3_class(result$data, "tbl_df")

  # Data columns
  expect_named(result$data, c("ufId", "sectorId", "gasId", "yearId", "emissionKt"))

  # Metadata
  expect_true(grepl("BTR1", result$metadata$inventoryPeriod))
  expect_equal(result$metadata$sectorId, 1L)  # Energy
  expect_true(1990 %in% result$metadata$years)
  expect_true(2022 %in% result$metadata$years)

  # 4 sheets x 28 UFs x 33 years = 3696 rows
  expect_equal(nrow(result$data), 4 * 28 * 33)

  # All values should be numeric and non-NA
  expect_true(all(!is.na(result$data$emissionKt)))

  # Check a known value: Rondônia, CO2 eq, 1990
  ro_1990 <- result$data |>
    dplyr::filter(ufId == 11, gasId == 1, yearId == 1990)
  expect_equal(nrow(ro_1990), 1)
  expect_true(ro_1990$emissionKt > 3000)  # ~3356 kt
})

test_that("parse_btr1_metadata detects sector and period", {
  path <- testthat::test_path("..", "..", "inst", "extdata", "BTR1_UF_Energia.xlsx")
  skip_if_not(file.exists(path))

  meta <- parse_btr1_metadata(path)

  expect_equal(meta$sectorId, 1L)
  expect_equal(meta$inventoryPeriod, "BTR1 (1990-2022)")
  expect_equal(length(meta$years), 33)
  expect_true("CO2 eq" %in% meta$sheetNames)
})

test_that("resolve_source handles local files", {
  # Existing file
  tmp <- tempfile(fileext = ".xlsx")
  file.create(tmp)
  expect_equal(resolve_source(tmp), tmp)
  unlink(tmp)

  # Non-existing file
  expect_error(resolve_source("nonexistent.xlsx"), "File not found")
})
