test_that("db_connect creates an in-memory SQLite connection", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  expect_true(DBI::dbIsValid(con))
  db_disconnect(con)
})

test_that("db_disconnect closes the connection", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  db_disconnect(con)
  expect_false(DBI::dbIsValid(con))
})

test_that("db_disconnect handles already-closed connections", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  DBI::dbDisconnect(con)
  # Should not error on double disconnect
  expect_no_error(db_disconnect(con))
})

test_that("db_connect rejects unknown backend", {
  expect_error(db_connect("postgres"), "Unknown backend")
})

test_that("db_create_schema creates all expected tables", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  # Need to provide the schema file path since package isn't installed
  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")

  # Skip if file not found (e.g. in CI without inst/)
  skip_if_not(file.exists(sql_path), "Schema SQL file not found")

  db_create_schema(con, sql_path = sql_path)

  tables <- DBI::dbListTables(con)
  expect_true("dimUf" %in% tables)
  expect_true("dimBtr1GasType" %in% tables)
  expect_true("dimSector" %in% tables)
  expect_true("dimYear" %in% tables)
  expect_true("factBtr1Emissions" %in% tables)
  expect_true("etlLog" %in% tables)
})

test_that("db_create_schema seeds dimUf with 28 entries", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  skip_if_not(file.exists(sql_path))

  db_create_schema(con, sql_path = sql_path)

  ufs <- DBI::dbGetQuery(con, "SELECT * FROM dimUf")
  expect_equal(nrow(ufs), 28)  # 27 states + Brasil

  # Check a known state
  sp <- ufs[ufs$ufCode == "SP", ]
  expect_equal(sp$ufId, 35)
  expect_equal(sp$regionName, "Sudeste")

  # Check Brasil total
  br <- ufs[ufs$ufCode == "BR", ]
  expect_equal(br$isBrasilTotal, 1)
})

test_that("db_create_schema seeds dimBtr1GasType with 7 gases", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  skip_if_not(file.exists(sql_path))

  db_create_schema(con, sql_path = sql_path)

  gases <- DBI::dbGetQuery(con, "SELECT * FROM dimBtr1GasType")
  expect_equal(nrow(gases), 7)
  expect_true("HFCs" %in% gases$gasName)
  expect_true("SF6" %in% gases$gasName)
})

test_that("db_create_schema seeds dimSector with 6 sectors", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  skip_if_not(file.exists(sql_path))

  db_create_schema(con, sql_path = sql_path)

  sectors <- DBI::dbGetQuery(con, "SELECT * FROM dimSector")
  expect_equal(nrow(sectors), 6)
  expect_true("Energy" %in% sectors$sectorName)
  expect_true("Total" %in% sectors$sectorName)
})

test_that("db_create_schema is idempotent (safe to re-run)", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  skip_if_not(file.exists(sql_path))

  db_create_schema(con, sql_path = sql_path)
  expect_no_error(db_create_schema(con, sql_path = sql_path))

  # Should still have 28 UFs, not 56
  ufs <- DBI::dbGetQuery(con, "SELECT * FROM dimUf")
  expect_equal(nrow(ufs), 28)
})

test_that("db_seed_dim_year inserts and deduplicates", {
  con <- db_connect("sqlite", list(dbname = ":memory:"))
  on.exit(db_disconnect(con))

  sql_path <- testthat::test_path("..", "..", "inst", "config", "schemas_sqlite.sql")
  skip_if_not(file.exists(sql_path))

  db_create_schema(con, sql_path = sql_path)

  # First insert
  db_seed_dim_year(con, 1990:1995, "BTR1 (1990-2022)")
  rows1 <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dimYear")
  expect_equal(rows1$n, 6)

  # Re-insert same years — should not duplicate
  db_seed_dim_year(con, 1990:1995, "BTR1 (1990-2022)")
  rows2 <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dimYear")
  expect_equal(rows2$n, 6)

  # Insert new years — should add only new ones
  db_seed_dim_year(con, 1993:1998, "BTR1 (1990-2022)")
  rows3 <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dimYear")
  expect_equal(rows3$n, 9)  # 1990-1998
})
