#!/usr/bin/env Rscript
# M3 refinement of the EUR parallel candidate. Reads the versioned 12 October
# candidate as its baseline, retains all M3 threshold-crossing candidates, and
# interpolates G2G cumulative fuel/distance at candidate event times.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(purrr)
  library(readr)
  library(tidyr)
  library(tibble)
})

args <- commandArgs(trailingOnly = TRUE)
do_upload <- "--upload" %in% args
run_id_arg <- args[grepl("^--run-id=", args)]
run_id <- if (length(run_id_arg)) sub("^--run-id=", "", run_id_arg[[1]]) else "EUR-2026-10-13-001"
if (!nzchar(run_id)) stop("--run-id must not be empty.")
repo_root <- normalizePath(".", mustWork = TRUE)
store <- file.path(repo_root, ".fuelburn-data-store")
input_dir <- file.path(store, "raw/eur/source-sample")
base_id <- "EUR-2026-10-12-001"
base_dir <- file.path(store, "derived/eur/parallel-preprocessing", base_id)
output_dir <- file.path(store, "derived/eur/parallel-preprocessing", run_id)
evidence_dir <- file.path(repo_root, "notes/results/EUR", run_id)
airport_path <- file.path(repo_root, "notes/reference-data/EUR-airport-coordinates-2024-12-27.csv")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)

required_base <- c("EUR-canonical-milestones-parallel.parquet", "EUR-level-segments-parallel.parquet",
                   "EUR-level-segment-extensions.parquet", "EUR-phase-summaries-parallel.parquet",
                   "EUR-flights-parallel.parquet", "EUR-flight-eligibility-parallel.parquet")
if (!all(file.exists(file.path(base_dir, required_base)))) stop("The pinned baseline candidate is incomplete.")
if (!file.exists(airport_path)) stop("Missing airport-coordinate reference: ", airport_path)

# Reuse the project CHN implementation for the shared VFE TOC/TOD detector.
source(file.path(repo_root, "R/canonical-fuel-milestones.R"))

base_milestones <- read_parquet(file.path(base_dir, required_base[[1]]))
level_segments <- read_parquet(file.path(base_dir, required_base[[2]])) |>
  mutate(
    # PRU CCO/CDO ALT_START/ALT_END values are flight levels in hundreds of
    # feet (e.g. 140.2), despite the canonical *_FT field names.
    START_ALT_FT = START_ALT_FT * 100,
    END_ALT_FT = END_ALT_FT * 100,
    ALTITUDE_BAND_FT = floor(((START_ALT_FT + END_ALT_FT) / 2) / 1000) * 1000
  )
level_extensions <- read_parquet(file.path(base_dir, required_base[[3]]))
base_phases <- read_parquet(file.path(base_dir, required_base[[4]]))
flights <- read_parquet(file.path(base_dir, required_base[[5]]))
base_eligibility <- read_parquet(file.path(base_dir, required_base[[6]]))
airport_ref <- read_csv(airport_path, show_col_types = FALSE)
# The metadata source does not carry FLTID; retain the canonical baseline's
# already verified M3 CALLSIGN mapping and add only route/type/source fields.
meta <- flights |> select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, source_batch)
airport_dep <- airport_ref |> transmute(ADEP = ICAO, DEP_LAT = ARP_LAT, DEP_LON = ARP_LON)
airport_arr <- airport_ref |> transmute(ADES = ICAO, ARR_LAT = ARP_LAT, ARR_LON = ARP_LON)
airport_check <- meta |> distinct(ADEP, ADES) |>
  left_join(airport_dep, by = "ADEP") |> left_join(airport_arr, by = "ADES")
if (anyNA(airport_check$DEP_LAT) || anyNA(airport_check$ARR_LAT)) {
  stop("Airport-coordinate reference does not cover every study route.")
}

haversine_nm <- function(lat1, lon1, lat2, lon2) {
  r <- pi / 180
  dlat <- (lat2 - lat1) * r
  dlon <- (lon2 - lon1) * r
  h <- sin(dlat / 2)^2 + cos(lat1 * r) * cos(lat2 * r) * sin(dlon / 2)^2
  3440.065 * 2 * atan2(sqrt(h), sqrt(pmax(0, 1 - h)))
}

message("Reading G2G increments and M3 profiles...")
g2g <- read_parquet(file.path(input_dir, "g2g-segment-details-2025-summer.parquet")) |>
  mutate(SAM_ID = as.character(SAM_ID))
ground_source_coverage <- g2g |>
  group_by(SOURCE_UID = SAM_ID) |>
  summarise(G2G_TAXI_IN_SOURCE_PRESENT = any(FLIGHT_PHASE == "Taxi-In", na.rm = TRUE),
            G2G_LANDING_SOURCE_PRESENT = any(FLIGHT_PHASE == "Landing", na.rm = TRUE), .groups = "drop")
profile <- g2g |>
  arrange(SAM_ID, TIME_OVER, MILESTONE, FLIGHT_PHASE) |>
  group_by(SAM_ID) |>
  mutate(
    SOURCE_UID = as.character(SAM_ID), ROW_ID = row_number(),
    TIME = as.POSIXct(TIME_OVER, tz = "UTC"),
    TOT_FUEL_KG = cumsum(replace_na(as.numeric(FUEL_BURNT_KG), 0)),
    TOT_FUEL_KG_ORIGINAL = cumsum(replace_na(as.numeric(FUEL_BURNT_KG_ORIGINAL), 0)),
    DIST_FLOWN_NM = cumsum(replace_na(as.numeric(DISTANCE_NM), 0))
  ) |>
  ungroup() |>
  left_join(flights |> select(SOURCE_UID, TOTAL_FLOWN_NM), by = "SOURCE_UID") |>
  mutate(DIST_REMAINING_NM = pmax(0, TOTAL_FLOWN_NM - DIST_FLOWN_NM))
message("G2G cumulative profiles ready: ", nrow(profile), " rows")

m3_files <- file.path(input_dir, sprintf("m3-ctfm-2025-%02d.parquet", 6:8))
if (!all(file.exists(m3_files))) stop("One or more monthly M3 files are missing.")
m3 <- map_dfr(m3_files, ~ read_parquet(.x, col_select = c(
  FLIGHT_ID, TIME_OVER, LONGITUDE, LATITUDE, FLIGHT_LEVEL, POINT_ID, SEQ_ID
))) |>
  mutate(SOURCE_UID = as.character(FLIGHT_ID), TIME = as.POSIXct(TIME_OVER, tz = "UTC")) |>
  inner_join(meta, by = "SOURCE_UID") |>
  left_join(airport_dep, by = "ADEP") |>
  left_join(airport_arr, by = "ADES") |>
  mutate(
    ALT_FT = as.numeric(FLIGHT_LEVEL) * 100,
    DIST_FROM_DEP_NM = haversine_nm(LATITUDE, LONGITUDE, DEP_LAT, DEP_LON),
    DIST_TO_ARR_NM = haversine_nm(LATITUDE, LONGITUDE, ARR_LAT, ARR_LON)
  ) |>
  left_join(flights |> select(SOURCE_UID, TOTAL_FLOWN_NM), by = "SOURCE_UID") |>
  arrange(SOURCE_UID, TIME, SEQ_ID)
message("M3 study profiles ready: ", nrow(m3), " rows across ", n_distinct(m3$SOURCE_UID), " flights")
if (n_distinct(m3$SOURCE_UID) != nrow(flights)) stop("M3 does not cover every baseline study flight.")

# Interpolate G2G cumulative quantities on UTC time. These are G2G estimates,
# not M3 fuel observations. No extrapolation is allowed.
interp <- function(target, times, values) {
  x <- as.numeric(times); y <- as.numeric(values); t <- as.numeric(target)
  ok <- is.finite(x) & is.finite(y)
  if (!is.finite(t) || !any(ok)) return(NA_real_)
  x <- x[ok]; y <- y[ok]
  if (t < min(x) || t > max(x)) return(NA_real_)
  av <- tibble(x = x, y = y) |> group_by(x) |> summarise(y = mean(y), .groups = "drop")
  approx(av$x, av$y, xout = t, rule = 1)$y[[1]]
}
interp_many <- function(target, times, values) {
  x <- as.numeric(times); y <- as.numeric(values); q <- as.numeric(target)
  ok <- is.finite(x) & is.finite(y)
  if (!any(ok)) return(rep(NA_real_, length(q)))
  av <- tapply(y[ok], x[ok], mean)
  tx <- as.numeric(names(av)); vy <- as.numeric(av)
  ord <- order(tx); tx <- tx[ord]; vy <- vy[ord]
  if (length(tx) == 1L) return(ifelse(q == tx[[1]], vy[[1]], NA_real_))
  approx(tx, vy, xout = q, rule = 1, ties = mean)$y
}
nearest_g2g_row <- function(target, x) {
  ok <- !is.na(x$TIME) & !is.na(x$ROW_ID)
  if (!any(ok)) return(NA_integer_)
  x$ROW_ID[which(ok)[which.min(abs(as.numeric(x$TIME[ok]) - as.numeric(target)))]]
}
nearest_g2g_rows <- function(target, x) {
  times <- as.numeric(x$TIME)
  ok <- is.finite(times) & !is.na(x$ROW_ID)
  times <- times[ok]; ids <- x$ROW_ID[ok]
  ord <- order(times); times <- times[ord]; ids <- ids[ord]
  if (!length(times)) return(rep(NA_integer_, length(target)))
  if (length(times) == 1L) return(rep(as.integer(ids[[1]]), length(target)))
  q <- as.numeric(target)
  hi <- findInterval(q, times)
  lo_i <- pmax(1L, pmin(length(times), hi))
  hi_i <- pmax(1L, pmin(length(times), hi + 1L))
  choose_hi <- abs(times[hi_i] - q) < abs(times[lo_i] - q)
  as.integer(ifelse(choose_hi, ids[hi_i], ids[lo_i]))
}
g2g_by_flight <- split(profile, profile$SOURCE_UID)

# Enumerate every crossing on the sampled M3 trajectory. Linear interpolation
# is between adjacent M3 samples; the bracketing interval is retained as a
# resolution diagnostic. Distance is geodesic to the airport reference point.
cross_specs <- tribble(
  ~MST, ~MEASURE, ~THRESHOLD, ~SIDE,
  "D040", "DIST_FROM_DEP_NM", 40, "departure",
  "D100", "DIST_FROM_DEP_NM", 100, "departure",
  "D200", "DIST_FROM_DEP_NM", 200, "departure",
  "A200", "DIST_TO_ARR_NM", 200, "arrival",
  "A100", "DIST_TO_ARR_NM", 100, "arrival",
  "A040", "DIST_TO_ARR_NM", 40, "arrival",
  "D_FL075", "ALT_FT", 7500, "flight_level",
  "D_FL100", "ALT_FT", 10000, "flight_level",
  "D_FL180", "ALT_FT", 18000, "flight_level",
  "A_FL180", "ALT_FT", 18000, "flight_level",
  "A_FL100", "ALT_FT", 10000, "flight_level",
  "A_FL075", "ALT_FT", 7500, "flight_level"
)
one_crossing_set <- function(x, spec) {
  v0 <- x[[spec$MEASURE]]
  v1 <- x[[paste0("NEXT_", spec$MEASURE)]]
  t0 <- as.numeric(x$TIME); t1 <- as.numeric(x$NEXT_TIME)
  th <- spec$THRESHOLD
  valid <- is.finite(v0) & is.finite(v1) & v0 != v1 & is.finite(t0) & is.finite(t1) & t1 > t0
  idx <- which(valid & (v0 - th) * (v1 - th) <= 0)
  if (!length(idx)) return(tibble())
  f <- (th - v0[idx]) / (v1[idx] - v0[idx])
  direction <- ifelse(v1[idx] > v0[idx], "increasing", "decreasing")
  mst <- if (spec$SIDE == "flight_level") {
    ifelse(direction == "increasing", sub("^A_", "D_", spec$MST), sub("^D_", "A_", spec$MST))
  } else spec$MST
  time_num <- t0[idx] + f * (t1[idx] - t0[idx])
  lat <- x$LATITUDE[idx] + f * (x$NEXT_LATITUDE[idx] - x$LATITUDE[idx])
  lon <- x$LONGITUDE[idx] + f * (x$NEXT_LONGITUDE[idx] - x$LONGITUDE[idx])
  alt <- x$ALT_FT[idx] + f * (x$NEXT_ALT_FT[idx] - x$ALT_FT[idx])
  tibble(
    SOURCE_UID = x$SOURCE_UID[idx], MST = mst, THRESHOLD_VALUE = th,
    THRESHOLD_UNIT = if (spec$SIDE == "flight_level") "ft" else "NM",
    CROSSING_DIRECTION = if (spec$SIDE == "flight_level") ifelse(direction == "increasing", "up", "down") else ifelse(direction == "increasing", "outbound", "inbound"),
    TIME = as.POSIXct(time_num, origin = "1970-01-01", tz = "UTC"),
    LAT = lat, LON = lon, ALT_FT = alt,
    DIST_FROM_DEP_NM = haversine_nm(lat, lon, x$DEP_LAT[idx], x$DEP_LON[idx]),
    DIST_TO_ARR_NM = haversine_nm(lat, lon, x$ARR_LAT[idx], x$ARR_LON[idx]),
    M3_LEFT_SEQ_ID = x$SEQ_ID[idx], M3_RIGHT_SEQ_ID = x$NEXT_SEQ_ID[idx],
    M3_LEFT_TIME = as.POSIXct(t0[idx], origin = "1970-01-01", tz = "UTC"),
    M3_RIGHT_TIME = as.POSIXct(t1[idx], origin = "1970-01-01", tz = "UTC"),
    M3_BRACKET_GAP_SEC = t1[idx] - t0[idx], M3_RESOLUTION_30SEC_PASS = (t1[idx] - t0[idx]) <= 30,
    M3_METHOD = if (spec$SIDE == "flight_level") "m3_linear_altitude_crossing" else "m3_linear_arp_distance_crossing"
  )
}
m3_pairs <- m3 |>
  group_by(SOURCE_UID) |> arrange(TIME, SEQ_ID, .by_group = TRUE) |>
  mutate(NEXT_TIME = lead(TIME), NEXT_LATITUDE = lead(LATITUDE), NEXT_LONGITUDE = lead(LONGITUDE),
         NEXT_ALT_FT = lead(ALT_FT), NEXT_DIST_FROM_DEP_NM = lead(DIST_FROM_DEP_NM),
         NEXT_DIST_TO_ARR_NM = lead(DIST_TO_ARR_NM), NEXT_SEQ_ID = lead(SEQ_ID)) |>
  ungroup()
message("Enumerating crossings for ", n_distinct(m3$SOURCE_UID), " flight profiles...")
crossing_parts <- vector("list", nrow(cross_specs))
for (i in seq_len(nrow(cross_specs))) {
  message("  crossing set ", cross_specs$MST[[i]])
  crossing_parts[[i]] <- one_crossing_set(m3_pairs, cross_specs[i, ])
}
crossings <- bind_rows(crossing_parts) |>
  arrange(SOURCE_UID, MST, TIME) |>
  distinct(SOURCE_UID, MST, TIME, CROSSING_DIRECTION, .keep_all = TRUE) |>
  group_by(SOURCE_UID, MST) |>
  mutate(CANDIDATE_ORDER = row_number(), CANDIDATE_ID = sprintf("%s-%s-%03d", SOURCE_UID, MST, CANDIDATE_ORDER)) |>
  ungroup()
candidate_list <- split(m3, m3$SOURCE_UID)
message("Crossing candidates found: ", nrow(crossings))

# Preserve all crossings in the candidate audit. Suppress only candidates that
# fall within an accepted CCO/CDO interval whose altitude envelope contains the
# crossed flight level (500 ft association tolerance).
level_assoc <- crossings |> filter(THRESHOLD_UNIT == "ft") |>
  inner_join(level_segments |> select(SOURCE_UID, LEVEL_SEGMENT_ID, START_TIME, END_TIME, START_ALT_FT, END_ALT_FT),
             by = "SOURCE_UID", relationship = "many-to-many") |>
  filter(TIME >= START_TIME, TIME <= END_TIME,
         THRESHOLD_VALUE >= pmin(START_ALT_FT, END_ALT_FT) - 500,
         THRESHOLD_VALUE <= pmax(START_ALT_FT, END_ALT_FT) + 500) |>
  group_by(CANDIDATE_ID) |>
  summarise(SUPPRESS_LEVEL_ASSOCIATED = TRUE,
            ASSOCIATED_LEVEL_SEGMENT_IDS = paste(unique(LEVEL_SEGMENT_ID), collapse = "|"), .groups = "drop")
crossings <- crossings |> left_join(level_assoc, by = "CANDIDATE_ID") |>
  mutate(SUPPRESS_LEVEL_ASSOCIATED = replace_na(SUPPRESS_LEVEL_ASSOCIATED, FALSE),
         ASSOCIATED_LEVEL_SEGMENT_IDS = replace_na(ASSOCIATED_LEVEL_SEGMENT_IDS, ""))
message("Level-associated candidates identified: ", sum(crossings$SUPPRESS_LEVEL_ASSOCIATED))

# Add G2G-integrated totals and nearest-row trace pointers to each M3 crossing.
crossings <- crossings |>
  group_by(SOURCE_UID) |>
  group_modify(function(x, key) {
    g <- g2g_by_flight[[key$SOURCE_UID[[1]]]]
    if (is.null(g)) return(x |> mutate(TOT_FUEL_KG = NA_real_, TOT_FUEL_KG_ORIGINAL = NA_real_, DIST_FLOWN_NM = NA_real_, ROW_ID = NA_integer_))
    x$TOT_FUEL_KG <- interp_many(x$TIME, g$TIME, g$TOT_FUEL_KG)
    x$TOT_FUEL_KG_ORIGINAL <- interp_many(x$TIME, g$TIME, g$TOT_FUEL_KG_ORIGINAL)
    x$DIST_FLOWN_NM <- interp_many(x$TIME, g$TIME, g$DIST_FLOWN_NM)
    x$ROW_ID <- nearest_g2g_rows(x$TIME, g)
    x
  }) |>
  ungroup() |>
  left_join(flights |> select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, TOTAL_FLOWN_NM, source_batch), by = "SOURCE_UID") |>
  mutate(DIST_REMAINING_NM = pmax(0, TOTAL_FLOWN_NM - DIST_FLOWN_NM))
message("Interpolated G2G values at crossing times.")

crossing_milestones <- crossings |> filter(!SUPPRESS_LEVEL_ASSOCIATED) |>
  transmute(
    SOURCE_UID, FLTID, ADEP, ADES, TYPE, TIME, LAT, LON, ALT_FT, MST,
    MST_GROUP = if_else(THRESHOLD_UNIT == "ft", "flight_level_anchor", "distance_anchor"),
    MST_METHOD = M3_METHOD, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL,
    DIST_FLOWN_NM, TOTAL_FLOWN_NM, DIST_REMAINING_NM,
    DIST_FROM_DEP_NM, DIST_TO_ARR_NM, FLIGHT_PHASE_RAW = NA_character_,
    LEVEL_SEGMENT_ID = NA_character_, LEVEL_DURATION_SEC = NA_real_,
    LEVEL_DISTANCE_NM = NA_real_, LEVEL_FUEL_KG = NA_real_,
    LEVEL_CONTEXT_PHASE = NA_character_, ROW_ID = as.integer(ROW_ID), source_batch
  )

# Repair zero-duration climb/cruise/descent boundaries only when the shared CHN
# TOC/TOD detector returns an ordered M3 pair. Terminal taxi/runway phases are
# not inferred from M3 because its observed coverage does not extend to stands.
bad_core <- base_phases |> filter(PHASE %in% c("CLIMB", "CRUISE", "DESCENT"), is.na(DURATION_MIN) | DURATION_MIN <= 0)
zero_cruise_ids <- bad_core |> filter(PHASE == "CRUISE") |> pull(SOURCE_UID) |> unique()
base_operational <- base_milestones |> filter(MST %in% c("AOBT", "ERWY", "ATOT", "DLTO", "TOC", "TOD", "ALTO", "ALDT", "XRWY", "AIBT"))
operational_times <- base_operational |> select(SOURCE_UID, MST, TIME) |> distinct() |> pivot_wider(names_from = MST, values_from = TIME)

make_m3_snapshot <- function(uid, mst, row, method) {
  x <- candidate_list[[uid]]
  g <- g2g_by_flight[[uid]]
  t <- x$TIME[[row]]
  tibble(
    SOURCE_UID = uid, FLTID = x$FLTID[[row]], ADEP = x$ADEP[[row]], ADES = x$ADES[[row]], TYPE = x$TYPE[[row]],
    TIME = t, LAT = x$LATITUDE[[row]], LON = x$LONGITUDE[[row]], ALT_FT = x$ALT_FT[[row]], MST = mst,
    MST_GROUP = if (mst %in% c("TOC", "TOD")) "cruise_bounds" else "operational_profile",
    MST_METHOD = method,
    TOT_FUEL_KG = interp(t, g$TIME, g$TOT_FUEL_KG),
    TOT_FUEL_KG_ORIGINAL = interp(t, g$TIME, g$TOT_FUEL_KG_ORIGINAL),
    DIST_FLOWN_NM = interp(t, g$TIME, g$DIST_FLOWN_NM),
    TOTAL_FLOWN_NM = x$TOTAL_FLOWN_NM[[row]],
    DIST_REMAINING_NM = pmax(0, x$TOTAL_FLOWN_NM[[row]] - interp(t, g$TIME, g$DIST_FLOWN_NM)),
    DIST_FROM_DEP_NM = x$DIST_FROM_DEP_NM[[row]], DIST_TO_ARR_NM = x$DIST_TO_ARR_NM[[row]],
    FLIGHT_PHASE_RAW = "M3_TRAJECTORY", LEVEL_SEGMENT_ID = NA_character_,
    LEVEL_DURATION_SEC = NA_real_, LEVEL_DISTANCE_NM = NA_real_, LEVEL_FUEL_KG = NA_real_,
    LEVEL_CONTEXT_PHASE = NA_character_, ROW_ID = as.integer(nearest_g2g_row(t, g)),
    source_batch = "PRU_G2G_2025SUMMER"
  )
}

toc_tod_repairs <- map_dfr(zero_cruise_ids, function(uid) {
  x <- candidate_list[[uid]] |> arrange(TIME, SEQ_ID)
  op <- operational_times |> filter(SOURCE_UID == uid)
  atot_time <- op$ATOT[[1]]
  aldt_time <- op$ALDT[[1]]
  if (is.na(atot_time) || is.na(aldt_time)) return(tibble())
  up_crossings <- which(x$ALT_FT[-1] >= 3000 & x$ALT_FT[-nrow(x)] < 3000 & x$TIME[-1] > atot_time)
  down_crossings <- which(x$ALT_FT[-1] <= 3000 & x$ALT_FT[-nrow(x)] > 3000 & x$TIME[-1] < aldt_time)
  if (!length(up_crossings) || !length(down_crossings)) return(tibble())
  dlto <- up_crossings[[1]] + 1L
  alto <- tail(down_crossings, 1) + 1L
  if (is.na(dlto) || is.na(alto) || dlto >= alto) return(tibble())
  ix <- fuel_vfe_toc_tod(x |> transmute(TIME, ALT_FT, DIST_FROM_DEP_NM, DIST_TO_ARR_NM), dlto, alto)
  if (is.na(ix$TOC) || is.na(ix$TOD) || ix$TOD <= ix$TOC) return(tibble())
  bind_rows(make_m3_snapshot(uid, "TOC", ix$TOC, "m3_shared_chn_vfe_toc_tod_repair"),
            make_m3_snapshot(uid, "TOD", ix$TOD, "m3_shared_chn_vfe_toc_tod_repair")) |>
    mutate(REPAIR_PHASE = "CRUISE", ORIGINAL_DURATION_MIN = 0,
           REPAIRED_DURATION_MIN = as.numeric(difftime(TIME[2], TIME[1], units = "mins")))
})

# One zero climb in the baseline had DLTO and TOC on the same G2G row. Use the
# first M3 upward crossing of 3,000 ft after ATOT for that flight only.
zero_climb_ids <- bad_core |> filter(PHASE == "CLIMB") |> pull(SOURCE_UID) |> unique()
dlto_repair_ids <- union(zero_climb_ids, zero_cruise_ids)
dlto_repairs <- map_dfr(dlto_repair_ids, function(uid) {
  x <- candidate_list[[uid]] |> arrange(TIME, SEQ_ID)
  t_atot <- operational_times |> filter(SOURCE_UID == uid) |> pull(ATOT)
  if (!length(t_atot) || is.na(t_atot[[1]])) return(tibble())
  i <- which(x$ALT_FT[-1] >= 3000 & x$ALT_FT[-nrow(x)] < 3000 & x$TIME[-1] > t_atot[[1]])[1]
  if (is.na(i)) return(tibble())
  frac <- (3000 - x$ALT_FT[[i]]) / (x$ALT_FT[[i + 1]] - x$ALT_FT[[i]])
  t <- as.POSIXct(as.numeric(x$TIME[[i]]) + frac * as.numeric(difftime(x$TIME[[i + 1]], x$TIME[[i]], units = "secs")), origin = "1970-01-01", tz = "UTC")
  g <- g2g_by_flight[[uid]]
  tibble(SOURCE_UID = uid, FLTID = x$FLTID[[i]], ADEP = x$ADEP[[i]], ADES = x$ADES[[i]], TYPE = x$TYPE[[i]],
         TIME = t, LAT = x$LATITUDE[[i]] + frac * (x$LATITUDE[[i + 1]] - x$LATITUDE[[i]]),
         LON = x$LONGITUDE[[i]] + frac * (x$LONGITUDE[[i + 1]] - x$LONGITUDE[[i]]), ALT_FT = 3000,
         MST = "DLTO", MST_GROUP = "operational_profile", MST_METHOD = "m3_linear_3000ft_crossing_repair",
         TOT_FUEL_KG = interp(t, g$TIME, g$TOT_FUEL_KG), TOT_FUEL_KG_ORIGINAL = interp(t, g$TIME, g$TOT_FUEL_KG_ORIGINAL),
         DIST_FLOWN_NM = interp(t, g$TIME, g$DIST_FLOWN_NM), TOTAL_FLOWN_NM = x$TOTAL_FLOWN_NM[[i]],
         DIST_REMAINING_NM = pmax(0, x$TOTAL_FLOWN_NM[[i]] - interp(t, g$TIME, g$DIST_FLOWN_NM)),
         DIST_FROM_DEP_NM = haversine_nm(LAT, LON, x$DEP_LAT[[i]], x$DEP_LON[[i]]),
         DIST_TO_ARR_NM = haversine_nm(LAT, LON, x$ARR_LAT[[i]], x$ARR_LON[[i]]),
         FLIGHT_PHASE_RAW = "M3_TRAJECTORY", LEVEL_SEGMENT_ID = NA_character_, LEVEL_DURATION_SEC = NA_real_,
         LEVEL_DISTANCE_NM = NA_real_, LEVEL_FUEL_KG = NA_real_, LEVEL_CONTEXT_PHASE = NA_character_,
         ROW_ID = as.integer(nearest_g2g_row(t, g)), source_batch = "PRU_G2G_2025SUMMER",
         REPAIR_PHASE = if (uid %in% zero_climb_ids) "CLIMB" else "CRUISE",
         ORIGINAL_DURATION_MIN = if (uid %in% zero_climb_ids) 0 else NA_real_, REPAIRED_DURATION_MIN = NA_real_)
})

repairs <- bind_rows(toc_tod_repairs, dlto_repairs)
repair_uids <- unique(repairs$SOURCE_UID)
milestones <- base_milestones |>
  mutate(ALT_FT = if_else(MST %in% c("LVL_START", "LVL_END"), ALT_FT * 100, ALT_FT)) |>
  filter(!MST %in% c(cross_specs$MST)) |>
  filter(!(SOURCE_UID %in% zero_cruise_ids & MST %in% c("TOC", "TOD"))) |>
  filter(!(SOURCE_UID %in% dlto_repair_ids & MST == "DLTO")) |>
  bind_rows(crossing_milestones, repairs |> select(any_of(names(base_milestones)))) |>
  arrange(SOURCE_UID, TIME, ROW_ID, MST, LEVEL_SEGMENT_ID)

phase_defs <- tribble(
  ~PHASE, ~FROM_MST, ~TO_MST,
  "TAXI_OUT", "AOBT", "ERWY", "TAKE_OFF_ROLL", "ERWY", "ATOT",
  "LTO_CLIMB_OUT", "ATOT", "DLTO", "CLIMB", "DLTO", "TOC",
  "CRUISE", "TOC", "TOD", "DESCENT", "TOD", "ALTO",
  "LTO_APPROACH_LANDING", "ALTO", "ALDT", "RUNWAY_EXIT", "ALDT", "XRWY",
  "TAXI_IN", "XRWY", "AIBT"
)
build_phase_intervals <- function(milestone_table) {
  phase_milestones <- milestone_table |> filter(MST %in% unique(c(phase_defs$FROM_MST, phase_defs$TO_MST))) |>
    group_by(SOURCE_UID, MST) |> arrange(TIME, .by_group = TRUE) |> slice(1) |> ungroup()
  phase_defs |>
    crossing(meta) |>
    left_join(phase_milestones |> select(SOURCE_UID, MST, TIME, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM),
              by = c("SOURCE_UID", "FROM_MST" = "MST")) |>
    rename(START_TIME = TIME, START_FUEL = TOT_FUEL_KG, START_FUEL_ORIGINAL = TOT_FUEL_KG_ORIGINAL, START_DIST = DIST_FLOWN_NM) |>
    left_join(phase_milestones |> select(SOURCE_UID, MST, TIME, TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM),
              by = c("SOURCE_UID", "TO_MST" = "MST")) |>
    rename(END_TIME = TIME, END_FUEL = TOT_FUEL_KG, END_FUEL_ORIGINAL = TOT_FUEL_KG_ORIGINAL, END_DIST = DIST_FLOWN_NM) |>
    mutate(DURATION_MIN = as.numeric(difftime(END_TIME, START_TIME, units = "mins")),
           FUEL_KG = END_FUEL - START_FUEL, FUEL_KG_ORIGINAL = END_FUEL_ORIGINAL - START_FUEL_ORIGINAL,
           DISTANCE_NM = END_DIST - START_DIST) |>
    select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, PHASE, FROM_MST, TO_MST, START_TIME, END_TIME,
           DURATION_MIN, FUEL_KG, FUEL_KG_ORIGINAL, DISTANCE_NM, source_batch)
}
phase_intervals <- build_phase_intervals(milestones)

# Apply the M3 repair pair only when it produces a coherent positive climb,
# cruise, and descent with nonnegative interpolated fuel and distance. Otherwise
# restore the baseline events and leave the original phase as unresolved.
repair_target_ids <- union(zero_cruise_ids, zero_climb_ids)
core_coherence <- phase_intervals |> filter(PHASE %in% c("CLIMB", "CRUISE", "DESCENT")) |>
  group_by(SOURCE_UID) |> summarise(
    CORE_REPAIR_COHERENT = n() == 3L & all(is.finite(DURATION_MIN) & DURATION_MIN > 0) &
      all(is.finite(FUEL_KG) & FUEL_KG >= 0) & all(is.finite(DISTANCE_NM) & DISTANCE_NM >= 0), .groups = "drop")
failed_repair_ids <- core_coherence |> filter(SOURCE_UID %in% repair_target_ids, !CORE_REPAIR_COHERENT) |> pull(SOURCE_UID)
if (length(failed_repair_ids)) {
  message("M3 phase repair failed coherence checks for ", length(failed_repair_ids), " flights; restoring baseline TOC/TOD/DLTO events.")
  milestones <- milestones |>
    filter(!(SOURCE_UID %in% failed_repair_ids & MST %in% c("TOC", "TOD", "DLTO"))) |>
    bind_rows(base_milestones |> filter(SOURCE_UID %in% failed_repair_ids, MST %in% c("TOC", "TOD", "DLTO"))) |>
    arrange(SOURCE_UID, TIME, ROW_ID, MST, LEVEL_SEGMENT_ID)
  phase_intervals <- build_phase_intervals(milestones)
}
applied_repairs <- repairs |> filter(!SOURCE_UID %in% failed_repair_ids)

required_milestones <- milestones |> filter(MST %in% c("ATOT", "TOC", "TOD", "ALDT")) |>
  distinct(SOURCE_UID, MST) |> mutate(PRESENT = TRUE) |> pivot_wider(names_from = MST, values_from = PRESENT, values_fill = FALSE) |>
  rename(ATOT_PRESENT = ATOT, TOC_PRESENT = TOC, TOD_PRESENT = TOD, ALDT_PRESENT = ALDT)
core_phase_screen <- phase_intervals |> filter(PHASE %in% c("CLIMB", "CRUISE", "DESCENT")) |>
  group_by(SOURCE_UID) |> summarise(CORE_PHASE_COUNT = n_distinct(PHASE),
    CORE_PHASE_MISSING = any(is.na(DURATION_MIN) | is.na(FUEL_KG) | is.na(DISTANCE_NM)),
    CORE_PHASE_NONPOSITIVE_DURATION = any(DURATION_MIN <= 0, na.rm = TRUE),
    CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE = any(FUEL_KG < 0 | DISTANCE_NM < 0, na.rm = TRUE), .groups = "drop")
level_screen <- level_extensions |> group_by(SOURCE_UID) |> summarise(
  LEVEL_SEGMENT_COUNT = n(), LEVEL_CLIMB_COUNT = sum(LEVEL_CONTEXT_PHASE == "CLIMB"),
  LEVEL_DESCENT_COUNT = sum(LEVEL_CONTEXT_PHASE == "DESCENT"), LEVEL_G2G_ALL_VALID = all(G2G_INTERVAL_VALID), .groups = "drop")
eligibility <- flights |> select(SOURCE_UID, FLTID, ADEP, ADES, TYPE) |>
  left_join(required_milestones, by = "SOURCE_UID") |> left_join(core_phase_screen, by = "SOURCE_UID") |>
  left_join(level_screen, by = "SOURCE_UID") |>
  mutate(across(c(ATOT_PRESENT, TOC_PRESENT, TOD_PRESENT, ALDT_PRESENT), ~ replace_na(.x, FALSE)),
         across(c(LEVEL_SEGMENT_COUNT, LEVEL_CLIMB_COUNT, LEVEL_DESCENT_COUNT), ~ replace_na(.x, 0L)),
         CORE_PHASE_COUNT = replace_na(CORE_PHASE_COUNT, 0L), CORE_PHASE_MISSING = replace_na(CORE_PHASE_MISSING, TRUE),
         CORE_PHASE_NONPOSITIVE_DURATION = replace_na(CORE_PHASE_NONPOSITIVE_DURATION, TRUE),
         CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE = replace_na(CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE, TRUE),
         LEVEL_G2G_ALL_VALID = replace_na(LEVEL_G2G_ALL_VALID, TRUE),
         CORE_PHASE_SCREEN_PASS = CORE_PHASE_COUNT == 3L & !CORE_PHASE_MISSING & !CORE_PHASE_NONPOSITIVE_DURATION & !CORE_PHASE_NEGATIVE_FUEL_OR_DISTANCE,
         FULL_PROFILE_SCREEN_PASS = !is.na(FLTID) & ATOT_PRESENT & TOC_PRESENT & TOD_PRESENT & ALDT_PRESENT & CORE_PHASE_SCREEN_PASS,
         SCREEN_DEFINITION = "EUR_parallel_core_phase_v2_m3")

# Phase-level screens preserve the flight and the other phase rows when one
# interval is unusable. Ground intervals are not repaired from M3: their event
# timing belongs to the APDF/G2G and ICAO-roll convention.
phase_eligibility <- phase_intervals |>
  left_join(ground_source_coverage, by = "SOURCE_UID") |>
  mutate(G2G_TAXI_IN_SOURCE_PRESENT = replace_na(G2G_TAXI_IN_SOURCE_PRESENT, FALSE),
         G2G_LANDING_SOURCE_PRESENT = replace_na(G2G_LANDING_SOURCE_PRESENT, FALSE),
         SOURCE_PHASE_PRESENT = PHASE != "TAXI_IN" | G2G_TAXI_IN_SOURCE_PRESENT,
         PHASE_TIME_FUEL_SCREEN_PASS = SOURCE_PHASE_PRESENT & is.finite(DURATION_MIN) & DURATION_MIN > 0 &
           is.finite(FUEL_KG) & FUEL_KG >= 0,
         PHASE_DISTANCE_FUEL_SCREEN_PASS = SOURCE_PHASE_PRESENT & is.finite(DISTANCE_NM) & DISTANCE_NM > 0 &
           is.finite(FUEL_KG) & FUEL_KG >= 0,
         PHASE_SCREEN_PASS = PHASE_TIME_FUEL_SCREEN_PASS & PHASE_DISTANCE_FUEL_SCREEN_PASS,
         TIME_FUEL_SCREEN_REASON = case_when(
           PHASE == "TAXI_IN" & !G2G_TAXI_IN_SOURCE_PRESENT ~ "g2g_taxi_in_phase_absent",
           is.na(DURATION_MIN) ~ "duration_missing",
           DURATION_MIN <= 0 ~ "nonpositive_duration",
           is.na(FUEL_KG) ~ "fuel_missing",
           FUEL_KG < 0 ~ "negative_fuel",
           TRUE ~ "pass"),
         DISTANCE_FUEL_SCREEN_REASON = case_when(
           PHASE == "TAXI_IN" & !G2G_TAXI_IN_SOURCE_PRESENT ~ "g2g_taxi_in_phase_absent",
           is.na(DISTANCE_NM) ~ "distance_missing",
           DISTANCE_NM <= 0 ~ "nonpositive_distance",
           is.na(FUEL_KG) ~ "fuel_missing",
           FUEL_KG < 0 ~ "negative_fuel",
           TRUE ~ "pass"),
         PHASE_SCREEN_REASON = case_when(
           PHASE == "TAXI_IN" & !G2G_TAXI_IN_SOURCE_PRESENT ~ "g2g_taxi_in_phase_absent",
           is.na(DURATION_MIN) ~ "boundary_time_missing",
           DURATION_MIN <= 0 ~ "nonpositive_duration",
           is.na(FUEL_KG) ~ "fuel_missing",
           FUEL_KG < 0 ~ "negative_fuel",
           is.na(DISTANCE_NM) ~ "distance_missing",
           DISTANCE_NM <= 0 ~ "nonpositive_distance",
           TRUE ~ "pass")) |>
  select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, PHASE, FROM_MST, TO_MST,
         START_TIME, END_TIME, DURATION_MIN, FUEL_KG, FUEL_KG_ORIGINAL, DISTANCE_NM,
         G2G_TAXI_IN_SOURCE_PRESENT, G2G_LANDING_SOURCE_PRESENT,
         PHASE_TIME_FUEL_SCREEN_PASS, TIME_FUEL_SCREEN_REASON,
         PHASE_DISTANCE_FUEL_SCREEN_PASS, DISTANCE_FUEL_SCREEN_REASON,
         PHASE_SCREEN_PASS, PHASE_SCREEN_REASON, source_batch)

# Keep the exact shared CHN schemas. Multiple analytical threshold crossings
# remain distinct milestone rows; their candidate IDs and direction live in the
# restricted crossing-candidate table.
milestone_cols <- names(base_milestones)
phase_cols <- names(base_phases)
milestones <- milestones |> select(all_of(milestone_cols))
phase_intervals <- phase_intervals |> select(all_of(phase_cols))

write_parquet(milestones, file.path(output_dir, required_base[[1]]), compression = "zstd")
write_parquet(level_segments, file.path(output_dir, required_base[[2]]), compression = "zstd")
invisible(file.copy(file.path(base_dir, required_base[[3]]), file.path(output_dir, required_base[[3]]), overwrite = TRUE))
write_parquet(phase_intervals, file.path(output_dir, required_base[[4]]), compression = "zstd")
invisible(file.copy(file.path(base_dir, required_base[[5]]), file.path(output_dir, required_base[[5]]), overwrite = TRUE))
write_parquet(eligibility, file.path(output_dir, required_base[[6]]), compression = "zstd")
write_parquet(crossings, file.path(output_dir, "EUR-milestone-crossing-candidates.parquet"), compression = "zstd")
write_csv(crossings |> count(MST, SUPPRESS_LEVEL_ASSOCIATED, M3_RESOLUTION_30SEC_PASS, name = "candidate_count"),
          file.path(evidence_dir, "EUR-crossing-candidate-counts.csv"))

phase_repair_audit <- base_phases |> filter(is.na(DURATION_MIN) | DURATION_MIN <= 0) |>
  left_join(phase_intervals |> select(SOURCE_UID, PHASE, REPAIRED_DURATION_MIN = DURATION_MIN), by = c("SOURCE_UID", "PHASE")) |>
  left_join(applied_repairs |> distinct(SOURCE_UID, REPAIR_PHASE) |> mutate(HAS_REPAIR = TRUE), by = c("SOURCE_UID", "PHASE" = "REPAIR_PHASE")) |>
  mutate(HAS_REPAIR = replace_na(HAS_REPAIR, FALSE),
         REPAIR_STATUS = case_when(HAS_REPAIR & !is.na(REPAIRED_DURATION_MIN) & REPAIRED_DURATION_MIN > 0 ~ "repaired_from_m3",
                                   PHASE %in% c("RUNWAY_EXIT", "TAXI_IN") ~ "unresolved_ground_phase_boundary_mapping_pending_APDF_G2G_review",
                                   SOURCE_UID %in% failed_repair_ids ~ "unresolved_m3_profile_failed_phase_coherence_check",
                                   TRUE ~ "unresolved_no_ordered_m3_boundary_pair")) |>
  select(SOURCE_UID, PHASE, FROM_MST, TO_MST, ORIGINAL_DURATION_MIN = DURATION_MIN, REPAIRED_DURATION_MIN, REPAIR_STATUS)
write_parquet(phase_repair_audit, file.path(output_dir, "EUR-phase-boundary-repair-detail.parquet"), compression = "zstd")
write_csv(phase_repair_audit |> count(PHASE, REPAIR_STATUS, name = "flight_count"),
          file.path(evidence_dir, "EUR-phase-repair-audit.csv"))
write_parquet(phase_eligibility, file.path(output_dir, "EUR-phase-eligibility-parallel.parquet"), compression = "zstd")
terminal_phase_screen <- phase_eligibility |>
  filter(PHASE %in% c("RUNWAY_EXIT", "TAXI_IN")) |>
  count(PHASE, PHASE_SCREEN_PASS, PHASE_SCREEN_REASON,
        G2G_TAXI_IN_SOURCE_PRESENT, G2G_LANDING_SOURCE_PRESENT, name = "flight_count")
write_csv(terminal_phase_screen, file.path(evidence_dir, "EUR-terminal-phase-screen.csv"))
write_csv(terminal_phase_screen, file.path(output_dir, "EUR-terminal-phase-screen.csv"))
phase_eligibility_summary <- phase_eligibility |>
  count(PHASE, PHASE_TIME_FUEL_SCREEN_PASS, TIME_FUEL_SCREEN_REASON,
        PHASE_DISTANCE_FUEL_SCREEN_PASS, DISTANCE_FUEL_SCREEN_REASON,
        PHASE_SCREEN_PASS, PHASE_SCREEN_REASON, name = "flight_count")
write_csv(phase_eligibility_summary, file.path(evidence_dir, "EUR-phase-eligibility-summary.csv"))
write_csv(phase_eligibility_summary, file.path(output_dir, "EUR-phase-eligibility-summary.csv"))

audit <- bind_rows(
  tibble(metric = c("base_run_id", "study_flights", "m3_rows", "m3_flights", "airport_reference_airports",
                    "airport_coordinate_source", "level_segments_altitude_unit_converted_from_FL_to_ft",
                    "level_segments_with_zero_altitude_band_after_conversion",
                    "m3_crossing_candidate_rows", "m3_crossing_candidates_suppressed_by_level", "m3_crossings_bracketed_within_30sec",
                    "m3_toc_tod_repairs", "m3_dlto_repairs", "m3_repairs_reverted_for_phase_incoherence",
                    "core_phase_screen_pass_flights",
                    "phase_zero_duration_rows_after_repair", "phase_missing_duration_rows_after_repair",
                    "runway_exit_or_taxi_in_unresolved_rows"),
         value = c(base_id, n_distinct(flights$SOURCE_UID), nrow(m3), n_distinct(m3$SOURCE_UID), nrow(airport_ref),
                   "OurAirports 2024-12-27; airport coordinate proxy pending NM ARP confirmation",
                   nrow(level_segments), sum(level_segments$ALTITUDE_BAND_FT == 0, na.rm = TRUE),
                   nrow(crossings), sum(crossings$SUPPRESS_LEVEL_ASSOCIATED), sum(crossings$M3_RESOLUTION_30SEC_PASS),
                   n_distinct(applied_repairs$SOURCE_UID[applied_repairs$MST %in% c("TOC", "TOD")]),
                   n_distinct(applied_repairs$SOURCE_UID[applied_repairs$MST == "DLTO"]),
                   length(failed_repair_ids),
                   sum(eligibility$CORE_PHASE_SCREEN_PASS), sum(phase_intervals$DURATION_MIN == 0, na.rm = TRUE),
                   sum(is.na(phase_intervals$DURATION_MIN)), sum(phase_repair_audit$PHASE %in% c("RUNWAY_EXIT", "TAXI_IN"))))
)
write_csv(audit, file.path(output_dir, "EUR-parallel-build-audit.csv"))
write_csv(audit, file.path(evidence_dir, "EUR-parallel-build-audit.csv"))

sha256_file <- function(path) {
  out <- system2("shasum", c("-a", "256", path), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  if (!length(out) || status %in% c(1L, 127L)) stop("Could not hash file: ", path)
  strsplit(out[[1]], "[[:space:]]+")[[1]][[1]]
}
code_commit <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)
if (length(code_commit) != 1L || !grepl("^[0-9a-f]{40}$", code_commit)) stop("Could not resolve the full producing commit SHA.")
input_paths <- c(
  file.path(base_dir, required_base),
  file.path(input_dir, "g2g-segment-details-2025-summer.parquet"),
  m3_files,
  airport_path,
  file.path(repo_root, "R/canonical-fuel-milestones.R"),
  file.path(repo_root, "scripts/build-eur-parallel-canonical-m3.R")
)
input_names <- c(
  paste0("derived/eur/parallel-preprocessing/", base_id, "/", required_base),
  "raw/eur/source-sample/g2g-segment-details-2025-summer.parquet",
  paste0("raw/eur/source-sample/", basename(m3_files)),
  "notes/reference-data/EUR-airport-coordinates-2024-12-27.csv",
  "R/canonical-fuel-milestones.R",
  "scripts/build-eur-parallel-canonical-m3.R"
)
output_names <- c(required_base, "EUR-milestone-crossing-candidates.parquet",
                  "EUR-phase-boundary-repair-detail.parquet", "EUR-phase-eligibility-parallel.parquet",
                  "EUR-terminal-phase-screen.csv", "EUR-phase-eligibility-summary.csv",
                  "EUR-parallel-build-audit.csv")
manifest <- bind_rows(
  tibble(role = "input_or_code", artifact = input_names, sha256 = map_chr(input_paths, sha256_file),
         size_bytes = as.numeric(file.info(input_paths)$size), producing_code_commit = code_commit),
  tibble(role = "output", artifact = paste0("derived/eur/parallel-preprocessing/", run_id, "/", output_names),
         sha256 = map_chr(file.path(output_dir, output_names), sha256_file),
         size_bytes = as.numeric(file.info(file.path(output_dir, output_names))$size), producing_code_commit = code_commit)
)
manifest_path <- file.path(output_dir, "EUR-parallel-release-manifest.csv")
write_csv(manifest, manifest_path)
manifest_sha <- sha256_file(manifest_path)
writeLines(paste(manifest_sha, "  EUR-parallel-release-manifest.csv"),
           file.path(output_dir, "EUR-parallel-release-manifest.sha256"))

if (do_upload) {
  source(file.path(repo_root, "R/r2-storage.R"))
  prefix <- paste0("derived/eur/parallel-preprocessing/", run_id, "/")
  upload_files <- c(required_base, "EUR-milestone-crossing-candidates.parquet",
                    "EUR-phase-boundary-repair-detail.parquet", "EUR-phase-eligibility-parallel.parquet",
                    "EUR-terminal-phase-screen.csv", "EUR-phase-eligibility-summary.csv",
                    "EUR-parallel-build-audit.csv",
                    "EUR-parallel-release-manifest.csv", "EUR-parallel-release-manifest.sha256")
  for (name in upload_files) r2_upload(file.path(output_dir, name), paste0(prefix, name))
}
message("M3-refined candidate written to: ", output_dir)
print(audit, n = Inf)
