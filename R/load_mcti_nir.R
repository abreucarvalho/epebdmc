#' Seed dimNirCategory from extracted categories
#'
#' Populates the dimNirCategory table from the categories parsed
#' during extraction. Safe to call multiple times — existing
#' categories are skipped.
#'
#' @param con A `DBIConnection` object.
#' @param categories Tibble of categories from [extract_nir()] or
#'   [extract_nir_all()], with columns: categoryCode, categoryName,
#'   categoryLevel, parentCode, sectorId.
#'
#' @export
db_seed_nir_categories <- function(con, categories) {

  etl_log("info", paste0("Seeding dimNirCategory: ", nrow(categories), " categories"))

  existing <- DBI::dbGetQuery(con, "SELECT categoryCode FROM dimNirCategory")

  new_cats <- dplyr::anti_join(categories, existing, by = "categoryCode")

  if (nrow(new_cats) > 0) {
    DBI::dbAppendTable(con, "dimNirCategory", new_cats)
    etl_log("info", paste0("Inserted ", nrow(new_cats), " new categories"))
  } else {
    etl_log("info", "All categories already exist in dimNirCategory")
  }
}


#' Load NIR extraction results into the database
#'
#' Takes the output of [extract_nir()] or [extract_nir_all()]
#' and loads categories, years, and fact data in one step.
#'
#' @param result The list returned by [extract_nir()] or [extract_nir_all()].
#' @param con A `DBIConnection` object.
#' @param mode Character. Write mode for factNirEmissions.
#'   `"append"` (default) or `"overwrite"`.
#'
#' @return Invisible `TRUE` on success.
#' @export
load_nir <- function(result, con, mode = "append") {

  etl_log("load", "Loading NIR data to database")

  # Seed years
  if ("inventoryPeriod" %in% names(result$metadata)) {
    meta <- result$metadata
  } else {
    meta <- result$metadata[[1]]
  }
  db_seed_dim_year(con, meta$years, meta$inventoryPeriod)

  # Seed categories
  db_seed_nir_categories(con, result$categories)

  # Map categoryCode to categoryId for the fact table
  cat_lookup <- DBI::dbGetQuery(con,
                                "SELECT categoryId, categoryCode FROM dimNirCategory"
  )

  fact_data <- result$data |>
    dplyr::inner_join(cat_lookup, by = "categoryCode") |>
    dplyr::select("categoryId", "metricId", "yearId", "emissionKt")

  load_to_db(fact_data, con, "factNirEmissions", mode = mode)

  etl_log("load", "NIR load complete")
  invisible(TRUE)
}
