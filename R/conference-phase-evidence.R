# Presentation selections over the adopted analyses; no source or cache writes.
load_conference_phase_evidence <- function(study,climb,review) {
  root <- 'notes/results/descent-enroute-lookup-2026-10-28'
  manifest <- readr::read_csv(file.path(root,'product-manifest.csv'),show_col_types=FALSE)
  stopifnot(all(manifest$SHA256==vapply(file.path(root,manifest$FILE),
    digest::digest,character(1),algo='sha256',file=TRUE)))
  lookup <- readr::read_csv(file.path(root,'lookup_wide.csv'),show_col_types=FALSE)
  selected_types <- c('A20N','C919','A320','B738','A333','B77W')
  ground_windows <- c('Taxi-out recorded segment','Takeoff roll source segment',
    'Landing-roll/runway-exit source segment','Taxi-in recorded segment')
  ground <- study$wide_grid |>
    dplyr::filter(TYPE=='B738',BAND100==600,WINDOW%in%ground_windows) |>
    dplyr::arrange(match(WINDOW,ground_windows),REGION)
  # Independent time support is retained; do not reuse fuel n for duration.
  ground_time_check <- paper_metric_values(study$windows) |>
    dplyr::filter(TYPE=='B738',BAND100==600,WINDOW%in%ground_windows,FUEL_OK,TIME_OK) |>
    dplyr::group_by(REGION,WINDOW) |>
    dplyr::summarise(N=dplyr::n(),DURATION_P50=stats::median(DURATION_MIN),.groups='drop')
  terminal_windows <- c('Climb-out source LTO','Takeoff-FL075','Climb FL075-FL100',
    'Approach-landing source LTO','FL075-landing')
  terminal <- study$wide_grid |>
    dplyr::filter(TYPE=='B738',BAND100==600,WINDOW%in%terminal_windows) |>
    dplyr::arrange(match(WINDOW,terminal_windows),REGION)
  boeing_climb <- climb$duration_bands |>
    dplyr::filter(TYPE=='B738',BAND100==600,TIME_BAND=='3-4')
  direction <- climb$routes |>
    dplyr::filter(REGION=='EUR',TYPE=='B738',BAND100==600,
      ADEP%in%c('EHAM','LEBL'),ADES%in%c('EHAM','LEBL'))
  fleet_climb <- climb$stage_bands |>
    dplyr::filter(REGION=='CHN',BAND100==600,TYPE%in%c('A20N','A320','A333','B789'))
  exposure <- lookup |>
    dplyr::filter(REGION=='CHN',TYPE%in%selected_types,GCD_GROUP=='500-<700',
      WINDOW=='Descent FL180-FL100',
      PROFILE_AXIS=='Source-native tagged time; compact exposure bins') |>
    dplyr::arrange(match(TYPE,selected_types),match(PROFILE_CLASS,c('<=2 min','>2-5 min','>5 min')))
  descent <- review$fine_window_time_groups_exact |>
    dplyr::filter(TYPE%in%c('A20N','B738'),BAND100==600,WINDOW=='Descent FL180-FL100',
      TIME_GROUP%in%c('6-<7','7-<8')) |>
    dplyr::bind_rows(review$lower_descent_two_three_minutes |>
      dplyr::filter(TYPE%in%c('A20N','B738'),BAND100==600) |>
      dplyr::mutate(TIME_GROUP='2-<3'))
  enroute <- study$wide_grid |>
    dplyr::filter(TYPE=='B738',BAND100==600,WINDOW=='Enroute source window')
  boundaries <- study$enroute$paired_summary |>dplyr::filter(TYPE=='B738',BAND100==600)
  fleet_enroute <- lookup |>
    dplyr::filter(REGION=='CHN',TYPE%in%selected_types,GCD_GROUP=='500-<700',
      WINDOW=='Enroute source window',PROFILE_AXIS=='Marginal baseline')
  # These checks bind the displayed examples to their intended strata and support.
  stopifnot(nrow(ground)==8L,all(ground$N_KG_MIN>=30),
    all(ground$N_FUEL_KG==ground$N_KG_MIN),
    all(ground$N_DURATION_MIN[ground$REGION=='CHN']==220L),
    all(ground$N_FUEL_KG[ground$REGION=='CHN']==160L),
    nrow(ground_time_check)==8L,
    nrow(terminal)==10L,all(terminal$N_FUEL_KG>=30),
    all(terminal$N_FUEL_KG==terminal$N_DURATION_MIN),
    all(terminal$N_FUEL_KG==terminal$N_KG_MIN),
    nrow(boeing_climb)==2L,all(boeing_climb$N>=30),nrow(direction)==2L,
    all(direction$N>=30),nrow(fleet_climb)==4L,all(fleet_climb$N>=30),
    nrow(exposure)==18L,all(exposure$N_FUEL_KG>=30),
    nrow(descent)==12L,all(descent$FUEL_N>=30),nrow(enroute)==2L,
    all(enroute$N_KG_NM>=30),nrow(boundaries)==4L,nrow(fleet_enroute)==6L)
  paired_n <- boundaries |>dplyr::group_by(REGION) |>
    dplyr::summarise(N_COUNTS=dplyr::n_distinct(N),.groups='drop')
  stopifnot(all(paired_n$N_COUNTS==1L),
    all(!is.finite(fleet_enroute$P50_KG_NM[fleet_enroute$TYPE=='C919'])))
  list(ground=ground,ground_fuel_cohort_time_check=ground_time_check,terminal_references=terminal,
    boeing_climb=boeing_climb,european_direction=direction,
    fleet_climb=fleet_climb,descent_comparable_time=descent,descent_fleet_exposure=exposure,
    boeing_enroute=enroute,boeing_boundary_sensitivity=boundaries,fleet_enroute=fleet_enroute)
}
