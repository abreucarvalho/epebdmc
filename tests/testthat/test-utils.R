test_that("etl_log prints without error", {
  expect_message(etl_log("extract", "test message"))
  expect_message(etl_log("transform", "test message"))
  expect_message(etl_log("load", "test message"))
  expect_message(etl_log("info", "test message"))
  expect_message(etl_log("unknown_step", "falls back to default icon"))
})
