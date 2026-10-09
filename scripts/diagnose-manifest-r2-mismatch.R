#!/usr/bin/env Rscript
# Diagnose manifest vs R2 content mismatch

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

source(here("R", "r2-storage.R"))

cat("=== MANIFEST vs R2 DIAGNOSTIC ===\n\n")

# Download and read current manifest
data_store <- r2_data_store()
manifest <- r2_download_current_manifest(data_store)

cat("Manifest entries (status=current):\n")
manifest_current <- manifest |>
  filter(status == "current") |>
  select(key, required, size_bytes)

print(manifest_current, n = Inf)
cat("\n")

# List actual R2 contents
cat("Fetching R2 contents...\n")
r2_files <- r2_list()

cat("\nR2 contents:\n")
print(r2_files |> select(Key, Size), n = Inf)
cat("\n")

# Find mismatches
cat("=== MISMATCH ANALYSIS ===\n\n")

# Files in manifest but not in R2
manifest_keys <- manifest_current$key
r2_keys <- r2_files$Key

missing_in_r2 <- setdiff(manifest_keys, r2_keys)
if (length(missing_in_r2) > 0) {
  cat("❌ Files in MANIFEST but MISSING in R2:\n")
  for (key in missing_in_r2) {
    required <- manifest_current$required[manifest_current$key == key]
    cat(sprintf("  - %s (required=%s)\n", key, required))
  }
  cat("\n")
} else {
  cat("✓ All manifest files present in R2\n\n")
}

# Files in R2 but not in manifest
extra_in_r2 <- setdiff(r2_keys, manifest_keys)
if (length(extra_in_r2) > 0) {
  cat("⚠ Files in R2 but NOT in manifest:\n")
  for (key in extra_in_r2) {
    cat(sprintf("  - %s\n", key))
  }
  cat("\n")
}

cat("=== RECOMMENDATIONS ===\n\n")

if (length(missing_in_r2) > 0) {
  cat("Missing files should either be:\n")
  cat("1. Uploaded to R2 if they are authoritative\n")
  cat("2. Removed from manifest if they are not authoritative\n\n")

  cat("Commands to remove from manifest:\n")
  cat("Edit manifest/current-artifacts.csv and remove these keys:\n")
  for (key in missing_in_r2) {
    cat(sprintf("  - %s\n", key))
  }
}
