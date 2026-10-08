#!/usr/bin/env Rscript
# Update reconstruct_level_segments() with vectorized logic

harm_file <- "R/eur-milestone-harmonization.R"
lines <- readLines(harm_file)

# Find the function start and end
func_start <- which(grepl("^reconstruct_level_segments <- function", lines))
# Find matching closing brace - count braces
brace_count <- 0
func_end <- func_start
for (i in func_start:length(lines)) {
  line <- lines[i]
  open_braces <- lengths(regmatches(line, gregexpr("\\{", line)))
  close_braces <- lengths(regmatches(line, gregexpr("\\}", line)))
  brace_count <- brace_count + open_braces - close_braces

  if (i > func_start && brace_count == 0) {
    func_end <- i
    break
  }
}

cat("Function starts at line:", func_start, "\n")
cat("Function ends at line:", func_end, "\n")

# New function implementation (vectorized)
new_function <- '
#\' Reconstruct level segment start/end pairs from LVL events with implicit END markers
#\'
#\' Converts single LVL milestone events into paired LVL_START and LVL_END milestones.
#\' Adds implicit LVL_END markers at:
#\' - TOD if preceded by active level segment
#\' - Phase transition from Lvl_* to non-Lvl_*
#\' - Last trajectory point if in Lvl_* phase
#\'
#\' @param df Data frame with LVL milestones
#\' @param uid_col Name of the flight UID column (default "UID")
#\' @param mst_col Name of the milestone column (default "MST")
#\' @param phase_col Name of the phase column (default "PHASE")
#\' @param order_cols Character vector of columns to order by
#\' @return Data frame with LVL_START and LVL_END milestone rows
#\' @export
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

  # Find implicit END points: where we\'re in level AND (TOD OR phase transition OR last point)
  implicit_ends <- all_milestones |>
    dplyr::filter(
      .in_level,
      .data[[mst_col]] != "LVL_END",  # Don\'t duplicate existing ENDs
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
'

# Find the roxygen comment before the function
comment_start <- func_start
while (comment_start > 1 && grepl("^#", lines[comment_start - 1])) {
  comment_start <- comment_start - 1
}

# Replace the function
new_lines <- c(
  lines[1:(comment_start - 1)],
  strsplit(new_function, "\n")[[1]],
  lines[(func_end + 1):length(lines)]
)

# Write back
writeLines(new_lines, harm_file)

cat("✓ Updated reconstruct_level_segments() with vectorized logic\n")
cat("  Old version: lines", comment_start, "-", func_end, "\n")
cat("  New version: vectorized operations, no nested loops\n")
