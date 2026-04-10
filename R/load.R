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
