#' Plot emissions over time
#'
#' Creates a line chart of emissions by year. All filters from
#' [get_emissions()] are available. The `colorBy` parameter controls
#' how lines are grouped and colored.
#'
#' @inheritParams get_emissions
#' @param colorBy Character. What to map to color/lines:
#'   `"uf"` (default), `"sector"`, `"gas"`, or `"region"`.
#' @param title Character. Plot title. Auto-generated if `NULL`.
#' @param showTotal Logical. Show a dashed total line? Default `FALSE`.
#'
#' @return A ggplot2 object (can be further customized with `+`).
#' @export
#' @examples
#' \dontrun{
#'   # Emissions by state in the Energy sector
#'   plot_emissions(sector = "Energy", region = "Sudeste")
#'
#'   # Compare sectors for S\u00e3o Paulo
#'   plot_emissions(uf = "SP", colorBy = "sector")
#'
#'   # Compare gases for Brasil
#'   plot_emissions(
#'     includeBrasil = TRUE, uf = "BR",
#'     gas = c("CO2", "CH4", "N2O"),
#'     colorBy = "gas"
#'   )
#'
#'   # By region
#'   plot_emissions(sector = "LULUCF", colorBy = "region")
#' }
plot_emissions <- function(sector = NULL,
                           uf = NULL,
                           gas = "CO2 eq",
                           year = NULL,
                           region = NULL,
                           includeBrasil = FALSE,
                           colorBy = "uf",
                           title = NULL,
                           showTotal = FALSE,
                           dbname = "epebdmc.sqlite") {

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
    warning("No data found for the given filters.")
    return(ggplot2::ggplot() + ggplot2::theme_void() +
             ggplot2::ggtitle("No data found"))
  }

  # Determine the color/group variable
  color_var <- switch(colorBy,
                      uf      = "ufCode",
                      sector  = "sectorName",
                      gas     = "gasName",
                      region  = "regionName",
                      stop("colorBy must be one of: 'uf', 'sector', 'gas', 'region'")
  )

  # If colorBy is "region", aggregate by region first
  if (colorBy == "region") {
    data <- data |>
      dplyr::summarise(
        emissionKt = sum(.data$emissionKt, na.rm = TRUE),
        .by = c("yearId", "regionName", "sectorName", "gasName")
      )
  }

  # Build the plot
  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(
      x     = .data$yearId,
      y     = .data$emissionKt,
      color = .data[[color_var]],
      group = .data[[color_var]]
    )
  ) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::labs(
      x     = "Year",
      y     = "Emissions (kt)",
      color = NULL
    ) +
    ggplot2::scale_y_continuous(labels = scales::comma) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank()
    )

  # Optional total line
  if (showTotal) {
    totals <- data |>
      dplyr::summarise(
        emissionKt = sum(.data$emissionKt, na.rm = TRUE),
        .by = "yearId"
      )
    p <- p + ggplot2::geom_line(
      data = totals,
      ggplot2::aes(x = .data$yearId, y = .data$emissionKt,
                   group = 1, color = NULL),
      linewidth = 1.2, linetype = "dashed", color = "grey30",
      inherit.aes = FALSE
    )
  }

  # Auto-generate title
  if (is.null(title)) {
    parts <- c()
    if (!is.null(sector)) parts <- c(parts, paste(sector, collapse = ", "))
    if (!is.null(gas))    parts <- c(parts, paste(gas, collapse = ", "))
    if (!is.null(region)) parts <- c(parts, paste(region, collapse = ", "))
    if (length(parts) > 0) {
      title <- paste("Emissions:", paste(parts, collapse = " | "))
    } else {
      title <- "Emissions by Year"
    }
  }
  p <- p + ggplot2::ggtitle(title)

  p
}


#' Plot emissions as a bar chart for a single year
#'
#' Creates a horizontal bar chart comparing states, sectors, or
#' regions for a given year.
#'
#' @inheritParams get_emissions
#' @param year Integer. A single year. Default: most recent year.
#' @param rankBy Character. How to group bars:
#'   `"uf"` (default), `"sector"`, or `"region"`.
#' @param topN Integer. Show only the top N entries. Default: all.
#' @param title Character. Plot title. Auto-generated if `NULL`.
#'
#' @return A ggplot2 object.
#' @export
#' @examples
#' \dontrun{
#'   # Top 10 emitting states in 2022, Energy sector
#'   plot_ranking(sector = "Energy", year = 2022, topN = 10)
#'
#'   # Compare sectors in 2022
#'   plot_ranking(year = 2022, rankBy = "sector")
#'
#'   # Compare regions for LULUCF
#'   plot_ranking(sector = "LULUCF", year = 2022, rankBy = "region")
#' }
plot_ranking <- function(sector = NULL,
                         uf = NULL,
                         gas = "CO2 eq",
                         year = NULL,
                         region = NULL,
                         includeBrasil = FALSE,
                         rankBy = "uf",
                         topN = NULL,
                         title = NULL,
                         dbname = "epebdmc.sqlite") {

  # If no year specified, get the most recent
  if (is.null(year)) {
    con <- get_db(dbname)
    on.exit(db_disconnect(con), add = TRUE)
    max_year <- DBI::dbGetQuery(con, "SELECT MAX(yearId) AS y FROM factEmissions")
    year <- max_year$y
  }

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
    warning("No data found for the given filters.")
    return(ggplot2::ggplot() + ggplot2::theme_void() +
             ggplot2::ggtitle("No data found"))
  }

  # Aggregate and sort
  rank_var <- switch(rankBy,
                     uf     = "ufCode",
                     sector = "sectorName",
                     region = "regionName",
                     stop("rankBy must be one of: 'uf', 'sector', 'region'")
  )

  agg <- data |>
    dplyr::summarise(
      emissionKt = sum(.data$emissionKt, na.rm = TRUE),
      .by = dplyr::all_of(rank_var)
    ) |>
    dplyr::arrange(dplyr::desc(.data$emissionKt))

  if (!is.null(topN)) {
    agg <- dplyr::slice_head(agg, n = topN)
  }

  # Reorder factor for plotting
  agg[[rank_var]] <- stats::reorder(agg[[rank_var]], agg$emissionKt)

  p <- ggplot2::ggplot(
    agg,
    ggplot2::aes(
      x    = .data$emissionKt,
      y    = .data[[rank_var]],
      fill = .data[[rank_var]]
    )
  ) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::labs(
      x = "Emissions (kt)",
      y = NULL
    ) +
    ggplot2::scale_x_continuous(labels = scales::comma) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  if (is.null(title)) {
    gas_label <- paste(gas, collapse = ", ")
    title <- paste0("Emissions Ranking (", year, ") \u2014 ", gas_label)
    if (!is.null(sector)) title <- paste0(title, " | ", paste(sector, collapse = ", "))
  }
  p <- p + ggplot2::ggtitle(title)

  p
}
