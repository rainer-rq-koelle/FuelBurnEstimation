#!/usr/bin/env Rscript
# Clean manifest by removing non-authoritative entries

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

source(here("R", "r2-storage.R"))

cat("=== CLEANING R2 MANIFEST ===\n\n")

# Download current manifest
data_store <- r2_data_store()
manifest_path <- file.path(data_store, "manifest", "current-artifacts.csv")
manifest <- r2_download_current_manifest(data_store)

cat("Current manifest entries: ", nrow(manifest), "\n")

# Keys to remove (non-authoritative / missing from R2)
keys_to_remove <- c(
  "derived/eur/level-segments-eur-2026-ENRICHED.parquet",
  "raw/eur/EUR-canonical-milestones-summer2025-ENRICHED.parquet",
  "archive/old-lobt-bug/canonical-milestones-eur-2026-harmonized.parquet"
)

cat("\nRemoving non-authoritative entries:\n")
for (key in keys_to_remove) {
  cat(sprintf("  - %s\n", key))
}

# Filter manifest
cleaned_manifest <- manifest |>
  filter(!key %in% keys_to_remove)

cat("\nCleaned manifest entries: ", nrow(cleaned_manifest), "\n")

# Update manifest metadata
cleaned_manifest <- cleaned_manifest |>
  mutate(
    manifest_created_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    manifest_machine = Sys.info()[["nodename"]],
    manifest_user = Sys.info()[["user"]]
  )

# Write cleaned manifest locally
write_csv(cleaned_manifest, manifest_path)
cat("\n✓ Cleaned manifest written locally: ", manifest_path, "\n")

# Archive old manifest in R2
cat("\nArchiving old manifest in R2...\n")
archive_key <- sprintf("manifest/archive/artifacts-%s.csv",
                      format(Sys.time(), "%Y%m%d-%H%M%S"))
tryCatch({
  r2_copy(
    from = "manifest/current-artifacts.csv",
    to = archive_key
  )
  cat("✓ Archived: ", archive_key, "\n")
}, error = function(e) {
  cat("⚠ Archive failed (old manifest may not exist): ", e$message, "\n")
})

# Upload cleaned manifest
cat("\nUploading cleaned manifest to R2...\n")
r2_upload(
  local_path = manifest_path,
  r2_path = "manifest/current-artifacts.csv"
)

cat("\n✓ Cleaned manifest published to R2\n")

cat("\n=== VERIFICATION ===\n\n")
cat("Run this to verify:\n")
cat("  Rscript scripts/r2-sync-status.R\n\n")
cat("Expected result: All artifacts show sync_status='current'\n")
