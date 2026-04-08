test_that("transform_filter reduces rows", {
  df <- tibble::tibble(status = c("a", "b", "a"), value = 1:3)
  result <- transform_filter(df, status == "a")
  expect_equal(nrow(result), 2)
})

test_that("transform_select keeps specified columns", {
  df <- tibble::tibble(a = 1, b = 2, c = 3)
  result <- transform_select(df, a, c)
  expect_named(result, c("a", "c"))
})

test_that("transform_enrich adds computed columns", {
  df <- tibble::tibble(price = c(10, 20), qty = c(2, 3))
  result <- transform_enrich(df, total = price * qty)
  expect_true("total" %in% names(result))
  expect_equal(result$total, c(20, 60))
})

test_that("transform_clean removes empty rows", {
  df <- tibble::tibble(a = c(1, NA, 3), b = c("x", NA, "z"))
  result <- transform_clean(df, cleanNames = FALSE)
  expect_equal(nrow(result), 2)
})

test_that("transform_clean trims whitespace", {
  df <- tibble::tibble(name = c("  Alice  ", "Bob  "))
  result <- transform_clean(df, removeEmptyRows = FALSE, cleanNames = FALSE)
  expect_equal(result$name, c("Alice", "Bob"))
})

test_that("transform_exclude_totals removes ufId 99", {
  df <- tibble::tibble(ufId = c(11L, 35L, 99L), emissionKt = c(1, 2, 3))
  result <- transform_exclude_totals(df)
  expect_equal(nrow(result), 2)
  expect_false(99L %in% result$ufId)
})

test_that("transform_validate_totals detects no discrepancies in clean data", {
  # Simulate: two states summing to Brasil total
  df <- tibble::tibble(
    ufId       = c(11L, 35L, 99L),
    sectorId   = c(1L, 1L, 1L),
    gasId      = c(1L, 1L, 1L),
    yearId     = c(2022L, 2022L, 2022L),
    emissionKt = c(100.0, 200.0, 300.0)
  )
  result <- transform_validate_totals(df)
  expect_equal(nrow(result), 0)
})

test_that("transform_validate_totals catches discrepancies", {
  df <- tibble::tibble(
    ufId       = c(11L, 35L, 99L),
    sectorId   = c(1L, 1L, 1L),
    gasId      = c(1L, 1L, 1L),
    yearId     = c(2022L, 2022L, 2022L),
    emissionKt = c(100.0, 200.0, 999.0)  # doesn't match
  )
  result <- transform_validate_totals(df)
  expect_equal(nrow(result), 1)
  expect_true(result$diff > 0)
})
