#' Load a complete BTR1 extraction into the database
#'
#' Takes the output of [extract_btr1_uf()] or [extract_btr1_all()]
#' and loads both the metadata (dimYear) and fact data (factBtr1Emissions)
#' in one step. Ensures the schema exists before writing.
#'
#' @param result The list returned by [extract_btr1_uf()] or
#'   [extract_btr1_all()], containing `$data` and `$metadata`.
#' @param con A `DBIConnection` object.
#' @param mode Character. Write mode for factBtr1Emissions
#'   `"append"` (default) or `"overwrite"`.
#'
#' @return Invisible `TRUE` on success.
#' @export
#' @examples
#' \dontrun{
#'   con <- db_connect()
#'
#'   db_create_schema(con)
#'
#'   result <- extract_btr1_uf("BTR1_UF_Energia.xlsx")
#'
#'   load_btr1(result, con)
#'
#'   db_disconnect(con)
#' }
load_btr1 <- function(result, con, mode = "append") {

  etl_log("load", "Loading BTR1 data to database")

  # Handle both single-sector and all-sectors metadata

  if ("inventoryPeriod" %in% names(result$metadata)) {

    # Single sector: result$metadata is a list with $years, $inventoryPeriod

    meta <- result$metadata

    db_seed_dim_year(con, meta$years, meta$inventoryPeriod)

  } else {

    # All sectors: result$metadata is a list of lists, we use the first one for
    # year seeding (all share the same years)

    meta <- result$metadata[[1]]

    db_seed_dim_year(con, meta$years, meta$inventoryPeriod)
  }

  load_to_db(result$data, con, "factBtr1Emissions", mode = mode)

  etl_log("load", "BTR1 load complete")

  invisible(TRUE)
}
