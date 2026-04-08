#' Export emissions data to a file
#'
#' Queries the database with the same filters as [get_emissions()]
#' and saves the result to CSV or Excel format.
#'
#' @inheritParams get_emissions
#' @param path Character. Output file path. The extension determines
#'   the format: `.csv` for CSV, `.xlsx` for Excel.
#' @param ... Additional filter arguments passed to [get_emissions()].
#'
#' @return Invisible tibble of the exported data.
#' @export
#' @examples
#' \dontrun{
#'   # Export Energy sector as CSV
#'   export_emissions(
#'     path   = "energy_emissions.csv",
#'     sector = "Energy"
#'   )
#'
#'   # Export all data as Excel
#'   export_emissions(path = "all_emissions.xlsx")
#'
#'   # Filtered export
#'   export_emissions(
#'     path   = "sudeste_2022.csv",
#'     region = "Sudeste",
#'     year   = 2022
#'   )
#' }
export_emissions <- function(path,
                             sector = NULL,
                             uf = NULL,
                             gas = "CO2 eq",
                             year = NULL,
                             region = NULL,
                             includeBrasil = FALSE,
                             dbname = "epebdmc.sqlite",
                             ...) {

  data <- get_emissions(
    sector        = sector,
    uf            = uf,
    gas           = gas,
    year          = year,
    region        = region,
    includeBrasil = includeBrasil,
    dbname        = dbname
  )

  if (nrow(data) == 0) {
    warning("No data to export for the given filters.")
    return(invisible(data))
  }

  ext <- tolower(tools::file_ext(path))

  if (ext == "csv") {
    readr::write_csv(data, path)
    etl_log("info", paste0("Exported ", nrow(data), " rows to CSV: ", path))

  } else if (ext == "xlsx") {
    if (!requireNamespace("writexl", quietly = TRUE)) {
      stop("Package 'writexl' is required for Excel export. ",
           "Install with install.packages('writexl').")
    }
    writexl::write_xlsx(data, path)
    etl_log("info", paste0("Exported ", nrow(data), " rows to Excel: ", path))

  } else {
    stop("Unsupported format: '.", ext, "'. Use .csv or .xlsx.")
  }

  invisible(data)
}
