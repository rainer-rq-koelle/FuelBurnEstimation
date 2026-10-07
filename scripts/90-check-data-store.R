#!/usr/bin/env Rscript
# Check the local shared data-store configuration.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")

if (identical(data_store, "")) {
  stop(
    "FUELBURN_DATA_STORE is not set. Add it to .Renviron and restart R/Rscript.",
    call. = FALSE
  )
}

cat("FuelBurnEstimation data store\n")
cat("=============================\n\n")
cat("FUELBURN_DATA_STORE:\n", data_store, "\n\n", sep = "")

if (!dir.exists(data_store)) {
  stop("Data-store folder does not exist: ", data_store, call. = FALSE)
}

expected_dirs <- file.path(
  data_store,
  c(
    "raw/chn",
    "raw/eur",
    "derived/chn",
    "derived/eur",
    "manifests",
    "handover"
  )
)

dir_status <- tibble::tibble(
  folder = gsub(paste0("^", normalizePath(data_store, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(expected_dirs, winslash = "/", mustWork = FALSE)),
  path = expected_dirs,
  exists = dir.exists(expected_dirs)
)

cat("Folder structure:\n")
print(dir_status, n = Inf)

files <- list.files(data_store, recursive = TRUE, full.names = TRUE, no.. = TRUE)
files <- files[file.info(files)$isdir %in% FALSE]

file_inventory <- tibble::tibble(
  file = gsub(paste0("^", normalizePath(data_store, winslash = "/", mustWork = FALSE), "/?"), "", normalizePath(files, winslash = "/", mustWork = FALSE)),
  size_mb = round(file.info(files)$size / 1024^2, 3),
  sha256 = if (length(files) > 0) as.character(tools::sha256sum(files)) else character()
) |>
  arrange(.data$file)

cat("\nFiles:\n")
if (nrow(file_inventory) == 0) {
  cat("No files found yet.\n")
} else {
  print(file_inventory, n = Inf)
}

if (!all(dir_status$exists)) {
  quit(status = 2)
}

cat("\nData-store check complete.\n")
