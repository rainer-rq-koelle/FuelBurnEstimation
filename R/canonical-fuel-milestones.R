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

fuel_read_chn_qar_csv <- function(path, date = NULL) {
  meta <- fuel_parse_chn_filename(path)
  if (is.null(date)) date <- meta$DATE[[1]]

  dt <- data.table::fread(path, check.names = TRUE)
  names(dt) <- toupper(names(dt))

  alt_cols <- grep("^ALT_STD", names(dt), value = TRUE)
  ff_cols <- intersect(c("FF1C", "FF2C", "FF3C", "FF4C"), names(dt))

  if (!"TIME" %in% names(dt)) stop("QAR file has no TIME column: ", path)
  if (length(alt_cols) == 0) stop("QAR file has no ALT_STD column: ", path)
  if (length(ff_cols) == 0) stop("QAR file has no FF*C fuel-flow columns: ", path)

  phase_vec <- if ("FLIGHT_PHASE" %in% names(dt)) as.character(dt$FLIGHT_PHASE) else NA_character_
  ias_vec <- if ("IASC" %in% names(dt)) dt$IASC else NA_real_
  gs_vec <- if ("GS" %in% names(dt)) dt$GS else NA_real_

	  out <- tibble::as_tibble(dt) |>
	    dplyr::mutate(
	      TIME = fuel_make_time(date, .data$TIME),
	      LAT = fuel_fill_numeric_linear(.data$LATP),
	      LON = fuel_fill_numeric_linear(.data$LONP),
	      ALT_FT = rowMeans(dplyr::pick(dplyr::all_of(alt_cols)), na.rm = TRUE),
      IASC = ias_vec,
      GS = gs_vec,
      FLIGHT_PHASE_RAW = phase_vec,
      FF_TOTAL_RAW_KGPH = rowSums(dplyr::pick(dplyr::all_of(ff_cols)), na.rm = TRUE)
    )

  out <- out |>
    dplyr::bind_cols(fuel_clean_flow_spikes(out$FF_TOTAL_RAW_KGPH) |> dplyr::select(-FF_TOTAL_RAW_KGPH)) |>
    dplyr::arrange(.data$TIME) |>
    dplyr::mutate(
      DT_SEC = as.numeric(dplyr::lead(.data$TIME) - .data$TIME),
      DT_SEC = dplyr::if_else(is.na(.data$DT_SEC) | .data$DT_SEC < 0 | .data$DT_SEC > 300, 0, .data$DT_SEC),
      FUEL_BURNT_KG_ORIGINAL = .data$FF_TOTAL_RAW_KGPH * .data$DT_SEC / 3600,
      FUEL_BURNT_KG = .data$FF_TOTAL_KGPH * .data$DT_SEC / 3600,
      DISTANCE_NM = fuel_haversine_nm(.data$LAT, .data$LON, dplyr::lead(.data$LAT), dplyr::lead(.data$LON)),
      DISTANCE_NM = dplyr::if_else(is.na(.data$DISTANCE_NM), 0, .data$DISTANCE_NM),
      TOT_FUEL_KG = cumsum(.data$FUEL_BURNT_KG),
      TOT_FUEL_KG_ORIGINAL = cumsum(.data$FUEL_BURNT_KG_ORIGINAL),
      DIST_FLOWN_NM = cumsum(.data$DISTANCE_NM)
    ) |>
    dplyr::bind_cols(meta[rep(1, nrow(dt)), ])

  out
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
      DT_SEC_PREV = as.numeric(.data[[time_col]] - dplyr::lag(.data[[time_col]])),
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
      DT_SEC_PREV = as.numeric(.data$TIME - dplyr::lag(.data$TIME)),
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
    dplyr::mutate(REL_TIME_MIN = as.numeric(.data$TIME - min(.data$TIME, na.rm = TRUE)) / 60)
  mst <- milestones |>
    dplyr::filter(.data$SOURCE_UID == source_id, .data$MST %in% c("DLTO", "D200", "TOC", "TOD", "A200", "ALTO")) |>
    dplyr::mutate(REL_TIME_MIN = as.numeric(.data$TIME - min(trj$TIME, na.rm = TRUE)) / 60)

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
