#' Get NIR emissions data with flexible filters
#'
#' Queries the NIR fact table with any combination of filters
#' and returns a clean, labeled tibble with dimension names joined in.
#'
#' @param sector Character vector. Sector names in English or Portuguese.
#'   Default: all sectors.
#' @param category Character vector. IPCC category codes (e.g. "1.A.1",
#'   "3.D"). Partial matching: "1.A" returns all subcategories under 1.A.
#'   Default: all categories.
#' @param level Integer vector. Category levels to include (1 = sector,
#'   2 = subsector, etc.). Default: all levels.
#' @param metric Character vector. Metric names (e.g. "CO2e_GWP_AR5",
#'   "CO2", "CH4", "HFC-23"). Default: "CO2e_GWP_AR5".
#' @param year Integer vector or range. Default: all years.
#' @param includeTotal Logical. Include the "Total" aggregation row?
#'   Default `FALSE`.
#' @param dbname Character. Path to the database.
#'
#' @return A tibble with columns: yearId, categoryCode, categoryName,
#'   categoryLevel, parentCode, sectorName, metricName, metricFormula,
#'   emissionKt, inventoryPeriod.
#'
#' @export
#' @examples
#' \dontrun{
#'   # All Energy subcategories, GWP AR5
#'   get_nir_emissions(sector = "Energy")
#'
#'   # Transport detail, all metrics
#'   get_nir_emissions(category = "1.A.3", metric = c("CO2e_GWP_AR5", "CO2", "CH4"))
#'
#'   # Top-level sectors only, 2022
#'   get_nir_emissions(level = 1, year = 2022)
#'
#'   # LULUCF level 2 subcategories
#'   get_nir_emissions(sector = "LULUCF", level = 2)
#' }
get_nir_emissions <- function(sector = NULL,
                              category = NULL,
                              level = NULL,
                              metric = "CO2e_GWP_AR5",
                              year = NULL,
                              includeTotal = FALSE,
                              dbname = "epebdmc.sqlite") {

  con <- get_db(dbname)
  on.exit(db_disconnect(con), add = TRUE)

  query <- dplyr::tbl(con, "factNirEmissions") |>
    dplyr::inner_join(dplyr::tbl(con, "dimNirCategory"), by = "categoryId") |>
    dplyr::inner_join(dplyr::tbl(con, "dimNirMetric"),   by = "metricId") |>
    dplyr::inner_join(dplyr::tbl(con, "dimSector"),      by = "sectorId") |>
    dplyr::inner_join(dplyr::tbl(con, "dimYear"),        by = "yearId")

  # Sector filter
  if (!is.null(sector)) {
    query <- query |>
      dplyr::filter(
        .data$sectorName %in% sector | .data$sectorNamePt %in% sector
      )
  }

  # Metric filter
  if (!is.null(metric)) {
    query <- query |>
      dplyr::filter(.data$metricName %in% metric)
  }

  # Year filter
  if (!is.null(year)) {
    query <- query |>
      dplyr::filter(.data$yearId %in% year)
  }

  # Level filter
  if (!is.null(level)) {
    query <- query |>
      dplyr::filter(.data$categoryLevel %in% level)
  }

  # Category filter (supports partial matching)
  if (!is.null(category)) {
    # Build SQL LIKE patterns for partial match
    cat_patterns <- paste0(category, "%")
    query <- query |>
      dplyr::filter(
        .data$categoryCode %in% category |
          purrr::reduce(
            cat_patterns,
            function(q, pat) q | (.data$categoryCode %LIKE% pat),
            .init = (.data$categoryCode %in% category)
          )
      )
  }

  # Total row
  if (!includeTotal) {
    query <- query |>
      dplyr::filter(.data$categoryCode != "Total")
  }

  result <- query |>
    dplyr::select(
      "yearId", "categoryCode", "categoryName", "categoryLevel",
      "parentCode", "sectorName", "sectorNamePt",
      "metricName", "metricFormula",
      "emissionKt", "inventoryPeriod"
    ) |>
    dplyr::arrange(.data$categoryCode, .data$metricName, .data$yearId) |>
    dplyr::collect()

  etl_log("info", paste0("NIR query returned ", nrow(result), " rows"))

  result
}
