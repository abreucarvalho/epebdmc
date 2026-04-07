
## epebdmc

A simple, direct ETL package for R.

- **Extract** from CSV, Excel, JSON, APIs, and databases
- **Transform** with clean, filter, select, and enrich steps
- **Load** treated data into SQLite (with SQL Server migration path)

## Installation

``` r
# install.packages("devtools")
devtools::install_github("yourusername/epebdmc")
```

## Quick example

``` r
library(epebdmc)

con <- db_connect()

extract_csv("sales.csv") |>
  transform_clean() |>
  transform_filter(amount > 0) |>
  load_to_db(con, "sales_treated")

db_disconnect(con)
```

## Learn more

- `vignette("usage-guide", package = "epebdmc")` — full usage guide
- `vignette("how-epebdmc-was-built", package = "epebdmc")` — build
  process
- `vignette("migration-sqlite-to-sqlserver", package = "epebdmc")` —
  migration guide
