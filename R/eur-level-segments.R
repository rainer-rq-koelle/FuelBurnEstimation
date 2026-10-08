#' EUR level-segment reconstruction helpers
#'
#' The PRU milestone extract stores level-off evidence as `LVL` tokens, often
#' combined with other event tokens such as `F100/LVL` or `LVL/FL100`. These
#' helpers keep the token parsing source-specific and produce a separate
#' interval table for downstream threshold choices.

#' Test whether a slash-separated milestone label contains a token
#'
#' @param labels Character vector of milestone labels
#' @param token Token to match exactly
#' @return Logical vector
#' @export
has_milestone_token <- function(labels, token) {
  token_pattern <- paste0("(^|/)", stringr::fixed(token), "($|/)")
  stringr::str_detect(labels, token_pattern)
}

#' Canonicalize slash-separated EUR milestone tokens
#'
#' @param mst_label Character vector of raw milestone labels
#' @param phase Character vector of raw phase labels
#' @return Character vector with known legacy tokens mapped to canonical tokens
#' @export
canonicalize_eur_milestone_tokens <- function(mst_label, phase) {
  phase <- rep_len(phase, length(mst_label))

  purrr::map2_chr(mst_label, phase, function(label, phase_value) {
    tokens <- unlist(strsplit(label, "/", fixed = TRUE), use.names = FALSE)
    phase_lc <- stringr::str_to_lower(phase_value %||% "")

    mapped <- dplyr::case_when(
      tokens %in% c("F40", "D40") ~ "D040",
      tokens %in% c("F100") ~ "D100",
      tokens %in% c("L40", "A40") ~ "A040",
      tokens %in% c("L100") ~ "A100",
      tokens == "FL100" & stringr::str_detect(phase_lc, "climb") ~ "D_FL100",
      tokens == "FL100" & stringr::str_detect(phase_lc, "descent|approach") ~ "A_FL100",
      tokens == "FL100" ~ "FL100_REVIEW",
      TRUE ~ tokens
    )

    paste(unique(mapped), collapse = "/")
  })
}

#' Classify EUR level phase context
#'
#' @param phase Character vector of raw phase labels
#' @return Character vector with climb, descent, or unknown
#' @export
eur_level_phase_context <- function(phase) {
  phase_lc <- stringr::str_to_lower(phase)
  dplyr::case_when(
    stringr::str_detect(phase_lc, "climb") ~ "climb",
    stringr::str_detect(phase_lc, "descent|approach") ~ "descent",
    TRUE ~ "unknown"
  )
}

#' Build EUR level-segment intervals from LVL-bearing milestone events
#'
#' Consecutive LVL-token events are paired within each flight and phase context.
#' Odd terminal events are retained as `orphan_start` rows instead of being
#' discarded.
#'
#' @param df EUR canonical milestone table
#' @param altitude_band_ft Width used to round the segment altitude band
#' @return Tibble with one row per paired or orphan candidate level segment
#' @export
build_eur_level_segments <- function(df, altitude_band_ft = 1000) {
  pick_col <- function(candidates, required = TRUE) {
    out <- candidates[candidates %in% names(df)][1]
    if (is.na(out) && required) {
      stop("Missing required column. Expected one of: ", paste(candidates, collapse = ", "), call. = FALSE)
    }
    out
  }

  uid_col <- pick_col(c("UID", "SOURCE_UID"))
  time_col <- pick_col(c("TIME", "timestamp"))
  alt_col <- pick_col(c("ALT", "ALT_FT", "altitude_ft"))
  mst_col <- pick_col(c("MST", "milestone"))
  fuel_col <- pick_col(c("TOT_FUEL", "TOT_FUEL_KG"))
  phase_col <- pick_col(c("PHASE", "FLIGHT_PHASE_RAW", "phase"))
  row_col <- pick_col(c("ROW_ID", "row_id"), required = FALSE)

  optional_cols <- intersect(c("FLTID", "ADEP", "ADES", "TYPE", "OPERATOR", "SOURCE", "FIR_ID", "AUA_ID"), names(df))
  order_cols <- c(uid_col, row_col, time_col)
  order_cols <- order_cols[!is.na(order_cols)]

  events <- df |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols))) |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(row_in_flight = if (!is.na(row_col)) .data[[row_col]] else dplyr::row_number()) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      uid_value = .data[[uid_col]],
      mst_raw = .data[[mst_col]],
      mst_canonical = canonicalize_eur_milestone_tokens(.data[[mst_col]], .data[[phase_col]]),
      phase_context = eur_level_phase_context(.data[[phase_col]])
    ) |>
    dplyr::filter(has_milestone_token(.data$mst_canonical, "LVL")) |>
    dplyr::arrange(.data$uid_value, .data$phase_context, dplyr::across(dplyr::all_of(order_cols))) |>
    dplyr::group_by(.data$uid_value, .data$phase_context) |>
    dplyr::mutate(
      level_event_seq = dplyr::row_number(),
      segment_ordinal = as.integer((.data$level_event_seq + 1L) / 2L),
      boundary_role = dplyr::if_else(.data$level_event_seq %% 2L == 1L, "start", "end")
    ) |>
    dplyr::ungroup()

  starts <- events |>
    dplyr::filter(.data$boundary_role == "start") |>
    dplyr::transmute(
      UID = .data$uid_value,
      dplyr::across(dplyr::all_of(optional_cols)),
      phase_context = .data$phase_context,
      segment_ordinal = .data$segment_ordinal,
      start_time = .data[[time_col]],
      start_row_in_flight = .data$row_in_flight,
      start_alt_ft = .data[[alt_col]],
      start_fuel_kg = .data[[fuel_col]],
      start_phase = .data[[phase_col]],
      start_mst_raw = .data$mst_raw,
      start_mst_canonical = .data$mst_canonical
    )

  ends <- events |>
    dplyr::filter(.data$boundary_role == "end") |>
    dplyr::transmute(
      UID = .data$uid_value,
      phase_context = .data$phase_context,
      segment_ordinal = .data$segment_ordinal,
      end_time = .data[[time_col]],
      end_row_in_flight = .data$row_in_flight,
      end_alt_ft = .data[[alt_col]],
      end_fuel_kg = .data[[fuel_col]],
      end_phase = .data[[phase_col]],
      end_mst_raw = .data$mst_raw,
      end_mst_canonical = .data$mst_canonical
    )

  dplyr::full_join(
    starts,
    ends,
    by = c("UID", "phase_context", "segment_ordinal")
  ) |>
    dplyr::mutate(
      segment_id = sprintf("%s_LVL_%s_%04d", .data$UID, .data$phase_context, .data$segment_ordinal),
      pairing_method = "consecutive_lvl_tokens_within_flight_phase",
      duration_sec = as.numeric(difftime(.data$end_time, .data$start_time, units = "secs")),
      fuel_kg = .data$end_fuel_kg - .data$start_fuel_kg,
      altitude_delta_ft = .data$end_alt_ft - .data$start_alt_ft,
      altitude_min_ft = pmin(.data$start_alt_ft, .data$end_alt_ft, na.rm = TRUE),
      altitude_max_ft = pmax(.data$start_alt_ft, .data$end_alt_ft, na.rm = TRUE),
      altitude_mid_ft = (.data$start_alt_ft + .data$end_alt_ft) / 2,
      altitude_band_ft = round(.data$altitude_mid_ft / altitude_band_ft) * altitude_band_ft,
      duration_band = dplyr::case_when(
        is.na(.data$duration_sec) ~ "orphan",
        .data$duration_sec < 20 ~ "[0,20)",
        .data$duration_sec < 60 ~ "[20,60)",
        .data$duration_sec < 120 ~ "[60,120)",
        .data$duration_sec < 300 ~ "[120,300)",
        .data$duration_sec < 600 ~ "[300,600)",
        .data$duration_sec < 1200 ~ "[600,1200)",
        TRUE ~ "[1200,+)"
      ),
      quality_flag = dplyr::case_when(
        is.na(.data$start_time) ~ "orphan_end",
        is.na(.data$end_time) ~ "orphan_start",
        .data$duration_sec <= 0 ~ "nonpositive_duration",
        .data$fuel_kg < 0 ~ "negative_fuel_delta",
        .data$phase_context == "unknown" ~ "unknown_phase_context",
        TRUE ~ "paired"
      )
    ) |>
    dplyr::select(
      "UID",
      dplyr::any_of(optional_cols),
      "segment_id",
      "phase_context",
      "segment_ordinal",
      "pairing_method",
      "quality_flag",
      "duration_band",
      "start_time",
      "end_time",
      "duration_sec",
      "start_row_in_flight",
      "end_row_in_flight",
      "start_alt_ft",
      "end_alt_ft",
      "altitude_delta_ft",
      "altitude_min_ft",
      "altitude_max_ft",
      "altitude_mid_ft",
      "altitude_band_ft",
      "start_fuel_kg",
      "end_fuel_kg",
      "fuel_kg",
      "start_phase",
      "end_phase",
      "start_mst_raw",
      "end_mst_raw",
      "start_mst_canonical",
      "end_mst_canonical"
    ) |>
    dplyr::arrange(.data$UID, .data$phase_context, .data$segment_ordinal)
}

#' Summarise EUR level-segment duration and quality distributions
#'
#' @param segments Output from `build_eur_level_segments()`
#' @return Tibble with quantile, band, and quality-count summaries
#' @export
summarise_eur_level_segments <- function(segments) {
  paired <- segments |>
    dplyr::filter(.data$quality_flag == "paired")

  quantiles <- dplyr::bind_rows(
    paired |> dplyr::mutate(phase_context = "all"),
    paired
  ) |>
    dplyr::group_by(.data$phase_context) |>
    dplyr::summarise(
      summary_type = "duration_quantiles",
      n_segments = dplyr::n(),
      duration_min_sec = min(.data$duration_sec, na.rm = TRUE),
      duration_p05_sec = as.numeric(stats::quantile(.data$duration_sec, 0.05, na.rm = TRUE)),
      duration_p25_sec = as.numeric(stats::quantile(.data$duration_sec, 0.25, na.rm = TRUE)),
      duration_p50_sec = as.numeric(stats::quantile(.data$duration_sec, 0.50, na.rm = TRUE)),
      duration_p75_sec = as.numeric(stats::quantile(.data$duration_sec, 0.75, na.rm = TRUE)),
      duration_p95_sec = as.numeric(stats::quantile(.data$duration_sec, 0.95, na.rm = TRUE)),
      duration_max_sec = max(.data$duration_sec, na.rm = TRUE),
      duration_band = NA_character_,
      quality_flag = NA_character_,
      .groups = "drop"
    )

  bands <- dplyr::bind_rows(
    segments |> dplyr::mutate(phase_context = "all"),
    segments
  ) |>
    dplyr::count(.data$phase_context, .data$duration_band, name = "n_segments") |>
    dplyr::mutate(
      summary_type = "duration_bands",
      quality_flag = NA_character_,
      duration_min_sec = NA_real_,
      duration_p05_sec = NA_real_,
      duration_p25_sec = NA_real_,
      duration_p50_sec = NA_real_,
      duration_p75_sec = NA_real_,
      duration_p95_sec = NA_real_,
      duration_max_sec = NA_real_
    )

  quality <- dplyr::bind_rows(
    segments |> dplyr::mutate(phase_context = "all"),
    segments
  ) |>
    dplyr::count(.data$phase_context, .data$quality_flag, name = "n_segments") |>
    dplyr::mutate(
      summary_type = "quality_flags",
      duration_band = NA_character_,
      duration_min_sec = NA_real_,
      duration_p05_sec = NA_real_,
      duration_p25_sec = NA_real_,
      duration_p50_sec = NA_real_,
      duration_p75_sec = NA_real_,
      duration_p95_sec = NA_real_,
      duration_max_sec = NA_real_
    )

  dplyr::bind_rows(quantiles, bands, quality) |>
    dplyr::select(
      "summary_type",
      "phase_context",
      "duration_band",
      "quality_flag",
      "n_segments",
      "duration_min_sec",
      "duration_p05_sec",
      "duration_p25_sec",
      "duration_p50_sec",
      "duration_p75_sec",
      "duration_p95_sec",
      "duration_max_sec"
    ) |>
    dplyr::arrange(.data$summary_type, .data$phase_context, .data$duration_band, .data$quality_flag)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x)) y else x
}
