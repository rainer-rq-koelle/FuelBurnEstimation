#' utility functions to extract fuel mst
#'
#' @param .g2g_per_flight 
#'
#' @return
#' @export
#'

eur_extract_fuel_mst <- function(.g2g_per_flight){
  tmp <- .g2g_per_flight |> 
    # ensure ordered by time for cumsum
    group_by(SAM_ID) |> arrange(TIME_OVER, .by_group = TRUE) |> 
    # calc burn along flight
    mutate( TOT_FUEL   = cumsum(FUEL_BURNT_KG)
            ,TOT_CO2   = cumsum(CO2)
            ,DIST_FLOWN = cumsum(DISTANCE_NM)
    ) |> 
    # rename and prepare output
    select(ADEP, ADES, TYPE = AIRCRAFT_TYPE
           , TIME = TIME_OVER, ALT = ALTITUDE_FT, LAT, LON,
           , DIST_FLOWN, TOT_FUEL
           , MST = Milestone, Flight_phase
           , everything()    # for now keep everything else
    ) |> 
    mutate(MST_G2G = MST) |> 
  ungroup() |> 
    mutate(MST = case_when(
      is.na(MST) ~ "XX"
      ,.default = MST
    ))
  return(tmp)
}

duplicate_multilabel_mst <- function(.g2g_per_flight){
  single_msts <- .g2g_per_flight |> dplyr::filter(nchar(MST) < 5)
  multi_msts  <- .g2g_per_flight |> dplyr::filter(nchar(MST) >= 5)
  
  multi_msts  <- multi_msts |> 
    dplyr::mutate(
       MMST_ID = dplyr::consecutive_id(MST)
      ,.after = MST 
      )
  
  split_MST <- function(.df){
    multi_label <- .df |> dplyr::pull(MST) |> str_split(pattern = "/")
    df <- .df |> mutate(MST = multi_label)    # add list column
  }
  
  multi_msts <- multi_msts |> dplyr::group_by(MMST_ID) |> 
    dplyr::group_modify(.f = ~ split_MST(.x)) |> tidyr::unnest(MST) |> 
    dplyr::ungroup()
  
  this_msts <- dplyr::bind_rows(single_msts, multi_msts) |> 
    dplyr::arrange(TIME)
  this_msts
}

eur_relabel_milestones <- function(.g2g_per_flight){
  my_msts <- .g2g_per_flight |> 
    # ensure ordered by time for cumsum
    group_by(SAM_ID) |> arrange(TIME, .by_group = TRUE) |> 
    # study milestones
    mutate(MST = case_when(
       TIME == min(TIME) & Flight_phase == "Taxi-Out" ~ "AOBT"
      ,TIME != min(TIME) & Flight_phase == "Taxi-Out" ~ "ERWY"
      ,DIST_FLOWN == 0 & lead(ALT) > 0                ~ "ATOT"
      ,Flight_phase == "Climb-Out"                    ~ "DLTO"
      ,MST == "F40" ~ "D40", MST == "F100" ~ "D100"
      ,MST == "L40" ~ "A40", MST == "L100" ~ "A100"
      ,between(ALT, 2500, 3500) & Flight_phase == "Descent" ~ "ALTO"
      ,lag(ALT) > 0 & ALT == 0 & Flight_phase == "Approach" ~ "ALDT"
      ,lag(ALT) == 0 & ALT == 0 & Flight_phase == "Landing" ~ "XRWY"
      ,TIME == max(TIME) & Flight_phase == "Taxi-In"  ~ "AIBT"
      ,TIME != max(TIME) & Flight_phase == "Taxi-In"  ~ "XRWY"
      , .default = MST
    )
    )
}
