#!/usr/bin/env Rscript
# Upload FIXED G2G data to R2

library(arrow)
source("R/r2-storage.R")

cat("\n=== Uploading FIXED Data to R2 ===\n\n")

# Upload flight metadata
cat("1. Uploading flight metadata...\n")
r2_upload(
  "data-store/raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet",
  "raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet"
)

# Upload segment details
cat("2. Uploading segment details...\n")
r2_upload(
  "data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet",
  "raw/eur/g2g-segment-details-2025-summer-FIXED.parquet"
)

cat("\n✓ Upload complete!\n")
cat("\nFIXED data now available in R2:\n")
cat("  - raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet\n")
cat("  - raw/eur/g2g-segment-details-2025-summer-FIXED.parquet\n")
