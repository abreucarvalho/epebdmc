#' Log an ETL step message
#'
#' Prints a timestamped, styled message to the console.
#'
#' @param step Character. The ETL phase: "extract", "transform", "load", or "info".
#' @param msg Character. The message to display.
#'
#' @export
etl_log <- function(step, msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  icon <- switch(step,
                 extract   = "\U0001F4E5",
                 transform = "\U0001F504",
                 load      = "\U0001F4E4",
                 "\U0001F539"
  )
  cli::cli_alert_info("{icon} [{timestamp}] [{toupper(step)}] {msg}")
}
