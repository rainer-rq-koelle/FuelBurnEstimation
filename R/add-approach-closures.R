#' Add Closing LVL_END Markers for Orphaned Approach Segments
#'
#' Post-extraction correction: Adds synthetic LVL_END markers for orphaned
#' LVL_START events below FL100 in descent phase. These represent brief
#' level-offs during final approach that don't have explicit END markers
#' before landing.
#'
#' The synthetic END marker is placed 8 seconds after the orphaned START at
#' slightly lower altitude. The 8-second offset is deliberately "systemic"
#' (artificial) so future analysts can:
#' 1. Identify these as post-processing corrections
#' 2. Filter them out by duration threshold (< 10 seconds)
#' 3. Flag them for quality review
#'
#' @param df Harmonized milestones data frame
#' @param uid_col Name of flight UID column
#' @param mst_col Name of milestone column
#' @param alt_col Name of altitude column
#' @param time_col Name of time column (default: "TIME")
#' @param offset_seconds Time offset for synthetic END marker (default: 8)
#' @return Data frame with approach closure markers added
#' @export
add_approach_segment_closures <- function(
    df,
    uid_col = "UID",
    mst_col = "MST",
    alt_col = "ALT",
    time_col = "TIME",
    offset_seconds = 8
) {

  # Find orphaned LVL_START markers below FL100 in descent
  orphan_analysis <- df |>
    dplyr::arrange(.data[[uid_col]], .data[[time_col]]) |>
    dplyr::group_by(.data[[uid_col]]) |>
    dplyr::mutate(.row_num = dplyr::row_number()) |>
    dplyr::filter(
      .data[[mst_col]] == "LVL_START",
      .data[[alt_col]] < 10000  # Below FL100
    )

  if (nrow(orphan_analysis) == 0) {
    message("  No LVL_START markers below FL100 found")
    return(df)
  }

  # For each LVL_START, check if there's a matching LVL_END after it
  orphaned_starts <- orphan_analysis |>
    dplyr::rowwise() |>
    dplyr::mutate(
      .has_end = any(df[[mst_col]][df[[uid_col]] == .data[[uid_col]] &
                                     df[[time_col]] > .data[[time_col]]] == "LVL_END")
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(!.has_end)

  if (nrow(orphaned_starts) == 0) {
    message("  No orphaned approach segments found")
    return(df)
  }

  message(sprintf("  Found %d orphaned approach segments - adding closure markers",
                  nrow(orphaned_starts)))

  # Create synthetic LVL_END markers
  # Place 8 seconds after the orphaned START at slightly lower altitude
  synthetic_ends <- orphaned_starts |>
    dplyr::mutate(
      !!time_col := .data[[time_col]] + offset_seconds,
      !!alt_col := pmax(0, .data[[alt_col]] - 100),  # 100 ft lower, minimum 0
      !!mst_col := "LVL_END",
      .milestone_source = "implicit_approach_closure",
      .synthetic_offset_sec = offset_seconds
    ) |>
    dplyr::select(-dplyr::starts_with("."))

  # Combine with original data
  result <- dplyr::bind_rows(df, synthetic_ends) |>
    dplyr::arrange(.data[[uid_col]], .data[[time_col]])

  message(sprintf("  Added %d synthetic LVL_END markers (offset: %ds)",
                  nrow(synthetic_ends), offset_seconds))

  result
}
