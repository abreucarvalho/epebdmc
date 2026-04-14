#' Set up the NIR emissions database
#'
#' One-call function that reads all 6 NIR sector files, creates
#' the schema, and loads everything into SQLite.
#'
#' @param dbname Character. Path to the SQLite database file.
#'   Default `"epebdmc.sqlite"`.
#' @param sources Named character vector of file paths or URLs.
#'   Defaults to local files in inst/extdata.
#' @param overwrite Logical. If `TRUE`, drops and recreates
#'   factNirEmissions. Default `FALSE`.
#'
#' @return Invisible list with dbname, rows, categories count, and years.
#' @export
setup_nir <- function(dbname = "epebdmc.sqlite",
                      sources = NULL,
                      overwrite = FALSE) {

  etl_log("info", "========== NIR SETUP START ==========")
  start_time <- Sys.time()

  # Extract
  all <- extract_nir_all(sources = sources)

  # Connect & schema
  con <- db_connect("sqlite", list(dbname = dbname))
  on.exit(db_disconnect(con), add = TRUE)
  db_create_schema(con)

  # Load
  mode <- if (overwrite) "overwrite" else "append"
  load_nir(all, con, mode = mode)

  # Summary
  elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 1)
  years <- all$metadata[[1]]$years

  etl_log("info", paste0(
    "Setup complete in ", elapsed, "s | ",
    "DB: ", dbname, " | ",
    nrow(all$data), " rows | ",
    nrow(all$categories), " categories | ",
    min(years), "-", max(years)
  ))
  etl_log("info", "========== NIR SETUP COMPLETE ==========")

  invisible(list(
    dbname     = dbname,
    rows       = nrow(all$data),
    categories = nrow(all$categories),
    years      = years
  ))
}
