# Restricted comparison plus explicitly aggregate-only summary tables.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==2)
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
runs<-vapply(args,normalizePath,"",mustWork=TRUE)
for(run in runs)stopifnot(startsWith(run,paste0(store,"/")))
suppressPackageStartupMessages({library(dplyr);library(readr);library(tidyr)})
read<-function(p)read_csv(p,show_col_types=FALSE)
old<-read(file.path(runs[1],"evaluation/flight-quality.csv"))
new<-read(file.path(runs[2],"evaluation/flight-quality.csv"))
out<-file.path(runs[2],"comparison");if(dir.exists(out))stop("Comparison already exists")
dir.create(out)
x<-new |> left_join(select(old,INPUT_ID,OLD_EXCLUDE=STUDY_EXCLUDE,OLD_REASONS=UNRESOLVED_REASONS),by="INPUT_ID") |>
  mutate(REVIEW_CATEGORY=case_when(!STUDY_EXCLUDE~"included",
    grepl("missing_engine_flow_column",UNRESOLVED_REASONS)~"source_fuel_channels_absent",
    !AIRBORNE_TIME_VALID~"source_clock_or_sampling",
    grepl("position_unresolved",UNRESOLVED_REASONS)~"source_position_or_profile",
    grepl("altitude_unresolved",UNRESOLVED_REASONS)~"source_altitude_or_profile",
    grepl("repair_budget",UNRESOLVED_REASONS)~"unapproved_repair_share",
    TRUE~"other_unresolved"))
stopifnot(nrow(x)==233,!any(!x$OLD_EXCLUDE & x$STUDY_EXCLUDE))
write_csv(x,file.path(out,"individual-transitions.csv"))
write_csv(count(x,ROLE,OLD_EXCLUDE,STUDY_EXCLUDE,name="files"),file.path(out,"aggregate-transitions.csv"))
write_csv(x |> group_by(ROLE,REVIEW_CATEGORY) |> summarise(files=n(),flight_identifiers=n_distinct(SOURCE_UID),.groups="drop"),file.path(out,"aggregate-review-categories.csv"))
write_csv(x |> group_by(ROLE) |> summarise(files=n(),identifiers=n_distinct(SOURCE_UID),included=sum(!STUDY_EXCLUDE),
  held=sum(STUDY_EXCLUDE),included_identifiers=n_distinct(SOURCE_UID[!STUDY_EXCLUDE]),
  fuel_time_eligible=sum(ELIGIBLE_FUEL_TIME),whole_airborne_fuel_time_eligible=sum(WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE),
  position_share_approvals=sum(POSITION_SHARE_REVIEW_APPROVED),.groups="drop"),file.path(out,"aggregate-cohort.csv"))
issues<-read(file.path(runs[2],"evaluation/issues.csv"))
write_csv(issues |> filter(STATUS=="out_of_scope") |> select(INPUT_ID,DOMAIN) |> distinct() |> count(DOMAIN,name="files"),file.path(out,"aggregate-out-of-scope-domains.csv"))
ms0<-read(file.path(runs[1],"evaluation/milestones.csv"))
ms1<-read(file.path(runs[2],"evaluation/milestones.csv"))
event_diff<-inner_join(select(ms0,INPUT_ID,MST,OLD_TIME=TIME),select(ms1,INPUT_ID,MST,NEW_TIME=TIME),by=c("INPUT_ID","MST"),relationship="many-to-many") |>
  filter(MST%in%c("ATOT","ALDT")) |> mutate(CHANGE_SEC=as.numeric(NEW_TIME)-as.numeric(OLD_TIME))
write_csv(event_diff,file.path(out,"individual-airborne-boundary-comparison.csv"))
stopifnot(all(event_diff$CHANGE_SEC==0))
base<-ms0 |> filter(MST%in%c("ATOT","ALDT")) |> select(INPUT_ID,MST,TOT_FUEL_KG,DIST_FLOWN_NM) |>
  pivot_wider(names_from=MST,values_from=c(TOT_FUEL_KG,DIST_FLOWN_NM)) |>
  mutate(OLD_AIR_FUEL_KG=TOT_FUEL_KG_ALDT-TOT_FUEL_KG_ATOT,OLD_AIR_DIST_NM=DIST_FLOWN_NM_ALDT-DIST_FLOWN_NM_ATOT)
whole<-read(file.path(runs[2],"evaluation/airborne_summary.csv"))
paired<-inner_join(base,select(whole,INPUT_ID,NEW_AIR_FUEL_KG=FUEL_KG,NEW_AIR_DIST_NM=DISTANCE_NM),by="INPUT_ID") |>
  inner_join(select(x,INPUT_ID,ROLE,OLD_EXCLUDE,STUDY_EXCLUDE),by="INPUT_ID") |>
  mutate(FUEL_CHANGE_KG=NEW_AIR_FUEL_KG-OLD_AIR_FUEL_KG,DIST_CHANGE_NM=NEW_AIR_DIST_NM-OLD_AIR_DIST_NM)
write_csv(paired,file.path(out,"individual-airborne-quantity-comparison.csv"))
accepted<-filter(paired,!OLD_EXCLUDE)
stopifnot(all(abs(accepted$FUEL_CHANGE_KG)<1e-6))
write_csv(accepted |> group_by(ROLE) |> summarise(files=n(),max_abs_fuel_change_kg=max(abs(FUEL_CHANGE_KG)),
  max_abs_distance_change_nm=max(abs(DIST_CHANGE_NM)),.groups="drop"),file.path(out,"aggregate-previously-included-conservation.csv"))
print(count(x,ROLE,STUDY_EXCLUDE,name="files"),n=20)
