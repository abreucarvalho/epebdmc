# ============================================================
# 01_setup.R — Package creation and initial configuration
# Run date: 2026-04-07
# ============================================================

# Step 1: Create the package skeleton
# Run this from a fresh R session (not inside another project)
# usethis::create_package("epebdmc")

# Step 2: Initialize Git and connect to GitHub
# usethis::use_git()
# usethis::use_github()

# Step 3: Fill in DESCRIPTION
# Edited manually:
#   Title, Version, Authors@R, Description, License

# Step 4: License
# usethis::use_mit_license("Your Full Name")  # replace with actual name

# Step 5: Create the logging utility
# usethis::use_r("utils")
# -> Wrote etl_log() function — see R/utils.R
# etl_log(step, msg) provides timestamped console feedback
# using cli::cli_alert_info() with emoji icons per ETL phase
