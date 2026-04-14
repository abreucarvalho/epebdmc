test_that("load_to_db writes and counts rows", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  df <- tibble::tibble(name = c("A", "B"), value = c(1, 2))
  load_to_db(df, con, "test_table", mode = "overwrite")

  result <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM test_table")
  expect_equal(result$n, 2)
})

test_that("load_to_db appends on second call", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  df <- tibble::tibble(name = c("A", "B"), value = c(1, 2))
  load_to_db(df, con, "test_table", mode = "overwrite")
  load_to_db(df, con, "test_table", mode = "append")

  result <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM test_table")
  expect_equal(result$n, 4)
})

test_that("load_to_db overwrite replaces data", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  df1 <- tibble::tibble(name = c("A", "B", "C"), value = 1:3)
  df2 <- tibble::tibble(name = c("X"), value = 99)

  load_to_db(df1, con, "test_table", mode = "overwrite")
  load_to_db(df2, con, "test_table", mode = "overwrite")

  result <- DBI::dbGetQuery(con, "SELECT * FROM test_table")
  expect_equal(nrow(result), 1)
  expect_equal(result$name, "X")
})

test_that("load_to_csv creates a file", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))

  df <- tibble::tibble(a = 1:3, b = c("x", "y", "z"))
  load_to_csv(df, tmp)

  expect_true(file.exists(tmp))
  read_back <- readr::read_csv(tmp, show_col_types = FALSE)
  expect_equal(nrow(read_back), 3)
})

test_that("load_btr1 handles single-sector result", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  skip_if_not(file.exists(sql_path))

  db_create_schema(con, sql_path = sql_path)

  # Fake a single-sector extraction result
  fake_result <- list(
    data = tibble::tibble(
      ufId       = c(11L, 35L),
      sectorId   = c(1L, 1L),
      gasId      = c(1L, 1L),
      yearId     = c(2022L, 2022L),
      emissionKt = c(100.0, 200.0)
    ),
    metadata = list(
      inventoryPeriod = "BTR1 (1990-2022)",
      years = 2022L
    )
  )

  load_btr1(fake_result, con, mode = "overwrite")

  rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM factBtr1Emissions")
  expect_equal(rows$n, 2)

  years <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dimYear")
  expect_equal(years$n, 1)
})
