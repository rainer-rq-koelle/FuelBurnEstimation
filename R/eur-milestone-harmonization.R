#' EUR Milestone Harmonization
#'
#' Functions to harmonize EUR canonical milestone labels to the 2026 enriched
#' milestone convention.
#'
#' @details
#' The EUR PRU data uses legacy naming:
#' - F40, F100 (first 40/100 NM from departure)
#' - L40, L100 (last 40/100 NM to arrival)
#' - FL100 (generic, direction inferred from phase)
#' - LVL (level segment event, needs pairing)
#'
#' Target canonical labels:
#' - D040, D100, D200 (departure-side distance)
#' - A040, A100, A200 (arrival-side distance)
#' - D_FL075, D_FL100, D_FL180 (departure-side FL crossings)
#' - A_FL075, A_FL100, A_FL180 (arrival-side FL crossings)
#' - LVL_START, LVL_END (paired level segment boundaries)

#' Rename distance milestones to canonical labels
#'
#' @param mst_label Character vector of milestone labels
#' @return Character vector with renamed labels
#' @export
rename_distance_milestones <- function(mst_label) {
  dplyr::case_when(
    mst_label == "F40" ~ "D040",
    mst_label == "F100" ~ "D100",
    mst_label == "L40" ~ "A040",
    mst_label == "L100" ~ "A100",
    TRUE ~ mst_label
  )
}

#' Map FL100 to direction-aware labels based on phase
#'
#' @param mst_label Character vector of milestone labels
#' @param phase Character vector of phase labels
#' @return Character vector with direction-aware FL100 labels
#' @export
map_fl100_direction <- function(mst_label, phase) {
  dplyr::case_when(
    mst_label == "FL100" & stringr::str_detect(stringr::str_to_lower(phase), "climb") ~ "D_FL100",
    mst_label == "FL100" & stringr::str_detect(stringr::str_to_lower(phase), "descent|approach") ~ "A_FL100",
    mst_label == "FL100" ~ "FL100_REVIEW",  # Flag ambiguous cases
    TRUE ~ mst_label
  )
}

#' Derive direction-aware flight-level crossing milestones
#'
#' Adds D_FL075, D_FL100, D_FL180 (first upward crossing) and
#' A_FL075, A_FL100, A_FL180 (last downward crossing).
#'
#' @param df Data frame with columns: UID, ALT (altitude in feet), and ordering columns
#' @param uid_col Name of the flight UID column (default "UID")
#' @param alt_col Name of the altitude column (default "ALT")
#' @param order_cols Character vector of columns to order by (default: c("UID", "TIME"))
#' @return Data frame with additional FL crossing milestone rows
#' @export
derive_fl_crossings <- function(df, uid_col = "UID", alt_col = "ALT", order_cols = c("UID", "TIME")) {

  fl_thresholds <- c(
    FL075 = 7500,
    FL100 = 10000,
    FL180 = 18000
  )

  # Order data and compute lag altitude
  df_ordered <- df |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols))) |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(
      .prev_alt = dplyr::lag(.data[[alt_col]]),
      .row_num = dplyr::row_number()
    ) |>
    dplyr::ungroup()

  # Departure-side: first upward crossing of each FL
  d_crossings <- purrr::map_dfr(names(fl_thresholds), function(fl_name) {
    threshold <- fl_thresholds[[fl_name]]

    df_ordered |>
      dplyr::filter(
        !is.na(.prev_alt),
        .prev_alt < threshold,
        .data[[alt_col]] >= threshold
      ) |>
      dplyr::group_by(.data[[uid_col]]) |>
      dplyr::slice_min(.row_num, n = 1, with_ties = FALSE) |>
      dplyr::ungroup() |>
      dplyr::mutate(
        MST = paste0("D_", fl_name),
        .milestone_source = "derived_fl_crossing"
      )
  })

  # Arrival-side: last downward crossing of each FL
  a_crossings <- purrr::map_dfr(names(fl_thresholds), function(fl_name) {
    threshold <- fl_thresholds[[fl_name]]

    df_ordered |>
      dplyr::filter(
        !is.na(.prev_alt),
        .prev_alt > threshold,
        .data[[alt_col]] <= threshold
      ) |>
      dplyr::group_by(.data[[uid_col]]) |>
      dplyr::slice_max(.row_num, n = 1, with_ties = FALSE) |>
      dplyr::ungroup() |>
      dplyr::mutate(
        MST = paste0("A_", fl_name),
        .milestone_source = "derived_fl_crossing"
      )
  })

  # Combine and clean up temporary columns
  dplyr::bind_rows(
    df_ordered |> dplyr::select(-c(.prev_alt, .row_num)),
    d_crossings |> dplyr::select(-c(.prev_alt, .row_num)),
    a_crossings |> dplyr::select(-c(.prev_alt, .row_num))
  ) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols)))
}


#' Reconstruct level segment start/end pairs from LVL events with implicit END markers
#'
#' Converts single LVL milestone events into paired LVL_START and LVL_END milestones.
#' Adds implicit LVL_END markers at:
#' - TOD if preceded by active level segment
#' - Phase transition from Lvl_* to non-Lvl_*
#' - Last trajectory point if in Lvl_* phase
#'
#' @param df Data frame with LVL milestones
#' @param uid_col Name of the flight UID column (default "UID")
#' @param mst_col Name of the milestone column (default "MST")
#' @param phase_col Name of the phase column (default "PHASE")
#' @param order_cols Character vector of columns to order by
#' @return Data frame with LVL_START and LVL_END milestone rows
#' @export
reconstruct_level_segments <- function(df, uid_col = "UID", mst_col = "MST", phase_col = "PHASE", order_cols = c("UID", "TIME")) {

  # Extract LVL events and convert to START/END
  lvl_events <- df |>
    dplyr::filter(.data[[mst_col]] == "LVL") |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols))) |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(
      .lvl_seq = dplyr::row_number(),
      .is_odd = .lvl_seq %% 2 == 1
    ) |>
    dplyr::ungroup()

  # Convert to START/END
  lvl_starts <- lvl_events |>
    dplyr::filter(.is_odd) |>
    dplyr::mutate(
      !!mst_col := "LVL_START",
      .segment_id = paste0(.data[[uid_col]], "_LVL_", (.lvl_seq + 1) / 2),
      .milestone_source = "derived_level_segment"
    ) |>
    dplyr::select(-c(.lvl_seq, .is_odd))

  lvl_ends <- lvl_events |>
    dplyr::filter(!.is_odd) |>
    dplyr::mutate(
      !!mst_col := "LVL_END",
      .segment_id = paste0(.data[[uid_col]], "_LVL_", .lvl_seq / 2),
      .milestone_source = "derived_level_segment"
    ) |>
    dplyr::select(-c(.lvl_seq, .is_odd))

  # Find implicit END markers using vectorized operations
  # Combine all milestones including the new START/END markers
  all_milestones <- dplyr::bind_rows(
    df |> dplyr::filter(.data[[mst_col]] != "LVL"),
    lvl_starts,
    lvl_ends
  ) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols))) |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(
      .row_num = dplyr::row_number(),
      .is_last = .row_num == dplyr::n()
    )

  # Add phase transition detection if phase column exists
  if (phase_col %in% names(all_milestones)) {
    all_milestones <- all_milestones |>
      dplyr::mutate(
        .prev_phase = dplyr::lag(.data[[phase_col]]),
        .phase_transition = !is.na(.prev_phase) &
                            !is.na(.data[[phase_col]]) &
                            grepl("^Lvl_", .prev_phase) &
                            !grepl("^Lvl_", .data[[phase_col]])
      )
  } else {
    all_milestones <- all_milestones |>
      dplyr::mutate(.phase_transition = FALSE)
  }

  all_milestones <- all_milestones |> dplyr::ungroup()

  # Track level segment state: cumulative START - END
  all_milestones <- all_milestones |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(
      .start_flag = dplyr::if_else(.data[[mst_col]] == "LVL_START", 1L, 0L),
      .end_flag = dplyr::if_else(.data[[mst_col]] == "LVL_END", 1L, 0L),
      .level_balance = cumsum(.start_flag - .end_flag),
      .prev_balance = dplyr::lag(.level_balance, default = 0L),
      .in_level = .prev_balance > 0  # Use previous balance to check if we were in level BEFORE this milestone
    ) |>
    dplyr::ungroup()

  # Find implicit END points: where we're in level AND (TOD OR phase transition OR last point)
  implicit_ends <- all_milestones |>
    dplyr::filter(
      .in_level,
      .data[[mst_col]] != "LVL_END",  # Don't duplicate existing ENDs
      (.data[[mst_col]] == "TOD" | .phase_transition | .is_last)
    ) |>
    dplyr::mutate(
      .orig_mst = .data[[mst_col]],
      !!mst_col := "LVL_END",
      .milestone_source = dplyr::case_when(
        .orig_mst == "TOD" ~ "implicit_end_at_TOD",
        .phase_transition ~ "implicit_end_at_phase_transition",
        .is_last ~ "implicit_end_at_trajectory_end",
        TRUE ~ "implicit_end"
      )
    ) |>
    dplyr::select(-dplyr::starts_with("."))

  # Combine all level markers
  dplyr::bind_rows(lvl_starts, lvl_ends, implicit_ends) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols)))
}

#' Apply full EUR milestone harmonization pipeline
#'
#' Combines all harmonization steps:
#' 1. Rename distance milestones (F40→D040, etc.)
#' 2. Map FL100 to direction-aware labels
#' 3. Derive FL crossing milestones
#' 4. Reconstruct level segment pairs with implicit END markers
#'
#' @param df Data frame with EUR canonical milestones
#' @param uid_col Name of flight UID column
#' @param mst_col Name of milestone column
#' @param alt_col Name of altitude column
#' @param phase_col Name of phase column
#' @param order_cols Character vector of ordering columns (default: c("UID", "TIME"))
#' @return Harmonized milestone data frame
#' @export
harmonize_eur_milestones <- function(
    df,
    uid_col = "UID",
    mst_col = "MST",
    alt_col = "ALT",
    phase_col = "PHASE",
    order_cols = c("UID", "TIME")
) {

  message("Step 1: Renaming distance milestones...")
  df <- df |>
    dplyr::mutate(
      !!mst_col := rename_distance_milestones(.data[[mst_col]])
    )

  message("Step 2: Mapping FL100 to direction-aware labels...")
  df <- df |>
    dplyr::mutate(
      !!mst_col := map_fl100_direction(.data[[mst_col]], .data[[phase_col]])
    )

  message("Step 3: Deriving FL crossing milestones...")
  df <- derive_fl_crossings(
    df,
    uid_col = uid_col,
    alt_col = alt_col,
    order_cols = order_cols
  )

  message("Step 4: Reconstructing level segment pairs with implicit END markers...")
  lvl_segments <- reconstruct_level_segments(
    df,
    uid_col = uid_col,
    mst_col = mst_col,
    phase_col = phase_col,
    order_cols = order_cols
  )

  # Replace original LVL events with paired segments
  df_no_lvl <- df |>
    dplyr::filter(.data[[mst_col]] != "LVL")

  result <- dplyr::bind_rows(df_no_lvl, lvl_segments) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols)))

  message("Harmonization complete.")
  message("  Original milestones: ", nrow(df))
  message("  Harmonized milestones: ", nrow(result))

  # Count implicit END markers
  if (".milestone_source" %in% names(result)) {
    implicit_count <- sum(grepl("implicit_end", result$.milestone_source), na.rm = TRUE)
    if (implicit_count > 0) {
      message("  Implicit LVL_END markers added: ", implicit_count)
    }
  }

  result
}
