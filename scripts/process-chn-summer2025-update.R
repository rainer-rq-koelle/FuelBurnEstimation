#!/usr/bin/env Rscript
# Process CHN Summer 2025 Update (June-July-August)
#
# Consolidates output from Chinese colleagues' QAR processing pipeline
# and uploads to R2 for cross-machine sync

library(arrow)
library(dplyr)
library(readr)

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  CHN Summer 2025 Data - Consolidation & Upload              ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Paths
incoming_dir <- "data-incoming/chn-summer2025/CHN QAR summary（June July and August）"
datastore_dir <- "data-store/processed/chn"
dir.create(datastore_dir, recursive = TRUE, showWarnings = FALSE)

# Source R2 functions
source("R/r2-storage.R")

# Find all output directories
output_dirs <- list.dirs(incoming_dir, full.names = TRUE, recursive = FALSE) %>%
  .[grepl("output\\d+", basename(.))] %>%
  sort()

cat(sprintf("\nFound %d output directories to consolidate\n", length(output_dirs)))

# ============================================================================
# Step 1: Consolidate canonical milestones
# ============================================================================

cat("\n=== Step 1: Consolidating Canonical Milestones ===\n")

all_milestones <- list()

for (dir in output_dirs) {
  dir_name <- basename(dir)
  milestone_file <- file.path(dir, "CHN-canonical-milestones.parquet")

  if (file.exists(milestone_file)) {
    df <- read_parquet(milestone_file) %>%
      mutate(source_batch = dir_name)
    all_milestones[[dir_name]] <- df
    cat(sprintf("  ✓ %s: %s records\n", dir_name, format(nrow(df), big.mark = ",")))
  }
}

milestones_combined <- bind_rows(all_milestones)

cat(sprintf("\n✓ Combined: %s milestone records from %s flights\n",
            format(nrow(milestones_combined), big.mark = ","),
            format(n_distinct(milestones_combined$SOURCE_UID), big.mark = ",")))

# Save consolidated
milestone_out <- file.path(datastore_dir, "CHN-canonical-milestones-summer2025.parquet")
write_parquet(milestones_combined, milestone_out)
cat("✓ Saved:", milestone_out, "\n")

# ============================================================================
# Step 2: Consolidate level segments
# ============================================================================

cat("\n=== Step 2: Consolidating Level Segments ===\n")

all_level_segments <- list()

for (dir in output_dirs) {
  dir_name <- basename(dir)
  level_file <- file.path(dir, "CHN-level-segments.parquet")

  if (file.exists(level_file)) {
    df <- read_parquet(level_file) %>%
      mutate(source_batch = dir_name)
    all_level_segments[[dir_name]] <- df
    cat(sprintf("  ✓ %s: %s segments\n", dir_name, format(nrow(df), big.mark = ",")))
  }
}

level_segments_combined <- bind_rows(all_level_segments)

cat(sprintf("\n✓ Combined: %s level segments\n",
            format(nrow(level_segments_combined), big.mark = ",")))

# Save consolidated
level_out <- file.path(datastore_dir, "CHN-level-segments-summer2025.parquet")
write_parquet(level_segments_combined, level_out)
cat("✓ Saved:", level_out, "\n")

# ============================================================================
# Step 3: Consolidate phase summaries
# ============================================================================

cat("\n=== Step 3: Consolidating Phase Summaries ===\n")

all_phase_summaries <- list()

for (dir in output_dirs) {
  dir_name <- basename(dir)
  phase_file <- file.path(dir, "CHN-phase-summaries.parquet")

  if (file.exists(phase_file)) {
    df <- read_parquet(phase_file) %>%
      mutate(source_batch = dir_name)
    all_phase_summaries[[dir_name]] <- df
    cat(sprintf("  ✓ %s: %s phase records\n", dir_name, format(nrow(df), big.mark = ",")))
  }
}

phase_summaries_combined <- bind_rows(all_phase_summaries)

cat(sprintf("\n✓ Combined: %s phase records\n",
            format(nrow(phase_summaries_combined), big.mark = ",")))

# Save consolidated
phase_out <- file.path(datastore_dir, "CHN-phase-summaries-summer2025.parquet")
write_parquet(phase_summaries_combined, phase_out)
cat("✓ Saved:", phase_out, "\n")

# ============================================================================
# Step 4: Create summary statistics
# ============================================================================

cat("\n=== Step 4: Summary Statistics ===\n")

# Route pairs
route_summary <- milestones_combined %>%
  distinct(SOURCE_UID, ADEP, ADES) %>%
  mutate(ROUTE_PAIR = paste(ADEP, ADES, sep = "-")) %>%
  count(ROUTE_PAIR, name = "flights") %>%
  arrange(desc(flights))

cat("\nRoute Pairs:\n")
print(route_summary, n = Inf)

# Aircraft types
aircraft_summary <- milestones_combined %>%
  distinct(SOURCE_UID, AIRCRAFT_TYPE) %>%
  count(AIRCRAFT_TYPE, name = "flights") %>%
  arrange(desc(flights))

cat("\nAircraft Types:\n")
print(aircraft_summary, n = Inf)

# Level segment quality
level_qc <- level_segments_combined %>%
  summarise(
    total_segments = n(),
    with_duration = sum(!is.na(duration_min)),
    with_fuel = sum(!is.na(fuel_burnt_kg)),
    mean_duration = mean(duration_min, na.rm = TRUE),
    median_duration = median(duration_min, na.rm = TRUE),
    mean_fuel = mean(fuel_burnt_kg, na.rm = TRUE)
  )

cat("\nLevel Segment Quality:\n")
print(level_qc)

# ============================================================================
# Step 5: Upload to R2
# ============================================================================

cat("\n=== Step 5: Uploading to R2 ===\n")

# Upload consolidated files
r2_upload(milestone_out, "processed/chn/CHN-canonical-milestones-summer2025.parquet")
r2_upload(level_out, "processed/chn/CHN-level-segments-summer2025.parquet")
r2_upload(phase_out, "processed/chn/CHN-phase-summaries-summer2025.parquet")

cat("\n✓ All files uploaded to R2!\n")

# ============================================================================
# Step 6: Create processing report
# ============================================================================

cat("\n=== Step 6: Creating Processing Report ===\n")

report_lines <- c(
  "# CHN Summer 2025 Data Processing Report",
  "",
  sprintf("**Processing Date:** %s", Sys.time()),
  sprintf("**Data Period:** June-July-August 2025"),
  "",
  "## Summary",
  "",
  sprintf("- **Total Flights:** %s", format(n_distinct(milestones_combined$SOURCE_UID), big.mark = ",")),
  sprintf("- **Milestone Records:** %s", format(nrow(milestones_combined), big.mark = ",")),
  sprintf("- **Level Segments:** %s", format(nrow(level_segments_combined), big.mark = ",")),
  sprintf("- **Phase Records:** %s", format(nrow(phase_summaries_combined), big.mark = ",")),
  sprintf("- **Source Batches:** %d (output1-output%d)", length(output_dirs), length(output_dirs)),
  "",
  "## Route Pairs",
  "",
  "| Route | Flights |",
  "|-------|---------|"
)

for (i in 1:nrow(route_summary)) {
  report_lines <- c(report_lines,
                   sprintf("| %s | %s |",
                          route_summary$ROUTE_PAIR[i],
                          format(route_summary$flights[i], big.mark = ",")))
}

report_lines <- c(report_lines,
  "",
  "## Aircraft Types",
  "",
  "| Type | Flights |",
  "|------|---------|"
)

for (i in 1:nrow(aircraft_summary)) {
  report_lines <- c(report_lines,
                   sprintf("| %s | %s |",
                          aircraft_summary$AIRCRAFT_TYPE[i],
                          format(aircraft_summary$flights[i], big.mark = ",")))
}

report_lines <- c(report_lines,
  "",
  "## Level Segment Statistics",
  "",
  sprintf("- Mean duration: %.1f minutes", level_qc$mean_duration),
  sprintf("- Median duration: %.1f minutes", level_qc$median_duration),
  sprintf("- Mean fuel burn: %.1f kg", level_qc$mean_fuel),
  sprintf("- Completeness: %.1f%% with duration data", 100 * level_qc$with_duration / level_qc$total_segments),
  "",
  "## Files in R2",
  "",
  "- `processed/chn/CHN-canonical-milestones-summer2025.parquet`",
  "- `processed/chn/CHN-level-segments-summer2025.parquet`",
  "- `processed/chn/CHN-phase-summaries-summer2025.parquet`",
  "",
  "## Next Steps",
  "",
  "1. Compare with EUR summer 2025 data for distance band matching",
  "2. Run distance band analysis for paper",
  "3. Create comparative visualizations (CHN vs EUR)",
  "4. Update paper with CHN summer 2025 results",
  "",
  "---",
  "",
  sprintf("*Report generated: %s*", Sys.time())
)

report_file <- file.path("notes", "CHN-Summer2025-Processing-Report.md")
writeLines(report_lines, report_file)
cat("✓ Report saved:", report_file, "\n")

# ============================================================================
# Summary
# ============================================================================

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  CONSOLIDATION COMPLETE                                      ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

cat("\nConsolidated Files:\n")
cat("✓ Local: data-store/processed/chn/\n")
cat("✓ R2: processed/chn/\n")
cat("✓ Report: notes/CHN-Summer2025-Processing-Report.md\n")

cat("\nReady for analysis!\n")
