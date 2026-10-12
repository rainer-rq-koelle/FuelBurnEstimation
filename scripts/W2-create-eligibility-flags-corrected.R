#!/usr/bin/env Rscript
# W2 — Create Phase-Specific Eligibility Flags (CORRECTED)
# Fixed: Airborne eligibility requires ALL THREE phases present AND eligible

library(arrow)
library(dplyr)
library(readr)

cat("Creating CHN phase-specific eligibility flags (corrected)...\n")

# Load data
milestones <- read_parquet("data-store/processed/chn/CHN-canonical-milestones-summer2025.parquet")
phase_summaries <- read_parquet("data-store/processed/chn/CHN-phase-summaries-summer2025.parquet")

# Identify flights with key milestones
milestone_presence <- milestones %>%
  mutate(
    has_ATOT = MST == "ATOT",
    has_TOC = MST == "TOC",
    has_TOD = MST == "TOD",
    has_ALDT = MST == "ALDT"
  ) %>%
  group_by(SOURCE_UID) %>%
  summarise(
    ATOT_present = any(has_ATOT),
    TOC_present = any(has_TOC),
    TOD_present = any(has_TOD),
    ALDT_present = any(has_ALDT),
    .groups = "drop"
  )

# Create phase-level eligibility
phase_eligibility <- phase_summaries %>%
  rename(FUEL_BURNT_KG = FUEL_KG) %>%
  left_join(milestone_presence, by = "SOURCE_UID") %>%
  mutate(
    # Time eligibility: has valid non-zero duration
    time_eligible = !is.na(DURATION_MIN) & DURATION_MIN > 0 & is.finite(DURATION_MIN),

    # Fuel eligibility: has valid fuel burn
    fuel_eligible = !is.na(FUEL_BURNT_KG) & is.finite(FUEL_BURNT_KG),

    # Distance eligibility: INVALID per W2 findings (coordinate quality issues)
    distance_eligible = FALSE,
    distance_issue = "coordinate_quality_unknown_cause",

    # Phase-specific eligibility based on boundary milestones
    phase_boundary_eligible = case_when(
      # ALDT-independent phases
      PHASE %in% c("TAXI_OUT", "TAKE_OFF_ROLL", "LTO_CLIMB_OUT") ~ ATOT_present,
      PHASE == "CLIMB" ~ ATOT_present & TOC_present,
      PHASE == "CRUISE" ~ TOC_present & TOD_present,
      PHASE == "DESCENT" ~ TOD_present,

      # ALDT-dependent phases
      PHASE == "LTO_APPROACH_LANDING" ~ TOD_present & ALDT_present,
      PHASE == "RUNWAY_EXIT" ~ ALDT_present,
      PHASE == "TAXI_IN" ~ ALDT_present,

      TRUE ~ FALSE
    ),

    # Overall phase eligibility for time/fuel analyses
    phase_time_fuel_eligible = time_eligible & fuel_eligible & phase_boundary_eligible,

    # Flag ALDT dependency
    aldt_dependent = PHASE %in% c("LTO_APPROACH_LANDING", "RUNWAY_EXIT", "TAXI_IN")
  ) %>%
  select(
    SOURCE_UID, source_batch, TYPE, PHASE,
    DURATION_MIN, FUEL_BURNT_KG, DISTANCE_NM,
    time_eligible, fuel_eligible, distance_eligible, distance_issue,
    phase_boundary_eligible, aldt_dependent, phase_time_fuel_eligible,
    ATOT_present, TOC_present, TOD_present, ALDT_present
  )

# Summary by phase
phase_summary <- phase_eligibility %>%
  group_by(PHASE, aldt_dependent) %>%
  summarise(
    total_records = n(),
    time_fuel_eligible = sum(phase_time_fuel_eligible),
    pct_eligible = 100 * time_fuel_eligible / total_records,
    .groups = "drop"
  ) %>%
  arrange(PHASE)

cat("\nPhase-Level Eligibility:\n")
print(phase_summary, n = Inf)

# Flight-level: Check which flights have all three airborne phases present and eligible
flight_airborne_check <- phase_eligibility %>%
  filter(PHASE %in% c("CLIMB", "CRUISE", "DESCENT")) %>%
  group_by(SOURCE_UID) %>%
  summarise(
    has_climb = any(PHASE == "CLIMB"),
    has_cruise = any(PHASE == "CRUISE"),
    has_descent = any(PHASE == "DESCENT"),
    climb_eligible = any(PHASE == "CLIMB" & phase_time_fuel_eligible),
    cruise_eligible = any(PHASE == "CRUISE" & phase_time_fuel_eligible),
    descent_eligible = any(PHASE == "DESCENT" & phase_time_fuel_eligible),
    # CORRECTED: All three must be present AND eligible
    airborne_eligible = has_climb & has_cruise & has_descent &
                        climb_eligible & cruise_eligible & descent_eligible,
    .groups = "drop"
  )

# Flight-level summary
flight_eligibility <- phase_eligibility %>%
  select(SOURCE_UID, source_batch, TYPE, ALDT_present) %>%
  distinct() %>%
  left_join(flight_airborne_check, by = "SOURCE_UID") %>%
  mutate(
    # Fill NAs (flights without any airborne phases)
    across(starts_with("has_"), ~coalesce(., FALSE)),
    across(ends_with("_eligible"), ~coalesce(., FALSE))
  )

flight_summary <- flight_eligibility %>%
  summarise(
    total_flights = n(),
    has_climb = sum(has_climb),
    has_cruise = sum(has_cruise),
    has_descent = sum(has_descent),
    climb_eligible = sum(climb_eligible),
    cruise_eligible = sum(cruise_eligible),
    descent_eligible = sum(descent_eligible),
    airborne_eligible = sum(airborne_eligible),
    has_ALDT = sum(ALDT_present)
  )

cat("\nFlight-Level Summary:\n")
print(flight_summary)

# Speed calculation check (exclude zero duration)
speed_check <- phase_eligibility %>%
  filter(DURATION_MIN > 0, !is.na(DISTANCE_NM)) %>%
  mutate(
    implied_speed_kt = DISTANCE_NM / (DURATION_MIN / 60)
  ) %>%
  summarise(
    total_phase_records = n(),
    extreme_speed_over_700kt = sum(implied_speed_kt > 700, na.rm = TRUE),
    pct_extreme = 100 * extreme_speed_over_700kt / total_phase_records
  )

cat("\nSpeed Check (excluding zero-duration records):\n")
cat(sprintf("  Numerator (>700kt): %d\n", speed_check$extreme_speed_over_700kt))
cat(sprintf("  Denominator (non-zero duration with distance): %d\n", speed_check$total_phase_records))
cat(sprintf("  Percentage: %.1f%%\n", speed_check$pct_extreme))

# Save outputs to local package (NOT to GitHub - these are flight-level)
output_dir <- "notes/results/W2/W2-2026-10-09-001/local-package"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write_csv(phase_eligibility, file.path(output_dir, "phase-eligibility-flags.csv"))
write_csv(flight_eligibility, file.path(output_dir, "flight-eligibility-flags.csv"))

# Create aggregate summaries for GitHub
github_dir <- "notes/results/W2/W2-2026-10-09-001"
write_csv(phase_summary, file.path(github_dir, "phase-eligibility-summary-corrected.csv"))
write_csv(flight_summary, file.path(github_dir, "flight-eligibility-summary-corrected.csv"))
write_csv(speed_check, file.path(github_dir, "speed-calculation-check.csv"))

cat("\n✓ Eligibility flags created\n")
cat("\nFlight-level outputs (local package, NOT in GitHub):\n")
cat(sprintf("  %s/phase-eligibility-flags.csv (%d records)\n",
            output_dir, nrow(phase_eligibility)))
cat(sprintf("  %s/flight-eligibility-flags.csv (%d records)\n",
            output_dir, nrow(flight_eligibility)))
cat("\nAggregate summaries (for GitHub):\n")
cat(sprintf("  %s/phase-eligibility-summary-corrected.csv\n", github_dir))
cat(sprintf("  %s/flight-eligibility-summary-corrected.csv\n", github_dir))
cat(sprintf("  %s/speed-calculation-check.csv\n", github_dir))
