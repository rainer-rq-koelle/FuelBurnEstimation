#!/usr/bin/env Rscript
# PRU LVL Data Quality Audit
# Compare source LVL markers to completed level segments

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(here)
})

cat("=== PRU LVL MARKER COMPLETENESS AUDIT ===\n")
cat("Comparing source data to completed harmonization\n\n")

# Read source and harmonized data
cat("Reading data files...\n")
raw <- read_parquet(here("data-store/raw/eur/EUR-canonical-milestones-summer2025.parquet"))
harmonized <- read_parquet(here("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet"))

cat("  Raw PRU data:", format(nrow(raw), big.mark = ","), "rows\n")
cat("  Harmonized data:", format(nrow(harmonized), big.mark = ","), "rows\n\n")

# 1. Count source LVL markers per flight
cat("Step 1: Counting source LVL markers per flight...\n")
source_lvl <- raw %>%
  filter(grepl("LVL", MST)) %>%
  mutate(
    has_standalone_lvl = MST == "LVL",
    has_compound_lvl = grepl("/", MST) & grepl("LVL", MST)
  ) %>%
  group_by(UID) %>%
  summarise(
    source_lvl_total = n(),
    source_lvl_standalone = sum(has_standalone_lvl),
    source_lvl_compound = sum(has_compound_lvl),
    source_is_paired = source_lvl_standalone %% 2 == 0,
    .groups = "drop"
  )

cat("  Flights with source LVL markers:", format(nrow(source_lvl), big.mark = ","), "\n\n")

# 2. Count harmonized LVL_START/END per flight
cat("Step 2: Counting harmonized LVL_START/END per flight...\n")
harmonized_lvl <- harmonized %>%
  filter(MST %in% c("LVL_START", "LVL_END")) %>%
  group_by(UID, MST) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(names_from = MST, values_from = n, values_fill = 0) %>%
  rename(
    harmonized_starts = LVL_START,
    harmonized_ends = LVL_END
  ) %>%
  mutate(
    harmonized_balance = harmonized_starts - harmonized_ends,
    harmonized_is_balanced = harmonized_balance == 0
  )

cat("  Flights with harmonized segments:", format(nrow(harmonized_lvl), big.mark = ","), "\n\n")

# 3. Count implicit END markers by type
cat("Step 3: Counting implicit END markers by type...\n")
implicit_ends <- harmonized %>%
  filter(
    MST == "LVL_END",
    !is.na(.milestone_source),
    grepl("implicit", .milestone_source)
  ) %>%
  group_by(UID, .milestone_source) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(
    names_from = .milestone_source,
    values_from = n,
    values_fill = 0
  )

# Join all data
cat("Step 4: Combining and analyzing...\n")
audit <- source_lvl %>%
  left_join(harmonized_lvl, by = "UID") %>%
  left_join(implicit_ends, by = "UID") %>%
  mutate(
    harmonized_starts = coalesce(harmonized_starts, 0),
    harmonized_ends = coalesce(harmonized_ends, 0),
    harmonized_balance = coalesce(harmonized_balance, 0),
    harmonized_is_balanced = coalesce(harmonized_is_balanced, FALSE),
    implicit_end_at_TOD = coalesce(implicit_end_at_TOD, 0),
    implicit_end_at_phase_transition = coalesce(implicit_end_at_phase_transition, 0),
    implicit_end_at_trajectory_end = coalesce(implicit_end_at_trajectory_end, 0),
    
    # Check consistency
    starts_match_source = harmonized_starts == source_lvl_standalone,
    
    # Categorize completion type
    completion_type = case_when(
      source_is_paired & harmonized_is_balanced ~ "source_already_paired",
      !source_is_paired & harmonized_is_balanced ~ "completed_by_implicit_end",
      !source_is_paired & !harmonized_is_balanced ~ "still_orphaned",
      TRUE ~ "other"
    ),
    
    # Which implicit END type was used
    implicit_end_type = case_when(
      implicit_end_at_TOD > 0 ~ "TOD",
      implicit_end_at_phase_transition > 0 ~ "phase_transition",
      implicit_end_at_trajectory_end > 0 ~ "trajectory_end",
      TRUE ~ "none"
    )
  )

# Summary statistics
cat("\n=== SUMMARY STATISTICS ===\n\n")

cat("1. SOURCE DATA PAIRING STATUS\n")
source_summary <- audit %>%
  count(source_is_paired) %>%
  mutate(
    pct = round(100 * n / sum(n), 1),
    status = if_else(source_is_paired, "Paired (even count)", "Unpaired (odd count)")
  )
print(source_summary)

cat("\n2. HARMONIZATION COMPLETION STATUS\n")
completion_summary <- audit %>%
  count(completion_type) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(desc(n))
print(completion_summary)

cat("\n3. IMPLICIT END TYPES USED\n")
implicit_summary <- audit %>%
  filter(completion_type == "completed_by_implicit_end") %>%
  count(implicit_end_type) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(desc(n))
print(implicit_summary)

cat("\n4. CONSISTENCY CHECK: STARTS MATCH SOURCE?\n")
consistency_check <- audit %>%
  count(starts_match_source) %>%
  mutate(
    pct = round(100 * n / sum(n), 1),
    result = if_else(starts_match_source, "✓ Match", "✗ Mismatch")
  )
print(consistency_check)

# Write outputs
cat("\n=== WRITING OUTPUTS ===\n")
output_dir <- here("notes")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

audit_file <- file.path(output_dir, "pru-lvl-completeness-audit.csv")
write_csv(audit, audit_file)
cat("✓ Detailed audit:", audit_file, "\n")

summary_file <- file.path(output_dir, "pru-lvl-quality-summary.csv")
summary_data <- bind_rows(
  source_summary %>% select(category = status, n, pct) %>% mutate(section = "Source Pairing"),
  completion_summary %>% select(category = completion_type, n, pct) %>% mutate(section = "Completion Status"),
  implicit_summary %>% select(category = implicit_end_type, n, pct) %>% mutate(section = "Implicit END Type")
) %>%
  select(section, category, n, pct)

write_csv(summary_data, summary_file)
cat("✓ Summary for PRU:", summary_file, "\n")

cat("\n=== AUDIT COMPLETE ===\n")
