# Smoke screens of delivered summaries; findings are leads, not raw-QAR diagnoses.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1)
run<-normalizePath(args[1],mustWork=TRUE);store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,"/")))
suppressPackageStartupMessages({library(dplyr);library(readr);library(purrr);library(tidyr)})
cache<-readRDS(file.path(run,"scan/returned-tables.rds"))
get<-function(type)bind_rows(lapply(Filter(function(x)x$type==type,cache),`[[`,"data"))
m<-get("CHN-canonical-milestones");p<-get("CHN-phase-summaries");l<-get("CHN-level-segments")
f<-get("CHN-qar-fuel-flow-qc");u<-get("CHN-fuel-flow-unit-qc");d<-get("CHN-phase-level-descriptors")
key<-c("SOURCE_BATCH","SOURCE_UID");findings<-list();screens<-list()
flag<-function(x,code,detail,kind="requires_source_check") {
  screens[[length(screens)+1L]]<<-tibble(CODE=code,INTERPRETATION=kind,DETAIL=detail,
    identifiers=n_distinct(x$SOURCE_UID),flight_batch_records=nrow(distinct(x,across(all_of(key)))))
  if(!nrow(x))return(invisible(NULL))
  findings[[length(findings)+1L]]<<-distinct(x,across(all_of(key))) |> mutate(CODE=code,INTERPRETATION=kind,DETAIL=detail)
}
flag(m |> filter(!is.finite(as.numeric(TIME))),"missing_event_time","Missing event timestamp")
flag(m |> filter(is.finite(LAT)&is.finite(LON)&(abs(LAT)>90|abs(LON)>180|LAT==0|LON==0)),"invalid_or_zero_event_position","Invalid range or zero coordinate at an emitted event")
flag(m |> filter(is.finite(ALT_FT)&(ALT_FT< -2000|ALT_FT>65000)),"altitude_outside_screen","Emitted pressure altitude outside -2000..65000 ft")
flag(m |> filter(MST%in%c("ATOT","TOC","TOD","ALDT")) |> count(across(all_of(c(key,"MST")))) |> filter(n>1),"duplicate_core_event_role","Repeated same-role operational boundary","identity_or_output_logic")
ids<-distinct(m,across(all_of(key)))
coverage<-ids |> left_join(m |> group_by(across(all_of(key))) |> summarise(across(.cols=MST,.fns=list(labels=~paste(unique(.x),collapse=";"))),.groups="drop"),by=key)
for(event in c("ATOT","TOC","TOD","ALDT"))flag(m |> group_by(across(all_of(key))) |> summarise(present=event%in%MST,.groups="drop") |> filter(!present),paste0("missing_",event),paste("Missing",event,"under the distributed legacy detector"),"source_or_legacy_detector")
seqs<-m |> distinct(across(all_of(c(key,"ROW_ID"))),.keep_all=TRUE) |> arrange(across(all_of(key)),ROW_ID) |>
  group_by(across(all_of(key))) |> mutate(DT=as.numeric(TIME)-lag(as.numeric(TIME)),DF=TOT_FUEL_KG-lag(TOT_FUEL_KG),
    DD=DIST_FLOWN_NM-lag(DIST_FLOWN_NM),DA=ALT_FT-lag(ALT_FT)) |> ungroup()
flag(filter(seqs,DT<0),"backward_event_time","Time goes backwards in trajectory-row order")
flag(filter(seqs,DF< -1e-6),"decreasing_cumulative_fuel","Cumulative consumed fuel decreases between emitted points")
flag(filter(seqs,DD< -1e-6),"decreasing_cumulative_distance","Cumulative distance decreases between emitted points")
flag(filter(seqs,DT==0&(abs(DF)>1e-6|abs(DD)>1e-6)),"quantities_change_at_same_time","Different physical quantities at identical event timestamps")
flag(filter(seqs,DT>0&abs(DA)/DT*60>12000),"event_vertical_rate_above_screen","Altitude difference between emitted rows exceeds 12000 ft/min")
p<-p |> mutate(IMPLIED_KT=if_else(DURATION_MIN>0,DISTANCE_NM/DURATION_MIN*60,NA_real_),RATE_KGPH=if_else(DURATION_MIN>0,FUEL_KG/DURATION_MIN*60,NA_real_))
ground<-c("TAXI_OUT","TAXI_IN","RUNWAY_EXIT")
flag(filter(p,DURATION_MIN<0),"negative_phase_duration","Negative phase duration")
flag(filter(p,DURATION_MIN==0&(abs(FUEL_KG)>1e-6|abs(DISTANCE_NM)>1e-6)),"zero_time_nonzero_phase_quantity","Zero-duration phase has nonzero fuel or distance","boundary_accounting_or_source")
flag(filter(p,FUEL_KG< -1e-6),"negative_phase_fuel","Negative consumed phase fuel")
flag(filter(p,DISTANCE_NM< -1e-6),"negative_phase_distance","Negative phase distance")
flag(filter(p,!PHASE%in%ground,IMPLIED_KT>750),"airborne_phase_speed_above_screen","Non-taxi phase mean speed exceeds 750 kt")
flag(filter(p,PHASE%in%ground,IMPLIED_KT>120),"ground_phase_speed_above_screen","Taxi/exit phase mean speed exceeds 120 kt")
flag(filter(p,PHASE%in%c("CLIMB","CRUISE","DESCENT"),DURATION_MIN>=10,FUEL_KG==0),"long_airborne_phase_zero_fuel","At least ten minutes of airborne phase with zero recorded fuel")
flag(filter(p,PHASE%in%c("CLIMB","CRUISE","DESCENT"),DURATION_MIN>=10,DISTANCE_NM==0),"long_airborne_phase_zero_distance","At least ten minutes of airborne phase with zero recorded distance")
flag(filter(p,PHASE=="CRUISE",DURATION_MIN==0),"zero_length_cruise","TOC/TOD coincide; legacy shared-peak fallback or true zero cruise","source_or_legacy_detector")
flag(filter(f,is.finite(total_fuel_kg_raw)&total_fuel_kg_raw>0,abs(fuel_delta_kg)/total_fuel_kg_raw>.05),"fuel_cleaning_over_5pct","Cleaning changes full-record fuel by more than 5%; window and source review needed","source_or_cleaning_rule")
flag(filter(f,spike_share>.01),"fuel_spike_share_over_1pct","More than 1% of source rows flagged as fuel spikes","source_or_cleaning_rule")
flag(filter(u,review_required),"fuel_unit_review_required","Returned fuel-unit inference requests review","configuration_or_source")
flag(filter(u,raw_total_flow_median<=0|selected_total_fuel_kg<=0),"nonpositive_whole_flow_or_fuel","Nonpositive whole-record flow median or fuel total")
flag(filter(d,SHARE_TIME_LEVEL>1+1e-6|SHARE_TIME_LEVEL< -1e-6),"level_share_outside_0_1","Level exposure outside parent phase; interval allocation/detector review","output_logic_or_interval_definition")
flag(filter(l,DURATION_SEC<=0),"nonpositive_level_duration","Level-segment duration is nonpositive","output_logic_or_source")
flag(filter(l,FUEL_KG< -1e-6|DISTANCE_NM< -1e-6),"negative_level_quantity","Level segment has negative fuel/distance")
flag(filter(l,abs(END_ALT_FT-START_ALT_FT)>1000),"level_endpoint_change_over_1000ft","Accepted level interval changes altitude by more than 1000 ft","detector_or_source")
overlap<-l |> arrange(across(all_of(key)),START_TIME,END_TIME) |> group_by(across(all_of(key))) |>
  mutate(PREV_END=cummax(as.numeric(END_TIME)),OVERLAP=as.numeric(START_TIME)<lag(PREV_END)-1e-6) |> ungroup()
flag(filter(overlap,OVERLAP),"overlapping_level_segments","Accepted level intervals overlap within a flight","output_logic_or_interval_definition")
cross_batch<-distinct(m,across(all_of(key))) |> count(SOURCE_UID) |> filter(n>1)
flag(filter(m,SOURCE_UID%in%cross_batch$SOURCE_UID),"flight_id_across_batches","Identifier occurs in multiple batches; do not silently count as independent flights","identity_or_output_logic")
# A nonzero position can be stale despite avoiding range/zero/jump screens.
# Event-only evidence cannot establish how the raw channel behaved between events.
envelopes<-m |> group_by(across(all_of(key))) |> summarise(
 span_min=diff(range(as.numeric(TIME),na.rm=TRUE))/60,
 point_count=n_distinct(paste(LAT,LON)),all_nonzero=all(is.finite(LAT)&is.finite(LON)&LAT!=0&LON!=0),
 all_zero=all(!is.na(LAT)&!is.na(LON)&(LAT==0|LON==0)),
 alt_span=if(any(is.finite(ALT_FT)))diff(range(ALT_FT,na.rm=TRUE))else NA_real_,.groups="drop")
write_csv(envelopes,file.path(run,"scan/flight-event-envelopes.csv"))
zero<-p |> filter(PHASE%in%c("CLIMB","CRUISE","DESCENT"),DURATION_MIN>=10,DISTANCE_NM==0) |>
 distinct(across(all_of(key))) |> left_join(envelopes,by=key)
write_csv(zero,file.path(run,"scan/zero-distance-crosscheck.csv"))
write_csv(bind_rows(screens),file.path(run,"scan/all-screen-counts.csv"))
all<-bind_rows(findings);write_csv(all,file.path(run,"scan/individual-screen-findings.csv"))
write_csv(all |> group_by(CODE,INTERPRETATION,DETAIL) |> summarise(flight_batch_records=n(),identifiers=n_distinct(SOURCE_UID),.groups="drop"),file.path(run,"scan/aggregate-screens.csv"))
write_csv(p |> group_by(PHASE) |> summarise(rows=n(),speed_gt750=sum(IMPLIED_KT>750,na.rm=TRUE),zero_duration=sum(DURATION_MIN==0,na.rm=TRUE),negative_fuel=sum(FUEL_KG<0,na.rm=TRUE),.groups="drop"),file.path(run,"scan/aggregate-phase-screens.csv"))
write_csv(m |> count(MST,name="events"),file.path(run,"scan/aggregate-milestone-counts.csv"))
write_csv(ids |> count(SOURCE_BATCH,name="flights"),file.path(run,"scan/aggregate-batch-sizes.csv"))
cat(nrow(ids),"flight/batch records;",n_distinct(ids$SOURCE_UID),"identifiers;",n_distinct(all$SOURCE_UID),"identifiers with at least one smoke flag.\n")
print(count(all,CODE,sort=TRUE),n=40)
