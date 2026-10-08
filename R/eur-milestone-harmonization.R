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
  purrr::map_chr(mst_label, function(label) {
    tokens <- unlist(strsplit(label, "/", fixed = TRUE), use.names = FALSE)
    mapped <- dplyr::case_when(
      tokens %in% c("F40", "D40") ~ "D040",
      tokens %in% c("F100") ~ "D100",
      tokens %in% c("L40", "A40") ~ "A040",
      tokens %in% c("L100") ~ "A100",
      TRUE ~ tokens
    )
    paste(unique(mapped), collapse = "/")
  })
}

#' Map FL100 to direction-aware labels based on phase
#'
#' @param mst_label Character vector of milestone labels
#' @param phase Character vector of phase labels
#' @return Character vector with direction-aware FL100 labels
#' @export
map_fl100_direction <- function(mst_label, phase) {
  canonicalize_eur_milestone_tokens(mst_label, phase)
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

#' Reconstruct level segment start/end pairs from LVL events
#'
#' Converts single LVL milestone events into paired LVL_START and LVL_END milestones.
#' Assumes consecutive LVL events for the same flight belong to the same segment.
#'
#' @param df Data frame with LVL milestones
#' @param uid_col Name of the flight UID column (default "UID")
#' @param mst_col Name of the milestone column (default "MST")
#' @param order_cols Character vector of columns to order by (default: c("UID", "TIME"))
#' @return Data frame with LVL_START and LVL_END milestone rows
#' @export
reconstruct_level_segments <- function(df, uid_col = "UID", mst_col = "MST", order_cols = c("UID", "TIME")) {

  # Extract LVL events only
  lvl_events <- df |>
    dplyr::filter(.data[[mst_col]] == "LVL") |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols))) |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(
      .lvl_seq = dplyr::row_number(),
      .is_odd = .lvl_seq %% 2 == 1
    ) |>
    dplyr::ungroup()

  # First occurrence in each pair → LVL_START
  lvl_starts <- lvl_events |>
    dplyr::filter(.is_odd) |>
    dplyr::mutate(
      !!mst_col := "LVL_START",
      .segment_id = paste0(.data[[uid_col]], "_LVL_", (.lvl_seq + 1) / 2),
      .milestone_source = "derived_level_segment"
    ) |>
    dplyr::select(-c(.lvl_seq, .is_odd))

  # Second occurrence in each pair → LVL_END
  lvl_ends <- lvl_events |>
    dplyr::filter(!.is_odd) |>
    dplyr::mutate(
      !!mst_col := "LVL_END",
      .segment_id = paste0(.data[[uid_col]], "_LVL_", .lvl_seq / 2),
      .milestone_source = "derived_level_segment"
    ) |>
    dplyr::select(-c(.lvl_seq, .is_odd))

  # Warn about orphaned LVL events (odd total count per flight)
  orphaned <- lvl_events |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::summarise(
      n_lvl = dplyr::n(),
      has_orphan = n_lvl %% 2 != 0,
      .groups = "drop"
    ) |>
    dplyr::filter(has_orphan)

  if (nrow(orphaned) > 0) {
    warning(
      "Detected ", nrow(orphaned), " flights with unpaired LVL events. ",
      "These flights have an odd number of LVL milestones and may have incomplete segments."
    )
  }

  dplyr::bind_rows(lvl_starts, lvl_ends) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(order_cols)))
}

#' Apply full EUR milestone harmonization pipeline
#'
#' Combines all harmonization steps:
#' 1. Rename distance milestones (F40→D040, etc.)
#' 2. Map FL100 to direction-aware labels
#' 3. Derive FL crossing milestones
#' 4. Reconstruct level segment pairs
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

  message("Step 4: Reconstructing level segment pairs...")
  lvl_segments <- reconstruct_level_segments(
    df,
    uid_col = uid_col,
    mst_col = mst_col,
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

  result
}
