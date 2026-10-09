#!/usr/bin/env Rscript
# W2 — CHN Distance, Boundaries, and Fuel Validation
# Run ID: W2-2026-10-09-001
# Worker: Claude Sonnet 4.5
# Objective: Systematically validate CHN QAR data for distance/time consistency,
#            missing ALDT, boundary quality, and fuel integration

library(arrow)
library(dplyr)
library(readr)

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  W2 — CHN Data Validation                                    ║\n")
cat("║  Run ID: W2-2026-10-09-001                                   ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

# Output directory
output_dir <- "notes/results/W2/W2-2026-10-09-001"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# Step 1: Load CHN data
# ============================================================================

cat("\n=== Step 1: Loading CHN Data ===\n")

milestones <- read_parquet("data-store/processed/chn/CHN-canonical-milestones-summer2025.parquet")
level_segments <- read_parquet("data-store/processed/chn/CHN-level-segments-summer2025.parquet")
phase_summaries <- read_parquet("data-store/processed/chn/CHN-phase-summaries-summer2025.parquet")

cat(sprintf("✓ Milestones: %s rows, %s flights\n",
            format(nrow(milestones), big.mark = ","),
            format(n_distinct(milestones$SOURCE_UID), big.mark = ",")))
cat(sprintf("✓ Level segments: %s rows\n", format(nrow(level_segments), big.mark = ",")))
cat(sprintf("✓ Phase summaries: %s rows\n", format(nrow(phase_summaries), big.mark = ",")))

# Rename columns for consistency
phase_summaries <- phase_summaries %>%
  rename(FUEL_BURNT_KG = FUEL_KG)

# ============================================================================
# Step 2: Investigate Missing ALDT by Batch/Type/Route
# ============================================================================

cat("\n=== Step 2: Missing ALDT Investigation ===\n")

aldt_analysis <- milestones %>%
  mutate(
    ATOT = if_else(MST == "ATOT", TIME, as.POSIXct(NA)),
    TOC = if_else(MST == "TOC", TIME, as.POSIXct(NA)),
    TOD = if_else(MST == "TOD", TIME, as.POSIXct(NA)),
    ALDT = if_else(MST == "ALDT", TIME, as.POSIXct(NA))
  ) %>%
  group_by(SOURCE_UID) %>%
  summarise(
    source_batch = first(source_batch),
    TYPE = first(TYPE),
    ADEP = first(ADEP),
    ADES = first(ADES),
    ROUTE = paste(first(ADEP), first(ADES), sep = "-"),
    ATOT = first(ATOT[!is.na(ATOT)]),
    TOC = first(TOC[!is.na(TOC)]),
    TOD = first(TOD[!is.na(TOD)]),
    ALDT = first(ALDT[!is.na(ALDT)]),
    has_ATOT = !is.na(first(ATOT[!is.na(ATOT)])),
    has_TOC = !is.na(first(TOC[!is.na(TOC)])),
    has_TOD = !is.na(first(TOD[!is.na(TOD)])),
    has_ALDT = !is.na(first(ALDT[!is.na(ALDT)])),
    .groups = "drop"
  )

missing_aldt_summary <- aldt_analysis %>%
  group_by(source_batch) %>%
  summarise(
    flights = n(),
    missing_ALDT = sum(!has_ALDT),
    missing_ALDT_pct = 100 * missing_ALDT / flights,
    missing_ATOT = sum(!has_ATOT),
    missing_TOC = sum(!has_TOC),
    missing_TOD = sum(!has_TOD),
    .groups = "drop"
  )

cat("\nMissing ALDT by Batch:\n")
print(missing_aldt_summary)

write_csv(missing_aldt_summary, file.path(output_dir, "missing-aldt-by-batch.csv"))

# By aircraft type
missing_aldt_by_type <- aldt_analysis %>%
  group_by(TYPE) %>%
  summarise(
    flights = n(),
    missing_ALDT = sum(!has_ALDT),
    missing_ALDT_pct = 100 * missing_ALDT / flights,
    .groups = "drop"
  ) %>%
  arrange(desc(missing_ALDT))

cat("\nMissing ALDT by Aircraft Type (top 10):\n")
print(head(missing_aldt_by_type, 10))

write_csv(missing_aldt_by_type, file.path(output_dir, "missing-aldt-by-type.csv"))

# By route
missing_aldt_by_route <- aldt_analysis %>%
  group_by(ROUTE) %>%
  summarise(
    flights = n(),
    missing_ALDT = sum(!has_ALDT),
    missing_ALDT_pct = 100 * missing_ALDT / flights,
    .groups = "drop"
  ) %>%
  filter(flights >= 10) %>%
  arrange(desc(missing_ALDT))

cat("\nMissing ALDT by Route (routes with ≥10 flights, top 10):\n")
print(head(missing_aldt_by_route, 10))

write_csv(missing_aldt_by_route, file.path(output_dir, "missing-aldt-by-route.csv"))

# Missing ALDT examples for review
missing_aldt_examples <- aldt_analysis %>%
  filter(!has_ALDT) %>%
  select(SOURCE_UID, source_batch, TYPE, ROUTE, has_ATOT, has_TOC, has_TOD) %>%
  head(50)

write_csv(missing_aldt_examples, file.path(output_dir, "missing-aldt-examples.csv"))

cat(sprintf("\n✓ Total flights missing ALDT: %d (%.1f%%)\n",
            sum(!aldt_analysis$has_ALDT),
            100 * sum(!aldt_analysis$has_ALDT) / nrow(aldt_analysis)))

# ============================================================================
# Step 3: Distance/Time/Speed Reconciliation
# ============================================================================

cat("\n=== Step 3: Distance/Time/Speed Reconciliation ===\n")

# Calculate implied speeds from phase summaries
speed_analysis <- phase_summaries %>%
  filter(!is.na(DISTANCE_NM), !is.na(DURATION_MIN)) %>%
  mutate(
    DURATION_HR = DURATION_MIN / 60,
    IMPLIED_SPEED_KT = if_else(DURATION_HR > 0, DISTANCE_NM / DURATION_HR, NA_real_),
    speed_flag = case_when(
      is.na(IMPLIED_SPEED_KT) ~ "missing_data",
      IMPLIED_SPEED_KT > 700 ~ "extreme_high",
      IMPLIED_SPEED_KT > 500 ~ "high",
      IMPLIED_SPEED_KT < 100 ~ "low",
      TRUE ~ "normal"
    )
  )

speed_summary <- speed_analysis %>%
  group_by(PHASE, speed_flag) %>%
  summarise(
    records = n(),
    median_speed = median(IMPLIED_SPEED_KT, na.rm = TRUE),
    mean_speed = mean(IMPLIED_SPEED_KT, na.rm = TRUE),
    p95_speed = quantile(IMPLIED_SPEED_KT, 0.95, na.rm = TRUE),
    median_distance = median(DISTANCE_NM, na.rm = TRUE),
    median_duration_min = median(DURATION_MIN, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(PHASE, desc(records))

cat("\nSpeed Distribution by Phase and Flag:\n")
print(speed_summary)

write_csv(speed_summary, file.path(output_dir, "speed-summary-by-phase.csv"))

# Extreme speed examples
extreme_speed_examples <- speed_analysis %>%
  filter(speed_flag == "extreme_high") %>%
  select(SOURCE_UID, source_batch, TYPE, PHASE,
         DISTANCE_NM, DURATION_MIN, IMPLIED_SPEED_KT) %>%
  arrange(desc(IMPLIED_SPEED_KT)) %>%
  head(100)

write_csv(extreme_speed_examples, file.path(output_dir, "extreme-speed-examples.csv"))

cat(sprintf("\n✓ Phase records with speed >700 kt: %d (%.1f%%)\n",
            sum(speed_analysis$speed_flag == "extreme_high", na.rm = TRUE),
            100 * sum(speed_analysis$speed_flag == "extreme_high", na.rm = TRUE) / nrow(speed_analysis)))

# Analyze by batch to check for systematic issues
speed_by_batch <- speed_analysis %>%
  group_by(source_batch, PHASE) %>%
  summarise(
    records = n(),
    extreme_high = sum(speed_flag == "extreme_high", na.rm = TRUE),
    extreme_high_pct = 100 * extreme_high / records,
    median_speed = median(IMPLIED_SPEED_KT, na.rm = TRUE),
    p95_speed = quantile(IMPLIED_SPEED_KT, 0.95, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(source_batch, PHASE)

cat("\nSpeed Issues by Batch and Phase:\n")
print(speed_by_batch)

write_csv(speed_by_batch, file.path(output_dir, "speed-by-batch-phase.csv"))

# ============================================================================
# Step 4: Level Segment Distance/Time Consistency
# ============================================================================

cat("\n=== Step 4: Level Segment Distance/Time Consistency ===\n")

level_speed_analysis <- level_segments %>%
  mutate(DURATION_MIN = DURATION_SEC / 60) %>%
  filter(!is.na(DISTANCE_NM), !is.na(DURATION_MIN)) %>%
  mutate(
    DURATION_HR = DURATION_MIN / 60,
    IMPLIED_SPEED_KT = if_else(DURATION_HR > 0, DISTANCE_NM / DURATION_HR, NA_real_),
    speed_flag = case_when(
      is.na(IMPLIED_SPEED_KT) ~ "missing_data",
      IMPLIED_SPEED_KT > 700 ~ "extreme_high",
      IMPLIED_SPEED_KT > 500 ~ "high",
      IMPLIED_SPEED_KT < 100 ~ "low",
      TRUE ~ "normal"
    )
  )

level_speed_summary <- level_speed_analysis %>%
  group_by(speed_flag) %>%
  summarise(
    segments = n(),
    median_speed = median(IMPLIED_SPEED_KT, na.rm = TRUE),
    p95_speed = quantile(IMPLIED_SPEED_KT, 0.95, na.rm = TRUE),
    median_distance = median(DISTANCE_NM, na.rm = TRUE),
    median_duration = median(DURATION_MIN, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nLevel Segment Speed Distribution:\n")
print(level_speed_summary)

write_csv(level_speed_summary, file.path(output_dir, "level-segment-speed-summary.csv"))

cat(sprintf("\n✓ Level segments with speed >700 kt: %d (%.1f%%)\n",
            sum(level_speed_analysis$speed_flag == "extreme_high", na.rm = TRUE),
            100 * sum(level_speed_analysis$speed_flag == "extreme_high", na.rm = TRUE) / nrow(level_speed_analysis)))

# Extreme level segment examples
extreme_level_examples <- level_speed_analysis %>%
  filter(speed_flag == "extreme_high") %>%
  select(SOURCE_UID, source_batch, START_TIME, END_TIME,
         DISTANCE_NM, DURATION_MIN, IMPLIED_SPEED_KT) %>%
  arrange(desc(IMPLIED_SPEED_KT)) %>%
  head(100)

write_csv(extreme_level_examples, file.path(output_dir, "extreme-level-segment-examples.csv"))

# ============================================================================
# Step 5: Fuel Integration Validation
# ============================================================================

cat("\n=== Step 5: Fuel Integration Validation ===\n")

# Check fuel consistency across phases
fuel_validation <- phase_summaries %>%
  group_by(SOURCE_UID) %>%
  summarise(
    source_batch = first(source_batch),
    TYPE = first(TYPE),
    phases_present = n(),
    total_phase_fuel = sum(FUEL_BURNT_KG, na.rm = TRUE),
    total_phase_time = sum(DURATION_MIN, na.rm = TRUE),
    total_phase_distance = sum(DISTANCE_NM, na.rm = TRUE),
    has_taxi_out = any(PHASE == "TAXI_OUT"),
    has_climb = any(PHASE == "CLIMB"),
    has_cruise = any(PHASE == "CRUISE"),
    has_descent = any(PHASE == "DESCENT"),
    has_taxi_in = any(PHASE == "TAXI_IN"),
    .groups = "drop"
  )

# Calculate airborne fuel (climb + cruise + descent)
airborne_fuel <- phase_summaries %>%
  filter(PHASE %in% c("CLIMB", "CRUISE", "DESCENT")) %>%
  group_by(SOURCE_UID) %>%
  summarise(
    airborne_fuel_kg = sum(FUEL_BURNT_KG, na.rm = TRUE),
    airborne_time_min = sum(DURATION_MIN, na.rm = TRUE),
    airborne_distance_nm = sum(DISTANCE_NM, na.rm = TRUE),
    .groups = "drop"
  )

fuel_validation <- fuel_validation %>%
  left_join(airborne_fuel, by = "SOURCE_UID") %>%
  mutate(
    airborne_fuel_kg = coalesce(airborne_fuel_kg, 0),
    airborne_time_min = coalesce(airborne_time_min, 0),
    airborne_distance_nm = coalesce(airborne_distance_nm, 0),
    airborne_burn_rate_kgph = if_else(airborne_time_min > 0,
                                       airborne_fuel_kg / (airborne_time_min / 60),
                                       NA_real_),
    airborne_burn_per_nm = if_else(airborne_distance_nm > 0,
                                    airborne_fuel_kg / airborne_distance_nm,
                                    NA_real_)
  )

# Summarize by aircraft type
fuel_by_type <- fuel_validation %>%
  group_by(TYPE) %>%
  summarise(
    flights = n(),
    median_airborne_fuel_kg = median(airborne_fuel_kg, na.rm = TRUE),
    median_burn_rate_kgph = median(airborne_burn_rate_kgph, na.rm = TRUE),
    median_burn_per_nm = median(airborne_burn_per_nm, na.rm = TRUE),
    p25_burn_per_nm = quantile(airborne_burn_per_nm, 0.25, na.rm = TRUE),
    p75_burn_per_nm = quantile(airborne_burn_per_nm, 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(flights >= 10) %>%
  arrange(desc(flights))

cat("\nAirborne Fuel by Aircraft Type (types with ≥10 flights):\n")
print(fuel_by_type)

write_csv(fuel_by_type, file.path(output_dir, "fuel-by-aircraft-type.csv"))

# Identify outliers
fuel_outliers <- fuel_validation %>%
  filter(
    !is.na(airborne_burn_rate_kgph) &
    (airborne_burn_rate_kgph < 500 | airborne_burn_rate_kgph > 15000)
  ) %>%
  select(SOURCE_UID, TYPE, airborne_fuel_kg,
         airborne_time_min, airborne_burn_rate_kgph) %>%
  arrange(desc(abs(airborne_burn_rate_kgph - 3000)))

cat(sprintf("\n✓ Flights with extreme burn rates (<500 or >15000 kg/h): %d\n", nrow(fuel_outliers)))

write_csv(fuel_outliers, file.path(output_dir, "fuel-outliers.csv"))

# ============================================================================
# Step 6: Boundary Quality Assessment
# ============================================================================

cat("\n=== Step 6: Boundary Quality Assessment ===\n")

# Check for ordered boundaries
boundary_check <- phase_summaries %>%
  select(SOURCE_UID, source_batch, PHASE, START_TIME, END_TIME,
         START_ALT_FT, END_ALT_FT) %>%
  group_by(SOURCE_UID) %>%
  mutate(
    duration_sec = as.numeric(difftime(END_TIME, START_TIME, units = "secs")),
    is_ordered = START_TIME < END_TIME,
    has_negative_duration = duration_sec < 0,
    altitude_change = abs(END_ALT_FT - START_ALT_FT)
  ) %>%
  ungroup()

boundary_issues <- boundary_check %>%
  summarise(
    total_phase_records = n(),
    negative_duration = sum(has_negative_duration, na.rm = TRUE),
    not_ordered = sum(!is_ordered, na.rm = TRUE),
    missing_start_time = sum(is.na(START_TIME)),
    missing_end_time = sum(is.na(END_TIME))
  )

cat("\nBoundary Quality:\n")
print(boundary_issues)

write_csv(boundary_issues, file.path(output_dir, "boundary-quality-summary.csv"))

# Altitude consistency for level segments
level_altitude_check <- level_segments %>%
  mutate(
    altitude_change_ft = abs(END_ALT_FT - START_ALT_FT),
    altitude_change_flag = case_when(
      is.na(altitude_change_ft) ~ "missing",
      altitude_change_ft > 1000 ~ "large_change",
      altitude_change_ft > 500 ~ "moderate_change",
      TRUE ~ "stable"
    )
  ) %>%
  group_by(altitude_change_flag) %>%
  summarise(
    segments = n(),
    median_change_ft = median(altitude_change_ft, na.rm = TRUE),
    .groups = "drop"
  )

cat("\nLevel Segment Altitude Stability:\n")
print(level_altitude_check)

write_csv(level_altitude_check, file.path(output_dir, "level-altitude-stability.csv"))

# ============================================================================
# Step 7: Batch-Level Exception Report
# ============================================================================

cat("\n=== Step 7: Batch-Level Exception Report ===\n")

batch_report <- milestones %>%
  group_by(source_batch) %>%
  summarise(
    flights = n_distinct(SOURCE_UID),
    milestone_records = n()
  ) %>%
  left_join(
    missing_aldt_summary %>% select(source_batch, missing_ALDT, missing_ALDT_pct),
    by = "source_batch"
  ) %>%
  left_join(
    speed_by_batch %>%
      filter(PHASE == "CRUISE") %>%
      select(source_batch, cruise_median_speed = median_speed,
             cruise_extreme_pct = extreme_high_pct),
    by = "source_batch"
  )

cat("\nBatch-Level Summary:\n")
print(batch_report)

write_csv(batch_report, file.path(output_dir, "batch-exception-report.csv"))

# ============================================================================
# Step 8: Overall Summary Statistics
# ============================================================================

cat("\n=== Step 8: Overall Summary Statistics ===\n")

overall_summary <- tibble(
  metric = c(
    "Total flights",
    "Total milestone records",
    "Total phase records",
    "Total level segments",
    "Flights missing ALDT",
    "Flights missing ALDT (%)",
    "Phase records with speed >700kt",
    "Phase records with speed >700kt (%)",
    "Level segments with speed >700kt",
    "Level segments with speed >700kt (%)",
    "Median cruise speed (kt)",
    "Median climb+cruise+descent fuel (kg)",
    "Median airborne burn rate (kg/h)"
  ),
  value = c(
    n_distinct(milestones$SOURCE_UID),
    nrow(milestones),
    nrow(phase_summaries),
    nrow(level_segments),
    sum(!aldt_analysis$has_ALDT),
    100 * sum(!aldt_analysis$has_ALDT) / nrow(aldt_analysis),
    sum(speed_analysis$speed_flag == "extreme_high", na.rm = TRUE),
    100 * sum(speed_analysis$speed_flag == "extreme_high", na.rm = TRUE) / nrow(speed_analysis),
    sum(level_speed_analysis$speed_flag == "extreme_high", na.rm = TRUE),
    100 * sum(level_speed_analysis$speed_flag == "extreme_high", na.rm = TRUE) / nrow(level_speed_analysis),
    median(speed_analysis$IMPLIED_SPEED_KT[speed_analysis$PHASE == "CRUISE"], na.rm = TRUE),
    median(fuel_validation$airborne_fuel_kg, na.rm = TRUE),
    median(fuel_validation$airborne_burn_rate_kgph, na.rm = TRUE)
  )
)

cat("\nOverall Summary:\n")
print(overall_summary)

write_csv(overall_summary, file.path(output_dir, "overall-summary.csv"))

# ============================================================================
# Summary
# ============================================================================

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║  W2 VALIDATION COMPLETE                                      ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n")

cat("\nDiagnostic outputs saved to:", output_dir, "\n")
cat("\nFiles created:\n")
list.files(output_dir, pattern = "\\.csv$") %>% walk(~cat("  ✓", .x, "\n"))

cat("\nNext step: Review diagnostics and determine corrective actions\n")
