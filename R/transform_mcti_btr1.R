#' Exclude Brasil totals from extracted data
#'
#' Removes the aggregated "Brasil" row (ufId = 99) from the data.
#' Useful when you want to compute your own totals or avoid
#' double-counting in aggregations.
#'
#' @param data A tibble with a ufId column.
#'
#' @return A tibble without the Brasil total rows.
#' @export
transform_exclude_totals <- function(data) {
  before <- nrow(data)
  data <- dplyr::filter(data, .data$ufId != 99L)
  etl_log("transform", paste0(
    "Excluded Brasil totals: ", before, " -> ", nrow(data), " rows"
  ))
  data
}


#' Validate extracted data against Brasil totals
#'
#' Compares the sum of state-level emissions with the reported
#' Brasil total for each gas × year combination. Returns a tibble
#' of discrepancies that exceed the given tolerance.
#'
#' @param data A tibble with columns: ufId, sectorId, gasId, yearId, emissionKt.
#'   Must include ufId = 99 (Brasil total).
#' @param tolerance Numeric. Maximum acceptable absolute difference in kt.
#'   Default 0.01 (due to floating point rounding).
#'
#' @return A tibble of discrepancies with columns: sectorId, gasId, yearId,
#'   statesSum, brasilTotal, diff. Empty tibble if all checks pass.
#' @export
transform_validate_totals <- function(data, tolerance = 0.01) {

  etl_log("transform", "Validating state sums against Brasil totals")

  brasil <- data |>
    dplyr::filter(.data$ufId == 99L) |>
    dplyr::select("sectorId", "gasId", "yearId",
                  brasilTotal = "emissionKt")

  states <- data |>
    dplyr::filter(.data$ufId != 99L) |>
    dplyr::summarise(
      statesSum = sum(.data$emissionKt, na.rm = TRUE),
      .by = c("sectorId", "gasId", "yearId")
    )

  comparison <- dplyr::inner_join(states, brasil,
                                  by = c("sectorId", "gasId", "yearId")) |>
    dplyr::mutate(diff = abs(.data$statesSum - .data$brasilTotal)) |>
    dplyr::filter(.data$diff > tolerance)

  if (nrow(comparison) == 0) {
    etl_log("transform", "Validation passed: all state sums match Brasil totals")
  } else {
    etl_log("transform", paste0(
      "WARNING: ", nrow(comparison), " discrepancies found (tolerance: ", tolerance, " kt)"
    ))
  }

  comparison
}
