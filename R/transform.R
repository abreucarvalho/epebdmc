#' Clean common data issues
#'
#' Trims whitespace in character columns, removes fully empty rows,
#' and standardizes column names to camelCase.
#'
#' @param data A tibble/data.frame.
#' @param removeEmptyRows Logical. Remove rows where all values are NA? Default `TRUE`.
#' @param cleanNames Logical. Standardize column names? Default `TRUE`.
#'
#' @return A cleaned tibble.
#' @export
transform_clean <- function(data, removeEmptyRows = TRUE, cleanNames = TRUE) {
  etl_log("transform", paste0("Cleaning data (", nrow(data), " rows)"))

  if (cleanNames) {
    names(data) <- names(data) |>
      stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
      stringr::str_replace_all("^_|_$", "") |>
      stringr::str_to_lower()
  }

  # Trim whitespace in character columns
  data <- data |>
    dplyr::mutate(
      dplyr::across(dplyr::where(is.character), stringr::str_trim)
    )

  if (removeEmptyRows) {
    before <- nrow(data)
    data <- data |> dplyr::filter(!dplyr::if_all(dplyr::everything(), is.na))
    removed <- before - nrow(data)
    if (removed > 0) etl_log("transform", paste0("Removed ", removed, " empty rows"))
  }

  etl_log("transform", paste0("Clean complete. ", nrow(data), " rows remain"))
  data
}


#' Filter data using expressions
#'
#' Apply one or more filter conditions, just like [dplyr::filter()].
#'
#' @param data A tibble/data.frame.
#' @param ... Filter expressions (tidy eval).
#'
#' @return A filtered tibble.
#' @export
#' @examples
#' \dontrun{
#'   data |> transform_filter(ufId != 99, yearId >= 2010)
#' }
transform_filter <- function(data, ...) {
  before <- nrow(data)
  data <- dplyr::filter(data, ...)
  after <- nrow(data)
  etl_log("transform", paste0("Filtered: ", before, " -> ", after, " rows"))
  data
}


#' Select and rename columns
#'
#' @param data A tibble/data.frame.
#' @param ... Column selections (tidy-select).
#'
#' @return A tibble with selected columns.
#' @export
transform_select <- function(data, ...) {
  data <- dplyr::select(data, ...)
  etl_log("transform", paste0("Selected ", ncol(data), " columns: ",
                              paste(names(data), collapse = ", ")))
  data
}


#' Enrich data with derived columns
#'
#' Add new computed columns using [dplyr::mutate()] syntax.
#'
#' @param data A tibble/data.frame.
#' @param ... Name-value pairs of new columns.
#'
#' @return An enriched tibble.
#' @export
#' @examples
#' \dontrun{
#'   data |> transform_enrich(
#'     emissionTon = emissionKt * 1000,
#'     decade      = (yearId %/% 10) * 10
#'   )
#' }
transform_enrich <- function(data, ...) {
  before_cols <- ncol(data)
  data <- dplyr::mutate(data, ...)
  new_cols <- ncol(data) - before_cols
  etl_log("transform", paste0("Enriched: +", new_cols, " new columns"))
  data
}


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
