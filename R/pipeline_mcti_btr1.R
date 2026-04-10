#' Set up the BTR1 emissions database
#'
#' One-call function that downloads all BTR1 sector files from MCTI,
#' creates the database schema, validates the data, and loads
#' everything into SQLite. Run this once, or again when MCTI
#' publishes updated data.
#'
#' @param dbname Character. Path to the SQLite database file.
#'   Default `"epebdmc.sqlite"`.
#' @param sources Named character vector of file paths or URLs.
#'   Defaults to the official MCTI download links (all 6 sectors).
#' @param overwrite Logical. If `TRUE`, drops and recreates the
#'   factEmissions table. If `FALSE` (default), appends to existing data.
#'   Dimension tables are never dropped — seed data uses INSERT OR IGNORE.
#' @param validate Logical. Run total validation before loading?
#'   Default `TRUE`.
#'
#' @return Invisible list with:
#'   \describe{
#'     \item{dbname}{Path to the created/updated database.}
#'     \item{rows}{Total rows loaded into factEmissions.}
#'     \item{sectors}{Character vector of sectors loaded.}
#'     \item{years}{Integer vector of years in the data.}
#'     \item{discrepancies}{Tibble of validation discrepancies (if any).}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#'   # First-time setup (downloads everything from MCTI)
#'   setup_btr1()
#'
#'   # Re-run when data is updated (fresh load)
#'   setup_btr1(overwrite = TRUE)
#'
#'   # Use local files instead of URLs
#'   setup_btr1(sources = c(
#'     Energia = "data/BTR1_UF_Energia.xlsx",
#'     IPPU    = "data/BTR1_UF_IPPU.xlsx"
#'   ))
#' }
setup_btr1 <- function(dbname = "epebdmc.sqlite",
                       sources = NULL,
                       overwrite = FALSE,
                       validate = TRUE) {

  etl_log("info", "========== BTR1 SETUP START ==========")
  start_time <- Sys.time()

  # --- EXTRACT ---
  all <- extract_btr1_all(sources = sources)

  # --- VALIDATE ---
  discrepancies <- NULL
  if (validate) {
    discrepancies <- transform_validate_totals(all$data)
  }

  # --- CONNECT & SCHEMA ---
  con <- db_connect("sqlite", list(dbname = dbname))
  on.exit(db_disconnect(con), add = TRUE)

  db_create_schema(con)

  # --- LOAD ---
  mode <- if (overwrite) "overwrite" else "append"
  load_btr1(all, con, mode = mode)

  # --- SUMMARY ---
  elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 1)

  sectors <- purrr::map_chr(all$metadata, "sectorNamePt")
  years   <- all$metadata[[1]]$years

  etl_log("info", paste0(
    "Setup complete in ", elapsed, "s | ",
    "DB: ", dbname, " | ",
    nrow(all$data), " rows | ",
    length(sectors), " sectors | ",
    min(years), "-", max(years)
  ))
  etl_log("info", "========== BTR1 SETUP COMPLETE ==========")

  invisible(list(
    dbname        = dbname,
    rows          = nrow(all$data),
    sectors       = sectors,
    years         = years,
    discrepancies = discrepancies
  ))
}


