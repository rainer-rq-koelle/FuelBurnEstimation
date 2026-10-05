suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(here)
})

source(here::here("R", "paths.R"))
source(here::here("R", "rqutils-zip.R"))
source(here::here("R", "chn-data-prep.R"))

message("Placeholder for the executable CHN reference-data build.")
message("Reference data folder: ", fuelburn_path("reference_2025_data"))
message("Next implementation step: parameterise selected CHN archives and write data-derived/CHN-fuel-msts.parquet.")
