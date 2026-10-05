suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

source(here::here("R", "paths.R"))

reference_data <- fuelburn_path("reference_2025_data")

if (!dir.exists(reference_data)) {
  stop("Reference data folder not found: ", reference_data, call. = FALSE)
}

files <- list.files(reference_data, full.names = TRUE, recursive = FALSE, all.files = FALSE)
info <- file.info(files)

inventory <- tibble(
  file = basename(files),
  path = files,
  size_bytes = info$size,
  size_mb = round(info$size / 1024^2, 2),
  modified_time = info$mtime
) |>
  arrange(file)

dir.create(here::here("notes"), showWarnings = FALSE, recursive = TRUE)
write_csv(inventory, here::here("notes", "reference-data-inventory.csv"))

message("Wrote notes/reference-data-inventory.csv with ", nrow(inventory), " files.")
