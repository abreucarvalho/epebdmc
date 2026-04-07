#' Connect to the ETL database
#'
#' Returns a DBI connection. Currently uses SQLite; SQL Server block
#' is included and commented for future migration.
#'
#' @param backend Character. `"sqlite"` (default) or `"sqlserver"` (future).
#' @param config Named list with connection parameters. For SQLite: `dbname`.
#'   For SQL Server (future): `driver`, `server`, `database`, `uid`, `pwd`, `port`.
#'
#' @return A `DBIConnection` object.
#' @export
db_connect <- function(backend = "sqlite", config = list()) {

  # *********************************************************
  # ACTIVE: SQLite (v1)
  # *********************************************************
  if (backend == "sqlite") {
    dbname <- config$dbname %||% "etl_store.sqlite"
    etl_log("info", paste0("Connecting to SQLite: ", dbname))

    con <- DBI::dbConnect(
      RSQLite::SQLite(),
      dbname = dbname
    )
    return(con)
  }

  # *********************************************************
  # FUTURE: SQL Server — uncomment this block when migrating
  # *********************************************************
  # if (backend == "sqlserver") {
  #   if (!requireNamespace("odbc", quietly = TRUE)) {
  #     stop("Package 'odbc' is required for SQL Server. Install with install.packages('odbc').")
  #   }
  #
  #   etl_log("info", paste0("Connecting to SQL Server: ", config$server, "/", config$database))
  #
  #   con <- DBI::dbConnect(
  #     odbc::odbc(),
  #     Driver   = config$driver   %||% "ODBC Driver 17 for SQL Server",
  #     Server   = config$server   %||% "localhost",
  #     Database = config$database %||% "etl_db",
  #     UID      = config$uid      %||% stop("SQL Server requires 'uid' in config"),
  #     PWD      = config$pwd      %||% stop("SQL Server requires 'pwd' in config"),
  #     Port     = config$port     %||% 1433
  #   )
  #   return(con)
  # }

  stop("Unknown backend: '", backend, "'. Use 'sqlite' or 'sqlserver'.")
}



#' Disconnect from the ETL database
#'
#' Safely closes a DBI connection.
#'
#' @param con A `DBIConnection` object.
#' @export
db_disconnect <- function(con) {
  if (DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
    etl_log("info", "Database connection closed.")
  }
}



#' Create schema tables from a SQL file
#'
#' Reads a `.sql` file and executes each statement. Uses
#' `CREATE TABLE IF NOT EXISTS` to safely skip existing tables.
#'
#' @param con A `DBIConnection` object (from `db_connect()`).
#' @param sql_path Path to a `.sql` file. Defaults to the SQLite schema
#'   bundled with the package.
#'
#' @export
db_create_schema <- function(con, sql_path = NULL) {

  if (is.null(sql_path)) {
    sql_path <- system.file("config/schemas_sqlite.sql", package = "epebdmc")
    if (sql_path == "") stop("Default schema file not found. Is the package installed?")
  }

  etl_log("info", paste0("Reading schema from: ", sql_path))

  sql_raw <- readLines(sql_path, warn = FALSE)
  sql_text <- paste(sql_raw, collapse = "\n")

  # Remove SQL comments
  sql_text <- gsub("--[^\n]*", "", sql_text)

  # Split on semicolons into individual statements
  statements <- strsplit(sql_text, ";")[[1]]
  statements <- trimws(statements)
  statements <- statements[nchar(statements) > 0]

  for (stmt in statements) {
    DBI::dbExecute(con, stmt)
  }

  etl_log("info", paste0("Executed ", length(statements), " statements"))
}

# /!\ One note on db_create_schema(): the current function strips SQL comments with
# gsub("--[^\n]*", "", sql_text). That works fine, but the SQL Server file uses
# block comments (/* */).



#' Seed dimYear from extracted metadata
#'
#' Populates the dimYear table dynamically based on the years
#' found in the source file. Safe to call multiple times —
#' existing years are skipped.
#'
#' @param con A `DBIConnection` object.
#' @param years Integer vector of years (e.g. 1990:2022).
#' @param inventoryPeriod Character. Label for this inventory
#'   (e.g. "BTR1 (1990-2022)"). Parsed from the source file header.
#'
#' @export
db_seed_dim_year <- function(con, years, inventoryPeriod) {

  etl_log("info", paste0(
    "Seeding dimYear: ", length(years), " years, period: ", inventoryPeriod
  ))

  dim_year <- dplyr::tibble(
    yearId          = as.integer(years),
    inventoryPeriod = inventoryPeriod
  )

  # Only insert years that don't already exist
  existing <- DBI::dbGetQuery(con, "SELECT yearId FROM dimYear")
  new_years <- dplyr::anti_join(dim_year, existing, by = "yearId")

  if (nrow(new_years) > 0) {
    DBI::dbAppendTable(con, "dimYear", new_years)
    etl_log("info", paste0("Inserted ", nrow(new_years), " new years"))
  } else {
    etl_log("info", "All years already exist in dimYear")
  }
}
