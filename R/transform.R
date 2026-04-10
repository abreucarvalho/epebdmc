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


