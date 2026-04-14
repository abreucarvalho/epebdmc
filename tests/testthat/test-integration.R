test_that("full roundtrip: extract -> load -> query", {
  path <- testthat::test_path("..", "..", "inst", "extdata", "BTR1_UF_Energia.xlsx")
  skip_if_not(file.exists(path), "Test file BTR1_UF_Energia.xlsx not found")

  # Use a temp database
  tmp_db <- tempfile(fileext = ".sqlite")
  on.exit(unlink(tmp_db))

  # Extract
  result <- extract_btr1_uf(path)
  expect_equal(nrow(result$data), 4 * 28 * 33)

  # Setup DB
  con <- db_connect("sqlite", list(dbname = tmp_db))
  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  db_create_schema(con, sql_path = sql_path)
  db_seed_dim_year(con, result$metadata$years, result$metadata$inventoryPeriod)
  load_to_db(result$data, con, "factBtr1Emissions", mode = "overwrite")
  db_disconnect(con)

  # Query via get_emissions
  sp_data <- get_emissions(
    uf     = "SP",
    gas    = "CO2 eq",
    sector = "Energy",
    dbname = tmp_db
  )

  expect_s3_class(sp_data, "tbl_df")
  expect_equal(nrow(sp_data), 33)  # 33 years
  expect_true(all(sp_data$ufCode == "SP"))
  expect_true(all(sp_data$sectorName == "Energy"))
  expect_true(all(sp_data$gasName == "CO2 eq"))

  # Query multiple states
  sudeste <- get_emissions(
    region = "Sudeste",
    gas    = "CO2",
    sector = "Energy",
    year   = 2022,
    dbname = tmp_db
  )
  expect_equal(nrow(sudeste), 4)  # MG, ES, RJ, SP
  expect_true(all(sudeste$regionName == "Sudeste"))

  # Query with IBGE code
  by_id <- get_emissions(uf = 35, gas = "CH4", sector = "Energy", dbname = tmp_db)
  expect_true(all(by_id$ufCode == "SP"))

  # Summary
  summary <- get_data_summary(dbname = tmp_db)
  expect_equal(summary$ufCount, 27)  # excluding Brasil
  expect_equal(summary$yearRange, c(1990, 2022))
})

test_that("full roundtrip: export works", {
  path <- testthat::test_path("..", "..", "inst", "extdata", "BTR1_UF_Energia.xlsx")
  skip_if_not(file.exists(path))

  tmp_db  <- tempfile(fileext = ".sqlite")
  tmp_csv <- tempfile(fileext = ".csv")
  on.exit({unlink(tmp_db); unlink(tmp_csv)})

  # Setup
  result <- extract_btr1_uf(path)
  con <- db_connect("sqlite", list(dbname = tmp_db))
  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  db_create_schema(con, sql_path = sql_path)
  db_seed_dim_year(con, result$metadata$years, result$metadata$inventoryPeriod)
  load_to_db(result$data, con, "factBtr1Emissions", mode = "overwrite")
  db_disconnect(con)

  # Export
  export_emissions(
    path   = tmp_csv,
    sector = "Energy",
    uf     = "RJ",
    gas    = "CO2 eq",
    dbname = tmp_db
  )

  expect_true(file.exists(tmp_csv))
  csv_data <- readr::read_csv(tmp_csv, show_col_types = FALSE)
  expect_equal(nrow(csv_data), 33)
  expect_true(all(csv_data$ufCode == "RJ"))
})

test_that("plot functions return ggplot objects", {
  path <- testthat::test_path("..", "..", "inst", "extdata", "BTR1_UF_Energia.xlsx")
  skip_if_not(file.exists(path))

  tmp_db <- tempfile(fileext = ".sqlite")
  on.exit(unlink(tmp_db))

  result <- extract_btr1_uf(path)
  con <- db_connect("sqlite", list(dbname = tmp_db))
  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  db_create_schema(con, sql_path = sql_path)
  db_seed_dim_year(con, result$metadata$years, result$metadata$inventoryPeriod)
  load_to_db(result$data, con, "factBtr1Emissions", mode = "overwrite")
  db_disconnect(con)

  p1 <- plot_emissions(sector = "Energy", region = "Sul", dbname = tmp_db)
  expect_s3_class(p1, "ggplot")

  p2 <- plot_ranking(sector = "Energy", year = 2022, topN = 5, dbname = tmp_db)
  expect_s3_class(p2, "ggplot")
})
