#' Parse an IPCC category code and name from a row label
#'
#' Extracts the code (e.g. "1.A.1.a"), name, hierarchy level,
#' and parent code from strings like "1.A.1.a.  Produção de eletricidade..."
#'
#' @param label Character. Raw row label from the Excel file.
#' @return A list with code, name, level, parentCode. NULL if unparseable.
#' @keywords internal
parse_ipcc_category <- function(label) {

  label <- trimws(label)

  # Special case: "Total"
  if (grepl("^Total$", label, ignore.case = TRUE)) {
    return(list(
      code       = "Total",
      name       = "Total",
      level      = 0L,
      parentCode = NA_character_
    ))
  }

  # Match: "1." or "1.A." or "1.A.1." or "1.A.3.b.i" etc, followed by spaces and name
  match <- regmatches(label, regexpr("^[\\d]+[\\w\\.]*", label, perl = TRUE))

  if (length(match) == 0 || nchar(match) == 0) {
    return(NULL)
  }

  code <- gsub("\\.$", "", match)  # remove trailing dot
  name <- trimws(sub("^[\\d]+[\\w\\.]*\\s*", "", label, perl = TRUE))

  # Determine level by counting parts
  parts <- strsplit(code, "\\.")[[1]]
  parts <- parts[nchar(parts) > 0]
  level <- length(parts)

  # Parent = everything except last part
  if (level > 1) {
    parent_code <- paste(parts[-length(parts)], collapse = ".")
  } else {
    parent_code <- NA_character_
  }

  list(
    code       = code,
    name       = name,
    level      = as.integer(level),
    parentCode = parent_code
  )
}


#' Map NIR sheet names to metricId
#'
#' Returns the metricId for a given sheet name. Must match dimNirMetric
#' seed data. Handles trailing spaces in sheet names.
#'
#' @param sheet_name Character. The Excel sheet name.
#' @return Integer metricId, or NA if unrecognized.
#' @keywords internal
nir_metric_id_from_sheet <- function(sheet_name) {

  sheet_name <- trimws(sheet_name)

  mapping <- c(
    "CO2e_GWP_AR5"  = 1L,
    "CO2e_GTP_AR5"  = 2L,
    "CO2e_GWP_SAR"  = 3L,
    "CO2"           = 4L,
    "CH4"           = 5L,
    "N2O"           = 6L,
    "HFC-23"        = 7L,
    "HFC-32"        = 8L,
    "HFC-125"       = 9L,
    "HFC-134a"      = 10L,
    "HFC-143a"      = 11L,
    "HFC-152a"      = 12L,
    "HFC-227ea"     = 13L,
    "HFC-365mfc"    = 14L,
    "CF4"           = 15L,
    "C2F6"          = 16L,
    "SF6"           = 17L
  )

  id <- unname(mapping[sheet_name])
  if (is.na(id)) warning("Unknown NIR sheet/metric: ", sheet_name)
  id
}


#' Detect sector from the first category row of a NIR file
#'
#' Maps the top-level IPCC code to the corresponding sectorId
#' in dimSector.
#'
#' @param code Character. The IPCC category code (e.g. "1", "2", "Total").
#' @return Integer sectorId.
#' @keywords internal
nir_sector_from_code <- function(code) {
  mapping <- c(
    "1"     = 1L,  # Energy
    "2"     = 2L,  # IPPU
    "3"     = 3L,  # Agriculture
    "4"     = 4L,  # LULUCF
    "5"     = 5L,  # Waste
    "Total" = 6L   # Total
  )
  unname(mapping[code])
}


#' Parse NIR metadata from the spreadsheet header
#'
#' Reads row 4 of the first sheet to extract the inventory period
#' and report name. Also reads year columns from row 6.
#'
#' @param path Local file path.
#' @return A list with inventoryPeriod, headerText, years, sheetNames.
#' @keywords internal
parse_nir_metadata <- function(path) {

  header <- readxl::read_excel(
    path,
    sheet      = 1,
    n_max      = 6,
    col_names  = FALSE,
    .name_repair = "minimal"
  )

  header_text <- as.character(header[[1]][4])
  etl_log("extract", paste0("Header: ", header_text))

  # Extract year range
  year_range <- regmatches(
    header_text,
    regexpr("\\(\\d{4}-\\d{4}\\)", header_text)
  )
  if (length(year_range) == 0) {
    warning("Could not parse year range from NIR header.")
    year_range <- ""
  }

  # Extract report identifier: "NIR 2024" from the header
  nir_match <- regmatches(
    header_text,
    regexpr("NIR\\s+\\d{4}", header_text)
  )
  report_id <- if (length(nir_match) > 0) nir_match else "NIR"

  inventory_period <- paste0(report_id, " ", year_range)

  # Read year columns from row 6
  col_header <- readxl::read_excel(
    path,
    sheet      = 1,
    skip       = 5,
    n_max      = 0,
    .name_repair = "minimal"
  )

  year_cols <- names(col_header)[-1]
  years <- as.integer(year_cols)
  years <- years[!is.na(years)]

  sheet_names <- readxl::excel_sheets(path)

  etl_log("extract", paste0(
    "NIR metadata: ", inventory_period,
    " | Years: ", min(years), "-", max(years),
    " | Sheets: ", paste(trimws(sheet_names), collapse = ", ")
  ))

  list(
    inventoryPeriod = inventory_period,
    headerText      = header_text,
    years           = years,
    sheetNames      = sheet_names
  )
}


#' Extract a single sheet from a NIR file
#'
#' Reads one sheet, parses IPCC category codes, and unpivots
#' from wide to long format.
#'
#' @param path Local file path.
#' @param sheet_name Sheet name to read.
#' @param metric_id Integer metricId for this sheet.
#'
#' @return A tibble with columns: categoryCode, categoryName,
#'   categoryLevel, parentCode, sectorId, metricId, yearId, emissionKt.
#' @keywords internal
extract_nir_sheet <- function(path, sheet_name, metric_id) {

  etl_log("extract", paste0("Processing sheet: ", trimws(sheet_name)))

  raw <- readxl::read_excel(
    path,
    sheet      = sheet_name,
    skip       = 5,
    col_names  = TRUE,
    .name_repair = "minimal"
  )

  # Drop columns with empty names (extra blank columns in some sheets)
  raw <- raw[, nchar(names(raw)) > 0]

  first_col <- names(raw)[1]
  raw <- dplyr::rename(raw, label = dplyr::all_of(first_col))
  raw <- dplyr::filter(raw, !is.na(.data$label))

  # Parse each row's IPCC category
  parsed <- purrr::map(raw$label, parse_ipcc_category)

  # Remove rows that couldn't be parsed
  valid <- !purrr::map_lgl(parsed, is.null)
  raw <- raw[valid, ]
  parsed <- parsed[valid]

  # Extract parsed fields
  raw <- raw |>
    dplyr::mutate(
      categoryCode  = purrr::map_chr(parsed, "code"),
      categoryName  = purrr::map_chr(parsed, "name"),
      categoryLevel = purrr::map_int(parsed, "level"),
      parentCode    = purrr::map_chr(parsed, "parentCode", .default = NA_character_),
      sectorId      = nir_sector_from_code(
        substr(.data$categoryCode, 1, 1)
      )
    )

  # Fix sectorId for "Total"
  raw <- raw |>
    dplyr::mutate(
      sectorId = dplyr::if_else(
        .data$categoryCode == "Total",
        6L,
        .data$sectorId
      )
    )

  # Force all year columns to character before pivot (handles mixed types)
  year_cols <- grep("^\\d{4}$", names(raw), value = TRUE)
  raw <- raw |>
    dplyr::mutate(dplyr::across(dplyr::all_of(year_cols), as.character))

  long <- raw |>
    dplyr::select(
      "categoryCode", "categoryName", "categoryLevel",
      "parentCode", "sectorId",
      dplyr::all_of(year_cols)
    ) |>
    tidyr::pivot_longer(
      cols      = dplyr::all_of(year_cols),
      names_to  = "yearId",
      values_to = "emissionKt"
    ) |>
    dplyr::mutate(
      yearId     = as.integer(.data$yearId),
      emissionKt = suppressWarnings(as.numeric(.data$emissionKt)),
      metricId   = metric_id
    )

  etl_log("extract", paste0(
    "Sheet ", trimws(sheet_name), ": ", nrow(long), " rows"
  ))

  long
}


#' Extract a NIR sector file
#'
#' Reads a NIR_2024_*.xlsx file (from a local path or URL),
#' auto-detects available metric sheets, parses IPCC categories,
#' and unpivots all sheets to long format.
#'
#' @param source File path or URL to a NIR_2024_*.xlsx file.
#'
#' @return A list with:
#'   \describe{
#'     \item{data}{Tibble with columns: categoryCode, categoryName,
#'       categoryLevel, parentCode, sectorId, metricId, yearId, emissionKt.}
#'     \item{categories}{Tibble of unique categories (for seeding dimNirCategory).}
#'     \item{metadata}{List with inventoryPeriod, years, sheetNames.}
#'   }
#'
#' @export
extract_nir <- function(source) {

  etl_log("extract", "Starting NIR extraction")

  path <- resolve_source(source)
  meta <- parse_nir_metadata(path)

  all_data <- purrr::map_dfr(meta$sheetNames, function(sheet_name) {

    metric_id <- nir_metric_id_from_sheet(sheet_name)

    if (is.na(metric_id)) {
      etl_log("extract", paste0("Skipping unknown sheet: ", sheet_name))
      return(NULL)
    }

    extract_nir_sheet(path, sheet_name, metric_id)
  })

  # Extract unique categories for dimension seeding
  categories <- all_data |>
    dplyr::distinct(
      .data$categoryCode, .data$categoryName,
      .data$categoryLevel, .data$parentCode, .data$sectorId
    ) |>
    dplyr::arrange(.data$categoryCode)

  # Select fact columns
  fact_data <- dplyr::select(
    all_data,
    "categoryCode", "metricId", "yearId", "emissionKt"
  )

  etl_log("extract", paste0(
    "NIR extraction complete: ",
    nrow(fact_data), " rows (",
    nrow(categories), " categories x ",
    length(unique(fact_data$metricId)), " metrics x ",
    length(unique(fact_data$yearId)), " years)"
  ))

  list(
    data       = fact_data,
    categories = categories,
    metadata   = meta
  )
}


#' Extract all NIR sector files
#'
#' Convenience function that extracts all 6 NIR files and combines
#' them into a single dataset.
#'
#' @param sources Named character vector of file paths or URLs.
#'   Defaults to local paths in inst/extdata.
#'
#' @return A list with combined data, categories, and metadata per sector.
#' @export
extract_nir_all <- function(sources = NULL) {

  if (is.null(sources)) {
    sources <- c(
      Energia      = "inst/extdata/NIR_2024_1990-2022_Energia.xlsx",
      IPPU         = "inst/extdata/NIR_2024_1990-2022_IPPU.xlsx",
      Agropecuaria = "inst/extdata/NIR_2024_1990-2022_Agropecuaria.xlsx",
      LULUCF       = "inst/extdata/NIR_2024_1990-2022_LULUCF.xlsx",
      Residuos     = "inst/extdata/NIR_2024_1990-2022_Residuos.xlsx",
      Total        = "inst/extdata/NIR_2024_1990-2022_TotalBrasil.xlsx"
    )
  }

  etl_log("extract", paste0("Extracting ", length(sources), " NIR sector files"))

  results <- purrr::map(sources, function(src) {
    extract_nir(src)
  })

  combined_data <- purrr::map_dfr(results, "data") |>
    dplyr::distinct(.data$categoryCode, .data$metricId, .data$yearId, .keep_all = TRUE)

  combined_cats <- purrr::map_dfr(results, "categories") |>
    dplyr::distinct(.data$categoryCode, .data$categoryName,
                    .data$categoryLevel, .data$parentCode, .data$sectorId)

  all_metadata  <- purrr::map(results, "metadata")

  etl_log("extract", paste0(
    "All NIR sectors combined: ", nrow(combined_data), " total rows, ",
    nrow(combined_cats), " unique categories"
  ))

  list(
    data       = combined_data,
    categories = combined_cats,
    metadata   = all_metadata
  )
}
