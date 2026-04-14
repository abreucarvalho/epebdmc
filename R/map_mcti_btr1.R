#' Plot emissions on a Brazil map
#'
#' Creates a choropleth map showing emissions by state for a given
#' year. States are colored by emission intensity. All filters from
#' [get_emissions()] are available.
#'
#' @inheritParams get_emissions
#' @param year Integer. A single year to display. Default: most recent year.
#' @param sector Character. Sector name. Default: `"Total"`.
#' @param gas Character. Gas name. Default: `"CO2 eq"`.
#' @param title Character. Plot title. Auto-generated if `NULL`.
#' @param palette Character. Color palette name from
#'   [ggplot2::scale_fill_distiller()]. Default: `"YlOrRd"`.
#' @param showValues Logical. Show emission values as labels on each
#'   state? Default `FALSE`.
#' @param dbname Character. Path to the database.
#'
#' @return A ggplot2 object.
#' @export
#' @examples
#' \dontrun{
#'   # Total CO2 eq emissions by state in 2022
#'   plot_map()
#'
#'   # Energy sector
#'   plot_map(sector = "Energy", year = 2022)
#'
#'   # LULUCF with values displayed
#'   plot_map(sector = "LULUCF", year = 2022, showValues = TRUE)
#'
#'   # CH4 emissions from Agriculture
#'   plot_map(sector = "Agriculture", gas = "CH4", year = 2015)
#'
#'   # Custom color palette
#'   plot_map(sector = "Energy", palette = "Blues")
#' }
plot_map <- function(sector = "Total",
                     gas = "CO2 eq",
                     year = NULL,
                     region = NULL,
                     title = NULL,
                     palette = "YlOrRd",
                     showValues = FALSE,
                     dbname = "epebdmc.sqlite") {

  if (!requireNamespace("geobr", quietly = TRUE)) {
    stop("Package 'geobr' is required for map plots. ",
         "Install with install.packages('geobr').")
  }

  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required for map plots. ",
         "Install with install.packages('sf').")
  }

  # If no year specified, get the most recent
  if (is.null(year)) {
    con <- get_db(dbname)
    on.exit(db_disconnect(con), add = TRUE)
    max_year <- DBI::dbGetQuery(con, "SELECT MAX(yearId) AS y FROM factBtr1Emissions")
    year <- max_year$y
  }

  # Get emissions data (excluding Brasil total)
  data <- get_emissions(
    sector        = sector,
    gas           = gas,
    year          = year,
    region        = region,
    includeBrasil = FALSE,
    dbname        = dbname
  )

  if (nrow(data) == 0) {
    warning("No data found for the given filters.")
    return(ggplot2::ggplot() + ggplot2::theme_void() +
             ggplot2::ggtitle("No data found"))
  }

  # Aggregate if multiple rows per state (shouldn't happen with
  # single sector + gas + year, but defensive)
  agg <- data |>
    dplyr::summarise(
      emissionKt = sum(.data$emissionKt, na.rm = TRUE),
      .by = c("ufCode", "ufName")
    )

  # Load Brazil state geometries from geobr
  etl_log("info", "Loading Brazil state geometries")
  br_states <- geobr::read_state(year = 2020, showProgress = FALSE)

  # Join emissions with geometries
  map_data <- br_states |>
    dplyr::mutate(ufCode = .data$abbrev_state) |>
    dplyr::left_join(agg, by = "ufCode")

  # Build the map
  p <- ggplot2::ggplot(map_data) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$emissionKt),
      color = "white",
      linewidth = 0.3
    ) +
    ggplot2::scale_fill_distiller(
      palette   = palette,
      direction = 1,
      name      = "Emissions (kt)",
      labels    = scales::comma,
      na.value  = "grey90"
    ) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5)
    )

  # Optional value labels
  if (showValues) {
    centroids <- sf::st_centroid(map_data)
    p <- p + ggplot2::geom_sf_text(
      data = centroids,
      ggplot2::aes(label = scales::comma(.data$emissionKt, accuracy = 1)),
      size = 2.5,
      color = "grey20"
    )
  }

  # Title
  if (is.null(title)) {
    sector_label <- paste(sector, collapse = ", ")
    gas_label <- paste(gas, collapse = ", ")
    title <- paste0(sector_label, " \u2014 ", gas_label, " (", year, ")")
  }
  p <- p + ggplot2::ggtitle(title)

  p
}


#' Plot emissions change on a Brazil map
#'
#' Shows the percentage change in emissions between two years
#' for each state. Green = decrease, red = increase.
#'
#' @inheritParams plot_map
#' @param yearFrom Integer. Start year for comparison.
#' @param yearTo Integer. End year for comparison.
#' @param title Character. Plot title. Auto-generated if `NULL`.
#'
#' @return A ggplot2 object.
#' @export
#' @examples
#' \dontrun{
#'   # Change in Energy CO2 emissions from 1990 to 2022
#'   plot_map_change(sector = "Energy", yearFrom = 1990, yearTo = 2022)
#'
#'   # LULUCF change over last decade
#'   plot_map_change(sector = "LULUCF", yearFrom = 2012, yearTo = 2022)
#' }
plot_map_change <- function(sector = "Total",
                            gas = "CO2 eq",
                            yearFrom = 1990,
                            yearTo = 2022,
                            region = NULL,
                            title = NULL,
                            showValues = FALSE,
                            dbname = "epebdmc.sqlite") {

  if (!requireNamespace("geobr", quietly = TRUE)) {
    stop("Package 'geobr' is required for map plots. ",
         "Install with install.packages('geobr').")
  }

  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required for map plots. ",
         "Install with install.packages('sf').")
  }

  # Get data for both years
  data <- get_emissions(
    sector        = sector,
    gas           = gas,
    year          = c(yearFrom, yearTo),
    region        = region,
    includeBrasil = FALSE,
    dbname        = dbname
  )

  if (nrow(data) == 0) {
    warning("No data found for the given filters.")
    return(ggplot2::ggplot() + ggplot2::theme_void() +
             ggplot2::ggtitle("No data found"))
  }

  # Compute change per state
  change <- data |>
    dplyr::summarise(
      emissionKt = sum(.data$emissionKt, na.rm = TRUE),
      .by = c("ufCode", "ufName", "yearId")
    ) |>
    tidyr::pivot_wider(
      names_from  = "yearId",
      values_from = "emissionKt",
      names_prefix = "y"
    )

  col_from <- paste0("y", yearFrom)
  col_to   <- paste0("y", yearTo)

  change <- change |>
    dplyr::mutate(
      pctChange = ((.data[[col_to]] - .data[[col_from]]) / abs(.data[[col_from]])) * 100
    )

  # Load geometries
  etl_log("info", "Loading Brazil state geometries")
  br_states <- geobr::read_state(year = 2020, showProgress = FALSE)

  map_data <- br_states |>
    dplyr::mutate(ufCode = .data$abbrev_state) |>
    dplyr::left_join(change, by = "ufCode")

  # Symmetric color scale centered at zero
  max_abs <- max(abs(map_data$pctChange), na.rm = TRUE)

  p <- ggplot2::ggplot(map_data) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$pctChange),
      color = "white",
      linewidth = 0.3
    ) +
    ggplot2::scale_fill_gradient2(
      low      = "#1a9850",
      mid      = "#ffffbf",
      high     = "#d73027",
      midpoint = 0,
      limits   = c(-max_abs, max_abs),
      name     = "Change (%)",
      labels   = function(x) paste0(round(x), "%"),
      na.value = "grey90"
    ) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(hjust = 0.5, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5)
    )

  if (showValues) {
    centroids <- sf::st_centroid(map_data)
    p <- p + ggplot2::geom_sf_text(
      data = centroids,
      ggplot2::aes(label = paste0(round(.data$pctChange), "%")),
      size = 2.5,
      color = "grey20"
    )
  }

  if (is.null(title)) {
    sector_label <- paste(sector, collapse = ", ")
    gas_label <- paste(gas, collapse = ", ")
    title <- paste0(
      sector_label, " \u2014 ", gas_label,
      " change (", yearFrom, " \u2192 ", yearTo, ")"
    )
  }
  p <- p + ggplot2::ggtitle(title)

  p
}
