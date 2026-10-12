#!/usr/bin/env Rscript
# Build a versioned EUR parallel-preprocessing candidate from raw PRU G2G,
# accepted PRU CCO/CDO intervals, and M3 callsign metadata.
# Flight-level outputs are written only to the ignored local data store and
# uploaded to the restricted R2 candidate prefix when --upload is supplied.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(tibble)
})

args <- commandArgs(trailingOnly = TRUE)
do_upload <- "--upload" %in% args
run_id <- "EUR-2026-10-12-001"
repo_root <- normalizePath(".", mustWork = TRUE)
input_dir <- file.path(repo_root, ".fuelburn-data-store/raw/eur/source-sample")
output_dir <- file.path(repo_root, ".fuelburn-data-store/derived/eur/parallel-preprocessing", run_id)
evidence_dir <- file.path(repo_root, "notes/results/EUR", run_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)

required_files <- c(
  "g2g-flight-metadata-2025-summer.parquet",
  "g2g-segment-details-2025-summer.parquet"
)
missing <- required_files[!file.exists(file.path(input_dir, required_files))]
if (length(missing)) stop("Missing input files: ", paste(missing, collapse = ", "))

message("Reading original G2G flight and segment source...")
meta <- read_parquet(file.path(input_dir, required_files[[1]])) |>
  mutate(SAM_ID = as.character(SAM_ID))
g2g <- read_parquet(file.path(input_dir, required_files[[2]])) |>
  mutate(SAM_ID = as.character(SAM_ID))

# The R2 source-sample includes both operationally adjusted and original fuel
# fields. Cross-check them against the local extraction companion when present.
fuel_companion_path <- file.path(repo_root, ".fuelburn-data-store/raw/eur/g2g-segment-details-2025-summer-FIXED.parquet")
if (!all(c("FUEL_BURNT_KG", "FUEL_BURNT_KG_ORIGINAL") %in% names(g2g))) {
  stop("R2 G2G source lacks the paired adjusted/original fuel fields.")
}
fuel_lineage <- tibble(source_rows = nrow(g2g), original_field_present = TRUE,
                       companion_check = "not_available", adjusted_mismatch_rows = NA_integer_,
                       original_mismatch_rows = NA_integer_)
if (file.exists(fuel_companion_path)) {
  fuel_companion <- read_parquet(fuel_companion_path) |>
    mutate(SAM_ID = as.character(SAM_ID)) |>
    select(SAM_ID, TIME_OVER, FLIGHT_PHASE, MILESTONE,
           COMPANION_ADJUSTED = FUEL_BURNT_KG,
           COMPANION_ORIGINAL = FUEL_BURNT_KG_ORIGINAL)
  fuel_check <- g2g |>
    select(SAM_ID, TIME_OVER, FLIGHT_PHASE, MILESTONE,
           R2_ADJUSTED = FUEL_BURNT_KG, R2_ORIGINAL = FUEL_BURNT_KG_ORIGINAL) |>
    inner_join(fuel_companion, by = c("SAM_ID", "TIME_OVER", "FLIGHT_PHASE", "MILESTONE"))
  if (nrow(fuel_check) != nrow(g2g)) stop("Fuel lineage companion has unmatched or duplicate G2G rows.")
  fuel_lineage <- tibble(
    source_rows = nrow(g2g), original_field_present = TRUE, companion_check = "matched",
    adjusted_mismatch_rows = sum(abs(fuel_check$R2_ADJUSTED - fuel_check$COMPANION_ADJUSTED) > 1e-8),
    original_mismatch_rows = sum(abs(fuel_check$R2_ORIGINAL - fuel_check$COMPANION_ORIGINAL) > 1e-8)
  )
  if (fuel_lineage$adjusted_mismatch_rows > 0 || fuel_lineage$original_mismatch_rows > 0) {
    stop("Fuel lineage mismatch: R2 source values differ from the local companion.")
  }
}

# Callsign is the agreed FLTID field. Map only when M3 has one non-empty
# callsign for the same internal flight identifier (FLIGHT_ID == SAM_ID).
m3_files <- sort(list.files(input_dir, pattern = "^m3-ctfm-2025-0[678]\\.parquet$", full.names = TRUE))
if (!length(m3_files)) stop("No M3 trajectory files found in ", input_dir)
m3_map <- map_dfr(m3_files, function(path) {
  read_parquet(path, col_select = c(FLIGHT_ID, CALLSIGN, ADEP, ADES, AIRCRAFT_TYPE)) |>
    transmute(
      SOURCE_UID = as.character(FLIGHT_ID),
      FLTID = str_trim(as.character(CALLSIGN)),
      M3_ADEP = as.character(ADEP), M3_ADES = as.character(ADES),
      M3_TYPE = as.character(AIRCRAFT_TYPE)
    )
}) |>
  filter(!is.na(FLTID), FLTID != "") |>
  group_by(SOURCE_UID) |>
  summarise(
    n_callsigns = n_distinct(FLTID),
    FLTID = if (n_callsigns == 1L) first(FLTID) else NA_character_,
    M3_ADEP = if (n_distinct(M3_ADEP) == 1L) first(M3_ADEP) else NA_character_,
    M3_ADES = if (n_distinct(M3_ADES) == 1L) first(M3_ADES) else NA_character_,
    M3_TYPE = if (n_distinct(M3_TYPE) == 1L) first(M3_TYPE) else NA_character_,
    .groups = "drop"
  )

meta <- meta |>
  left_join(m3_map, by = c("SAM_ID" = "SOURCE_UID")) |>
  mutate(
    SOURCE_UID = SAM_ID,
    FLTID = if_else(n_callsigns == 1L, FLTID, NA_character_),
    TYPE = as.character(AIRCRAFT_TYPE),
    source_batch = "PRU_G2G_2025SUMMER"
  )

metadata_consistency <- meta |>
  summarise(
    study_flights = n_distinct(SOURCE_UID),
    matched_unique_fltid = sum(!is.na(FLTID)),
    missing_or_ambiguous_fltid = sum(is.na(FLTID)),
    route_disagreement = sum((!is.na(M3_ADEP) & M3_ADEP != ADEP) | (!is.na(M3_ADES) & M3_ADES != ADES)),
    aircraft_disagreement = sum(!is.na(M3_TYPE) & M3_TYPE != TYPE)
  )

# G2G fuel and distance fields are per-row increments. Preserve the two fuel
# series as delivered; do not apply the operational take-off adjustment again.
profile <- g2g |>
  left_join(meta |> select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, source_batch),
            by = c("SAM_ID" = "SOURCE_UID"), suffix = c("", ".meta")) |>
  arrange(SAM_ID, TIME_OVER, MILESTONE, FLIGHT_PHASE) |>
  group_by(SAM_ID) |>
  mutate(
    ROW_ID = row_number(),
    TIME = as.POSIXct(TIME_OVER, tz = "UTC"),
    ALT_FT = as.numeric(ALTITUDE_FT),
    RAW_FUEL_INCREMENT_KG = as.numeric(FUEL_BURNT_KG_ORIGINAL),
    ADJUSTED_FUEL_INCREMENT_KG = as.numeric(FUEL_BURNT_KG),
    TOT_FUEL_KG_ORIGINAL = cumsum(replace_na(RAW_FUEL_INCREMENT_KG, 0)),
    TOT_FUEL_KG = cumsum(replace_na(ADJUSTED_FUEL_INCREMENT_KG, 0)),
    DIST_FLOWN_NM = cumsum(replace_na(as.numeric(DISTANCE_NM), 0))
  ) |>
  ungroup() |>
  mutate(
    SOURCE_UID = as.character(SAM_ID),
    FLTID = as.character(FLTID),
    LAT = as.numeric(LAT), LON = as.numeric(LON),
    FLIGHT_PHASE_RAW = as.character(FLIGHT_PHASE)
  )

flight_end <- profile |>
  group_by(SOURCE_UID) |>
  summarise(TOTAL_FLOWN_NM = max(DIST_FLOWN_NM, na.rm = TRUE), .groups = "drop")
profile <- profile |> left_join(flight_end, by = "SOURCE_UID") |>
  mutate(DIST_REMAINING_NM = pmax(0, TOTAL_FLOWN_NM - DIST_FLOWN_NM))

first_row <- function(test, rows) {
  idx <- which(!is.na(test) & test)
  if (!length(idx)) NA_integer_ else rows[[idx[[1]]]]
}
last_row <- function(test, rows) {
  idx <- which(!is.na(test) & test)
  if (!length(idx)) NA_integer_ else rows[[idx[[length(idx)]]]]
}
contains_mst <- function(x, label) str_detect(coalesce(x, ""), paste0("(^|/)", label, "($|/)"))

message("Deriving shared canonical milestone families...")
event_rows <- profile |>
  group_by(SOURCE_UID) |>
  group_modify(function(x, key) {
    rows <- x$ROW_ID
    phases <- x$FLIGHT_PHASE_RAW
    times <- x$TIME
    alt <- x$ALT_FT
    dist <- x$DIST_FLOWN_NM
    remaining <- x$DIST_REMAINING_NM
    milestone <- x$MILESTONE
    atot <- first_row(phases == "Take-Off", rows)
    toc <- first_row(contains_mst(milestone, "TOC"), rows)
    tod <- first_row(contains_mst(milestone, "TOD"), rows)
    aldt <- first_row(phases %in% c("Approach", "Landing") & alt == 0, rows)
    taxi_in <- first_row(phases == "Taxi-In", rows)
    # Use the canonical deterministic rules from the shared model. Source
    # generic FL100 and FIR/AUA tokens are deliberately not emitted.
    specs <- tribble(
      ~MST, ~ROW_ID, ~MST_GROUP, ~MST_METHOD,
      "AOBT", rows[[1]], "operational_profile", "derived_pru_g2g_phase",
      "ERWY", last_row(phases == "Taxi-Out", rows), "operational_profile", "derived_pru_g2g_phase",
      "ATOT", atot, "operational_profile", "derived_pru_g2g_phase",
      "DLTO", first_row(alt >= 3000 & rows > coalesce(atot, 0L), rows), "operational_profile", "derived_pru_g2g_phase",
      "TOC", toc, "cruise_bounds", "explicit_pru_g2g_milestone",
      "TOD", tod, "cruise_bounds", "explicit_pru_g2g_milestone",
      "ALTO", first_row(alt <= 3000 & rows > coalesce(tod, 0L), rows), "operational_profile", "derived_pru_g2g_phase",
      "ALDT", aldt, "operational_profile", "derived_pru_g2g_phase",
      "XRWY", if (is.na(taxi_in)) last_row(phases == "Landing", rows) else max(1L, taxi_in - 1L), "operational_profile", "derived_pru_g2g_phase",
      "AIBT", rows[[length(rows)]], "operational_profile", "derived_pru_g2g_phase"
    )
    distance_specs <- tribble(
      ~MST, ~idx, ~MST_GROUP, ~MST_METHOD,
      "D040", first_row(dist >= 40 & rows >= coalesce(atot, 1L), rows), "distance_anchor", "derived_along_track_distance",
      "D100", first_row(dist >= 100 & rows >= coalesce(atot, 1L), rows), "distance_anchor", "derived_along_track_distance",
      "D200", first_row(dist >= 200 & rows >= coalesce(atot, 1L), rows), "distance_anchor", "derived_along_track_distance",
      "A200", first_row(remaining <= 200 & rows >= coalesce(tod, 1L), rows), "distance_anchor", "derived_along_track_distance",
      "A100", first_row(remaining <= 100 & rows >= coalesce(tod, 1L), rows), "distance_anchor", "derived_along_track_distance",
      "A040", first_row(remaining <= 40 & rows >= coalesce(tod, 1L), rows), "distance_anchor", "derived_along_track_distance"
    ) |>
      transmute(MST, ROW_ID = idx, MST_GROUP, MST_METHOD)
    altitude_specs <- tribble(
      ~MST, ~threshold, ~direction, ~phase_start,
      "D_FL075", 7500, "up", "ATOT", "D_FL100", 10000, "up", "ATOT", "D_FL180", 18000, "up", "ATOT",
      "A_FL180", 18000, "down", "TOD", "A_FL100", 10000, "down", "TOD", "A_FL075", 7500, "down", "TOD"
    ) |>
      rowwise() |>
      mutate(ROW_ID = {
        start <- if (phase_start == "ATOT") coalesce(atot, 1L) else coalesce(tod, 1L)
        eligible <- rows >= start
        if (direction == "up") first_row(eligible & alt >= threshold, rows) else first_row(eligible & alt <= threshold, rows)
      }, MST_GROUP = "flight_level_anchor", MST_METHOD = "derived_pressure_altitude_crossing") |>
      ungroup() |>
      select(MST, ROW_ID, MST_GROUP, MST_METHOD)
    bind_rows(specs, distance_specs, altitude_specs) |>
      filter(!is.na(ROW_ID))
  }) |>
  ungroup()

make_milestone_snapshot <- function(events, source_rows = profile) {
  events |>
    left_join(source_rows, by = c("SOURCE_UID", "ROW_ID")) |>
    transmute(
      SOURCE_UID, FLTID, ADEP, ADES, TYPE, TIME, LAT, LON, ALT_FT,
      MST, MST_GROUP, MST_METHOD, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL,
      DIST_FLOWN_NM, TOTAL_FLOWN_NM, DIST_REMAINING_NM,
      DIST_FROM_DEP_NM = DIST_FLOWN_NM, DIST_TO_ARR_NM = DIST_REMAINING_NM,
      FLIGHT_PHASE_RAW, LEVEL_SEGMENT_ID = NA_character_,
      LEVEL_DURATION_SEC = NA_real_, LEVEL_DISTANCE_NM = NA_real_, LEVEL_FUEL_KG = NA_real_,
      LEVEL_CONTEXT_PHASE = NA_character_, ROW_ID = as.integer(ROW_ID), source_batch
    )
}
milestones <- make_milestone_snapshot(event_rows)

# Only PRU-accepted intervals are used. Rejected detector rows remain represented
# in aggregate counts and are not silently promoted to candidate level segments.
message("Reading accepted PRU CCO/CDO interval rows...")
lvl_files <- sort(list.files(input_dir, pattern = "^lvl_(cco|cdo)-2025-0[678]\\.parquet$", full.names = TRUE))
if (!length(lvl_files)) stop("No PRU CCO/CDO interval files found in ", input_dir)
accepted <- map_dfr(lvl_files, function(path) {
  context <- if (str_detect(basename(path), "^lvl_cco")) "CLIMB" else "DESCENT"
  open_dataset(path, format = "parquet") |>
    filter(CONSIDERED == 1) |>
    select(SAM_ID, TIME_START, TIME_END, LON_START, LAT_START, ALT_START,
           LON_END, LAT_END, ALT_END, DIST_LEVEL_NM,
           TIME_LEVEL_SECONDS, Add_fuel_kg, Add_CO2_kg, METHOD, CONSIDERED,
           EXCL_BOX, TOO_LOW, TOO_SHORT, nbr) |>
    collect() |>
    mutate(SOURCE_UID = as.character(SAM_ID), LEVEL_CONTEXT_PHASE = context,
           source_file = basename(path))
})

accepted <- accepted |>
  filter(!is.na(TIME_START), !is.na(TIME_END), TIME_END > TIME_START,
         !is.na(TIME_LEVEL_SECONDS), TIME_LEVEL_SECONDS > 0) |>
  distinct(SOURCE_UID, LEVEL_CONTEXT_PHASE, TIME_START, TIME_END, .keep_all = TRUE) |>
  inner_join(meta |> select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, source_batch), by = "SOURCE_UID") |>
  arrange(SOURCE_UID, TIME_START, TIME_END) |>
  group_by(SOURCE_UID) |>
  mutate(
    LEVEL_SEGMENT_ORDER = row_number(),
    LEVEL_SEGMENT_ID = sprintf("%s-LVL%03d", SOURCE_UID, LEVEL_SEGMENT_ORDER),
    START_TIME = as.POSIXct(TIME_START, tz = "UTC"),
    END_TIME = as.POSIXct(TIME_END, tz = "UTC"),
    DURATION_SEC = as.numeric(TIME_LEVEL_SECONDS)
  ) |>
  ungroup()

# Interpolate G2G cumulative values linearly to exact CCO/CDO boundary times.
# No extrapolation is allowed: absent source coverage yields NA and a quality flag.
interp <- function(target, times, values) {
  x <- as.numeric(times); y <- as.numeric(values); t <- as.numeric(target)
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]; y <- y[ok]
  if (!length(x) || !is.finite(t) || t < min(x) || t > max(x)) return(NA_real_)
  ord <- order(x); x <- x[ord]; y <- y[ord]
  if (anyDuplicated(x)) {
    z <- tibble(x = x, y = y) |> group_by(x) |> summarise(y = mean(y), .groups = "drop")
    x <- z$x; y <- z$y
  }
  approx(x, y, xout = t, rule = 1, ties = mean)$y[[1]]
}
nearest_row <- function(target, times, row_ids) {
  ok <- !is.na(times) & !is.na(row_ids)
  if (!any(ok)) return(NA_integer_)
  row_ids[which(ok)[which.min(abs(as.numeric(times[ok]) - as.numeric(target)))]]
}

message("Interpolating boundary totals and building shared tables...")
profile_groups <- split(profile, profile$SOURCE_UID)
unmatched_interval_count <- sum(!accepted$SOURCE_UID %in% names(profile_groups))
accepted <- accepted |> filter(SOURCE_UID %in% names(profile_groups))
boundary_values <- pmap_dfr(accepted |> select(SOURCE_UID, START_TIME, END_TIME), function(SOURCE_UID, START_TIME, END_TIME) {
  x <- profile_groups[[SOURCE_UID]]
  if (is.null(x)) return(tibble())
  tibble(
    START_ROW_ID = nearest_row(START_TIME, x$TIME, x$ROW_ID),
    END_ROW_ID = nearest_row(END_TIME, x$TIME, x$ROW_ID),
    START_FUEL_KG = interp(START_TIME, x$TIME, x$TOT_FUEL_KG),
    END_FUEL_KG = interp(END_TIME, x$TIME, x$TOT_FUEL_KG),
    START_FUEL_ORIGINAL_KG = interp(START_TIME, x$TIME, x$TOT_FUEL_KG_ORIGINAL),
    END_FUEL_ORIGINAL_KG = interp(END_TIME, x$TIME, x$TOT_FUEL_KG_ORIGINAL),
    START_DIST_FLOWN_NM = interp(START_TIME, x$TIME, x$DIST_FLOWN_NM),
    END_DIST_FLOWN_NM = interp(END_TIME, x$TIME, x$DIST_FLOWN_NM),
    G2G_COVERAGE_COMPLETE = START_TIME >= min(x$TIME, na.rm = TRUE) & END_TIME <= max(x$TIME, na.rm = TRUE)
  )
})
accepted <- bind_cols(accepted, boundary_values) |>
  mutate(
    G2G_LEVEL_FUEL_KG = END_FUEL_KG - START_FUEL_KG,
    G2G_LEVEL_FUEL_ORIGINAL_KG = END_FUEL_ORIGINAL_KG - START_FUEL_ORIGINAL_KG,
    G2G_LEVEL_DISTANCE_NM = END_DIST_FLOWN_NM - START_DIST_FLOWN_NM,
    LEVEL_START_ALT_FT = as.numeric(ALT_START), LEVEL_END_ALT_FT = as.numeric(ALT_END),
    LEVEL_ALTITUDE_BAND_FT = floor(((LEVEL_START_ALT_FT + LEVEL_END_ALT_FT) / 2) / 1000) * 1000,
    G2G_INTERVAL_VALID = G2G_COVERAGE_COMPLETE & is.finite(G2G_LEVEL_FUEL_KG) &
      is.finite(G2G_LEVEL_DISTANCE_NM) & G2G_LEVEL_FUEL_KG >= 0 & G2G_LEVEL_DISTANCE_NM >= 0
  )

level_segments <- accepted |>
  transmute(
    SOURCE_UID, FLTID, ADEP, ADES, TYPE, LEVEL_SEGMENT_ID, LEVEL_CONTEXT_PHASE,
    START_TIME, END_TIME, START_ROW_ID, END_ROW_ID,
    START_ALT_FT = LEVEL_START_ALT_FT, END_ALT_FT = LEVEL_END_ALT_FT,
    ALTITUDE_BAND_FT = LEVEL_ALTITUDE_BAND_FT,
    START_DIST_FLOWN_NM, END_DIST_FLOWN_NM,
    DISTANCE_NM = G2G_LEVEL_DISTANCE_NM,
    START_FUEL_KG, END_FUEL_KG, FUEL_KG = G2G_LEVEL_FUEL_KG,
    DURATION_SEC, source_batch
  )

level_extensions <- accepted |>
  transmute(
    SOURCE_UID, LEVEL_SEGMENT_ID, LEVEL_CONTEXT_PHASE,
    PRU_DIST_LEVEL_NM = as.numeric(DIST_LEVEL_NM),
    PRU_LON_START = as.numeric(LON_START), PRU_LAT_START = as.numeric(LAT_START),
    PRU_LON_END = as.numeric(LON_END), PRU_LAT_END = as.numeric(LAT_END),
    PRU_LEVEL_EXCESS_FUEL_KG = as.numeric(Add_fuel_kg),
    PRU_LEVEL_EXCESS_CO2_KG = as.numeric(Add_CO2_kg),
    PRU_METHOD = as.character(METHOD), PRU_CONSIDERED = as.integer(CONSIDERED),
    PRU_EXCL_BOX = as.integer(EXCL_BOX), PRU_TOO_LOW = as.integer(TOO_LOW), PRU_TOO_SHORT = as.integer(TOO_SHORT),
    source_file, source_nbr = as.integer(nbr),
    G2G_LEVEL_FUEL_KG, G2G_LEVEL_FUEL_ORIGINAL_KG, G2G_LEVEL_DISTANCE_NM,
    G2G_COVERAGE_COMPLETE, G2G_INTERVAL_VALID
  )

boundary_events <- bind_rows(
  accepted |> transmute(SOURCE_UID, ROW_ID = START_ROW_ID, MST = "LVL_START", TIME = START_TIME,
                        LEVEL_SEGMENT_ID, LEVEL_DURATION_SEC = DURATION_SEC,
                        LEVEL_DISTANCE_NM = G2G_LEVEL_DISTANCE_NM, LEVEL_FUEL_KG = G2G_LEVEL_FUEL_KG,
                        LEVEL_CONTEXT_PHASE, START = TRUE),
  accepted |> transmute(SOURCE_UID, ROW_ID = END_ROW_ID, MST = "LVL_END", TIME = END_TIME,
                        LEVEL_SEGMENT_ID, LEVEL_DURATION_SEC = DURATION_SEC,
                        LEVEL_DISTANCE_NM = G2G_LEVEL_DISTANCE_NM, LEVEL_FUEL_KG = G2G_LEVEL_FUEL_KG,
                        LEVEL_CONTEXT_PHASE, START = FALSE)
) |>
  left_join(accepted |> select(SOURCE_UID, LEVEL_SEGMENT_ID, START_TIME, END_TIME,
                               START_FUEL_KG, END_FUEL_KG, START_FUEL_ORIGINAL_KG, END_FUEL_ORIGINAL_KG,
                               START_DIST_FLOWN_NM, END_DIST_FLOWN_NM), by = c("SOURCE_UID", "LEVEL_SEGMENT_ID")) |>
  mutate(
    TIME = as.POSIXct(TIME, tz = "UTC"),
    TOT_FUEL_KG = if_else(START, START_FUEL_KG, END_FUEL_KG),
    TOT_FUEL_KG_ORIGINAL = if_else(START, START_FUEL_ORIGINAL_KG, END_FUEL_ORIGINAL_KG),
    DIST_FLOWN_NM = if_else(START, START_DIST_FLOWN_NM, END_DIST_FLOWN_NM),
    MST_GROUP = "level_segment", MST_METHOD = "explicit_pru_cco_cdo_v10_interval"
  ) |>
  left_join(profile |> select(SOURCE_UID, ROW_ID, TOTAL_FLOWN_NM, FLTID, ADEP, ADES, TYPE,
                              LAT, LON, ALT_FT, FLIGHT_PHASE_RAW, source_batch),
            by = c("SOURCE_UID", "ROW_ID"), suffix = c("", ".profile")) |>
  mutate(
    ALT_FT = if_else(MST == "LVL_START", accepted$LEVEL_START_ALT_FT[match(LEVEL_SEGMENT_ID, accepted$LEVEL_SEGMENT_ID)],
                     accepted$LEVEL_END_ALT_FT[match(LEVEL_SEGMENT_ID, accepted$LEVEL_SEGMENT_ID)]),
    LAT = if_else(START, accepted$LAT_START[match(LEVEL_SEGMENT_ID, accepted$LEVEL_SEGMENT_ID)],
                  accepted$LAT_END[match(LEVEL_SEGMENT_ID, accepted$LEVEL_SEGMENT_ID)]),
    LON = if_else(START, accepted$LON_START[match(LEVEL_SEGMENT_ID, accepted$LEVEL_SEGMENT_ID)],
                  accepted$LON_END[match(LEVEL_SEGMENT_ID, accepted$LEVEL_SEGMENT_ID)]),
    DIST_REMAINING_NM = TOTAL_FLOWN_NM - DIST_FLOWN_NM
  ) |>
  transmute(
    SOURCE_UID, FLTID, ADEP, ADES, TYPE, TIME, LAT, LON, ALT_FT, MST, MST_GROUP, MST_METHOD,
    TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM, TOTAL_FLOWN_NM, DIST_REMAINING_NM,
    DIST_FROM_DEP_NM = DIST_FLOWN_NM, DIST_TO_ARR_NM = DIST_REMAINING_NM, FLIGHT_PHASE_RAW,
    LEVEL_SEGMENT_ID, LEVEL_DURATION_SEC, LEVEL_DISTANCE_NM, LEVEL_FUEL_KG,
    LEVEL_CONTEXT_PHASE, ROW_ID = as.integer(ROW_ID), source_batch
  )

# If multiple intervals resolve to a shared nearest G2G row, event rows remain
# separate and unique through MST + LEVEL_SEGMENT_ID, as in the CHN schema.
milestones <- bind_rows(milestones, boundary_events) |>
  arrange(SOURCE_UID, TIME, ROW_ID, MST, LEVEL_SEGMENT_ID)

# Build CHN-compatible phase summary rows by joining the nine shared phase bounds.
phase_defs <- tribble(
  ~PHASE, ~FROM_MST, ~TO_MST,
  "TAXI_OUT", "AOBT", "ERWY", "TAKE_OFF_ROLL", "ERWY", "ATOT",
  "LTO_CLIMB_OUT", "ATOT", "DLTO", "CLIMB", "DLTO", "TOC",
  "CRUISE", "TOC", "TOD", "DESCENT", "TOD", "ALTO",
  "LTO_APPROACH_LANDING", "ALTO", "ALDT", "RUNWAY_EXIT", "ALDT", "XRWY",
  "TAXI_IN", "XRWY", "AIBT"
)
phase_intervals <- phase_defs |>
  crossing(meta |> select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, source_batch)) |>
  left_join(milestones |> select(SOURCE_UID, MST, TIME, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM),
            by = c("SOURCE_UID", "FROM_MST" = "MST")) |>
  rename(START_TIME = TIME, START_FUEL = TOT_FUEL_KG, START_FUEL_ORIGINAL = TOT_FUEL_KG_ORIGINAL, START_DIST = DIST_FLOWN_NM) |>
  left_join(milestones |> select(SOURCE_UID, MST, TIME, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM),
            by = c("SOURCE_UID", "TO_MST" = "MST")) |>
  rename(END_TIME = TIME, END_FUEL = TOT_FUEL_KG, END_FUEL_ORIGINAL = TOT_FUEL_KG_ORIGINAL, END_DIST = DIST_FLOWN_NM) |>
  mutate(
    DURATION_MIN = as.numeric(difftime(END_TIME, START_TIME, units = "mins")),
    FUEL_KG = END_FUEL - START_FUEL,
    FUEL_KG_ORIGINAL = END_FUEL_ORIGINAL - START_FUEL_ORIGINAL,
    DISTANCE_NM = END_DIST - START_DIST
  ) |>
  select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, PHASE, FROM_MST, TO_MST,
         START_TIME, END_TIME, DURATION_MIN, FUEL_KG, FUEL_KG_ORIGINAL, DISTANCE_NM, source_batch)

flights <- meta |>
  left_join(profile |> group_by(SOURCE_UID) |> summarise(
    FLIGHT_START_TIME = min(TIME), FLIGHT_END_TIME = max(TIME),
    TOT_FUEL_KG = max(TOT_FUEL_KG), TOT_FUEL_KG_ORIGINAL = max(TOT_FUEL_KG_ORIGINAL),
    TOTAL_FLOWN_NM = max(DIST_FLOWN_NM), .groups = "drop"), by = "SOURCE_UID") |>
  transmute(SOURCE_UID, FLTID, ADEP, ADES, TYPE,
            FLIGHT_START_TIME, FLIGHT_END_TIME,
            FLIGHT_DURATION_SEC = as.numeric(difftime(FLIGHT_END_TIME, FLIGHT_START_TIME, units = "secs")),
            TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, TOTAL_FLOWN_NM, source_batch)

required_milestones <- milestones |>
  filter(MST %in% c("ATOT", "TOC", "TOD", "ALDT")) |>
  distinct(SOURCE_UID, MST) |>
  mutate(PRESENT = TRUE) |>
  pivot_wider(names_from = MST, values_from = PRESENT, values_fill = FALSE) |>
  rename(ATOT_PRESENT = ATOT, TOC_PRESENT = TOC, TOD_PRESENT = TOD, ALDT_PRESENT = ALDT)
core_phase_screen <- phase_intervals |>
  filter(PHASE %in% c("CLIMB", "CRUISE", "DESCENT")) |>
  group_by(SOURCE_UID) |>
  summarise(
    CORE_PHASE_COUNT = n_distinct(PHASE),
    CORE_PHASE_MISSING = any(is.na(DURATION_MIN) | is.na(FUEL_KG) | is.na(DISTANCE_NM)),
    CORE_PHASE_NONPOSITIVE_DURATION = any(DURATION_MIN <= 0, na.rm = TRUE),
    CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE = any(FUEL_KG < 0 | DISTANCE_NM < 0, na.rm = TRUE),
    .groups = "drop"
  )
level_screen <- level_extensions |>
  group_by(SOURCE_UID) |>
  summarise(
    LEVEL_SEGMENT_COUNT = n(),
    LEVEL_CLIMB_COUNT = sum(LEVEL_CONTEXT_PHASE == "CLIMB"),
    LEVEL_DESCENT_COUNT = sum(LEVEL_CONTEXT_PHASE == "DESCENT"),
    LEVEL_G2G_ALL_VALID = all(G2G_INTERVAL_VALID),
    .groups = "drop"
  )
flight_eligibility <- flights |>
  select(SOURCE_UID, FLTID, ADEP, ADES, TYPE) |>
  left_join(required_milestones, by = "SOURCE_UID") |>
  left_join(core_phase_screen, by = "SOURCE_UID") |>
  left_join(level_screen, by = "SOURCE_UID") |>
  mutate(
    across(c(ATOT_PRESENT, TOC_PRESENT, TOD_PRESENT, ALDT_PRESENT), ~ replace_na(.x, FALSE)),
    across(c(LEVEL_SEGMENT_COUNT, LEVEL_CLIMB_COUNT, LEVEL_DESCENT_COUNT), ~ replace_na(.x, 0L)),
    CORE_PHASE_COUNT = replace_na(CORE_PHASE_COUNT, 0L),
    CORE_PHASE_MISSING = replace_na(CORE_PHASE_MISSING, TRUE),
    CORE_PHASE_NONPOSITIVE_DURATION = replace_na(CORE_PHASE_NONPOSITIVE_DURATION, TRUE),
    CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE = replace_na(CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE, TRUE),
    LEVEL_G2G_ALL_VALID = replace_na(LEVEL_G2G_ALL_VALID, TRUE),
    CORE_PHASE_SCREEN_PASS = CORE_PHASE_COUNT == 3L & !CORE_PHASE_MISSING &
      !CORE_PHASE_NONPOSITIVE_DURATION & !CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE,
    FULL_PROFILE_SCREEN_PASS = !is.na(FLTID) & ATOT_PRESENT & TOC_PRESENT & TOD_PRESENT & ALDT_PRESENT &
      CORE_PHASE_SCREEN_PASS,
    SCREEN_DEFINITION = "EUR_parallel_core_phase_v1"
  )

# Exact names/order of shared CHN canonical schemas (including its current
# lowercase source_batch column).
milestone_cols <- c("SOURCE_UID","FLTID","ADEP","ADES","TYPE","TIME","LAT","LON","ALT_FT","MST","MST_GROUP","MST_METHOD",
                    "TOT_FUEL_KG","TOT_FUEL_KG_ORIGINAL","DIST_FLOWN_NM","TOTAL_FLOWN_NM","DIST_REMAINING_NM",
                    "DIST_FROM_DEP_NM","DIST_TO_ARR_NM","FLIGHT_PHASE_RAW","LEVEL_SEGMENT_ID","LEVEL_DURATION_SEC",
                    "LEVEL_DISTANCE_NM","LEVEL_FUEL_KG","LEVEL_CONTEXT_PHASE","ROW_ID","source_batch")
level_cols <- c("SOURCE_UID","FLTID","ADEP","ADES","TYPE","LEVEL_SEGMENT_ID","LEVEL_CONTEXT_PHASE","START_TIME","END_TIME",
               "START_ROW_ID","END_ROW_ID","START_ALT_FT","END_ALT_FT","ALTITUDE_BAND_FT","START_DIST_FLOWN_NM",
               "END_DIST_FLOWN_NM","DISTANCE_NM","START_FUEL_KG","END_FUEL_KG","FUEL_KG","DURATION_SEC","source_batch")
phase_cols <- c("SOURCE_UID","FLTID","ADEP","ADES","TYPE","PHASE","FROM_MST","TO_MST","START_TIME","END_TIME",
                "DURATION_MIN","FUEL_KG","FUEL_KG_ORIGINAL","DISTANCE_NM","source_batch")
milestones <- milestones |> select(all_of(milestone_cols))
level_segments <- level_segments |> select(all_of(level_cols))
phase_intervals <- phase_intervals |> select(all_of(phase_cols))

chn_milestone_schema <- names(read_parquet(file.path(repo_root, ".fuelburn-data-store/processed/chn/CHN-canonical-milestones-summer2025.parquet")))
chn_level_schema <- names(read_parquet(file.path(repo_root, ".fuelburn-data-store/processed/chn/CHN-level-segments-summer2025.parquet")))
chn_phase_schema <- names(read_parquet(file.path(repo_root, ".fuelburn-data-store/processed/chn/CHN-phase-summaries-summer2025.parquet")))
schema_checks <- c(
  milestone_schema_matches_chn = identical(names(milestones), chn_milestone_schema),
  level_schema_matches_chn = identical(names(level_segments), chn_level_schema),
  phase_schema_matches_chn = identical(names(phase_intervals), chn_phase_schema)
)

write_parquet(milestones, file.path(output_dir, "EUR-canonical-milestones-parallel.parquet"), compression = "zstd")
write_parquet(level_segments, file.path(output_dir, "EUR-level-segments-parallel.parquet"), compression = "zstd")
write_parquet(level_extensions, file.path(output_dir, "EUR-level-segment-extensions.parquet"), compression = "zstd")
write_parquet(phase_intervals, file.path(output_dir, "EUR-phase-summaries-parallel.parquet"), compression = "zstd")
write_parquet(flights, file.path(output_dir, "EUR-flights-parallel.parquet"), compression = "zstd")
write_parquet(flight_eligibility, file.path(output_dir, "EUR-flight-eligibility-parallel.parquet"), compression = "zstd")

fuel_reconciliation <- flights |>
  left_join(meta |> transmute(SOURCE_UID, META_FUEL_KG = total_fuel_kg,
                              META_FUEL_ORIGINAL_KG = total_fuel_kg_original,
                              META_DISTANCE_NM = total_distance_nm), by = "SOURCE_UID") |>
  summarise(
    max_adjusted_fuel_delta_kg = max(abs(TOT_FUEL_KG - META_FUEL_KG), na.rm = TRUE),
    max_original_fuel_delta_kg = max(abs(TOT_FUEL_KG_ORIGINAL - META_FUEL_ORIGINAL_KG), na.rm = TRUE),
    max_distance_delta_nm = max(abs(TOTAL_FLOWN_NM - META_DISTANCE_NM), na.rm = TRUE)
  )
audit <- bind_rows(
  tibble(metric = names(metadata_consistency), value = as.character(unlist(metadata_consistency[1,]))),
  tibble(metric = names(fuel_lineage), value = as.character(unlist(fuel_lineage[1,]))),
  tibble(metric = names(fuel_reconciliation), value = as.character(unlist(fuel_reconciliation[1,]))),
  tibble(metric = c("g2g_source_rows", "canonical_milestone_rows", "level_segment_rows",
                    "level_flights", "climb_level_segments", "descent_level_segments",
                    "level_intervals_without_g2g_coverage", "level_intervals_failing_g2g_validation",
                    "source_intervals_unmatched_to_g2g", "negative_pru_level_excess_fuel_rows", "phase_summary_rows",
                    "phase_zero_duration_rows", "phase_missing_duration_rows",
                    "phase_negative_duration_rows", "full_profile_screen_pass_flights",
                    "milestone_label_set_matches_chn", names(schema_checks)),
         value = as.character(c(nrow(profile), nrow(milestones), nrow(level_segments),
                                n_distinct(level_segments$SOURCE_UID), sum(level_segments$LEVEL_CONTEXT_PHASE == "CLIMB"),
                                sum(level_segments$LEVEL_CONTEXT_PHASE == "DESCENT"),
                                sum(!accepted$G2G_COVERAGE_COMPLETE), sum(!accepted$G2G_INTERVAL_VALID),
                                unmatched_interval_count, sum(level_extensions$PRU_LEVEL_EXCESS_FUEL_KG < 0, na.rm = TRUE),
                                nrow(phase_intervals), sum(phase_intervals$DURATION_MIN == 0, na.rm = TRUE),
                                sum(is.na(phase_intervals$DURATION_MIN)), sum(phase_intervals$DURATION_MIN < 0, na.rm = TRUE),
                                sum(flight_eligibility$FULL_PROFILE_SCREEN_PASS),
                                setequal(unique(milestones$MST), unique(read_parquet(file.path(repo_root, ".fuelburn-data-store/processed/chn/CHN-canonical-milestones-summer2025.parquet"))$MST)),
                                schema_checks)))
)
utils::write.csv(audit, file.path(output_dir, "EUR-parallel-build-audit.csv"), row.names = FALSE)
utils::write.csv(audit, file.path(evidence_dir, "EUR-parallel-build-audit.csv"), row.names = FALSE)

if (do_upload) {
  source(file.path(repo_root, "R/r2-storage.R"))
  prefix <- paste0("derived/eur/parallel-preprocessing/", run_id, "/")
  for (name in c("EUR-canonical-milestones-parallel.parquet", "EUR-level-segments-parallel.parquet",
                 "EUR-level-segment-extensions.parquet", "EUR-phase-summaries-parallel.parquet",
                 "EUR-flights-parallel.parquet", "EUR-flight-eligibility-parallel.parquet",
                 "EUR-parallel-build-audit.csv")) {
    r2_upload(file.path(output_dir, name), paste0(prefix, name))
  }
}

message("Candidate output directory: ", output_dir)
print(audit, n = Inf)
