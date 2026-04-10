#' Get a connection to the package database
#'
#' Opens a read connection to the SQLite database populated by
#' [setup_btr1()]. Used internally by query and plot functions,
#' but exported so advanced users can run custom queries.
#'
#' @param dbname Character. Path to the SQLite database file.
#'   Default `"epebdmc.sqlite"`.
#'
#' @return A `DBIConnection` object.
#' @export
get_db <- function(dbname = "epebdmc.sqlite") {
  if (!file.exists(dbname)) {
    stop(
      "Database not found: '", dbname, "'. ",
      "Run setup_btr1() first to create it."
    )
  }
  db_connect("sqlite", list(dbname = dbname))
}
