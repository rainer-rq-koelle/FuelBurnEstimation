#!/usr/bin/env Rscript
# Update R2 registry with level-segment artifacts

# Read the current R/r2-storage.R file
r2_file <- "R/r2-storage.R"
lines <- readLines(r2_file)

# Find the registry function
registry_start <- which(grepl("r2_artifact_registry <- function\\(\\)", lines))
registry_end <- which(grepl("^\\}", lines) & seq_along(lines) > registry_start)[1]

# Create new registry content with level-segment artifacts added
new_registry <- c(
  'r2_artifact_registry <- function() {',
  '  tibble::tribble(',
  '    ~key, ~source, ~stage, ~required, ~version, ~produced_by_script, ~input_artifacts, ~description,',
  '    "raw/eur/EUR-canonical-milestones-summer2025.parquet",',
  '    "EUR/PRU", "raw", TRUE, "summer2025", "external-pru-source", "",',
  '    "EUR raw canonical milestones",',
  '',
  '    "derived/eur/canonical-milestones-eur-2026-harmonized.parquet",',
  '    "EUR/PRU", "derived", TRUE, "2026-harmonized", "scripts/04-harmonize-eur-milestones.R",',
  '    "raw/eur/EUR-canonical-milestones-summer2025.parquet",',
  '    "EUR harmonized milestones in the 2026 convention",',
  '',
  '    "derived/eur/level-segments-eur-2026.parquet",',
  '    "EUR/PRU", "derived", TRUE, "2026", "scripts/05-derive-eur-level-segments.R",',
  '    "derived/eur/canonical-milestones-eur-2026-harmonized.parquet",',
  '    "EUR level-segment intervals with QC flags",',
  '',
  '    "derived/eur/level-segment-duration-summary-eur-2026.csv",',
  '    "EUR/PRU", "derived", FALSE, "2026", "scripts/05-derive-eur-level-segments.R",',
  '    "derived/eur/level-segments-eur-2026.parquet",',
  '    "EUR level-segment duration distribution summary",',
  '',
  '    "derived/eur/level-segment-qc-eur-2026.csv",',
  '    "EUR/PRU", "derived", FALSE, "2026", "scripts/05-derive-eur-level-segments.R",',
  '    "derived/eur/level-segments-eur-2026.parquet",',
  '    "EUR level-segment QC detail by phase and altitude",',
  '',
  '    "raw/chn/CHN-canonical-milestones.parquet",',
  '    "CHN/QAR", "raw", FALSE, "pending", "scripts/prepare-chn-qar-canonical.R", "",',
  '    "CHN raw canonical milestones",',
  '',
  '    "derived/chn/CHN-canonical-milestones-harmonized.parquet",',
  '    "CHN/QAR", "derived", FALSE, "pending", "pending", "raw/chn/CHN-canonical-milestones.parquet",',
  '    "CHN harmonized milestones"',
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

cat("✓ Updated R2 registry with level-segment artifacts\n")
cat("  - level-segments-eur-2026.parquet (required)\n")
cat("  - level-segment-duration-summary-eur-2026.csv (optional)\n")
cat("  - level-segment-qc-eur-2026.csv (optional)\n")
