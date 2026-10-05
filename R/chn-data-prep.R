# Reusable CHN data-preparation helpers, adapted from the 2025 ICNS work.

condense_chn_data <- function(.qar_chn_augmented) {
  this_msts <- .qar_chn_augmented |>
    dplyr::select(TIME = Time4, MST = Milestone) |>
    dplyr::filter(!is.na(MST))

  this_trj <- .qar_chn_augmented |>
    dplyr::select(
      TIME = Time4,
      LAT = LATP,
      LON = LONP,
      ALT = ALT_STD,
      FF1C,
      FF2C,
      ADEP = DEP,
      ADES = ARR
    ) |>
    dplyr::distinct()

  dplyr::left_join(this_trj, this_msts, dplyr::join_by(TIME))
}

calc_fuelburn <- function(.trj, .unit_factor = 3600) {
  .trj |>
    dplyr::mutate(
      FUEL = (FF1C + FF2C) / .unit_factor,
      TOT_FUEL = cumsum(FUEL)
    )
}

assign_hopefully_unique_id <- function(.trj) {
  first_entry <- .trj[1, ]
  unix_epoch <- as.numeric(first_entry$TIME)
  uid <- paste(first_entry$FLTID, unix_epoch, first_entry$ADP, sep = "-")

  .trj |>
    dplyr::mutate(UID = uid)
}

patch_aibt <- function(.chn_fuel) {
  .chn_fuel |>
    dplyr::group_by(UID) |>
    dplyr::group_modify(
      .f = ~ dplyr::mutate(
        .x,
        MST = dplyr::case_when(
          TIME == max(TIME) & is.na(MST) ~ "AIBT",
          TIME == max(TIME) & !is.na(MST) ~ paste0(MST, "-AIBT"),
          .default = MST
        )
      )
    ) |>
    dplyr::ungroup()
}
