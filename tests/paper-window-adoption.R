# Integration checks of the adopted frozen view (requires the standalone build).
suppressPackageStartupMessages({library(dplyr);library(tidyr)})
source('R/enroute-level-exposure.R');source('R/paper-window-references.R')
x<-load_paper_window_references()
p<-x$paired_support |>filter(WINDOW%in%x$config$core_windows,METRIC=='FUEL_KG')
stopifnot(nrow(p)==4,all(p$CELLS==8),
 p$CHN[p$WINDOW=='Climb FL075-FL100']==1648,
 p$EUR[p$WINDOW=='Descent FL100-FL075']==6041,
 sum(x$inventory$INPUT)==27924)
f<-x$windows |>filter(FUEL_OK,WINDOW%in%c('Climb-out source LTO','Takeoff-FL075')) |>
 inner_join(x$paired_cells |>filter(PAIRED_SUPPORT,METRIC=='FUEL_KG') |>select(TYPE,BAND100,WINDOW),by=c('TYPE','BAND100','WINDOW'))
ids<-f |>select(REGION,SOURCE_UID,WINDOW) |>mutate(YES=TRUE) |>pivot_wider(names_from=WINDOW,values_from=YES,values_fill=FALSE)
stopifnot(all(ids$`Climb-out source LTO`&ids$`Takeoff-FL075`))
endpoints<-bind_rows(x$windows |>transmute(REGION,SOURCE_UID,MST=FROM,TIME=START_TIME),
 x$windows |>transmute(REGION,SOURCE_UID,MST=TO,TIME=END_TIME)) |>filter(!is.na(TIME)) |>distinct()
stopifnot(nrow(anti_join(endpoints,x$events,by=c('REGION','SOURCE_UID','MST','TIME')))==0)
# Independently valid pressure windows survive unsupported whole-airborne fuel.
whole<-x$windows |>filter(WINDOW=='Whole airborne') |>select(REGION,SOURCE_UID,WHOLE_OK=FUEL_OK)
local<-x$windows |>filter(WINDOW=='Climb FL100-FL180',FUEL_OK) |>left_join(whole,by=c('REGION','SOURCE_UID'))
stopifnot(sum(local$REGION=='CHN'&!local$WHOLE_OK)==26)
# Ground convention is used once, exactly as delivered; zero source distance stays zero.
roll<-x$windows |>filter(REGION=='EUR',WINDOW=='Takeoff roll source segment',FUEL_OK)
stopifnot(all(abs(roll$FUEL_KG/roll$ORIGINAL_FUEL_KG-.8)<1e-8),all(roll$FLOWN_NM==0),!any(roll$DISTANCE_RATE_OK))
stopifnot(x$dates$N[x$dates$REGION=='CHN'&x$dates$ATOT_UTC_MONTH=='2025-09']==2)
stopifnot(all(is.na(x$grid$P50[x$grid$N<30])),all(x$grid$PROFILE_CLASS=='All profiles'))
# Every exposure row accounts for its full duration, including unknown time.
e<-x$enroute$exposure |>group_by(REGION,SOURCE_UID,WINDOW) |>summarise(SHARE=sum(SHARE),.groups='drop')
stopifnot(all(abs(e$SHARE-1)<1e-8))
bars<-ggplot2::ggplot_build(plot_enroute_exposure(x$enroute))$data[[1]]
stopifnot(!anyNA(bars$xmax),!anyNA(bars$xmin))
cat('Adopted cohorts, local-window independence, terminal pairing, single roll adjustment, date retention and exposure accounting passed.\n')
