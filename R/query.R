#' Get emissions data with flexible filters
#'
#' The main user-facing function. Queries the database with any
#' combination of filters and returns a clean, labeled tibble
#' with dimension names joined in (not just IDs).
#'
#' @param sector Character vector. Sector names in English or Portuguese.
#'   E.g. `"Energy"`, `"Energia"`, `"LULUCF"`. Default: all sectors.
#' @param uf Character vector. State codes (`"SP"`, `"RJ"`),
#'   full names (`"São Paulo"`), or IBGE codes (35). Default: all states.
#' @param gas Character vector. Gas names: `"CO2"`, `"CH4"`, `"N2O"`,
#'   `"CO2 eq"`, `"HFCs"`, `"PFCs"`, `"SF6"`. Default: `"CO2 eq"`.
#' @param year Integer vector or range. E.g. `2022`, `2010:2022`,
#'   `c(1990, 2000, 2010, 2022)`. Default: all years.
#' @param region Character vector. Region names: `"Norte"`, `"Nordeste"`,
#'   `"Sudeste"`, `"Sul"`, `"Centro-Oeste"`. Default: all regions.
#' @param includeBrasil Logical. Include the Brasil total row?
#'   Default `FALSE`.
#' @param dbname Character. Path to the database. Default `"epebdmc.sqlite"`.
#'
#' @return A tibble with columns: yearId, ufCode, ufName, regionName,
#'   sectorName, gasName, emissionKt.
#'
#' @export
#' @examples
#' \dontrun{
#'   # All CO2 eq emissions for São Paulo
#'   get_emissions(uf = "SP")
#'
#'   # Energy sector, all states, 2010-2022
#'   get_emissions(sector = "Energy", year = 2010:2022)
#'
#'   # Compare regions for CH4 in 2022
#'   get_emissions(gas = "CH4", year = 2022)
#'
#'   # Multiple filters
#'   get_emissions(
#'     sector = "LULUCF",
#'     region = c("Norte", "Centro-Oeste"),
#'     gas    = "CO2",
#'     year   = 2000:2022
#'   )
#' }
get_emissions <- function(sector = NULL,
                          uf = NULL,
                          gas = "CO2 eq",
                          year = NULL,
                          region = NULL,
                          includeBrasil = FALSE,
                          dbname = "epebdmc.sqlite") {

  con <- get_db(dbname)
  on.exit(db_disconnect(con), add = TRUE)

  # Build query by joining all dimensions
  query <- dplyr::tbl(con, "factEmissions") |>
    dplyr::inner_join(dplyr::tbl(con, "dimUf"),      by = "ufId") |>
    dplyr::inner_join(dplyr::tbl(con, "dimSector"),   by = "sectorId") |>
    dplyr::inner_join(dplyr::tbl(con, "dimGasType"),  by = "gasId") |>
    dplyr::inner_join(dplyr::tbl(con, "dimYear"),     by = "yearId")

  # --- Apply filters ---

  # Sector: match English or Portuguese name
  if (!is.null(sector)) {
    query <- query |>
      dplyr::filter(
        .data$sectorName %in% sector | .data$sectorNamePt %in% sector
      )
  }

  # Gas
  if (!is.null(gas)) {
    query <- query |>
      dplyr::filter(.data$gasName %in% gas)
  }

  # Year
  if (!is.null(year)) {
    query <- query |>
      dplyr::filter(.data$yearId %in% year)
  }

  # Region
  if (!is.null(region)) {
    query <- query |>
      dplyr::filter(.data$regionName %in% region)
  }

  # UF: can be code ("SP"), name ("São Paulo"), or IBGE id (35)
  if (!is.null(uf)) {
    uf_chr <- as.character(uf)
    uf_int <- suppressWarnings(as.integer(uf))
    uf_int <- uf_int[!is.na(uf_int)]

    query <- query |>
      dplyr::filter(
        .data$ufCode %in% uf_chr |
          .data$ufName %in% uf_chr |
          .data$ufId   %in% uf_int
      )
  }

  # Brasil total
  if (!includeBrasil) {
    query <- query |>
      dplyr::filter(.data$isBrasilTotal == 0L)
  }

  # Select and collect
  result <- query |>
    dplyr::select(
      "yearId", "ufCode", "ufName", "regionName",
      "sectorName", "sectorNamePt", "gasName", "gasFormula",
      "emissionKt", "inventoryPeriod"
    ) |>
    dplyr::arrange(.data$sectorName, .data$ufCode, .data$gasName, .data$yearId) |>
    dplyr::collect()

  etl_log("info", paste0("Query returned ", nrow(result), " rows"))

  result
}


#' Get a summary of available data in the database
#'
#' Quick overview of what's in the database: sectors, gases,
#' year range, and state count.
#'
#' @param dbname Character. Path to the database.
#'
#' @return A list with sectors, gases, years, uf_count, total_rows.
#' @export
#' @examples
#' \dontrun{
#'   get_data_summary()
#' }
get_data_summary <- function(dbname = "epebdmc.sqlite") {

  con <- get_db(dbname)
  on.exit(db_disconnect(con), add = TRUE)

  sectors <- DBI::dbGetQuery(con,
                             "SELECT DISTINCT sectorName, sectorNamePt FROM dimSector
     WHERE sectorId IN (SELECT DISTINCT sectorId FROM factEmissions)
     ORDER BY sectorName"
  )

  gases <- DBI::dbGetQuery(con,
                           "SELECT DISTINCT gasName, gasFormula FROM dimGasType
     WHERE gasId IN (SELECT DISTINCT gasId FROM factEmissions)
     ORDER BY gasId"
  )

  years <- DBI::dbGetQuery(con,
                           "SELECT MIN(yearId) AS minYear, MAX(yearId) AS maxYear FROM factEmissions"
  )

  uf_count <- DBI::dbGetQuery(con,
                              "SELECT COUNT(DISTINCT ufId) AS n FROM factEmissions WHERE ufId != 99"
  )

  total_rows <- DBI::dbGetQuery(con,
                                "SELECT COUNT(*) AS n FROM factEmissions"
  )

  list(
    sectors    = sectors,
    gases      = gases,
    yearRange  = c(years$minYear, years$maxYear),
    ufCount    = uf_count$n,
    totalRows  = total_rows$n
  )
}
