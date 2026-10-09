#!/usr/bin/env Rscript
# Clean Up Intermediate Files After R2 Upload
#
# IMPORTANT: Run this ONLY after confirming R2 upload success!
#
# This script removes intermediate processing files, keeping only:
# - Production datasets
# - Documentation
# - R2 upload manifests

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  Local Cleanup - Intermediate Files                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("⚠️  WARNING: This will delete intermediate processing files!\n")
cat("   Ensure R2 upload completed successfully before proceeding.\n\n")

# Ask for confirmation
cat("Continue with cleanup? (yes/no): ")
response <- tolower(trimws(readLines("stdin", n = 1)))

if (response != "yes") {
  cat("\nCleanup cancelled.\n")
  quit(save = "no", status = 0)
}

cat("\nProceeding with cleanup...\n\n")

# ============================================================================
# Files to Remove (already uploaded to R2)
# ============================================================================

intermediate_files <- c(
  # OLD EUR derived data (archived in R2)
  "data-derived/canonical-milestones-eur-2025-summer.parquet",  # OLD schema version
  "data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet",  # Replaced by FIXED
  "data-store/derived/eur/level-segments-eur-2026.parquet",  # OLD with orphans
  "data-store/derived/eur/level-segment-duration-summary-eur-2026.csv",
  "data-store/derived/eur/level-segment-qc-eur-2026.csv"
)

# Files to KEEP (production & documentation)
keep_files <- c(
  "data-store/production/eur/EUR-canonical-milestones-summer2025.parquet",
  "data-store/production/eur/EUR-level-segments-summer2025.parquet",
  "data-store/production/eur/dataset-manifest-summer2025.csv",
  "data-store/raw/eur/EUR-canonical-milestones-summer2025-ENRICHED.parquet",
  "data-store/derived/eur/level-segments-eur-2026-ENRICHED.parquet",
  "notes/EUR-FIXED-R2-Upload-*.txt",
  "notes/EUR-FIXED-Final-Results.md",
  "notes/EUR-CHN-Schema-Comparison.md"
)

cat("Files to remove:\n")
removed_count <- 0
for (file in intermediate_files) {
  if (file.exists(file)) {
    size_mb <- file.info(file)$size / 1024 / 1024
    cat(sprintf("  - %s (%.2f MB)\n", file, size_mb))
    unlink(file)
    removed_count <- removed_count + 1
  }
}

cat(sprintf("\n✓ Removed %d intermediate files\n\n", removed_count))

# ============================================================================
# Archive Local OLD Data
# ============================================================================

cat("Archiving local OLD data...\n")

# Create local archive directory
archive_dir <- "data-store/archive/old-lobt-bug"
dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)

# Move OLD harmonization output
old_harmonized <- "data-derived/canonical-milestones-eur-2026-harmonized.parquet"
if (file.exists(old_harmonized)) {
  file.copy(old_harmonized, file.path(archive_dir, basename(old_harmonized)))
  cat(sprintf("  ✓ Archived: %s\n", basename(old_harmonized)))
}

cat("\n")

# ============================================================================
# Summary
# ============================================================================

cat("╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  ✅ Cleanup Complete                                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("Production Data (KEPT):\n")
cat("  ✓ data-store/production/eur/EUR-canonical-milestones-summer2025.parquet\n")
cat("  ✓ data-store/production/eur/EUR-level-segments-summer2025.parquet\n\n")

cat("Documentation (KEPT):\n")
cat("  ✓ notes/EUR-FIXED-*.md\n")
cat("  ✓ notes/EUR-FIXED-R2-Upload-*.txt\n\n")

cat("Archive (LOCAL):\n")
cat("  ✓ data-store/archive/old-lobt-bug/\n\n")

cat("R2 Storage:\n")
cat("  ✓ processed/eur/ (production data)\n")
cat("  ✓ archive/old-lobt-bug/ (OLD data)\n")
cat("  ✓ handover/ (documentation)\n\n")

cat("Local workspace cleaned and ready!\n")
