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
data_store <- r2_data_store()

message("R2 bucket: ", r2_bucket())
message("Local data store: ", data_store)
message("Timestamp: ", Sys.time())
message("\n")

# Ensure the local cache has the expected folder skeleton, including optional
# source folders that may not have files in R2 yet.
r2_ensure_data_store_dirs(data_store)

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

manifest_available <- "manifest/current-artifacts.csv" %in% r2_files$Key
if (manifest_available) {
  message("Authoritative manifest found: manifest/current-artifacts.csv")
  manifest <- r2_download_current_manifest(data_store)
  download_files <- manifest |>
    filter(.data$status == "current") |>
    transmute(
      r2_path = .data$key,
      local_path = file.path(data_store, .data$key),
      required = .data$required,
      description = .data$description,
      expected_sha256 = .data$sha256
    )
} else {
  warning(
    "Authoritative manifest not found. Falling back to registered required files without checksum verification."
  )
  download_files <- r2_artifact_registry() |>
    filter(.data$required) |>
    transmute(
      r2_path = .data$key,
      local_path = file.path(data_store, .data$key),
      required = .data$required,
      description = .data$description,
      expected_sha256 = NA_character_
    )
}

download_files <- download_files |>
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
      if (!is.na(expected_sha256)) {
        actual_sha256 <- unname(as.character(tools::sha256sum(local_path)))
        if (!identical(actual_sha256, expected_sha256)) {
          stop("Checksum mismatch for ", r2_path, call. = FALSE)
        }
      }
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
