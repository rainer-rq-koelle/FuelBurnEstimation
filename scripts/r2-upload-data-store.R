#!/usr/bin/env Rscript
# Upload local data store to Cloudflare R2
#
# This script uploads data artifacts from the local data store (OneDrive or local)
# to R2 for cross-machine sharing.

suppressPackageStartupMessages({
  library(dplyr)
  library(here)
  library(purrr)
})

source(here("R", "r2-storage.R"))

message("Uploading FuelBurnEstimation Data Store to R2")
message("============================================\n")

# Get local data store path
data_store <- Sys.getenv("FUELBURN_DATA_STORE", unset = "")

if (data_store == "") {
  stop(
    "FUELBURN_DATA_STORE not set.\n",
    "Set it in .Renviron to your local data store path.",
    call. = FALSE
  )
}

message("Local data store: ", data_store)
message("R2 bucket: ", r2_bucket())
message("Timestamp: ", Sys.time())
message("\n")

# Define files to upload
# Structure: local_path, r2_path, required
upload_files <- tibble::tribble(
  ~local_path, ~r2_path, ~required, ~description,
  file.path(data_store, "raw/eur/EUR-canonical-milestones-summer2025.parquet"),
  "raw/eur/EUR-canonical-milestones-summer2025.parquet",
  TRUE,
  "EUR raw canonical milestones",

  file.path(data_store, "derived/eur/canonical-milestones-eur-2026-harmonized.parquet"),
  "derived/eur/canonical-milestones-eur-2026-harmonized.parquet",
  TRUE,
  "EUR harmonized milestones (2026 convention)",

  file.path(data_store, "raw/chn/CHN-canonical-milestones.parquet"),
  "raw/chn/CHN-canonical-milestones.parquet",
  FALSE,
  "CHN raw canonical milestones",

  file.path(data_store, "derived/chn/CHN-canonical-milestones-harmonized.parquet"),
  "derived/chn/CHN-canonical-milestones-harmonized.parquet",
  FALSE,
  "CHN harmonized milestones"
) |>
  mutate(
    exists = file.exists(local_path),
    size_mb = ifelse(exists, round(file.info(local_path)$size / 1024^2, 2), NA_real_)
  )

message("Files to upload:")
for (i in seq_len(nrow(upload_files))) {
  row <- upload_files[i, ]
  status <- if (row$exists) sprintf("✓ (%s MB)", row$size_mb) else "✗ missing"
  req <- if (row$required) "[required]" else "[optional]"
  message(sprintf("  %s %s %s", status, row$description, req))
}

# Check for missing required files
missing_required <- upload_files |>
  filter(required & !exists)

if (nrow(missing_required) > 0) {
  stop(
    "\nMissing required files:\n",
    paste("  -", missing_required$local_path, collapse = "\n"),
    "\n\nRun scripts/00-check-data-store.R to diagnose the issue.",
    call. = FALSE
  )
}

message("\n")

# Upload files
upload_results <- upload_files |>
  filter(exists) |>
  rowwise() |>
  mutate(
    uploaded = tryCatch({
      r2_upload(local_path, r2_path)
      TRUE
    }, error = function(e) {
      message("  ✗ Upload failed: ", e$message)
      FALSE
    })
  ) |>
  ungroup()

# Also upload manifest and handover files
manifest_dir <- file.path(data_store, "manifest")
handover_dir <- file.path(data_store, "handover")

message("\nUploading manifest and handover files...")

# Find latest manifest and handover
if (dir.exists(manifest_dir)) {
  manifest_files <- list.files(manifest_dir, pattern = "\\.csv$", full.names = TRUE)
  if (length(manifest_files) > 0) {
    latest_manifest <- manifest_files[which.max(file.info(manifest_files)$mtime)]
    r2_upload(latest_manifest, file.path("manifest", basename(latest_manifest)))
  }
}

if (dir.exists(handover_dir)) {
  handover_files <- list.files(handover_dir, pattern = "\\.txt$", full.names = TRUE)
  if (length(handover_files) > 0) {
    latest_handover <- handover_files[which.max(file.info(handover_files)$mtime)]
    r2_upload(latest_handover, file.path("handover", basename(latest_handover)))
  }
}

message("\n")

# Summary
n_uploaded <- sum(upload_results$uploaded)
n_total <- nrow(upload_results)

if (n_uploaded == n_total) {
  message("✓ Upload complete: ", n_uploaded, "/", n_total, " files uploaded to R2")
} else {
  warning("⚠ Partial upload: ", n_uploaded, "/", n_total, " files uploaded")
}

message("\nVerify upload with: Rscript scripts/r2-list-files.R")
