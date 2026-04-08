#' Load data into a database table
#'
#' Writes a tibble to the specified table using DBI. Works identically
#' with SQLite and SQL Server backends.
#'
#' @param data A tibble/data.frame to write.
#' @param con A `DBIConnection` object.
#' @param tableName Character. Target table name.
#' @param mode Character. How to handle existing data:
#'   \describe{
#'     \item{"append"}{(default) Add rows to existing table.}
#'     \item{"overwrite"}{Drop and recreate the table.}
#'     \item{"fail"}{Error if the table already exists.}
#'   }
#'
#' @return Invisible `TRUE` on success.
#' @export
load_to_db <- function(data, con, tableName, mode = "append") {

  etl_log("load", paste0(
    "Writing ", nrow(data), " rows to table '", tableName, "' (mode: ", mode, ")"
  ))

  overwrite <- (mode == "overwrite")
  append    <- (mode == "append")

  DBI::dbWriteTable(
    conn      = con,
    name      = tableName,
    value     = data,
    overwrite = overwrite,
    append    = append
  )

  count <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tableName))
  etl_log("load", paste0("Table '", tableName, "' now has ", count$n, " total rows"))

  invisible(TRUE)
}


#' Load data to a CSV file
#'
#' @param data A tibble/data.frame.
#' @param path Output file path.
#' @param ... Additional arguments passed to [readr::write_csv()].
#'
#' @return Invisible file path.
#' @export
load_to_csv <- function(data, path, ...) {
  etl_log("load", paste0("Writing ", nrow(data), " rows to CSV: ", path))
  readr::write_csv(data, path, ...)
  etl_log("load", paste0("CSV saved: ", path))
  invisible(path)
}


#' Load a complete BTR1 extraction into the database
#'
#' Takes the output of [extract_btr1_uf()] or [extract_btr1_all()]
#' and loads both the metadata (dimYear) and fact data (factEmissions)
#' in one step. Ensures the schema exists before writing.
#'
#' @param result The list returned by [extract_btr1_uf()] or
#'   [extract_btr1_all()], containing `$data` and `$metadata`.
#' @param con A `DBIConnection` object.
#' @param mode Character. Write mode for factEmissions.
#'   `"append"` (default) or `"overwrite"`.
#'
#' @return Invisible `TRUE` on success.
#' @export
#' @examples
#' \dontrun{
#'   con <- db_connect()
#'   db_create_schema(con)
#'
#'   result <- extract_btr1_uf("BTR1_UF_Energia.xlsx")
#'   load_btr1(result, con)
#'
#'   db_disconnect(con)
#' }
load_btr1 <- function(result, con, mode = "append") {

  etl_log("load", "Loading BTR1 data to database")

  # Handle both single-sector and all-sectors metadata
  if ("inventoryPeriod" %in% names(result$metadata)) {
    # Single sector: result$metadata is a list with $years, $inventoryPeriod
    meta <- result$metadata
    db_seed_dim_year(con, meta$years, meta$inventoryPeriod)
  } else {
    # All sectors: result$metadata is a list of lists
    # Use the first one for year seeding (all share the same years)
    meta <- result$metadata[[1]]
    db_seed_dim_year(con, meta$years, meta$inventoryPeriod)
  }

  load_to_db(result$data, con, "factEmissions", mode = mode)

  etl_log("load", "BTR1 load complete")
  invisible(TRUE)
}
