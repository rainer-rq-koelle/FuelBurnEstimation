#' Level-Off Milestone Functions
#'
#' Functions to derive level-segment intervals from paired LVL_START/LVL_END
#' milestones with proper QC flags for orphaned/truncated segments.

#' Derive level-segment intervals from paired milestones
#'
#' @param df Data frame with harmonized milestones including LVL_START/LVL_END
#' @param uid_col Name of flight UID column (default "UID")
#' @param mst_col Name of milestone column (default "MST")
#' @param time_col Name of timestamp column (default "TIME")
#' @param alt_col Name of altitude column (default "ALT")
#' @param fuel_col Name of fuel column (default "TOT_FUEL")
#' @param phase_col Name of phase column (default "PHASE")
#' @return Data frame with level-segment intervals and QC flags
#' @export
derive_level_segments <- function(
    df,
    uid_col = "UID",
    mst_col = "MST",
    time_col = "TIME",
    alt_col = "ALT",
    fuel_col = "TOT_FUEL",
    phase_col = "PHASE"
) {

  # Extract level milestones
  lvl_milestones <- df |>
    dplyr::filter(.data[[mst_col]] %in% c("LVL_START", "LVL_END")) |>
    dplyr::arrange(.data[[uid_col]], .data[[time_col]])

  if (nrow(lvl_milestones) == 0) {
    message("No LVL_START/LVL_END milestones found")
    return(tibble::tibble())
  }

  # Create segment pairs within each flight
  segments <- lvl_milestones |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(
      segment_order = cumsum(.data[[mst_col]] == "LVL_START"),
      is_start = .data[[mst_col]] == "LVL_START",
      is_end = .data[[mst_col]] == "LVL_END"
    ) |>
    dplyr::ungroup()

  # Separate starts and ends
  starts <- segments |>
    dplyr::filter(is_start) |>
    dplyr::rename(
      start_time = dplyr::all_of(time_col),
      start_alt = dplyr::all_of(alt_col)
    ) |>
    dplyr::mutate(
      start_fuel = if (fuel_col %in% names(segments)) .data[[fuel_col]] else NA_real_,
      start_phase = if (phase_col %in% names(segments)) .data[[phase_col]] else NA_character_
    ) |>
    dplyr::select(
      dplyr::all_of(uid_col),
      segment_order,
      start_time,
      start_alt,
      start_fuel,
      start_phase,
      dplyr::any_of(c("ADEP", "ADES", "TYPE"))
    )

  ends <- segments |>
    dplyr::filter(is_end) |>
    dplyr::rename(
      end_time = dplyr::all_of(time_col),
      end_alt = dplyr::all_of(alt_col)
    ) |>
    dplyr::mutate(
      end_fuel = if (fuel_col %in% names(segments)) .data[[fuel_col]] else NA_real_,
      end_phase = if (phase_col %in% names(segments)) .data[[phase_col]] else NA_character_
    ) |>
    dplyr::select(
      dplyr::all_of(uid_col),
      segment_order,
      end_time,
      end_alt,
      end_fuel,
      end_phase
    )

  # Left join to keep all starts (including orphaned ones)
  paired_segments <- starts |>
    dplyr::left_join(
      ends,
      by = c(uid_col, "segment_order"),
      suffix = c("", "_end")
    )

  # Calculate segment metrics and QC flags
  level_segments <- paired_segments |>
    dplyr::mutate(
      segment_id = paste0(.data[[uid_col]], "_LVL_", segment_order),

      # QC: Check for missing end
      has_end = !is.na(end_time),

      # Duration in seconds
      duration_sec = dplyr::if_else(
        has_end,
        as.numeric(difftime(end_time, start_time, units = "secs")),
        NA_real_
      ),

      # Altitude metrics
      altitude_change_ft = dplyr::if_else(has_end, end_alt - start_alt, NA_real_),
      mean_altitude_ft = dplyr::if_else(has_end, (start_alt + end_alt) / 2, start_alt),
      altitude_band = dplyr::case_when(
        mean_altitude_ft < 10000 ~ "below_FL100",
        mean_altitude_ft < 18000 ~ "FL100_FL180",
        mean_altitude_ft < 24000 ~ "FL180_FL240",
        mean_altitude_ft >= 24000 ~ "above_FL240",
        TRUE ~ "unknown"
      ),

      # Fuel burn if available
      fuel_burn_kg = dplyr::if_else(
        has_end & !is.na(start_fuel) & !is.na(end_fuel),
        end_fuel - start_fuel,
        NA_real_
      ),

      # Phase context
      phase_context = dplyr::coalesce(start_phase, "unknown"),

      # QC flags
      qc_orphaned = !has_end,
      qc_zero_duration = has_end & duration_sec == 0,
      qc_negative_duration = has_end & duration_sec < 0,
      qc_excessive_altitude_change = has_end & abs(altitude_change_ft) > 1000,
      qc_missing_fuel = is.na(fuel_burn_kg),
      qc_negative_fuel = !is.na(fuel_burn_kg) & fuel_burn_kg < 0
    ) |>
    dplyr::mutate(
      qc_flag = dplyr::case_when(
        qc_orphaned ~ "orphaned_no_end",
        qc_negative_duration ~ "negative_duration",
        qc_zero_duration ~ "zero_duration",
        qc_excessive_altitude_change ~ "excessive_alt_change",
        qc_negative_fuel ~ "negative_fuel_burn",
        TRUE ~ "ok"
      )
    )

  level_segments
}

#' Summarize level-segment duration distributions
#'
#' @param level_segments Data frame from derive_level_segments()
#' @return Summary statistics by phase and QC status
#' @export
summarize_level_segments <- function(level_segments) {

  # Overall summary
  overall <- tibble::tibble(
    category = "overall",
    total_segments = nrow(level_segments),
    with_end = sum(level_segments$has_end),
    orphaned = sum(level_segments$qc_orphaned),
    mean_duration_sec = mean(level_segments$duration_sec, na.rm = TRUE),
    median_duration_sec = median(level_segments$duration_sec, na.rm = TRUE),
    min_duration_sec = min(level_segments$duration_sec, na.rm = TRUE),
    max_duration_sec = max(level_segments$duration_sec, na.rm = TRUE),
    mean_altitude_ft = mean(level_segments$mean_altitude_ft, na.rm = TRUE)
  )

  # By phase
  by_phase <- level_segments |>
    dplyr::group_by(phase_context) |>
    dplyr::summarise(
      total_segments = dplyr::n(),
      with_end = sum(has_end),
      orphaned = sum(qc_orphaned),
      mean_duration_sec = mean(duration_sec, na.rm = TRUE),
      median_duration_sec = median(duration_sec, na.rm = TRUE),
      min_duration_sec = suppressWarnings(min(duration_sec, na.rm = TRUE)),
      max_duration_sec = suppressWarnings(max(duration_sec, na.rm = TRUE)),
      mean_altitude_ft = mean(mean_altitude_ft, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(category = paste0("phase_", phase_context)) |>
    dplyr::select(category, dplyr::everything(), -phase_context)

  # By altitude band
  by_altitude <- level_segments |>
    dplyr::filter(!is.na(altitude_band)) |>
    dplyr::group_by(altitude_band) |>
    dplyr::summarise(
      total_segments = dplyr::n(),
      with_end = sum(has_end),
      orphaned = sum(qc_orphaned),
      mean_duration_sec = mean(duration_sec, na.rm = TRUE),
      median_duration_sec = median(duration_sec, na.rm = TRUE),
      min_duration_sec = suppressWarnings(min(duration_sec, na.rm = TRUE)),
      max_duration_sec = suppressWarnings(max(duration_sec, na.rm = TRUE)),
      mean_altitude_ft = mean(mean_altitude_ft, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(category = paste0("altitude_", altitude_band)) |>
    dplyr::select(category, dplyr::everything(), -altitude_band)

  # QC summary
  qc_summary <- level_segments |>
    dplyr::count(qc_flag) |>
    dplyr::mutate(
      category = paste0("qc_", qc_flag),
      total_segments = n,
      with_end = NA_integer_,
      orphaned = NA_integer_,
      mean_duration_sec = NA_real_,
      median_duration_sec = NA_real_,
      min_duration_sec = NA_real_,
      max_duration_sec = NA_real_,
      mean_altitude_ft = NA_real_
    ) |>
    dplyr::select(category, total_segments, with_end, orphaned, mean_duration_sec,
                  median_duration_sec, min_duration_sec, max_duration_sec, mean_altitude_ft)

  dplyr::bind_rows(overall, by_phase, by_altitude, qc_summary)
}
