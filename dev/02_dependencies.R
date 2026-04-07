# ============================================================
# 02_dependencies.R — All package dependencies
# Run date: 2026-04-07
# ============================================================

# Core infrastructure
usethis::use_package("DBI")
usethis::use_package("RSQLite")
usethis::use_package("dplyr")
usethis::use_package("rlang")
usethis::use_package("cli")

# Extract layer
usethis::use_package("readr")
usethis::use_package("readxl")
usethis::use_package("jsonlite")
usethis::use_package("httr2")

# Transform layer
usethis::use_package("tidyr")
usethis::use_package("lubridate")
usethis::use_package("stringr")
usethis::use_package("purrr")

# Future migration (not required to install)
usethis::use_package("odbc", type = "Suggests")
usethis::use_package("dbplyr", type = "Suggests")

# Testing
usethis::use_package("testthat", type = "Suggests")
