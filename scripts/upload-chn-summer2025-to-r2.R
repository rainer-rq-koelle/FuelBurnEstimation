#!/usr/bin/env Rscript
# Upload CHN Summer 2025 data to R2

library(arrow)
source("R/r2-storage.R")

cat("\n=== Uploading CHN Summer 2025 Data to R2 ===\n\n")

# Upload consolidated CHN files
cat("1. Uploading canonical milestones...\n")
r2_upload(
  "data-store/processed/chn/CHN-canonical-milestones-summer2025.parquet",
  "processed/chn/CHN-canonical-milestones-summer2025.parquet"
)

cat("2. Uploading level segments...\n")
r2_upload(
  "data-store/processed/chn/CHN-level-segments-summer2025.parquet",
  "processed/chn/CHN-level-segments-summer2025.parquet"
)

cat("3. Uploading phase summaries...\n")
r2_upload(
  "data-store/processed/chn/CHN-phase-summaries-summer2025.parquet",
  "processed/chn/CHN-phase-summaries-summer2025.parquet"
)

cat("\n✓ All CHN summer 2025 data uploaded to R2!\n")
cat("\nFiles available:\n")
cat("  - processed/chn/CHN-canonical-milestones-summer2025.parquet\n")
cat("  - processed/chn/CHN-level-segments-summer2025.parquet\n")
cat("  - processed/chn/CHN-phase-summaries-summer2025.parquet\n")
