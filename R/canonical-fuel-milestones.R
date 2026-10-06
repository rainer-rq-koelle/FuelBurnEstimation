# Canonical fuel-burn milestone helpers for CHN/EUR exchange work.

nm_per_km <- 0.539956803

fuel_haversine_nm <- function(lat1, lon1, lat2, lon2) {
  rad <- pi / 180
  dlat <- (lat2 - lat1) * rad
  dlon <- (lon2 - lon1) * rad
  a <- sin(dlat / 2)^2 +
    cos(lat1 * rad) * cos(lat2 * rad) * sin(dlon / 2)^2
  6371 * 2 * atan2(sqrt(a), sqrt(1 - a)) * nm_per_km
}

fuel_parse_chn_filename <- function(path) {
  stem <- tools::file_path_sans_ext(basename(path))
  parts <- strsplit(stem, "_", fixed = TRUE)[[1]]

  if (length(parts) >= 6 && grepl("^B-", parts[1])) {
    flt_idx <- which(grepl("^[A-Z]{2,3}[0-9]+[A-Z]?$", parts))
    flt_idx <- flt_idx[flt_idx > 2][1]
    if (is.na(flt_idx) || flt_idx + 3 > length(parts)) {
      flt_idx <- 3
    }
    tibble::tibble(
      SOURCE_UID = stem,
      DATE = as.Date(parts[flt_idx + 1], format = "%Y%m%d"),
      FLTID = parts[flt_idx],
      TYPE = paste(parts[2:(flt_idx - 1)], collapse = "-"),
      ADEP = parts[flt_idx + 2],
      ADES = parts[flt_idx + 3]
    )
  } else if (length(parts) >= 4) {
    route <- strsplit(parts[4], "-", fixed = TRUE)[[1]]
    tibble::tibble(
      SOURCE_UID = stem,
      DATE = as.Date(parts[1], format = "%Y%m%d"),
      FLTID = parts[2],
      TYPE = parts[3],
      ADEP = route[1],
      ADES = route[2]
    )
  } else {
    tibble::tibble(
      SOURCE_UID = stem,
      DATE = as.Date(NA),
      FLTID = NA_character_,
      TYPE = NA_character_,
      ADEP = NA_character_,
      ADES = NA_character_
    )
  }
}

fuel_make_time <- function(date, time_chr) {
  sec <- hms::as_hms(time_chr) |> as.numeric()
  day_offset <- cumsum(c(0, diff(sec) < 0))
  as.POSIXct(date, tz = "UTC") + sec + day_offset * 86400
}

fuel_first_index <- function(x) {
  idx <- which(x)
  if (length(idx) == 0) NA_integer_ else idx[1]
}

fuel_last_index <- function(x) {
  idx <- which(x)
  if (length(idx) == 0) NA_integer_ else idx[length(idx)]
}

fuel_roll_median <- function(x, k = 11) {
  if (!requireNamespace("zoo", quietly = TRUE) || length(x) < 3) {
    return(x)
  }
  if (k %% 2 == 0) k <- k + 1
  k <- min(k, length(x) - (length(x) + 1) %% 2)
  zoo::rollmedian(x, k = k, fill = NA, align = "center")
}

fuel_fill_numeric_linear <- function(x) {
  x <- as.numeric(x)
  if (!requireNamespace("zoo", quietly = TRUE) || sum(!is.na(x)) < 2) {
    return(x)
  }
  zoo::na.approx(x, na.rm = FALSE) |>
    zoo::na.locf(na.rm = FALSE) |>
    zoo::na.locf(fromLast = TRUE, na.rm = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) y else x
}

fuel_normalise_flow_unit <- function(unit) {
  unit <- tolower(trimws(unit %||% "auto"))
  unit <- gsub("_", "/", unit, fixed = TRUE)

  dplyr::case_when(
    unit %in% c("", "auto", "infer", "inferred") ~ "auto",
    unit %in% c("kg", "kgs", "kg/h", "kg/hr", "kgph", "kilogram", "kilograms", "kilograms/hour") ~ "kg/h",
    unit %in% c("lb", "lbs", "lb/h", "lbs/h", "lb/hr", "lbs/hr", "lbph", "pounds", "pounds/hour") ~ "lb/h",
    TRUE ~ NA_character_
  )
}

fuel_aircraft_fuel_reference <- function(type) {
  type <- toupper(gsub("[^A-Z0-9]", "", type %||% ""))

  if (grepl("^(A319|A320|A321|B737|B738|B739|B73|B38|B39|7M8|7M9|C919)", type)) {
    return(list(
      class = "narrow_body",
      burn_per_nm = c(low = 2.5, typical = 6.0, high = 14.0),
      burn_rate_kgph = c(low = 1200, typical = 3000, high = 6500),
      total_flow_kgph = c(low = 900, typical = 2800, high = 7000)
    ))
  }

  if (grepl("^(A330|A340|A350|A380|B747|B767|B777|B787|B77|B78|B76|B74)", type)) {
    return(list(
      class = "wide_body",
      burn_per_nm = c(low = 7.0, typical = 18.0, high = 45.0),
      burn_rate_kgph = c(low = 3500, typical = 8000, high = 22000),
      total_flow_kgph = c(low = 3000, typical = 8000, high = 26000)
    ))
  }

  if (grepl("^(E17|E19|E2|CRJ|ARJ|AT7|DH8)", type)) {
    return(list(
      class = "regional",
      burn_per_nm = c(low = 1.2, typical = 3.5, high = 9.0),
      burn_rate_kgph = c(low = 500, typical = 1400, high = 3500),
      total_flow_kgph = c(low = 400, typical = 1300, high = 4000)
    ))
  }

  list(
    class = "unknown",
    burn_per_nm = c(low = 1.2, typical = 7.0, high = 45.0),
    burn_rate_kgph = c(low = 500, typical = 3500, high = 22000),
    total_flow_kgph = c(low = 400, typical = 3500, high = 26000)
  )
}

fuel_metric_plausibility_score <- function(value, reference) {
  if (!is.finite(value) || value <= 0) return(NA_real_)

  low <- unname(reference[["low"]])
  typical <- unname(reference[["typical"]])
  high <- unname(reference[["high"]])

  score <- abs(log(value / typical))
  if (value < low) score <- score + 2 * abs(log(value / low))
  if (value > high) score <- score + 2 * abs(log(value / high))
  score
}

fuel_flow_unit_candidate_scores <- function(flow_raw, dt_sec, distance_nm, type) {
  flow_raw <- as.numeric(flow_raw)
  dt_sec <- as.numeric(dt_sec)
  distance_nm <- as.numeric(distance_nm)
  dt_sec[!is.finite(dt_sec) | dt_sec < 0 | dt_sec > 300] <- 0
  distance_nm[!is.finite(distance_nm) | distance_nm < 0] <- 0

  total_time_hr <- sum(dt_sec, na.rm = TRUE) / 3600
  total_distance_nm <- sum(distance_nm, na.rm = TRUE)
  ref <- fuel_aircraft_fuel_reference(type)

  score_one <- function(unit, factor) {
    flow_kgph <- flow_raw * factor
    total_burn_kg <- sum(flow_kgph * dt_sec / 3600, na.rm = TRUE)
    median_total_flow_kgph <- stats::median(flow_kgph[flow_kgph > 0], na.rm = TRUE)
    burn_rate_kgph <- if (total_time_hr > 0) total_burn_kg / total_time_hr else NA_real_
    burn_per_nm <- if (total_distance_nm > 0) total_burn_kg / total_distance_nm else NA_real_

    metric_scores <- c(
      1.00 * fuel_metric_plausibility_score(burn_per_nm, ref$burn_per_nm),
      0.75 * fuel_metric_plausibility_score(burn_rate_kgph, ref$burn_rate_kgph),
      0.50 * fuel_metric_plausibility_score(median_total_flow_kgph, ref$total_flow_kgph)
    )

    tibble::tibble(
      candidate_unit = unit,
      kg_per_raw_unit = factor,
      aircraft_reference_class = ref$class,
      candidate_total_burn_kg = total_burn_kg,
      candidate_burn_per_nm = burn_per_nm,
      candidate_burn_rate_kgph = burn_rate_kgph,
      candidate_median_total_flow_kgph = median_total_flow_kgph,
      candidate_score = sum(metric_scores, na.rm = TRUE),
      candidate_evidence_count = sum(!is.na(metric_scores))
    )
  }

  dplyr::bind_rows(
    score_one("kg/h", 1),
    score_one("lb/h", 0.45359237)
  )
}

fuel_infer_flow_unit <- function(flow_raw, dt_sec, distance_nm, type, requested_unit = "auto") {
  requested_unit <- fuel_normalise_flow_unit(requested_unit)
  if (is.na(requested_unit)) {
    stop("Unsupported fuel-flow unit. Use auto, kg/h, or lb/h.", call. = FALSE)
  }

  scores <- fuel_flow_unit_candidate_scores(flow_raw, dt_sec, distance_nm, type)
  kg <- scores |> dplyr::filter(.data$candidate_unit == "kg/h")
  lb <- scores |> dplyr::filter(.data$candidate_unit == "lb/h")

  best <- scores |>
    dplyr::arrange(.data$candidate_score) |>
    dplyr::slice(1)
  second <- scores |>
    dplyr::arrange(.data$candidate_score) |>
    dplyr::slice(2)

  if (requested_unit != "auto") {
    selected <- scores |> dplyr::filter(.data$candidate_unit == requested_unit)
    return(tibble::tibble(
      FF_UNIT_REQUESTED = requested_unit,
      FF_UNIT_INFERRED = requested_unit,
      FF_UNIT_CONFIDENCE = "forced",
      FF_UNIT_FLAG = "forced_by_user",
      FF_KG_PER_RAW_UNIT = selected$kg_per_raw_unit,
      FF_UNIT_SCORE_KG = kg$candidate_score,
      FF_UNIT_SCORE_LB = lb$candidate_score,
      FF_UNIT_SCORE_GAP = abs(kg$candidate_score - lb$candidate_score),
      FF_BURN_IF_KG = kg$candidate_total_burn_kg,
      FF_BURN_IF_LB = lb$candidate_total_burn_kg,
      FF_BURN_PER_NM_IF_KG = kg$candidate_burn_per_nm,
      FF_BURN_PER_NM_IF_LB = lb$candidate_burn_per_nm,
      FF_BURN_RATE_KGPH_IF_KG = kg$candidate_burn_rate_kgph,
      FF_BURN_RATE_KGPH_IF_LB = lb$candidate_burn_rate_kgph,
      FF_AIRCRAFT_REFERENCE_CLASS = best$aircraft_reference_class,
      FF_UNIT_REVIEW_REQUIRED = FALSE
    ))
  }

  score_gap <- second$candidate_score - best$candidate_score
  confidence <- dplyr::case_when(
    !is.finite(score_gap) | best$candidate_evidence_count == 0 ~ "unknown",
    score_gap >= 0.45 ~ "high",
    score_gap >= 0.20 ~ "medium",
    TRUE ~ "low"
  )
  flag <- dplyr::case_when(
    confidence == "high" ~ "ok_auto_inferred",
    confidence == "medium" ~ "review_auto_medium_confidence",
    confidence == "unknown" ~ "review_insufficient_evidence",
    TRUE ~ "review_ambiguous_unit"
  )

  tibble::tibble(
    FF_UNIT_REQUESTED = "auto",
    FF_UNIT_INFERRED = best$candidate_unit,
    FF_UNIT_CONFIDENCE = confidence,
    FF_UNIT_FLAG = flag,
    FF_KG_PER_RAW_UNIT = best$kg_per_raw_unit,
    FF_UNIT_SCORE_KG = kg$candidate_score,
    FF_UNIT_SCORE_LB = lb$candidate_score,
    FF_UNIT_SCORE_GAP = score_gap,
    FF_BURN_IF_KG = kg$candidate_total_burn_kg,
    FF_BURN_IF_LB = lb$candidate_total_burn_kg,
    FF_BURN_PER_NM_IF_KG = kg$candidate_burn_per_nm,
    FF_BURN_PER_NM_IF_LB = lb$candidate_burn_per_nm,
    FF_BURN_RATE_KGPH_IF_KG = kg$candidate_burn_rate_kgph,
    FF_BURN_RATE_KGPH_IF_LB = lb$candidate_burn_rate_kgph,
    FF_AIRCRAFT_REFERENCE_CLASS = best$aircraft_reference_class,
    FF_UNIT_REVIEW_REQUIRED = confidence != "high"
  )
}

fuel_clean_flow_spikes <- function(flow_kgph, window = 11, ratio_threshold = 4, min_delta_kgph = 1500) {
  raw <- as.numeric(flow_kgph)
  med <- fuel_roll_median(raw, k = window)
  med[is.na(med)] <- raw[is.na(med)]

  is_spike <- !is.na(raw) & !is.na(med) &
    med > 0 &
    raw > med * ratio_threshold &
    (raw - med) > min_delta_kgph

  cleaned <- raw
  cleaned[is_spike] <- med[is_spike]

  tibble::tibble(
    FF_TOTAL_RAW_KGPH = raw,
    FF_TOTAL_KGPH = cleaned,
    FF_SPIKE_FLAG = is_spike,
    FF_SPIKE_DELTA_KGPH = dplyr::if_else(is_spike, raw - cleaned, 0)
  )
}

fuel_read_chn_qar_csv <- function(path, date = NULL, fuel_flow_unit = Sys.getenv("CHN_QAR_FUEL_FLOW_UNIT", unset = "auto")) {
  meta <- fuel_parse_chn_filename(path)
  if (is.null(date)) date <- meta$DATE[[1]]

  dt <- data.table::fread(path, check.names = TRUE)
  names(dt) <- make.names(toupper(names(dt)), unique = TRUE)

  alt_cols <- grep("^ALT_STD", names(dt), value = TRUE)
  ff_cols <- intersect(c("FF1C", "FF2C", "FF3C", "FF4C"), names(dt))
  time_col <- if ("TIME.1" %in% names(dt)) "TIME.1" else "TIME"

  if (!time_col %in% names(dt)) stop("QAR file has no TIME column: ", path)
  if (length(alt_cols) == 0) stop("QAR file has no ALT_STD column: ", path)
  if (length(ff_cols) == 0) stop("QAR file has no FF*C fuel-flow columns: ", path)

  phase_vec <- if ("FLIGHT_PHASE" %in% names(dt)) as.character(dt$FLIGHT_PHASE) else NA_character_
  ias_vec <- if ("IASC" %in% names(dt)) dt$IASC else if ("IAS" %in% names(dt)) dt$IAS else NA_real_
  gs_vec <- if ("GS" %in% names(dt)) dt$GS else NA_real_

	  out <- tibble::as_tibble(dt) |>
	    dplyr::mutate(
	      TIME = fuel_make_time(date, .data[[time_col]]),
	      LAT = fuel_fill_numeric_linear(.data$LATP),
	      LON = fuel_fill_numeric_linear(.data$LONP),
      ALT_FT = rowMeans(dplyr::pick(dplyr::all_of(alt_cols)), na.rm = TRUE),
      IASC = ias_vec,
      GS = gs_vec,
      FLIGHT_PHASE_RAW = phase_vec,
      FF_TOTAL_RAW = rowSums(dplyr::pick(dplyr::all_of(ff_cols)), na.rm = TRUE)
    )

  out <- out |>
    dplyr::arrange(.data$TIME) |>
    dplyr::mutate(
      DT_SEC = as.numeric(difftime(dplyr::lead(.data$TIME), .data$TIME, units = "secs")),
      DT_SEC = dplyr::if_else(is.na(.data$DT_SEC) | .data$DT_SEC < 0 | .data$DT_SEC > 300, 0, .data$DT_SEC),
      DISTANCE_NM = fuel_haversine_nm(.data$LAT, .data$LON, dplyr::lead(.data$LAT), dplyr::lead(.data$LON)),
      DISTANCE_NM = dplyr::if_else(is.na(.data$DISTANCE_NM), 0, .data$DISTANCE_NM)
    )

  unit_info <- fuel_infer_flow_unit(
    flow_raw = out$FF_TOTAL_RAW,
    dt_sec = out$DT_SEC,
    distance_nm = out$DISTANCE_NM,
    type = meta$TYPE[[1]],
    requested_unit = fuel_flow_unit
  )

  out <- out |>
    dplyr::mutate(
      FF_UNIT_REQUESTED = unit_info$FF_UNIT_REQUESTED[[1]],
      FF_UNIT_INFERRED = unit_info$FF_UNIT_INFERRED[[1]],
      FF_UNIT_CONFIDENCE = unit_info$FF_UNIT_CONFIDENCE[[1]],
      FF_UNIT_FLAG = unit_info$FF_UNIT_FLAG[[1]],
      FF_KG_PER_RAW_UNIT = unit_info$FF_KG_PER_RAW_UNIT[[1]],
      FF_UNIT_SCORE_KG = unit_info$FF_UNIT_SCORE_KG[[1]],
      FF_UNIT_SCORE_LB = unit_info$FF_UNIT_SCORE_LB[[1]],
      FF_UNIT_SCORE_GAP = unit_info$FF_UNIT_SCORE_GAP[[1]],
      FF_BURN_IF_KG = unit_info$FF_BURN_IF_KG[[1]],
      FF_BURN_IF_LB = unit_info$FF_BURN_IF_LB[[1]],
      FF_BURN_PER_NM_IF_KG = unit_info$FF_BURN_PER_NM_IF_KG[[1]],
      FF_BURN_PER_NM_IF_LB = unit_info$FF_BURN_PER_NM_IF_LB[[1]],
      FF_BURN_RATE_KGPH_IF_KG = unit_info$FF_BURN_RATE_KGPH_IF_KG[[1]],
      FF_BURN_RATE_KGPH_IF_LB = unit_info$FF_BURN_RATE_KGPH_IF_LB[[1]],
      FF_AIRCRAFT_REFERENCE_CLASS = unit_info$FF_AIRCRAFT_REFERENCE_CLASS[[1]],
      FF_UNIT_REVIEW_REQUIRED = unit_info$FF_UNIT_REVIEW_REQUIRED[[1]],
      FF_TOTAL_RAW_KGPH = .data$FF_TOTAL_RAW * .data$FF_KG_PER_RAW_UNIT
    )

  out <- out |>
    dplyr::bind_cols(fuel_clean_flow_spikes(out$FF_TOTAL_RAW_KGPH) |> dplyr::select(-FF_TOTAL_RAW_KGPH)) |>
    dplyr::mutate(
      FUEL_BURNT_KG_ORIGINAL = .data$FF_TOTAL_RAW_KGPH * .data$DT_SEC / 3600,
      FUEL_BURNT_KG = .data$FF_TOTAL_KGPH * .data$DT_SEC / 3600,
      TOT_FUEL_KG = cumsum(.data$FUEL_BURNT_KG),
      TOT_FUEL_KG_ORIGINAL = cumsum(.data$FUEL_BURNT_KG_ORIGINAL),
      DIST_FLOWN_NM = cumsum(.data$DISTANCE_NM)
    ) |>
    dplyr::bind_cols(meta[rep(1, nrow(dt)), ])

  out
}

fuel_flow_unit_qc <- function(trajectories) {
  trj <- if (is.list(trajectories)) dplyr::bind_rows(trajectories) else trajectories

  trj |>
    dplyr::summarise(
      FLTID = dplyr::first(.data$FLTID),
      ADEP = dplyr::first(.data$ADEP),
      ADES = dplyr::first(.data$ADES),
      TYPE = dplyr::first(.data$TYPE),
      rows = dplyr::n(),
      duration_min = sum(.data$DT_SEC, na.rm = TRUE) / 60,
      distance_nm = max(.data$DIST_FLOWN_NM, na.rm = TRUE),
      raw_total_flow_median = stats::median(.data$FF_TOTAL_RAW[.data$FF_TOTAL_RAW > 0], na.rm = TRUE),
      selected_total_fuel_kg = max(.data$TOT_FUEL_KG, na.rm = TRUE),
      selected_total_fuel_kg_original = max(.data$TOT_FUEL_KG_ORIGINAL, na.rm = TRUE),
      burn_if_kg = dplyr::first(.data$FF_BURN_IF_KG),
      burn_if_lb = dplyr::first(.data$FF_BURN_IF_LB),
      burn_per_nm_if_kg = dplyr::first(.data$FF_BURN_PER_NM_IF_KG),
      burn_per_nm_if_lb = dplyr::first(.data$FF_BURN_PER_NM_IF_LB),
      burn_rate_kgph_if_kg = dplyr::first(.data$FF_BURN_RATE_KGPH_IF_KG),
      burn_rate_kgph_if_lb = dplyr::first(.data$FF_BURN_RATE_KGPH_IF_LB),
      inferred_unit = dplyr::first(.data$FF_UNIT_INFERRED),
      requested_unit = dplyr::first(.data$FF_UNIT_REQUESTED),
      unit_confidence = dplyr::first(.data$FF_UNIT_CONFIDENCE),
      unit_flag = dplyr::first(.data$FF_UNIT_FLAG),
      unit_score_kg = dplyr::first(.data$FF_UNIT_SCORE_KG),
      unit_score_lb = dplyr::first(.data$FF_UNIT_SCORE_LB),
      unit_score_gap = dplyr::first(.data$FF_UNIT_SCORE_GAP),
      aircraft_reference_class = dplyr::first(.data$FF_AIRCRAFT_REFERENCE_CLASS),
      review_required = dplyr::first(.data$FF_UNIT_REVIEW_REQUIRED),
      .by = SOURCE_UID
    ) |>
    dplyr::arrange(dplyr::desc(.data$review_required), .data$unit_confidence, .data$SOURCE_UID)
}

fuel_append_airport_distances <- function(trj, airport_meta) {
  apt <- airport_meta |>
    dplyr::select(ICAO, LAT, LON)

	  dep <- apt |>
	    dplyr::rename(ADEP = ICAO, ADEP_LAT = LAT, ADEP_LON = LON)
	  arr <- apt |>
	    dplyr::rename(ADES = ICAO, ADES_LAT = LAT, ADES_LON = LON)

  trj |>
    dplyr::left_join(dep, by = "ADEP") |>
    dplyr::left_join(arr, by = "ADES") |>
    dplyr::mutate(
      DIST_FROM_DEP_NM = fuel_haversine_nm(.data$LAT, .data$LON, .data$ADEP_LAT, .data$ADEP_LON),
      DIST_TO_ARR_NM = fuel_haversine_nm(.data$LAT, .data$LON, .data$ADES_LAT, .data$ADES_LON)
    )
}

fuel_vertical_profile <- function(trj, altitude_col = "ALT_FT", time_col = "TIME") {
  trj |>
    dplyr::arrange(.data[[time_col]]) |>
    dplyr::mutate(
      ALT_SMOOTH_FT = fuel_roll_median(.data[[altitude_col]], k = 31),
      ALT_SMOOTH_FT = dplyr::coalesce(.data$ALT_SMOOTH_FT, .data[[altitude_col]]),
      DT_SEC_PREV = as.numeric(difftime(.data[[time_col]], dplyr::lag(.data[[time_col]]), units = "secs")),
      ALT_DIFF_PREV = .data$ALT_SMOOTH_FT - dplyr::lag(.data$ALT_SMOOTH_FT),
      VERTICAL_RATE_FPM = .data$ALT_DIFF_PREV / (.data$DT_SEC_PREV / 60),
      VERTICAL_RATE_FPM = dplyr::if_else(
        is.finite(.data$VERTICAL_RATE_FPM) & .data$DT_SEC_PREV > 0 & .data$DT_SEC_PREV <= 300,
        .data$VERTICAL_RATE_FPM,
        NA_real_
      ),
      IS_LEVEL = !is.na(.data$VERTICAL_RATE_FPM) & abs(.data$VERTICAL_RATE_FPM) <= 300
    )
}

fuel_first_sustained_index <- function(cond, dt_sec, min_duration_sec = 120) {
  cond[is.na(cond)] <- FALSE
  dt_sec[is.na(dt_sec) | dt_sec < 0 | dt_sec > 300] <- 0

  starts <- which(cond & !dplyr::lag(cond, default = FALSE))
  for (start in starts) {
    end <- start
    while (end < length(cond) && cond[end + 1]) end <- end + 1
    if (sum(dt_sec[start:end], na.rm = TRUE) >= min_duration_sec) {
      return(start)
    }
  }
  NA_integer_
}

fuel_vfe_toc_tod <- function(trj, dlto, alto) {
  if (is.na(dlto) || is.na(alto) || dlto >= alto) {
    max_idx <- fuel_first_index(trj$ALT_FT == max(trj$ALT_FT, na.rm = TRUE))
    return(list(TOC = max_idx, TOD = max_idx))
  }

  d200 <- if ("DIST_FROM_DEP_NM" %in% names(trj)) {
    fuel_first_index(trj$DIST_FROM_DEP_NM >= 200)
  } else {
    NA_integer_
  }
  a200 <- if ("DIST_TO_ARR_NM" %in% names(trj)) {
    fuel_first_index(seq_len(nrow(trj)) > dlto & trj$DIST_TO_ARR_NM <= 200)
  } else {
    NA_integer_
  }

  profile <- fuel_vertical_profile(trj)
  row_id <- seq_len(nrow(profile))
  climb_end <- if (!is.na(a200)) max(dlto, a200 - 1L) else alto
  climb_window <- row_id >= dlto & row_id <= climb_end
  top_alt <- max(profile$ALT_SMOOTH_FT[climb_window], na.rm = TRUE)
  if (!is.finite(top_alt)) top_alt <- max(profile$ALT_SMOOTH_FT, na.rm = TRUE)
  cruise_band_floor <- top_alt - max(1000, top_alt * 0.03)

  toc_candidate <- fuel_first_sustained_index(
    climb_window &
      profile$ALT_SMOOTH_FT >= cruise_band_floor &
      dplyr::coalesce(profile$VERTICAL_RATE_FPM, 0) <= 300,
    profile$DT_SEC_PREV,
    min_duration_sec = 120
  )
  toc <- if (!is.na(toc_candidate)) {
    toc_candidate
  } else {
    fuel_first_index(climb_window & profile$ALT_SMOOTH_FT == top_alt)
  }

  descent_start <- if (!is.na(a200)) a200 else if (!is.na(toc)) toc else d200
  descent_window <- row_id >= descent_start & row_id <= alto
  tod_candidate <- fuel_first_sustained_index(
    descent_window &
      profile$ALT_SMOOTH_FT >= 3000 &
      dplyr::coalesce(profile$VERTICAL_RATE_FPM, 0) <= -300,
    profile$DT_SEC_PREV,
    min_duration_sec = 120
  )
  tod <- if (!is.na(tod_candidate)) {
    tod_candidate
  } else {
    fuel_last_index(descent_window & profile$ALT_SMOOTH_FT >= cruise_band_floor)
  }

  if (is.na(tod) || (!is.na(toc) && tod < toc)) {
    tod <- fuel_last_index(row_id >= toc & row_id <= alto & profile$ALT_SMOOTH_FT >= cruise_band_floor)
  }

  list(TOC = toc, TOD = tod)
}

fuel_snapshot_rows <- function(trj, milestone_index) {
  milestone_index |>
    dplyr::filter(!is.na(.data$ROW_ID)) |>
    dplyr::inner_join(
      trj |>
        dplyr::mutate(ROW_ID = dplyr::row_number()),
      by = "ROW_ID"
    ) |>
    dplyr::transmute(
      SOURCE_UID, FLTID, ADEP, ADES, TYPE,
      TIME, LAT, LON, ALT_FT,
      MST,
      TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM,
      DIST_FROM_DEP_NM = dplyr::coalesce(.data$DIST_FROM_DEP_NM, NA_real_),
      DIST_TO_ARR_NM = dplyr::coalesce(.data$DIST_TO_ARR_NM, NA_real_),
      FLIGHT_PHASE_RAW = dplyr::coalesce(.data$FLIGHT_PHASE_RAW, NA_character_),
      ROW_ID
    ) |>
    dplyr::arrange(.data$TIME, .data$ROW_ID, .data$MST)
}

fuel_chn_milestones <- function(trj, airport_meta = NULL) {
  if (!is.null(airport_meta)) {
    trj <- fuel_append_airport_distances(trj, airport_meta)
  }

	  trj <- trj |>
	    dplyr::arrange(.data$TIME) |>
	    dplyr::mutate(ROW_ID = dplyr::row_number())

	  phase_num <- suppressWarnings(as.numeric(trj$FLIGHT_PHASE_RAW))
	  dep_ground_alt <- stats::median(utils::head(trj$ALT_FT, min(300, nrow(trj))), na.rm = TRUE)
	  runway_roll <- (phase_num %in% c(3, 5)) | (trj$GS > 30 & trj$ALT_FT < 1500)
	  airborne <- (phase_num %in% 6:12) |
	    (!is.na(trj$GS) & trj$GS > 80 & (trj$ALT_FT - dep_ground_alt) > 100)
	  taxi_in <- as.numeric(trj$FLIGHT_PHASE_RAW) == 14
	  landing <- phase_num == 12

	  atot <- fuel_first_index(airborne)
	  erwy <- fuel_first_index(runway_roll)
	  if (is.na(erwy)) erwy <- max(1L, atot - 1L, na.rm = TRUE)
	  if (is.na(atot)) atot <- fuel_first_index((trj$ALT_FT - dep_ground_alt) > 100)
	  if (!is.na(erwy) && !is.na(atot) && erwy >= atot) {
	    erwy <- fuel_last_index(seq_len(nrow(trj)) < atot & trj$ALT_FT < 1000 & trj$GS > 20)
	  }
	  if (is.na(erwy) && !is.na(atot)) {
	    erwy <- max(1L, atot - 30L)
	  }
	  alto <- fuel_first_index(
	    seq_len(nrow(trj)) > atot &
	      trj$ALT_FT <= 3000 &
	      trj$DIST_FLOWN_NM > stats::median(trj$DIST_FLOWN_NM, na.rm = TRUE)
	  )
	  aldt <- fuel_first_index(seq_len(nrow(trj)) >= alto & (landing | trj$ALT_FT <= 100))
	  dlto <- fuel_first_index(seq_len(nrow(trj)) >= atot & trj$ALT_FT >= 3000)
	  vfe <- fuel_vfe_toc_tod(trj, dlto = dlto, alto = alto)

	  idx <- tibble::tribble(
	    ~MST, ~ROW_ID,
	    "AOBT", 1L,
	    "ERWY", erwy,
	    "ATOT", atot,
	    "DLTO", dlto,
	    "D40", if ("DIST_FROM_DEP_NM" %in% names(trj)) fuel_first_index(trj$DIST_FROM_DEP_NM >= 40) else NA_integer_,
	    "D100", if ("DIST_FROM_DEP_NM" %in% names(trj)) fuel_first_index(trj$DIST_FROM_DEP_NM >= 100) else NA_integer_,
	    "D200", if ("DIST_FROM_DEP_NM" %in% names(trj)) fuel_first_index(trj$DIST_FROM_DEP_NM >= 200) else NA_integer_,
	    "TOC", vfe$TOC,
	    "TOD", vfe$TOD,
	    "A200", if ("DIST_TO_ARR_NM" %in% names(trj)) fuel_first_index(seq_len(nrow(trj)) > atot & trj$DIST_TO_ARR_NM <= 200) else NA_integer_,
	    "A100", if ("DIST_TO_ARR_NM" %in% names(trj)) fuel_first_index(seq_len(nrow(trj)) > atot & trj$DIST_TO_ARR_NM <= 100) else NA_integer_,
	    "A40", if ("DIST_TO_ARR_NM" %in% names(trj)) fuel_first_index(seq_len(nrow(trj)) > atot & trj$DIST_TO_ARR_NM <= 40) else NA_integer_,
    "ALTO", alto,
    "ALDT", aldt,
    "XRWY", if (any(taxi_in, na.rm = TRUE)) fuel_first_index(taxi_in) else fuel_last_index(landing),
    "AIBT", nrow(trj)
  )

	  fuel_snapshot_rows(trj, idx) |>
	    dplyr::distinct(.data$SOURCE_UID, .data$MST, .keep_all = TRUE)
}

fuel_eur_milestones <- function(segments, flight_metadata) {
  meta <- flight_metadata |>
    dplyr::transmute(
      SOURCE_UID = as.character(.data$SAM_ID),
      SAM_ID = .data$SAM_ID,
      FLTID = NA_character_,
      ADEP, ADES,
      TYPE = .data$AIRCRAFT_TYPE
    )

  trj <- segments |>
    dplyr::left_join(meta, by = "SAM_ID") |>
    dplyr::arrange(.data$SAM_ID, .data$TIME_OVER) |>
    dplyr::group_by(.data$SAM_ID) |>
    dplyr::mutate(
      TIME = .data$TIME_OVER,
      ALT_FT = .data$ALTITUDE_FT,
      TOT_FUEL_KG = cumsum(.data$FUEL_BURNT_KG),
      TOT_FUEL_KG_ORIGINAL = cumsum(.data$FUEL_BURNT_KG_ORIGINAL),
      DIST_FLOWN_NM = cumsum(.data$DISTANCE_NM),
      ROW_ID = dplyr::row_number()
    ) |>
    dplyr::ungroup()

  relabel_flow_mst <- function(x) {
    dplyr::case_when(
      x == "F40" ~ "D40",
      x == "F100" ~ "D100",
      x == "L100" ~ "A100",
      x == "L40" ~ "A40",
      TRUE ~ x
    )
  }

  explicit <- trj |>
    dplyr::filter(!is.na(.data$MILESTONE)) |>
    tidyr::separate_longer_delim(.data$MILESTONE, delim = "/") |>
    dplyr::mutate(MST = relabel_flow_mst(.data$MILESTONE)) |>
	    dplyr::filter(.data$MST %in% c("D40", "D100", "TOC", "TOD", "A100", "A40", "FL100", "LVL", "FIR", "AUA")) |>
	    dplyr::select(SAM_ID, ROW_ID, MST)

  derived <- trj |>
    dplyr::group_by(.data$SAM_ID) |>
    dplyr::group_modify(\(.x, .y) {
      first_idx <- function(cond) {
        idx <- which(cond)
        if (length(idx) == 0) NA_integer_ else idx[1]
      }
      last_idx <- function(cond) {
        idx <- which(cond)
        if (length(idx) == 0) NA_integer_ else idx[length(idx)]
      }

      atot <- first_idx(.x$FLIGHT_PHASE == "Take-Off")
      tod <- first_idx(grepl("TOD", dplyr::coalesce(.x$MILESTONE, "")))
      taxi_in <- first_idx(.x$FLIGHT_PHASE == "Taxi-In")

      tibble::tribble(
        ~MST, ~ROW_ID,
        "AOBT", .x$ROW_ID[1],
        "ERWY", last_idx(.x$FLIGHT_PHASE == "Taxi-Out"),
        "ATOT", atot,
        "DLTO", first_idx(.x$ALT_FT >= 3000 & .x$ROW_ID > atot),
        "ALTO", first_idx(.x$ALT_FT <= 3000 & .x$ROW_ID > tod),
        "ALDT", first_idx(.x$FLIGHT_PHASE %in% c("Approach", "Landing") & .x$ALT_FT == 0),
        "XRWY", if (is.na(taxi_in)) NA_integer_ else max(1L, taxi_in - 1L),
        "AIBT", .x$ROW_ID[nrow(.x)]
      )
    }) |>
    dplyr::ungroup()

  dplyr::bind_rows(explicit, derived) |>
    dplyr::filter(!is.na(.data$ROW_ID)) |>
    dplyr::inner_join(trj, by = c("SAM_ID", "ROW_ID")) |>
    dplyr::transmute(
      SOURCE_UID, FLTID, ADEP, ADES, TYPE,
      TIME, LAT, LON, ALT_FT,
      MST,
      TOT_FUEL_KG, TOT_FUEL_KG_ORIGINAL, DIST_FLOWN_NM,
      DIST_FROM_DEP_NM = NA_real_,
      DIST_TO_ARR_NM = NA_real_,
      FLIGHT_PHASE_RAW = .data$FLIGHT_PHASE,
      ROW_ID
    ) |>
    dplyr::arrange(.data$SOURCE_UID, .data$TIME, .data$ROW_ID, .data$MST) |>
    dplyr::distinct(.data$SOURCE_UID, .data$MST, .data$ROW_ID, .keep_all = TRUE)
}

fuel_default_phase_definitions <- function() {
  tibble::tribble(
    ~PHASE, ~FROM_MST, ~TO_MST,
    "TAXI_OUT", "AOBT", "ERWY",
    "TAKE_OFF_ROLL", "ERWY", "ATOT",
    "LTO_CLIMB_OUT", "ATOT", "DLTO",
    "CLIMB", "DLTO", "TOC",
    "CRUISE", "TOC", "TOD",
    "DESCENT", "TOD", "ALTO",
    "LTO_APPROACH_LANDING", "ALTO", "ALDT",
    "RUNWAY_EXIT", "ALDT", "XRWY",
    "TAXI_IN", "XRWY", "AIBT"
  )
}

fuel_phase_summaries <- function(milestones, phase_definitions = fuel_default_phase_definitions()) {
	  from <- milestones |>
	    dplyr::select(SOURCE_UID, FLTID, ADEP, ADES, TYPE, FROM_MST = MST,
	                  FROM_TIME = TIME, FROM_ROW_ID = ROW_ID,
	                  FROM_FUEL = TOT_FUEL_KG,
	                  FROM_FUEL_ORIGINAL = TOT_FUEL_KG_ORIGINAL,
	                  FROM_DIST = DIST_FLOWN_NM)

	  to <- milestones |>
	    dplyr::select(SOURCE_UID, TO_MST = MST,
	                  TO_TIME = TIME, TO_ROW_ID = ROW_ID,
	                  TO_FUEL = TOT_FUEL_KG,
	                  TO_FUEL_ORIGINAL = TOT_FUEL_KG_ORIGINAL,
	                  TO_DIST = DIST_FLOWN_NM)

  phase_definitions |>
    dplyr::left_join(from, by = "FROM_MST", relationship = "many-to-many") |>
    dplyr::left_join(to, by = c("SOURCE_UID", "TO_MST"), relationship = "many-to-many") |>
    dplyr::filter(!is.na(.data$FROM_TIME), !is.na(.data$TO_TIME), .data$TO_ROW_ID >= .data$FROM_ROW_ID) |>
    dplyr::transmute(
      SOURCE_UID, FLTID, ADEP, ADES, TYPE,
      PHASE, FROM_MST, TO_MST,
      START_TIME = .data$FROM_TIME,
      END_TIME = .data$TO_TIME,
      DURATION_MIN = as.numeric(difftime(.data$TO_TIME, .data$FROM_TIME, units = "mins")),
      FUEL_KG = .data$TO_FUEL - .data$FROM_FUEL,
      FUEL_KG_ORIGINAL = .data$TO_FUEL_ORIGINAL - .data$FROM_FUEL_ORIGINAL,
      DISTANCE_NM = .data$TO_DIST - .data$FROM_DIST
    )
}

fuel_level_descriptors <- function(trajectory, phases, altitude_col = "ALT_FT", time_col = "TIME") {
	  trj <- trajectory |>
	    dplyr::group_by(.data$SOURCE_UID) |>
	    dplyr::group_modify(\(.x, .y) fuel_vertical_profile(.x, altitude_col = altitude_col, time_col = time_col)) |>
	    dplyr::ungroup()

	  phases |>
	    dplyr::select(SOURCE_UID, PHASE, START_TIME, END_TIME) |>
    dplyr::left_join(trj, by = "SOURCE_UID", relationship = "many-to-many") |>
    dplyr::filter(.data[[time_col]] >= .data$START_TIME, .data[[time_col]] < .data$END_TIME) |>
	    dplyr::summarise(
	      LEVEL_TIME_MIN = sum(dplyr::if_else(.data$IS_LEVEL, .data$DT_SEC_PREV, 0), na.rm = TRUE) / 60,
	      PHASE_TIME_MIN = sum(.data$DT_SEC_PREV, na.rm = TRUE) / 60,
	      SHARE_TIME_LEVEL = dplyr::if_else(.data$PHASE_TIME_MIN > 0, .data$LEVEL_TIME_MIN / .data$PHASE_TIME_MIN, NA_real_),
	      N_LEVEL_POINTS = sum(.data$IS_LEVEL, na.rm = TRUE),
	      MEDIAN_VERTICAL_RATE_FPM = stats::median(.data$VERTICAL_RATE_FPM, na.rm = TRUE),
	      .by = c(SOURCE_UID, PHASE)
	    )
}

fuel_eur_level_descriptors_from_segments <- function(segments, flight_metadata, phases) {
  meta <- flight_metadata |>
    dplyr::transmute(
      SOURCE_UID = as.character(.data$SAM_ID),
      SAM_ID = .data$SAM_ID
    )

  trj <- segments |>
    dplyr::left_join(meta, by = "SAM_ID") |>
    dplyr::arrange(.data$SAM_ID, .data$TIME_OVER) |>
    dplyr::group_by(.data$SAM_ID) |>
    dplyr::mutate(
      TIME = .data$TIME_OVER,
      ROW_ID = dplyr::row_number(),
      DT_SEC_PREV = as.numeric(difftime(.data$TIME, dplyr::lag(.data$TIME), units = "secs")),
      DT_SEC_PREV = dplyr::if_else(
        is.finite(.data$DT_SEC_PREV) & .data$DT_SEC_PREV > 0 & .data$DT_SEC_PREV <= 1800,
        .data$DT_SEC_PREV,
        NA_real_
      ),
      IS_LEVEL = .data$FLIGHT_PHASE %in% c("Lvl_climb", "Lvl_descent")
    ) |>
    dplyr::ungroup()

  phases |>
    dplyr::select(SOURCE_UID, PHASE, START_TIME, END_TIME) |>
    dplyr::filter(.data$PHASE %in% c("CLIMB", "DESCENT")) |>
    dplyr::left_join(trj, by = "SOURCE_UID", relationship = "many-to-many") |>
    dplyr::filter(.data$TIME >= .data$START_TIME, .data$TIME < .data$END_TIME) |>
    dplyr::arrange(.data$SOURCE_UID, .data$PHASE, .data$ROW_ID) |>
    dplyr::mutate(
      LEVEL_RUN = cumsum(.data$IS_LEVEL & !dplyr::lag(.data$IS_LEVEL, default = FALSE)),
      LEVEL_RUN = dplyr::if_else(.data$IS_LEVEL, .data$LEVEL_RUN, NA_integer_),
      .by = c(SOURCE_UID, PHASE)
    ) |>
    dplyr::summarise(
      LEVEL_TIME_MIN = sum(dplyr::if_else(.data$IS_LEVEL, .data$DT_SEC_PREV, 0), na.rm = TRUE) / 60,
      PHASE_TIME_MIN = sum(.data$DT_SEC_PREV, na.rm = TRUE) / 60,
      SHARE_TIME_LEVEL = dplyr::if_else(.data$PHASE_TIME_MIN > 0, .data$LEVEL_TIME_MIN / .data$PHASE_TIME_MIN, NA_real_),
      LEVEL_DISTANCE_NM = sum(dplyr::if_else(.data$IS_LEVEL, .data$DISTANCE_NM, 0), na.rm = TRUE),
      LEVEL_FUEL_KG = sum(dplyr::if_else(.data$IS_LEVEL, .data$FUEL_BURNT_KG, 0), na.rm = TRUE),
      N_LEVEL_POINTS = sum(.data$IS_LEVEL, na.rm = TRUE),
      N_LEVEL_PORTIONS = dplyr::n_distinct(stats::na.omit(.data$LEVEL_RUN)),
      .by = c(SOURCE_UID, PHASE)
    )
}

fuel_eur_level_descriptors_from_milestones <- function(milestones, phases) {
  lvl <- milestones |>
    dplyr::filter(.data$MST == "LVL") |>
    dplyr::mutate(
      PHASE = dplyr::case_when(
        .data$FLIGHT_PHASE_RAW == "Lvl_climb" ~ "CLIMB",
        .data$FLIGHT_PHASE_RAW == "Lvl_descent" ~ "DESCENT",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(!is.na(.data$PHASE)) |>
    dplyr::select(
      SOURCE_UID, PHASE, TIME, ROW_ID,
      TOT_FUEL_KG, DIST_FLOWN_NM
    )

  lvl_runs <- lvl |>
    dplyr::inner_join(
      phases |>
        dplyr::filter(.data$PHASE %in% c("CLIMB", "DESCENT")) |>
        dplyr::select(SOURCE_UID, PHASE, START_TIME, END_TIME, PHASE_TIME_MIN = DURATION_MIN),
      by = c("SOURCE_UID", "PHASE")
    ) |>
    dplyr::filter(.data$TIME >= .data$START_TIME, .data$TIME < .data$END_TIME) |>
    dplyr::arrange(.data$SOURCE_UID, .data$PHASE, .data$ROW_ID) |>
    dplyr::mutate(
      NEW_RUN = is.na(dplyr::lag(.data$ROW_ID)) | .data$ROW_ID > dplyr::lag(.data$ROW_ID) + 1L,
      LEVEL_RUN = cumsum(.data$NEW_RUN),
      .by = c(SOURCE_UID, PHASE)
    )

  lvl_runs |>
    dplyr::summarise(
      START_TIME = min(.data$TIME, na.rm = TRUE),
      END_TIME = max(.data$TIME, na.rm = TRUE),
      LEVEL_TIME_MIN = as.numeric(difftime(.data$END_TIME, .data$START_TIME, units = "mins")),
      LEVEL_DISTANCE_NM = max(.data$DIST_FLOWN_NM, na.rm = TRUE) - min(.data$DIST_FLOWN_NM, na.rm = TRUE),
      LEVEL_FUEL_KG = max(.data$TOT_FUEL_KG, na.rm = TRUE) - min(.data$TOT_FUEL_KG, na.rm = TRUE),
      N_LEVEL_POINTS = dplyr::n(),
      PHASE_TIME_MIN = dplyr::first(.data$PHASE_TIME_MIN),
      .by = c(SOURCE_UID, PHASE, LEVEL_RUN)
    ) |>
    dplyr::summarise(
      LEVEL_TIME_MIN = sum(.data$LEVEL_TIME_MIN, na.rm = TRUE),
      PHASE_TIME_MIN = dplyr::first(.data$PHASE_TIME_MIN),
      SHARE_TIME_LEVEL = dplyr::if_else(.data$PHASE_TIME_MIN > 0, .data$LEVEL_TIME_MIN / .data$PHASE_TIME_MIN, NA_real_),
      LEVEL_DISTANCE_NM = sum(.data$LEVEL_DISTANCE_NM, na.rm = TRUE),
      LEVEL_FUEL_KG = sum(.data$LEVEL_FUEL_KG, na.rm = TRUE),
      N_LEVEL_POINTS = sum(.data$N_LEVEL_POINTS, na.rm = TRUE),
      N_LEVEL_PORTIONS = dplyr::n(),
      .by = c(SOURCE_UID, PHASE)
    )
}

fuel_phase_code_diagnostics <- function(trajectories, phases = NULL) {
  trj <- dplyr::bind_rows(trajectories)
  if (!is.null(phases)) {
    trj <- phases |>
      dplyr::select(
        SOURCE_UID,
        DERIVED_PHASE = PHASE,
        START_TIME,
        END_TIME
      ) |>
      dplyr::left_join(trj, by = "SOURCE_UID", relationship = "many-to-many") |>
      dplyr::filter(.data$TIME >= .data$START_TIME, .data$TIME < .data$END_TIME)
  } else {
    trj <- trj |> dplyr::mutate(DERIVED_PHASE = NA_character_)
  }

  trj |>
    dplyr::filter(!is.na(.data$FLIGHT_PHASE_RAW)) |>
    dplyr::summarise(
      flights = dplyr::n_distinct(.data$SOURCE_UID),
      rows = dplyr::n(),
      min_alt_ft = min(.data$ALT_FT, na.rm = TRUE),
      median_alt_ft = stats::median(.data$ALT_FT, na.rm = TRUE),
      max_alt_ft = max(.data$ALT_FT, na.rm = TRUE),
      median_gs_kt = stats::median(.data$GS, na.rm = TRUE),
      .by = c(FLIGHT_PHASE_RAW, DERIVED_PHASE)
    ) |>
    dplyr::arrange(suppressWarnings(as.numeric(.data$FLIGHT_PHASE_RAW)), .data$DERIVED_PHASE)
}

fuel_plot_annotated_profile <- function(trajectory, milestones, output_file) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(invisible(FALSE))
  }

  source_id <- unique(trajectory$SOURCE_UID)[1]
  trj <- trajectory |>
    dplyr::arrange(.data$TIME) |>
    dplyr::mutate(REL_TIME_MIN = as.numeric(difftime(.data$TIME, min(.data$TIME, na.rm = TRUE), units = "secs")) / 60)
  mst <- milestones |>
    dplyr::filter(.data$SOURCE_UID == source_id, .data$MST %in% c("DLTO", "D200", "TOC", "TOD", "A200", "ALTO")) |>
    dplyr::mutate(REL_TIME_MIN = as.numeric(difftime(.data$TIME, min(trj$TIME, na.rm = TRUE), units = "secs")) / 60)

  p <- ggplot2::ggplot(trj, ggplot2::aes(x = .data$REL_TIME_MIN, y = .data$ALT_FT)) +
    ggplot2::geom_line(linewidth = 0.4, colour = "#2f3b52") +
    ggplot2::geom_vline(
      data = mst,
      ggplot2::aes(xintercept = .data$REL_TIME_MIN, colour = .data$MST),
      linewidth = 0.4,
      show.legend = FALSE
    ) +
    ggplot2::geom_text(
      data = mst,
      ggplot2::aes(x = .data$REL_TIME_MIN, y = .data$ALT_FT, label = .data$MST),
      angle = 90,
      vjust = -0.3,
      hjust = 0,
      size = 2.8,
      show.legend = FALSE
    ) +
    ggplot2::labs(
      title = source_id,
      x = "Elapsed time (min)",
      y = "Altitude (ft)"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(plot.title = ggplot2::element_text(size = 9))

  ggplot2::ggsave(output_file, p, width = 8, height = 4.5, dpi = 160)
  invisible(TRUE)
}
