# Diagnostic comparison only: never writes canonical releases or contacts R2.
# Usage: Rscript scripts/audit-chn-qar-verification.R <restricted-run-directory>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
run <- normalizePath(args[[1]], mustWork = TRUE)
store <- normalizePath(Sys.getenv("FUELBURN_DATA_STORE", ".fuelburn-data-store"), mustWork = TRUE)
stopifnot(startsWith(run, paste0(store, "/")))
suppressPackageStartupMessages({library(dplyr); library(readr); library(purrr)})
reference <- list.files(file.path(run, "helper-reference"), "^canonical-fuel-milestones[.]R$", recursive = TRUE, full.names = TRUE)
stopifnot(length(reference) == 1L)
source(reference)
out <- file.path(run, "evidence")
dir.create(out, showWarnings = FALSE)
cases <- read_csv(file.path(run, "requested-cases.csv"), col_types = cols(.default = "c"))
controls <- read_csv(file.path(run, "control-cases.csv"), col_types = cols(.default = "c"))
cases <- bind_rows(cases, controls)
stopifnot(!anyDuplicated(cases$SOURCE_UID), all(file.exists(cases$path)))
airport <- tibble(ICAO = c("ZBAA", "ZSSS", "ZLXY", "ZGGG", "ZPPP"),
                  LAT = c(40.0801, 31.1979, 34.4471, 23.3924, 24.9928),
                  LON = c(116.5846, 121.3364, 108.7514, 113.2988, 102.7412))
returned_files <- function(name) list.files(file.path(run, "returned-batches"), paste0("^", name, "$"), recursive = TRUE, full.names = TRUE)
read_returned <- function(name) map_dfr(returned_files(name), function(p) {
  arrow::read_parquet(p) |> mutate(source_batch = basename(dirname(p)))
})
delivered <- read_returned("CHN-canonical-milestones[.]parquet")
delivered_phases <- read_returned("CHN-phase-summaries[.]parquet")
delivered_levels <- read_returned("CHN-level-segments[.]parquet")
write_csv(delivered |> filter(SOURCE_UID %in% cases$SOURCE_UID), file.path(out, "returned-selected-milestones.csv"))
write_csv(delivered_phases |> filter(SOURCE_UID %in% cases$SOURCE_UID), file.path(out, "returned-selected-phases.csv"))
write_csv(delivered_levels |> filter(SOURCE_UID %in% cases$SOURCE_UID), file.path(out, "returned-selected-levels.csv"))

# Compare by explicit keys, including missing key values. Every mismatching field
# is retained locally; numeric equality permits only serialization-scale error.
compare_tables <- function(a, b, keys, label) {
  key <- function(x) do.call(paste, c(lapply(x[keys], function(v) ifelse(is.na(v), "<NA>", as.character(v))), sep = "|"))
  ka <- key(a); kb <- key(b)
  stopifnot(!anyDuplicated(ka), !anyDuplicated(kb))
  ai <- match(intersect(ka, kb), ka); bi <- match(intersect(ka, kb), kb)
  common <- intersect(names(a), names(b))
  diffs <- map_dfr(common, function(col) {
    x <- a[[col]][ai]; y <- b[[col]][bi]
    num <- is.numeric(x) || inherits(x, "POSIXt")
    if (num) {
      delta <- as.numeric(x) - as.numeric(y)
      same <- (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & abs(delta) <= 1e-6)
    } else {
      delta <- rep(NA_real_, length(x))
      same <- (is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & as.character(x) == as.character(y))
    }
    bad <- which(is.na(same) | !same)
    tibble(comparison = label, key = ka[ai[bad]], field = col,
           reference = as.character(x[bad]), diagnostic = as.character(y[bad]), delta = delta[bad])
  })
  write_csv(diffs, file.path(out, paste0(label, "-field-differences.csv")))
  tibble(comparison = label, reference_rows = nrow(a), diagnostic_rows = nrow(b),
         common_keys = length(ai), reference_only_keys = sum(!ka %in% kb),
         diagnostic_only_keys = sum(!kb %in% ka), mismatching_fields = nrow(diffs),
         reference_only_columns = paste(setdiff(names(a), names(b)), collapse = ";"),
         diagnostic_only_columns = paste(setdiff(names(b), names(a)), collapse = ";"))
}
consolidation <- list()
for (item in list(list("canonical-milestones", delivered, c("source_batch", "SOURCE_UID", "MST", "ROW_ID", "LEVEL_SEGMENT_ID")),
                  list("phase-summaries", delivered_phases, c("source_batch", "SOURCE_UID", "PHASE")),
                  list("level-segments", delivered_levels, c("source_batch", "SOURCE_UID", "LEVEL_SEGMENT_ID")))) {
  production <- arrow::read_parquet(file.path(store, "processed/chn", paste0("CHN-", item[[1]], "-summer2025.parquet")))
  consolidation[[item[[1]]]] <- compare_tables(item[[2]], production, item[[3]], paste0("consolidation-", item[[1]]))
}
write_csv(bind_rows(consolidation), file.path(out, "consolidation-comparison.csv"))

metrics <- list(); comparisons <- list(); events <- list(); phasechecks <- list(); units <- list(); rawschema <- list(); runtime_issues <- list(); clocks <- list()
finite_min <- function(x) if (any(is.finite(x))) min(x[is.finite(x)]) else NA_real_
finite_max <- function(x) if (any(is.finite(x))) max(x[is.finite(x)]) else NA_real_
for (i in seq_len(nrow(cases))) {
  cc <- cases[i, ]; uid <- cc$SOURCE_UID
  raw <- data.table::fread(cc$path, check.names = TRUE)
  names(raw) <- make.names(toupper(names(raw)), unique = TRUE)
  rawschema[[i]] <- tibble(case = cc$case, SOURCE_UID = uid, column = names(raw), type = vapply(raw, function(x) paste(class(x), collapse = "/"), ""))
  clocks[[i]] <- map_dfr(grep("^TIME([.][0-9]+)?$", names(raw), value = TRUE), function(col) {
    sec <- as.numeric(hms::as_hms(raw[[col]])); dd <- diff(sec)
    tibble(case = cc$case, SOURCE_UID = uid, column = col, helper_selected = col == ifelse("TIME.1" %in% names(raw), "TIME.1", "TIME"),
           duplicate_steps = sum(dd == 0, na.rm = TRUE), backward_steps = sum(dd < 0, na.rm = TRUE),
           small_backward_steps = sum(dd < 0 & dd > -43200, na.rm = TRUE),
           helper_elapsed_min = (tail(sec, 1) - head(sec, 1) + 86400 * sum(dd < 0, na.rm = TRUE)) / 60,
           positive_step_median_s = if (any(dd > 0, na.rm = TRUE)) median(dd[dd > 0], na.rm = TRUE) else NA_real_)
  })
  ww <- character()
  tr <- withCallingHandlers(fuel_read_chn_qar_csv(cc$path, fuel_flow_unit = "auto"),
    warning = function(w) {ww <<- c(ww, conditionMessage(w)); invokeRestart("muffleWarning")})
  helper_error <- NA_character_
  result <- tryCatch(withCallingHandlers({
    ms <- fuel_chn_milestones(tr, airport_meta = airport)
    list(ms = ms, ph = fuel_phase_summaries(ms), lv = fuel_level_segments_from_milestones(ms))
  }, warning = function(w) {ww <<- c(ww, conditionMessage(w)); invokeRestart("muffleWarning")}),
  error = function(e) {helper_error <<- conditionMessage(e); NULL})
  runtime_issues[[i]] <- tibble(case = cc$case, SOURCE_UID = uid, helper_error = helper_error,
                               warnings = paste(unique(ww), collapse = "\n"))
  ms <- if (is.null(result)) delivered[0, ] else result$ms
  ph <- if (is.null(result)) delivered_phases[0, ] else result$ph
  lv <- if (is.null(result)) delivered_levels[0, ] else result$lv
  units[[i]] <- fuel_flow_unit_qc(list(tr)) |> mutate(case = cc$case)
  a <- delivered |> filter(SOURCE_UID == uid)
  ap <- delivered_phases |> filter(SOURCE_UID == uid)
  al <- delivered_levels |> filter(SOURCE_UID == uid)
  if (nrow(a) && is.na(helper_error)) {
    stopifnot(all(a$source_batch == cc$source_batch))
    comparisons[[paste0(i, "m")]] <- compare_tables(a, ms, c("SOURCE_UID", "MST", "ROW_ID", "LEVEL_SEGMENT_ID"), paste0("case-", cc$case, "-milestones"))
    comparisons[[paste0(i, "p")]] <- compare_tables(ap, ph, c("SOURCE_UID", "PHASE"), paste0("case-", cc$case, "-phases"))
    comparisons[[paste0(i, "l")]] <- compare_tables(al, lv, c("SOURCE_UID", "LEVEL_SEGMENT_ID"), paste0("case-", cc$case, "-levels"))
  }
  if (cc$role == "representative_control" && is.na(helper_error)) {
    old <- read_csv(file.path(run, "provenance/historical-modern-canonical.csv"), show_col_types = FALSE) |>
      filter(SOURCE_UID == uid)
    # The earlier reference predates enriched distance/level markers. Compare
    # shared operational events only, preserving any changed selection explicitly.
    shared_events <- intersect(intersect(old$MST, ms$MST), c("AOBT", "ERWY", "ATOT", "DLTO", "TOC", "TOD", "ALTO", "ALDT", "XRWY", "AIBT"))
    # This reference includes an airport outside the packaged study-pair table.
    # Keep its expected spatial-metadata differences in a separate comparison.
    fields <- setdiff(intersect(names(old), names(ms)), c("DIST_FROM_DEP_NM", "DIST_TO_ARR_NM"))
    comparisons[[paste0(i, "h")]] <- compare_tables(old |> filter(MST %in% shared_events) |> select(all_of(fields)),
      ms |> filter(MST %in% shared_events) |> select(all_of(fields)), c("SOURCE_UID", "MST"), paste0("case-", cc$case, "-historical-operational-events"))
    compare_tables(old |> filter(MST %in% intersect(old$MST, ms$MST)),
      ms |> filter(MST %in% intersect(old$MST, ms$MST)), c("SOURCE_UID", "MST"), paste0("case-", cc$case, "-historical-all-common-events"))
  }
  # Independent great-circle calculation: vector cross/dot atan2, radius in NM.
  xyz <- function(lat, lon) cbind(cos(lat*pi/180)*cos(lon*pi/180), cos(lat*pi/180)*sin(lon*pi/180), sin(lat*pi/180))
  v <- xyz(tr$LAT, tr$LON); u <- v[c(seq.int(2L, nrow(v)), nrow(v)), , drop = FALSE]
  cross <- cbind(v[,2]*u[,3]-v[,3]*u[,2], v[,3]*u[,1]-v[,1]*u[,3], v[,1]*u[,2]-v[,2]*u[,1])
  independent_leg <- 6371 / 1.852 * atan2(sqrt(rowSums(cross^2)), rowSums(v*u))
  true_dt <- c(diff(as.numeric(tr$TIME)), 0)
  speed_nm <- tr$GS * true_dt / 3600
  implied_kt <- ifelse(true_dt > 0, independent_leg / true_dt * 3600, NA_real_)
  from_start_dist <- c(0, head(cumsum(independent_leg), -1))
  helper_dist_at_time <- c(0, head(cumsum(tr$DISTANCE_NM), -1))
  from_start_fuel <- c(0, head(cumsum(tr$FF_TOTAL_KGPH * true_dt / 3600), -1))
  tc <- if ("TIME.1" %in% names(raw)) "TIME.1" else "TIME"
  clock <- as.numeric(hms::as_hms(raw[[tc]])); clock_delta <- diff(clock)
  altcols <- grep("^ALT_STD", names(raw), value = TRUE)
  rawphase <- suppressWarnings(as.numeric(raw$FLIGHT_PHASE))
  # Screens identify candidate anomalies; 750 kt is a diagnostic screen, not a
  # source-cleaning rule or an eligibility decision.
  badcoord <- !is.finite(raw$LATP) | !is.finite(raw$LONP) | abs(raw$LATP) > 90 | abs(raw$LONP) > 180
  zero <- raw$LATP == 0 | raw$LONP == 0
  metrics[[i]] <- tibble(case = cc$case, role = cc$role, SOURCE_UID = uid, source_batch = cc$source_batch,
    rows = nrow(tr), helper_error = helper_error, returned_milestones = nrow(a), returned_phases = nrow(ap),
    returned_levels = nrow(al), diagnostic_milestones = nrow(ms), diagnostic_phases = nrow(ph), diagnostic_levels = nrow(lv),
    time_span_min = diff(range(as.numeric(tr$TIME))) / 60,
    clock_backward = sum(clock_delta < 0, na.rm = TRUE), clock_small_backward = sum(clock_delta < 0 & clock_delta > -43200, na.rm = TRUE),
    duplicate_clock = sum(clock_delta == 0, na.rm = TRUE), gaps_over_300s = sum(true_dt > 300),
    invalid_coordinate_rows = sum(badcoord), zero_coordinate_rows = sum(zero, na.rm = TRUE),
    coordinate_missing_rows = sum(is.na(raw$LATP) | is.na(raw$LONP)),
    speed_missing_rows = sum(is.na(tr$GS)), speed_min = finite_min(tr$GS), speed_max = finite_max(tr$GS),
    path_nm = sum(independent_leg), helper_path_nm = sum(tr$DISTANCE_NM), speed_integral_nm_assuming_knots = sum(speed_nm, na.rm = TRUE),
    legs_above_750kt = sum(implied_kt > 750, na.rm = TRUE), max_leg_nm = max(independent_leg), max_implied_kt = max(implied_kt, na.rm = TRUE),
    distance_vs_helper_max_nm = max(abs(independent_leg-tr$DISTANCE_NM)),
    first_alt_ft = first(tr$ALT_FT), last_alt_ft = last(tr$ALT_FT), min_alt_ft = finite_min(tr$ALT_FT), max_alt_ft = finite_max(tr$ALT_FT),
    missing_altitude_rows = sum(!is.finite(tr$ALT_FT)),
    last_300_median_alt_ft = median(tail(tr$ALT_FT, 300)), altitude_columns = length(altcols),
    altitude_sensor_max_spread_ft = finite_max(apply(as.matrix(raw[, ..altcols]), 1, function(x) if (any(is.finite(x))) diff(range(x[is.finite(x)])) else NA_real_)),
    phase12_rows = sum(rawphase == 12, na.rm = TRUE), phase14_rows = sum(rawphase == 14, na.rm = TRUE),
    final_phase = last(rawphase), final_gs = last(tr$GS),
    raw_flow_total_kg = sum(tr$FUEL_BURNT_KG_ORIGINAL), clean_flow_total_kg = sum(tr$FUEL_BURNT_KG),
    spike_rows = sum(tr$FF_SPIKE_FLAG), inferred_unit = first(tr$FF_UNIT_INFERRED),
    unit_confidence = first(tr$FF_UNIT_CONFIDENCE), unit_review = first(tr$FF_UNIT_REVIEW_REQUIRED),
    ALDT_present = if (is.na(helper_error)) "ALDT" %in% ms$MST else NA,
    TOC_present = if (is.na(helper_error)) "TOC" %in% ms$MST else NA,
    TOD_present = if (is.na(helper_error)) "TOD" %in% ms$MST else NA)
  # Preserve event neighborhoods and all suspect coordinate legs locally.
  er <- unique(c(1:3, (nrow(tr)-2):nrow(tr), ms$ROW_ID[!ms$MST %in% c("LVL_START", "LVL_END")],
                 which(implied_kt > 750), which(implied_kt > 750) + 1L))
  er <- er[is.finite(er) & er >= 1 & er <= nrow(tr)]
  events[[i]] <- tr[sort(er), c("TIME", "LATP", "LONP", "LAT", "LON", "ALT_FT", "GS", "FLIGHT_PHASE_RAW", "DISTANCE_NM", "DT_SEC", "TOT_FUEL_KG", "DIST_FLOWN_NM")] |>
    mutate(case = cc$case, SOURCE_UID = uid, ROW_ID = sort(er),
           independent_leg_nm = independent_leg[sort(er)], implied_kt = implied_kt[sort(er)],
           distance_at_timestamp_nm = from_start_dist[sort(er)], fuel_at_timestamp_kg = from_start_fuel[sort(er)])
  phasechecks[[i]] <- map_dfr(seq_len(nrow(ph)), function(j) {
    f <- ms$ROW_ID[ms$MST == ph$FROM_MST[j]]; t <- ms$ROW_ID[ms$MST == ph$TO_MST[j]]
    stopifnot(length(f) == 1, length(t) == 1)
    correct_distance <- helper_dist_at_time[t] - helper_dist_at_time[f]
    correct_fuel <- from_start_fuel[t] - from_start_fuel[f]
    tibble(case = cc$case, SOURCE_UID = uid, PHASE = ph$PHASE[j], from_row = f, to_row = t,
           duration_min = ph$DURATION_MIN[j], helper_distance_nm = ph$DISTANCE_NM[j],
           timestamp_distance_nm = correct_distance, distance_shift_nm = ph$DISTANCE_NM[j] - correct_distance,
           independent_timestamp_distance_nm = from_start_dist[t] - from_start_dist[f],
           speed_integral_nm_assuming_knots = sum(speed_nm[seq.int(f, max(f, t - 1L))]) * as.numeric(t > f),
           helper_fuel_kg = ph$FUEL_KG[j], timestamp_fuel_kg = correct_fuel, fuel_shift_kg = ph$FUEL_KG[j] - correct_fuel,
           boundary_distance_identity_error = ph$DISTANCE_NM[j] - correct_distance - tr$DISTANCE_NM[t] + tr$DISTANCE_NM[f],
           boundary_fuel_identity_error = ph$FUEL_KG[j] - correct_fuel - tr$FUEL_BURNT_KG[t] + tr$FUEL_BURNT_KG[f])
  })
  # Source milestones are kept only as event identifiers for diagnosis, not a
  # regenerated canonical output table.
  write_csv(ms |> filter(!MST %in% c("LVL_START", "LVL_END")) |> select(MST, ROW_ID, TIME, ALT_FT, FLIGHT_PHASE_RAW),
            file.path(out, paste0("case-", cc$case, "-event-selection.csv")))
}
write_csv(bind_rows(metrics), file.path(out, "case-metrics.csv"))
write_csv(bind_rows(comparisons), file.path(out, "helper-comparison.csv"))
write_csv(bind_rows(events), file.path(out, "source-event-evidence.csv"))
write_csv(bind_rows(phasechecks), file.path(out, "phase-boundary-accounting.csv"))
write_csv(bind_rows(units), file.path(out, "unit-evidence.csv"))
write_csv(bind_rows(rawschema), file.path(out, "source-schemas.csv"))
write_csv(bind_rows(runtime_issues), file.path(out, "runtime-issues.csv"))
write_csv(bind_rows(clocks), file.path(out, "clock-candidate-evidence.csv"))
writeLines(c(capture.output(sessionInfo()), paste("Reference SHA256:", digest::digest(file = reference, algo = "sha256")),
             "Configuration: packaged airport table; fuel_flow_unit=auto; original helper functions; no patches"),
           file.path(out, "runtime.txt"))
print(bind_rows(metrics) |> summarise(cases = n(), requested = sum(role == "requested_issue"),
       controls = sum(role != "requested_issue"), with_invalid_coords = sum(invalid_coordinate_rows > 0),
       with_zero_coords = sum(zero_coordinate_rows > 0), with_fast_legs = sum(legs_above_750kt > 0),
       missing_ALDT = sum(!ALDT_present, na.rm = TRUE), helper_failures = sum(!is.na(helper_error))))
print(bind_rows(comparisons) |> summarise(comparisons = n(), reference_only_keys = sum(reference_only_keys),
       diagnostic_only_keys = sum(diagnostic_only_keys), mismatching_fields = sum(mismatching_fields)))
