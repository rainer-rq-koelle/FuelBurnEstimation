# Aggregate completeness/conservation report; individual joins remain restricted.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)%in%c(1L,2L))
run<-normalizePath(args[1],mustWork=TRUE);store<-normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,'/')))
suppressPackageStartupMessages({library(dplyr);library(readr);library(tidyr)})
old<-file.path(dirname(run),if(length(args)==2)args[2]else'CHN-v2-2026-10-18-005','evaluation');out<-file.path(run,'completeness');dir.create(out,showWarnings=FALSE)
read<-function(name,where=file.path(run,'evaluation'))read_csv(file.path(where,paste0(name,'.csv')),show_col_types=FALSE)
q<-read('flight-quality');oq<-read('flight-quality',old)
m<-read('milestones');om<-read('milestones',old);a<-read('milestone_availability');candidates<-read('milestone_candidates')
summary<-q |> group_by(ROLE) |> summarise(FILES=n(),INCLUDED=sum(!STUDY_EXCLUDE),HELD=sum(STUDY_EXCLUDE),
 WHOLE_AIRBORNE_FUEL_TIME=sum(WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE),PROFILE_FUEL_TIME=sum(ELIGIBLE_FUEL_TIME),
 FULL_RECORD_FUEL_TIME=sum(TIME_VALID&FUEL_VALID),ALL_12_ARP_FL_ANCHORS_PRESENT=sum(ALL_12_ARP_FL_ANCHORS_PRESENT),
 FROZEN_POSITION_INPUTS=sum(POSITION_FROZEN_ROWS>0),.groups='drop')
write_csv(summary,file.path(out,'aggregate-cohort-and-completeness.csv'))
write_csv(a |> left_join(select(q,INPUT_ID,ROLE),by='INPUT_ID') |> count(ROLE,MST,AVAILABILITY,name='INPUTS'),file.path(out,'aggregate-anchor-availability.csv'))
write_csv(m |> left_join(select(q,INPUT_ID,ROLE),by='INPUT_ID') |> group_by(ROLE,MST) |> summarise(INPUTS=n_distinct(INPUT_ID),EVENTS=n(),.groups='drop'),file.path(out,'aggregate-emitted-milestones.csv'))
write_csv(candidates |> left_join(select(q,INPUT_ID,ROLE),by='INPUT_ID') |> group_by(ROLE,MST) |> summarise(CANDIDATES=n(),INPUTS=n_distinct(INPUT_ID),SUPPORTED=sum(SUPPORTED),SELECTED=sum(SELECTED),LEVEL_ASSOCIATED=sum(SUPPRESS_LEVEL_ASSOCIATED),.groups='drop'),file.path(out,'aggregate-crossing-candidates.csv'))
trans<-select(q,INPUT_ID,ROLE,NEW_EXCLUDE=STUDY_EXCLUDE,POSITION_FROZEN_ROWS,UNRESOLVED_REASONS) |> left_join(select(oq,INPUT_ID,OLD_EXCLUDE=STUDY_EXCLUDE),by='INPUT_ID')
write_csv(trans,file.path(out,'individual-transitions.csv'));write_csv(count(trans,ROLE,OLD_EXCLUDE,NEW_EXCLUDE,name='INPUTS'),file.path(out,'aggregate-transitions.csv'))
# Carry-forward reviews are conditional on invariant physical repairs/accounting.
fields<-c('POSITION_REPAIRED_ROWS','ALTITUDE_REPAIRED_ROWS','FUEL_REPAIRED_ROWS','POSITION_ALIGNED_ROWS',
 'AIRBORNE_POSITION_REPAIR_SHARE','AIRBORNE_ALTITUDE_REPAIR_SHARE','AIRBORNE_FUEL_REPAIR_SHARE','CLOCK_COLUMN',
 'AIRBORNE_TIME_VALID','AIRBORNE_FUEL_VALID','AIRBORNE_PROFILE_VALID')
comparisons<-lapply(fields,function(f){x<-q[[f]];y<-oq[[f]][match(q$INPUT_ID,oq$INPUT_ID)];eq<-(is.na(x)&is.na(y))|(!is.na(x)&!is.na(y)&x==y);tibble(FIELD=f,IDENTICAL_INPUTS=sum(eq),FILES=nrow(q))})
write_csv(bind_rows(comparisons),file.path(out,'aggregate-repair-invariance.csv'));stopifnot(all(bind_rows(comparisons)$IDENTICAL_INPUTS==nrow(q)))
# Compare derived profile boundaries separately from observed record/phase edges.
ops<-c('AOBT','ERWY','ATOT','DLTO','TOC','TOD','ALTO','ALDT','XRWY','AIBT')
x<-m |> filter(MST%in%ops) |> select(INPUT_ID,MST,TIME,TOT_FUEL_KG,DIST_FLOWN_NM)
y<-om |> filter(MST%in%ops) |> select(INPUT_ID,MST,TIME,TOT_FUEL_KG,DIST_FLOWN_NM)
j<-full_join(x,y,by=c('INPUT_ID','MST'),suffix=c('_NEW','_OLD')) |>
 mutate(TIME_DIFF_SEC=as.numeric(TIME_NEW)-as.numeric(TIME_OLD),FUEL_DIFF_KG=TOT_FUEL_KG_NEW-TOT_FUEL_KG_OLD,DISTANCE_DIFF_NM=DIST_FLOWN_NM_NEW-DIST_FLOWN_NM_OLD)
write_csv(j,file.path(out,'individual-operational-event-comparison.csv'))
max_abs<-function(x)if(any(is.finite(x)))max(abs(x),na.rm=TRUE)else NA_real_
write_csv(tibble(OPERATIONAL_EVENTS=nrow(j),TIME_DIFF_MAX_SEC=max_abs(j$TIME_DIFF_SEC),FUEL_DIFF_MAX_KG=max_abs(j$FUEL_DIFF_KG),DISTANCE_DIFF_MAX_NM=max_abs(j$DISTANCE_DIFF_NM)),file.path(out,'aggregate-operational-event-invariance.csv'))
fixed<-j[j$MST%in%c('AOBT','ERWY','ATOT','ALDT','XRWY','AIBT'),]
stopifnot(all(is.finite(fixed$TIME_NEW)),all(is.finite(fixed$TIME_OLD)),max_abs(fixed$TIME_DIFF_SEC)==0,max_abs(fixed$FUEL_DIFF_KG)<1e-7)
write_csv(j |> group_by(MST) |> summarise(PAIRED=sum(is.finite(TIME_NEW)&is.finite(TIME_OLD)),CHANGED=sum(abs(TIME_DIFF_SEC)>1e-6,na.rm=TRUE),UNPAIRED=sum(is.na(TIME_NEW)|is.na(TIME_OLD)),MAX_ABS_TIME_DIFF_SEC=max_abs(TIME_DIFF_SEC),.groups='drop'),file.path(out,'aggregate-derived-boundary-changes.csv'))
air<-read('airborne_summary');oair<-read('airborne_summary',old)
j<-left_join(select(air,INPUT_ID,DURATION_MIN,FUEL_KG,DISTANCE_NM),select(oair,INPUT_ID,DURATION_MIN,FUEL_KG,DISTANCE_NM),by='INPUT_ID',suffix=c('_NEW','_OLD'))
write_csv(j,file.path(out,'individual-airborne-comparison.csv'))
write_csv(tibble(INPUTS=nrow(j),MAX_TIME_DIFF_MIN=max_abs(j$DURATION_MIN_NEW-j$DURATION_MIN_OLD),MAX_FUEL_DIFF_KG=max_abs(j$FUEL_KG_NEW-j$FUEL_KG_OLD),MAX_DISTANCE_DIFF_NM=max_abs(j$DISTANCE_NM_NEW-j$DISTANCE_NM_OLD)),file.path(out,'aggregate-airborne-invariance.csv'))
# Frozen-position flags warrant raw-point evidence even where another hold existed.
write_csv(q |> filter(POSITION_FROZEN_ROWS>0),file.path(out,'frozen-position-inputs.csv'))
stopifnot(file.copy(file.path(run,'evaluation/study-exclusions.csv'),file.path(run,'further-investigation.csv'),overwrite=TRUE))
stopifnot(identical(readBin(file.path(run,'further-investigation.csv'),'raw',n=1e9),readBin(file.path(run,'evaluation/study-exclusions.csv'),'raw',n=1e9)))
print(summary);cat('Repair invariance and observed event checks passed.\n')
