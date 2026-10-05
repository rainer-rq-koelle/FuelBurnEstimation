# Flight-phase summaries used by paper and technical note.

extract_mst_phase_variability <- function(
  .trj_mst,
  .mst_phases = c("AOBT", "ATOT", "D100", "A100", "ALDT", "AIBT")
) {
  this_uid <- unique(.trj_mst$UID)
  this_type <- unique(.trj_mst$TYPE)

  start <- .trj_mst |> dplyr::filter(TIME == min(TIME))
  end <- .trj_mst |> dplyr::filter(TIME == max(TIME))

  aobt <- .trj_mst |> dplyr::filter(MST == "AOBT")
  atot <- .trj_mst |> dplyr::filter(MST == "ATOT")
  d100 <- .trj_mst |> dplyr::filter(MST == "D100") |> dplyr::slice_min(TIME)
  a100 <- .trj_mst |> dplyr::filter(MST == "A100") |> dplyr::slice_max(TIME)
  aldt <- .trj_mst |> dplyr::filter(MST == "ALDT")
  aibt <- .trj_mst |> dplyr::filter(MST == "AIBT")

  delta_first_last <- function(df1, df2, .phase, .uid = this_uid) {
    dplyr::bind_rows(df1, df2) |>
      dplyr::summarise(
        TIME = difftime(dplyr::last(TIME), dplyr::first(TIME), units = "min") |> as.numeric(),
        FUEL_PHASE = dplyr::last(TOT_FUEL) - dplyr::first(TOT_FUEL)
      ) |>
      dplyr::mutate(UID = .uid, PHASE = .phase, TYPE = this_type, .before = TIME)
  }

  dplyr::bind_rows(
    delta_first_last(start, end, "FLT"),
    delta_first_last(aobt, atot, "TXO"),
    delta_first_last(atot, d100, "CLIMB100"),
    delta_first_last(d100, a100, "ENR100"),
    delta_first_last(a100, aldt, "DESC100"),
    delta_first_last(aldt, aibt, "TXI")
  )
}

calc_refs_per_phase <- function(.phase_mst_fuelburns) {
  .phase_mst_fuelburns |>
    dplyr::group_by(TYPE, LB, UB, PHASE) |>
    dplyr::reframe(
      SMPL_N = dplyr::n(),
      TIME_10P = stats::quantile(TIME, probs = 0.1),
      TIME_20P = stats::quantile(TIME, probs = 0.2),
      TIME_50P = stats::quantile(TIME, probs = 0.5),
      TIME_90P = stats::quantile(TIME, probs = 0.9),
      FUEL_10P = stats::quantile(FUEL_PHASE, probs = 0.1),
      FUEL_20P = stats::quantile(FUEL_PHASE, probs = 0.2),
      FUEL_50P = stats::quantile(FUEL_PHASE, probs = 0.5),
      FUEL_90P = stats::quantile(FUEL_PHASE, probs = 0.9)
    )
}
