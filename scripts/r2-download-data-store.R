#!/usr/bin/env Rscript
# Download data store from Cloudflare R2 to local machine
#
# This script downloads data artifacts from R2 to the local data store.
# Use this on a new machine or to sync the latest data.

suppressPackageStartupMessages({
  library(dplyr)
  library(here)
  library(purrr)
})

source(here("R", "r2-storage.R"))

message("Downloading FuelBurnEstimation Data Store from R2")
message("===============================================\n")

# Get local data store path
data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")

if (data_store == "") {
  stop(
    "FUELBURN_DATA_STORE not set.\n",
    "Set it in .Renviron to your local data store path.",
    call. = FALSE
  )
}

message("R2 bucket: ", r2_bucket())
message("Local data store: ", data_store)
message("Timestamp: ", Sys.time())
message("\n")

# Check what's available in R2
message("Checking R2 bucket contents...")
r2_files <- r2_list()

if (nrow(r2_files) == 0) {
  stop(
    "No files found in R2 bucket.\n",
    "Run scripts/r2-upload-data-store.R on the source machine first.",
    call. = FALSE
  )
}

message("Found ", nrow(r2_files), " files in R2:\n")
print(r2_files |> select(Key, Size_MB, LastModified))

message("\n")

# Define files to download
download_files <- tibble::tribble(
  ~r2_path, ~local_path, ~required, ~description,
  "raw/eur/EUR-canonical-milestones-summer2025.parquet",
  file.path(data_store, "raw/eur/EUR-canonical-milestones-summer2025.parquet"),
  TRUE,
  "EUR raw canonical milestones",

  "derived/eur/canonical-milestones-eur-2026-harmonized.parquet",
  file.path(data_store, "derived/eur/canonical-milestones-eur-2026-harmonized.parquet"),
  TRUE,
  "EUR harmonized milestones (2026 convention)",

  "raw/chn/CHN-canonical-milestones.parquet",
  file.path(data_store, "raw/chn/CHN-canonical-milestones.parquet"),
  FALSE,
  "CHN raw canonical milestones",

  "derived/chn/CHN-canonical-milestones-harmonized.parquet",
  file.path(data_store, "derived/chn/CHN-canonical-milestones-harmonized.parquet"),
  FALSE,
  "CHN harmonized milestones"
) |>
  mutate(
    in_r2 = r2_path %in% r2_files$Key,
    local_exists = file.exists(local_path)
  )

message("Files to download:")
for (i in seq_len(nrow(download_files))) {
  row <- download_files[i, ]
  status <- if (row$in_r2) {
    if (row$local_exists) "⟳ exists locally (will overwrite)" else "⬇ new"
  } else {
    "✗ not in R2"
  }
  req <- if (row$required) "[required]" else "[optional]"
  message(sprintf("  %s %s %s", status, row$description, req))
}

# Check for missing required files in R2
missing_required <- download_files |>
  filter(required & !in_r2)

if (nrow(missing_required) > 0) {
  stop(
    "\nRequired files not found in R2:\n",
    paste("  -", missing_required$r2_path, collapse = "\n"),
    "\n\nRun scripts/r2-upload-data-store.R on the source machine first.",
    call. = FALSE
  )
}

message("\n")

# Download files
download_results <- download_files |>
  filter(in_r2) |>
  rowwise() |>
  mutate(
    downloaded = tryCatch({
      r2_download(r2_path, local_path, overwrite = TRUE)
      TRUE
    }, error = function(e) {
      message("  ✗ Download failed: ", e$message)
      FALSE
    })
  ) |>
  ungroup()

# Download manifest and handover files
message("\nDownloading manifest and handover files...")

manifest_files <- r2_files |> filter(grepl("^manifest/", Key))
handover_files <- r2_files |> filter(grepl("^handover/", Key))

for (file in manifest_files$Key) {
  local_path <- file.path(data_store, file)
  tryCatch({
    r2_download(file, local_path, overwrite = TRUE)
  }, error = function(e) {
    message("  ⚠ Skipped: ", basename(file))
  })
}

for (file in handover_files$Key) {
  local_path <- file.path(data_store, file)
  tryCatch({
    r2_download(file, local_path, overwrite = TRUE)
  }, error = function(e) {
    message("  ⚠ Skipped: ", basename(file))
  })
}

message("\n")

# Summary
n_downloaded <- sum(download_results$downloaded)
n_total <- nrow(download_results)

if (n_downloaded == n_total) {
  message("✓ Download complete: ", n_downloaded, "/", n_total, " files downloaded from R2")
} else {
  warning("⚠ Partial download: ", n_downloaded, "/", n_total, " files downloaded")
}

message("\nVerify local data store with: Rscript scripts/00-check-data-store.R")
