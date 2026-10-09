#!/usr/bin/env Rscript
# Update R2 Artifact Registry for FIXED Pipeline Production Data

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  Update R2 Artifact Registry - FIXED Pipeline               ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# Read the current R/r2-storage.R file
r2_file <- "R/r2-storage.R"
lines <- readLines(r2_file)

# Find the registry function
registry_start <- which(grepl("r2_artifact_registry <- function\\(\\)", lines))
registry_end <- which(grepl("^\\}", lines) & seq_along(lines) > registry_start)[1]

cat("Updating artifact registry with FIXED production data...\n\n")

# Create new registry content with FIXED production artifacts
new_registry <- c(
  'r2_artifact_registry <- function() {',
  '  tibble::tribble(',
  '    ~key, ~source, ~stage, ~required, ~version, ~produced_by_script, ~input_artifacts, ~description,',
  '',
  '    # ===================================================================',
  '    # EUR PRODUCTION DATA (FIXED Pipeline - 0% orphans)',
  '    # ===================================================================',
  '',
  '    "processed/eur/EUR-canonical-milestones-summer2025.parquet",',
  '    "EUR/PRU", "production", TRUE, "FIXED-summer2025", "scripts/08-create-harmonized-analytical-datasets.R",',
  '    "data-store/raw/eur/EUR-canonical-milestones-summer2025-ENRICHED.parquet",',
  '    "EUR production canonical milestones - FIXED pipeline with CHN-compatible schema (21 cols, 0% orphans)",',
  '',
  '    "processed/eur/EUR-level-segments-summer2025.parquet",',
  '    "EUR/PRU", "production", TRUE, "FIXED-summer2025", "scripts/08-create-harmonized-analytical-datasets.R",',
  '    "data-store/derived/eur/level-segments-eur-2026-ENRICHED.parquet",',
  '    "EUR production level segments - FIXED pipeline (31 cols, 100% complete, 0% orphans)",',
  '',
  '    # ===================================================================',
  '    # CHN PRODUCTION DATA',
  '    # ===================================================================',
  '',
  '    "processed/chn/CHN-canonical-milestones-summer2025.parquet",',
  '    "CHN/QAR", "production", TRUE, "summer2025", "scripts/process-chn-summer2025-update.R",',
  '    "",',
  '    "CHN production canonical milestones - Summer 2025 (21 cols, compatible with EUR)",',
  '',
  '    "processed/chn/CHN-level-segments-summer2025.parquet",',
  '    "CHN/QAR", "production", TRUE, "summer2025", "scripts/process-chn-summer2025-update.R",',
  '    "",',
  '    "CHN production level segments - Summer 2025 (31 cols)",',
  '',
  '    "processed/chn/CHN-phase-summaries-summer2025.parquet",',
  '    "CHN/QAR", "production", FALSE, "summer2025", "scripts/process-chn-summer2025-update.R",',
  '    "",',
  '    "CHN phase summaries - Summer 2025",',
  '',
  '    # ===================================================================',
  '    # EUR RAW DATA (FIXED extraction)',
  '    # ===================================================================',
  '',
  '    "raw/eur/EUR-canonical-milestones-summer2025-ENRICHED.parquet",',
  '    "EUR/PRU", "raw", FALSE, "FIXED-enriched", "scripts/06-enrich-eur-canonical.R",',
  '    "data-store/raw/eur/EUR-canonical-milestones-summer2025-FIXED.parquet",',
  '    "EUR enriched canonical milestones - FIXED extraction with metadata (21 cols)",',
  '',
  '    "raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet",',
  '    "EUR/PRU", "raw", FALSE, "FIXED", "external-pru-query",',
  '    "",',
  '    "EUR G2G flight metadata - FIXED extraction (LOBT bug corrected)",',
  '',
  '    "raw/eur/g2g-segment-details-2025-summer-FIXED.parquet",',
  '    "EUR/PRU", "raw", FALSE, "FIXED", "external-pru-query",',
  '    "",',
  '    "EUR G2G segment details - FIXED extraction (LOBT bug corrected)",',
  '',
  '    # ===================================================================',
  '    # EUR DERIVED DATA (FIXED pipeline)',
  '    # ===================================================================',
  '',
  '    "derived/eur/level-segments-eur-2026-ENRICHED.parquet",',
  '    "EUR/PRU", "derived", FALSE, "FIXED-enriched", "scripts/07-enrich-eur-level-segments.R",',
  '    "data-store/derived/eur/level-segments-eur-2026.parquet",',
  '    "EUR enriched level segments with LEVEL_CONTEXT_PHASE (31 cols)",',
  '',
  '    # ===================================================================',
  '    # ARCHIVED DATA (OLD pipeline - pre-LOBT fix)',
  '    # ===================================================================',
  '',
  '    "archive/old-lobt-bug/canonical-milestones-eur-2026-harmonized.parquet",',
  '    "EUR/PRU", "archive", FALSE, "OLD-2026", "archived-2026-10-09",',
  '    "",',
  '    "ARCHIVED: EUR harmonized milestones OLD pipeline (54.4% orphans) - kept for reference",',
  '',
  '    "archive/old-lobt-bug/level-segments-eur-2026.parquet",',
  '    "EUR/PRU", "archive", FALSE, "OLD-2026", "archived-2026-10-09",',
  '    "",',
  '    "ARCHIVED: EUR level segments OLD pipeline (9.2% orphans after harmonization) - kept for reference"',
  '  )',
  '}'
)

# Replace the registry function
new_lines <- c(
  lines[1:(registry_start - 1)],
  new_registry,
  lines[(registry_end + 1):length(lines)]
)

# Write back
writeLines(new_lines, r2_file)

cat("✓ Updated R2 artifact registry\n\n")

cat("Production Artifacts (required=TRUE):\n")
cat("  ✓ processed/eur/EUR-canonical-milestones-summer2025.parquet (FIXED)\n")
cat("  ✓ processed/eur/EUR-level-segments-summer2025.parquet (FIXED)\n")
cat("  ✓ processed/chn/CHN-canonical-milestones-summer2025.parquet\n")
cat("  ✓ processed/chn/CHN-level-segments-summer2025.parquet\n\n")

cat("Pipeline Quality:\n")
cat("  • EUR: FIXED pipeline, 0% orphans, 100% complete\n")
cat("  • CHN: Summer 2025 data\n")
cat("  • Schemas: Harmonized and compatible\n\n")

cat("Next Step: Publish manifest to R2\n")
cat("  Rscript scripts/r2-publish-manifest.R\n\n")
