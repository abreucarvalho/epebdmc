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



