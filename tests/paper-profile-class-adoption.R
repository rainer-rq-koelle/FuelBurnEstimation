suppressPackageStartupMessages({library(dplyr);library(arrow)})
source('R/paper-window-references.R');source('R/paper-profile-classes.R')
x<-load_paper_profile_classes()
p<-x$config$output
z<-read_parquet(file.path(p,'restricted-profile-class-ledger.parquet'))
stopifnot(nrow(z)==27924L*10L*5L,!anyDuplicated(z[,c('REGION','SOURCE_UID','WINDOW','SPEC')]),
  all(z$PROFILE_CLASS[!z$PROFILE_ELIGIBLE]=='Unknown'),
  all(is.na(z$INTERRUPTION_N[!z$PROFILE_ELIGIBLE])),
  all(z$MAX_NATIVE_GAP_SEC[z$PROFILE_ELIGIBLE]<=z$MAX_GAP_SEC[z$PROFILE_ELIGIBLE]+1e-7),
  all(z$DURATION_MIN[z$PROFILE_ELIGIBLE]*60+1e-7>=z$MIN_LEVEL_SEC[z$PROFILE_ELIGIBLE]),
  all(z$LEVEL_SHARE[z$PROFILE_ELIGIBLE]>=0&z$LEVEL_SHARE[z$PROFILE_ELIGIBLE]<=1+1e-7),
  nrow(x$input_manifest)==138)
stopifnot(all(x$support$CLASSIFIABLE_N==x$support$CONTINUOUS_N+x$support$LIGHT_N+x$support$HEAVY_N),
  all(x$support$INPUT==x$support$CLASSIFIABLE_N+x$support$UNKNOWN_N),
  all(x$support$CLASSIFIABLE_FUEL_N<=x$support$CLASSIFIABLE_N),
  all(is.na(x$class_references$P50[x$class_references$N<30])),
  !any(x$cell_support$PAIRED_FUEL[x$cell_support$PROFILE_CLASS=='Unknown']))
# Class computation depends on trajectory descriptors, never on fuel values/flags.
primary<-filter(z,SPEC==x$config$primary_spec)
labels<-paper_profile_class(primary$INTERRUPTION_N,primary$LEVEL_SEC,primary$DURATION_MIN*60,
  primary$LONGEST_SEC,primary$PROFILE_ELIGIBLE)
stopifnot(identical(labels,primary$PROFILE_CLASS))
# Sparse returned CHN knots must not inherit dense-source QC as native coverage.
upper<-filter(primary,REGION=='CHN',WINDOW%in%c('Climb FL100-FL180','Descent FL180-FL100'))
stopifnot(!any(upper$PROFILE_ELIGIBLE),!any(z$PROFILE_ELIGIBLE&!z$SOURCE_PROFILE_OK))
base<-load_paper_window_references()
old<-base$windows |>select(REGION,SOURCE_UID,WINDOW,FUEL_OK,TIME_OK,DISTANCE_RATE_OK,FUEL_KG)
check<-primary |>inner_join(old,by=c('REGION','SOURCE_UID','WINDOW'),suffix=c('','.base'))
stopifnot(all(check$FUEL_OK==check$FUEL_OK.base),all(check$TIME_OK==check$TIME_OK.base),
  all(check$DISTANCE_RATE_OK==check$DISTANCE_RATE_OK.base),
  isTRUE(all.equal(check$FUEL_KG,check$FUEL_KG.base)))
cat('Input immutability, separate profile/fuel eligibility, complete unknown accounting, class limits and native-gap provenance passed.\n')
