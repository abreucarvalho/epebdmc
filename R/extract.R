#' Extract data from an Excel file
#'
#' Generic Excel reader. Returns the data as-is (wide format).
#'
#' @param path File path to the .xlsx/.xls file.
#' @param sheet Sheet name or index (default: first sheet).
#' @param ... Additional arguments passed to [readxl::read_excel()].
#'
#' @return A tibble.
#' @export
extract_excel <- function(path, sheet = 1, ...) {
  etl_log("extract", paste0("Reading Excel: ", path, " (sheet: ", sheet, ")"))
  data <- readxl::read_excel(path, sheet = sheet, ...)
  etl_log("extract", paste0("Done. ", nrow(data), " rows x ", ncol(data), " cols"))
  data
}



#' Resolve a source path (local file or URL)
#'
#' If the source is a URL, downloads it to a temporary file and returns
#' the local path. If it's already a local path, returns it unchanged.
#'
#' @param source File path or URL.
#' @param quiet Logical. Suppress download progress? Default `TRUE`.
#'
#' @return A local file path.
#' @keywords internal
resolve_source <- function(source, quiet = TRUE) {

  is_url <- grepl("^https?://", source, ignore.case = TRUE)

  if (!is_url) {
    if (!file.exists(source)) stop("File not found: ", source)
    return(source)
  }

  etl_log("extract", paste0("Downloading from URL: ", source))

  ext <- tools::file_ext(source)
  if (nchar(ext) == 0) ext <- "xlsx"
  tmp <- tempfile(fileext = paste0(".", ext))

  resp <- httr2::request(source) |>
    httr2::req_perform(path = tmp)

  etl_log("extract", paste0("Downloaded to: ", tmp))
  tmp
}



#' Parse BTR1 metadata from the spreadsheet header
#'
#' Reads row 4 of the first sheet to extract the inventory period,
#' report identifier, and sector name. Also reads the year columns
#' from row 6.
#'
#' @param path Local file path to the Excel file.
#'
#' @return A list with:
#'   \describe{
#'     \item{inventoryPeriod}{Character, e.g. "BTR1 (1990-2022)"}
#'     \item{sectorNamePt}{Character, e.g. "Energia", "LULUCF"}
#'     \item{sectorId}{Integer matching dimSector}
#'     \item{headerText}{Character, the raw row 4 text}
#'     \item{years}{Integer vector of years found in column headers}
#'     \item{sheetNames}{Character vector of sheet names in the file}
#'   }
#'
#' @keywords internal
parse_btr1_metadata <- function(path) {

  # Read just the first 6 rows of the first sheet
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
    warning("Could not parse year range from header.")
    year_range <- ""
  }

  # Detect report identifier
  report_map <- c(
    "Primeiro" = "BTR1", "Segundo" = "BTR2", "Terceiro" = "BTR3",
    "Quarto"   = "BTR4", "Quinto"  = "BTR5"
  )
  report_id <- "BTR"
  for (word in names(report_map)) {
    if (grepl(word, header_text, ignore.case = TRUE)) {
      report_id <- report_map[[word]]
      break
    }
  }

  inventory_period <- paste0(report_id, " ", year_range)

  # Detect sector from row 4
  # Pattern: "... - Setor Energia" or "... - Total Brasil"
  sector_map <- c(
    "Energia"        = 1L,
    "IPPU"           = 2L,
    "Agropecu\u00e1ria" = 3L,
    "LULUCF"         = 4L,
    "Res\u00edduos"  = 5L,
    "Total Brasil"   = 6L
  )

  sector_id <- NA_integer_
  sector_name_pt <- NA_character_

  for (name in names(sector_map)) {
    if (grepl(name, header_text, ignore.case = TRUE)) {
      sector_id <- sector_map[[name]]
      sector_name_pt <- name
      break
    }
  }

  if (is.na(sector_id)) {
    warning("Could not detect sector from header: ", header_text)
  }

  etl_log("extract", paste0(
    "Detected: ", inventory_period, " | Sector: ", sector_name_pt,
    " (id=", sector_id, ")"
  ))

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

  # Get all sheet names
  sheet_names <- readxl::excel_sheets(path)

  etl_log("extract", paste0(
    "Years: ", min(years), "-", max(years),
    " | Sheets: ", paste(sheet_names, collapse = ", ")
  ))

  list(
    inventoryPeriod = inventory_period,
    sectorNamePt    = sector_name_pt,
    sectorId        = sector_id,
    headerText      = header_text,
    years           = years,
    sheetNames      = sheet_names
  )
}



#' Sheet name to gasId mapping
#'
#' Returns the gasId for a given sheet name. Must match dimGasType
#' seed data. Returns NA for unrecognized sheets.
#'
#' @param sheet_name Character. The Excel sheet name.
#' @return Integer gasId.
#' @keywords internal
gas_id_from_sheet <- function(sheet_name) {

  mapping <- c(
    "CO2 eq" = 1L,
    "CO2"    = 2L,
    "CH4"    = 3L,
    "N2O"    = 4L,
    "HFCs"   = 5L,
    "PFCs"   = 6L,
    "SF6"    = 7L
  )

  id <- unname(mapping[sheet_name])
  if (is.na(id)) warning("Unknown sheet/gas: ", sheet_name)
  id
}


#' State name to IBGE code mapping
#'
#' Returns a named integer vector mapping state names (as they appear
#' in the BTR1 spreadsheets) to official IBGE UF codes.
#'
#' @return Named integer vector.
#' @keywords internal
uf_ibge_map <- function() {
  c(
    "Rond\u00f4nia"           = 11L,
    "Acre"                    = 12L,
    "Amazonas"                = 13L,
    "Roraima"                 = 14L,
    "Par\u00e1"               = 15L,
    "Amap\u00e1"              = 16L,
    "Tocantins"               = 17L,
    "Maranh\u00e3o"           = 21L,
    "Piau\u00ed"              = 22L,
    "Cear\u00e1"              = 23L,
    "Rio Grande do Norte"     = 24L,
    "Para\u00edba"            = 25L,
    "Pernambuco"              = 26L,
    "Alagoas"                 = 27L,
    "Sergipe"                 = 28L,
    "Bahia"                   = 29L,
    "Minas Gerais"            = 31L,
    "Esp\u00edrito Santo"     = 32L,
    "Rio de Janeiro"          = 33L,
    "S\u00e3o Paulo"          = 35L,
    "Paran\u00e1"             = 41L,
    "Santa Catarina"          = 42L,
    "Rio Grande do Sul"       = 43L,
    "Mato Grosso do Sul"      = 50L,
    "Mato Grosso"             = 51L,
    "Goi\u00e1s"              = 52L,
    "Distrito Federal"        = 53L,
    "Brasil"                  = 99L
  )
}


#' Extract a single sheet from a BTR1 UF file
#'
#' Reads one sheet, maps state names to IBGE codes, and unpivots
#' from wide to long format.
#'
#' @param path Local file path.
#' @param sheet_name Sheet name to read.
#' @param gas_id Integer gasId for this sheet.
#' @param sector_id Integer sectorId for this file.
#'
#' @return A tibble with columns: ufId, sectorId, gasId, yearId, emissionKt.
#' @keywords internal
extract_btr1_sheet <- function(path, sheet_name, gas_id, sector_id) {

  etl_log("extract", paste0("Processing sheet: ", sheet_name))

  uf_map <- uf_ibge_map()

  raw <- readxl::read_excel(
    path,
    sheet      = sheet_name,
    skip       = 5,
    col_names  = TRUE,
    .name_repair = "minimal"
  )

  first_col <- names(raw)[1]
  raw <- dplyr::rename(raw, ufName = dplyr::all_of(first_col))
  raw <- dplyr::filter(raw, !is.na(.data$ufName))
  raw <- dplyr::mutate(raw, ufId = uf_map[.data$ufName])

  unmapped <- raw |>
    dplyr::filter(is.na(.data$ufId)) |>
    dplyr::pull(.data$ufName)

  if (length(unmapped) > 0) {
    warning("Unmapped states: ", paste(unmapped, collapse = ", "))
  }

  long <- raw |>
    dplyr::select("ufId", dplyr::matches("^\\d{4}$")) |>
    tidyr::pivot_longer(
      cols      = -"ufId",
      names_to  = "yearId",
      values_to = "emissionKt"
    ) |>
    dplyr::mutate(
      yearId   = as.integer(.data$yearId),
      sectorId = sector_id,
      gasId    = gas_id
    )

  etl_log("extract", paste0(
    "Sheet ", sheet_name, ": ", nrow(long), " rows"
  ))

  long
}



#' Extract BTR1 Emissions by State (any sector)
#'
#' Reads a BTR1_UF_*.xlsx file (from a local path or URL),
#' auto-detects the sector and available gas sheets, unpivots all
#' sheets to long format, and returns data ready for factEmissions.
#'
#' Works with all BTR1 UF files: Energia, IPPU, Agropecuária,
#' LULUCF, Resíduos, and Total_Brasil.
#'
#' @param source File path or URL to a BTR1_UF_*.xlsx file.
#'
#' @return A list with two elements:
#'   \describe{
#'     \item{data}{Tibble with columns: ufId, sectorId, gasId,
#'       yearId, emissionKt. Ready to load into factEmissions.}
#'     \item{metadata}{List with inventoryPeriod, sectorId,
#'       sectorNamePt, years, and sheetNames.}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#'   # Single sector from URL
#'   result <- extract_btr1_uf(
#'     "https://www.gov.br/.../BTR1_UF_Energia.xlsx"
#'   )
#'
#'   # Local file
#'   result <- extract_btr1_uf("data/BTR1_UF_IPPU.xlsx")
#'
#'   result$data
#'   result$metadata$sectorNamePt
#' }
extract_btr1_uf <- function(source) {

  etl_log("extract", "Starting BTR1 UF extraction")

  path <- resolve_source(source)
  meta <- parse_btr1_metadata(path)

  # Process each sheet that has a known gas mapping
  all_data <- purrr::map_dfr(meta$sheetNames, function(sheet_name) {

    gas_id <- gas_id_from_sheet(sheet_name)

    if (is.na(gas_id)) {
      etl_log("extract", paste0("Skipping unknown sheet: ", sheet_name))
      return(NULL)
    }

    extract_btr1_sheet(path, sheet_name, gas_id, meta$sectorId)
  })

  result <- dplyr::select(
    all_data, "ufId", "sectorId", "gasId", "yearId", "emissionKt"
  )

  etl_log("extract", paste0(
    "Extraction complete [", meta$sectorNamePt, "]: ",
    nrow(result), " rows (",
    length(unique(result$ufId)), " UFs x ",
    length(unique(result$gasId)), " gases x ",
    length(unique(result$yearId)), " years)"
  ))

  list(
    data     = result,
    metadata = meta
  )
}


#' Extract all BTR1 UF sector files
#'
#' Convenience function that extracts all 6 sector files from the
#' official MCTI URLs (or local paths) and combines them into a
#' single dataset.
#'
#' @param sources Named character vector of file paths or URLs.
#'   Names should match sector file names. Defaults to the official
#'   MCTI download links.
#'
#' @return A list with:
#'   \describe{
#'     \item{data}{Combined tibble of all sectors, ready for factEmissions.}
#'     \item{metadata}{List of metadata objects, one per sector.}
#'   }
#'
#' @export
extract_btr1_all <- function(sources = NULL) {

  base_url <- "https://www.gov.br/mcti/pt-br/acompanhe-o-mcti/cgcl/clima/arquivos/arquivos_bi/5-aba"

  if (is.null(sources)) {
    sources <- c(
      Energia      = paste0(base_url, "/BTR1_UF_Energia.xlsx"),
      IPPU         = paste0(base_url, "/BTR1_UF_IPPU.xlsx"),
      Agropecuaria = paste0(base_url, "/BTR1_UF_Agropecuaria.xlsx"),
      LULUCF       = paste0(base_url, "/BTR1_UF_LULUCF.xlsx"),
      Residuos     = paste0(base_url, "/BTR1_UF_Res%C3%ADduos.xlsx"),
      Total        = paste0(base_url, "/BTR1_UF_Total_Brasil.xlsx")
    )
  }

  etl_log("extract", paste0("Extracting ", length(sources), " BTR1 sector files"))

  results <- purrr::map(sources, function(src) {
    extract_btr1_uf(src)
  })

  combined_data <- purrr::map_dfr(results, "data")
  all_metadata  <- purrr::map(results, "metadata")

  etl_log("extract", paste0(
    "All sectors combined: ", nrow(combined_data), " total rows across ",
    length(sources), " files"
  ))

  list(
    data     = combined_data,
    metadata = all_metadata
  )
}
