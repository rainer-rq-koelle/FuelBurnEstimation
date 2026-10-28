# Read-only, metric/window-specific support mapping; no canonical adoption.
# Usage: Rscript scripts/assess-chn-eur-paper-support.R <restricted output directory>
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
store<-normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
out<-normalizePath(args[1],mustWork=TRUE);stopifnot(startsWith(out,paste0(store,'/')))
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow)})
eurd<-file.path(store,'derived/eur/parallel-preprocessing/EUR-2026-10-13-002')
chnd<-file.path(store,'derived/chn/verification/CHN-2026-10-27-001/returned')
readc<-function(name)bind_rows(lapply(list.files(chnd,paste0('^',name,'[.]parquet$'),recursive=TRUE,full.names=TRUE),function(p)as.data.frame(read_parquet(p))))
cm<-readc('CHN-canonical-milestones');em<-as.data.frame(read_parquet(file.path(eurd,'EUR-canonical-milestones-parallel.parquet')))
cq<-readc('CHN-flight-quality');ci<-readc('CHN-phase-intervals')
# Cumulative model quantities must be coherent between emitted source knots.
fuel_audit<-em |> group_by(SOURCE_UID,TIME) |> summarise(LO=min(TOT_FUEL_KG),HI=max(TOT_FUEL_KG),.groups='drop') |>
 arrange(SOURCE_UID,TIME) |> group_by(SOURCE_UID) |> mutate(NEG=coalesce(LO-lag(HI)< -1e-6,FALSE),AMBIG=HI-LO>1e-6) |> ungroup()
stopifnot(!any(fuel_audit$NEG),!any(fuel_audit$AMBIG))
write_csv(tibble(REGION='EUR',FLIGHTS=n_distinct(em$SOURCE_UID),NEGATIVE_CUMULATIVE_STEPS=sum(fuel_audit$NEG),SAME_TIME_AMBIGUITIES=sum(fuel_audit$AMBIG)),file.path(out,'aggregate-eur-cumulative-audit.csv'))

ec<-as.data.frame(read_parquet(file.path(eurd,'EUR-milestone-crossing-candidates.parquet')))
# Preserve source dictionaries; normalize only exact, supported type labels.
type_map<-c('A330-300'='A333','A330-200'='A332','B737-800'='B738','B737-700'='B737','A321-NEO'='A21N','A320-NEO'='A20N','B777-300ER'='B77W','B787-9'='B789','A350-900'='A359')
ap<-bind_rows(read_csv('helpers/chn-qar-v2/data/airports.csv',show_col_types=FALSE) |> select(ICAO,LAT,LON),read_csv('notes/reference-data/EUR-airport-coordinates-2024-12-27.csv',show_col_types=FALSE) |> transmute(ICAO,LAT=ARP_LAT,LON=ARP_LON)) |> distinct(ICAO,.keep_all=TRUE)
gcd<-function(a,b,c,d){r<-pi/180;3440.065*2*asin(sqrt(pmin(1,pmax(0,sin((c-a)*r/2)^2+cos(a*r)*cos(c*r)*sin((d-b)*r/2)^2))))}
meta<-bind_rows(cm |> distinct(SOURCE_UID,TYPE,ADEP,ADES) |> mutate(REGION='CHN'),em |> distinct(SOURCE_UID,TYPE,ADEP,ADES) |> mutate(REGION='EUR')) |>
 mutate(TYPE=recode(TYPE,!!!type_map)) |> left_join(ap |> transmute(ADEP=ICAO,DLAT=LAT,DLON=LON),by='ADEP') |> left_join(ap |> transmute(ADES=ICAO,ALAT=LAT,ALON=LON),by='ADES') |>
 mutate(GCD_NM=gcd(DLAT,DLON,ALAT,ALON),BAND100=floor(GCD_NM/100)*100)
stopifnot(nrow(meta)==27924,!anyDuplicated(meta[,c('REGION','SOURCE_UID')]),all(is.finite(meta$GCD_NM)))
write_csv(meta,file.path(out,'restricted-flight-strata.csv'))
core<-bind_rows(cm |> select(SOURCE_UID,MST,TIME) |> mutate(REGION='CHN'),em |> select(SOURCE_UID,MST,TIME) |> mutate(REGION='EUR')) |> filter(MST%in%c('ATOT','ALDT')) |>
 pivot_wider(names_from=MST,values_from=TIME)
# Retain the existing paper's broad whole-flight timing/GCD review, rather than
# silently passing its known out-of-context EUR source-clock case. Local CHN
# coverage can still support a window when a separate part of the flight has a gap.
meta<-meta |> left_join(core,by=c('REGION','SOURCE_UID')) |>
 mutate(SOURCE_AIR_MIN=as.numeric(difftime(ALDT,ATOT,units='mins')),
 SOURCE_CORE_TIMING_OK=coalesce(SOURCE_AIR_MIN>=10&SOURCE_AIR_MIN<=480&GCD_NM/SOURCE_AIR_MIN*60<=650,FALSE))
write_csv(meta,file.path(out,'restricted-flight-strata.csv'))
write_csv(meta |> mutate(ATOT_UTC_MONTH=if_else(is.na(ATOT),'missing',format(ATOT,'%Y-%m',tz='UTC'))) |> count(REGION,ATOT_UTC_MONTH,name='FLIGHTS'),file.path(out,'aggregate-operating-months.csv'))
write_csv(meta |> group_by(REGION) |> summarise(INPUT=n(),TIMING_CONTEXT_PASS=sum(SOURCE_CORE_TIMING_OK),TIMING_CONTEXT_REVIEW=sum(!SOURCE_CORE_TIMING_OK),.groups='drop'),file.path(out,'aggregate-source-context-review.csv'))

# EUR has repeated retained candidates. Harmonize to CHN first departure / last arrival,
# preserving the other candidates in the immutable source products.
anchors<-c('D_FL075','D_FL100','D_FL180','A_FL180','A_FL100','A_FL075','D040','D100','D200','A200','A100','A040')
events<-bind_rows(cm |> filter(MST%in%c('ATOT','TOC','TOD','ALDT',anchors)) |> select(SOURCE_UID,MST,TIME,ALT_FT,TOT_FUEL_KG,TOT_FUEL_KG_ORIGINAL,DIST_FLOWN_NM,MST_METHOD,BRACKET_SEC) |> mutate(REGION='CHN'),
 em |> filter(MST%in%c('ATOT','TOC','TOD','ALDT',anchors)) |> select(SOURCE_UID,MST,TIME,ALT_FT,TOT_FUEL_KG,TOT_FUEL_KG_ORIGINAL,DIST_FLOWN_NM,MST_METHOD) |> mutate(REGION='EUR',BRACKET_SEC=NA_real_)) |>
 inner_join(core,by=c('REGION','SOURCE_UID')) |> filter(is.finite(as.numeric(TIME)),TIME>=ATOT,TIME<=ALDT) |> arrange(REGION,SOURCE_UID,MST,TIME) |>
 group_by(REGION,SOURCE_UID,MST) |> slice(if(first(MST)%in%c('A040','A100','A200','A_FL075','A_FL100','A_FL180'))n()else 1L) |> ungroup()
# Endpoint resolution comes from the actual M3 crossing, not nearest G2G row IDs.
res<-ec |> filter(!SUPPRESS_LEVEL_ASSOCIATED) |> select(SOURCE_UID,MST,TIME,M3_BRACKET_GAP_SEC) |> distinct(SOURCE_UID,MST,TIME,.keep_all=TRUE)
events<-events |> left_join(mutate(res,REGION='EUR'),by=c('REGION','SOURCE_UID','MST','TIME'))
windows<-tribble(~WINDOW,~FROM,~TO,~FAMILY,
 'Whole airborne','ATOT','ALDT','Whole',
 'Climb source window','ATOT','TOC','Macro',
 'Enroute source window','TOC','TOD','Macro',
 'Descent source window','TOD','ALDT','Macro',
 'Climb FL075-FL100','D_FL075','D_FL100','Pressure',
 'Climb FL100-FL180','D_FL100','D_FL180','Pressure',
 'Descent FL180-FL100','A_FL180','A_FL100','Pressure',
 'Descent FL100-FL075','A_FL100','A_FL075','Pressure',
 'Takeoff-FL075','ATOT','D_FL075','Pressure_terminal',
 'FL075-landing','A_FL075','ALDT','Pressure_terminal',
 'Departure ARP040-100','D040','D100','ARP',
 'Departure ARP100-200','D100','D200','ARP',
 'Arrival ARP200-100','A200','A100','ARP',
 'Arrival ARP100-040','A100','A040','ARP')
w<-crossing(meta,windows) |>
 left_join(events |> select(REGION,SOURCE_UID,FROM=MST,START_TIME=TIME,FROM_ALT=ALT_FT,FROM_FUEL=TOT_FUEL_KG,FROM_ORIGINAL=TOT_FUEL_KG_ORIGINAL,FROM_DIST=DIST_FLOWN_NM,FROM_GAP=M3_BRACKET_GAP_SEC,FROM_METHOD=MST_METHOD),by=c('REGION','SOURCE_UID','FROM')) |>
 left_join(events |> select(REGION,SOURCE_UID,TO=MST,END_TIME=TIME,TO_ALT=ALT_FT,TO_FUEL=TOT_FUEL_KG,TO_ORIGINAL=TOT_FUEL_KG_ORIGINAL,TO_DIST=DIST_FLOWN_NM,TO_GAP=M3_BRACKET_GAP_SEC,TO_METHOD=MST_METHOD),by=c('REGION','SOURCE_UID','TO')) |>
 mutate(DURATION_MIN=as.numeric(difftime(END_TIME,START_TIME,units='mins')),FUEL_KG=TO_FUEL-FROM_FUEL,ORIGINAL_FUEL_KG=TO_ORIGINAL-FROM_ORIGINAL,FLOWN_NM=TO_DIST-FROM_DIST,ORDERED=is.finite(DURATION_MIN)&DURATION_MIN>0)
cat('Constructed',nrow(w),'flight/window opportunities\n')
# Local CHN accounting uses the returned non-overlapping fine partition, so a gap
# or bad channel outside this window does not remove an independently supported interval.
prefix<-ci |> arrange(SOURCE_UID,START_TIME,END_TIME) |> group_by(SOURCE_UID) |>
 mutate(C_TIME=cumsum(DURATION_MIN),C_FUEL=cumsum(if_else(is.finite(FUEL_KG),FUEL_KG,0)),C_DIST=cumsum(if_else(is.finite(DISTANCE_NM),DISTANCE_NM,0)),
 C_BAD_FUEL=cumsum(!coalesce(ELIGIBLE_FUEL_TIME&is.finite(FUEL_KG)&FUEL_KG>=0,FALSE)),C_BAD_DIST=cumsum(!coalesce(ELIGIBLE_DISTANCE&is.finite(DISTANCE_NM)&DISTANCE_NM>=0,FALSE)),C_BAD_PROFILE=cumsum(!is.finite(ALTITUDE_CHANGE_FT))) |> ungroup()
zeros<-prefix |> group_by(SOURCE_UID) |> slice_head(n=1) |> ungroup() |> transmute(SOURCE_UID,TIME=START_TIME,C_TIME=0,C_FUEL=0,C_DIST=0,C_BAD_FUEL=0,C_BAD_DIST=0,C_BAD_PROFILE=0)
prefix<-bind_rows(zeros,prefix |> transmute(SOURCE_UID,TIME=END_TIME,C_TIME,C_FUEL,C_DIST,C_BAD_FUEL,C_BAD_DIST,C_BAD_PROFILE))
stopifnot(!anyDuplicated(prefix[,c('SOURCE_UID','TIME')]))
cw<-w |> filter(REGION=='CHN') |>
 left_join(prefix |> rename(START_TIME=TIME) |> rename_with(~paste0('START_',.x),starts_with('C_')),by=c('SOURCE_UID','START_TIME')) |>
 left_join(prefix |> rename(END_TIME=TIME) |> rename_with(~paste0('END_',.x),starts_with('C_')),by=c('SOURCE_UID','END_TIME')) |>
 left_join(cq |> select(SOURCE_UID,AIRBORNE_TIME_VALID,AIRBORNE_DISTANCE_VALID,AIRBORNE_PROFILE_VALID,STUDY_EXCLUDE,WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE),by='SOURCE_UID') |>
 mutate(PARTITION_COVERS=coalesce(abs(END_C_TIME-START_C_TIME-DURATION_MIN)<1e-5,FALSE),
 LOCAL_FUEL=PARTITION_COVERS&coalesce(END_C_BAD_FUEL==START_C_BAD_FUEL,FALSE),LOCAL_DIST=PARTITION_COVERS&coalesce(END_C_BAD_DIST==START_C_BAD_DIST,FALSE),LOCAL_PROFILE=PARTITION_COVERS&coalesce(END_C_BAD_PROFILE==START_C_BAD_PROFILE,FALSE),
 FUEL_KG=if_else(LOCAL_FUEL,END_C_FUEL-START_C_FUEL,NA_real_),FLOWN_NM=if_else(LOCAL_DIST,END_C_DIST-START_C_DIST,NA_real_),
 TIME_OK=ORDERED&(AIRBORNE_TIME_VALID|LOCAL_FUEL)&(FAMILY%in%c('Whole','Macro')==FALSE|SOURCE_CORE_TIMING_OK),
 GEOMETRY_OK=FAMILY!='ARP'|LOCAL_DIST,
 PROFILE_OK=TIME_OK&LOCAL_PROFILE&is.finite(FROM_ALT)&is.finite(TO_ALT)&GEOMETRY_OK,
 FUEL_OK=TIME_OK&LOCAL_FUEL&is.finite(FUEL_KG)&FUEL_KG>0&GEOMETRY_OK,
 DISTANCE_OK=TIME_OK&LOCAL_DIST&is.finite(FLOWN_NM)&FLOWN_NM>0&FLOWN_NM/DURATION_MIN*60<=750,
 TIME_OK=TIME_OK&GEOMETRY_OK,
 RESOLUTION_30=TRUE,RESOLUTION_300=TRUE,PROFILE_300_OK=PROFILE_OK)
# EUR fuel is time-interpolated model cumulative fuel at retained M3/G2G events.
# These are structural/model-support counts, not an assertion of recorder-level resolution.
ew<-w |> filter(REGION=='EUR') |> mutate(
 TIME_OK=ORDERED&(!FAMILY%in%c('Whole','Macro')|SOURCE_CORE_TIMING_OK),GEOMETRY_OK=TRUE,
 PROFILE_OK=TIME_OK&is.finite(FROM_ALT)&is.finite(TO_ALT),
 FUEL_OK=TIME_OK&is.finite(FUEL_KG)&FUEL_KG>0&SOURCE_CORE_TIMING_OK,
 DISTANCE_OK=TIME_OK&is.finite(FLOWN_NM)&FLOWN_NM>0&FLOWN_NM/DURATION_MIN*60<=750&SOURCE_CORE_TIMING_OK,
 RESOLUTION_30=(FROM%in%c('ATOT','ALDT')|coalesce(FROM_GAP<=30,FALSE))&(TO%in%c('ATOT','ALDT')|coalesce(TO_GAP<=30,FALSE)),
 RESOLUTION_300=(FROM%in%c('ATOT','ALDT')|coalesce(FROM_GAP<=300,FALSE))&(TO%in%c('ATOT','ALDT')|coalesce(TO_GAP<=300,FALSE)))
# Independently assess EUR altitude-time bracketing from the unchanged M3 profiles.
# The all-span model and <=300 s support are distinct, not a global exclusion.
m3_files<-file.path(store,'raw/eur/source-sample',sprintf('m3-ctfm-2025-%02d.parquet',6:8))
m3<-bind_rows(lapply(m3_files,function(p)as.data.frame(read_parquet(p,col_select=c('FLIGHT_ID','TIME_OVER','FLIGHT_LEVEL'))))) |>
 transmute(SOURCE_UID=as.character(FLIGHT_ID),T=as.numeric(TIME_OVER),ALT_FT=as.numeric(FLIGHT_LEVEL)*100) |>
 filter(is.finite(T),is.finite(ALT_FT),ALT_FT>=0,ALT_FT<=50000) |>
 group_by(SOURCE_UID,T) |> summarise(ALT_FT=median(ALT_FT),.groups='drop') |> arrange(SOURCE_UID,T)
m3_bounds<-m3 |> group_by(SOURCE_UID) |> summarise(MIN_T=min(T),MAX_T=max(T),.groups='drop')
bad_spans<-m3 |> group_by(SOURCE_UID) |> mutate(LEFT_T=T,RIGHT_T=lead(T)) |> ungroup() |>
 filter(RIGHT_T-LEFT_T>300) |> select(SOURCE_UID,LEFT_T,RIGHT_T)
eprofile<-ew |> transmute(SOURCE_UID,WINDOW,START_NUM=as.numeric(START_TIME),END_NUM=as.numeric(END_TIME)) |>
 left_join(bad_spans,by=join_by(SOURCE_UID,START_NUM<RIGHT_T,END_NUM>LEFT_T),relationship='many-to-many') |>
 mutate(BAD_SEC=coalesce(pmax(0,pmin(END_NUM,RIGHT_T)-pmax(START_NUM,LEFT_T)),0)) |>
 group_by(SOURCE_UID,WINDOW) |> summarise(M3_LONG_GAP_SEC=sum(BAD_SEC),.groups='drop')
ew<-ew |> left_join(m3_bounds,by='SOURCE_UID') |> left_join(eprofile,by=c('SOURCE_UID','WINDOW')) |>
 mutate(PROFILE_OK=PROFILE_OK&coalesce(as.numeric(START_TIME)>=MIN_T-2e-6&as.numeric(END_TIME)<=MAX_T+2e-6,FALSE),
 PROFILE_300_OK=PROFILE_OK&coalesce(M3_LONG_GAP_SEC<1e-5,FALSE))

# Missing or ambiguous source units/geometry are not borrowed from the other region.
keep<-c(names(w),'TIME_OK','GEOMETRY_OK','PROFILE_OK','FUEL_OK','DISTANCE_OK','RESOLUTION_30','RESOLUTION_300','PROFILE_300_OK')
x<-bind_rows(select(cw,all_of(keep)),select(ew,all_of(keep))) |> mutate(FUEL_RATE_OK=FUEL_OK,DISTANCE_RATE_OK=FUEL_OK&DISTANCE_OK,PROFILE_FUEL_OK=FUEL_OK&PROFILE_OK,PROFILE_FUEL_300_OK=FUEL_OK&PROFILE_300_OK,
 FUEL_30_OK=if_else(FAMILY%in%c('Whole','Macro'),NA,FUEL_OK&RESOLUTION_30),FUEL_300_OK=if_else(FAMILY%in%c('Whole','Macro'),NA,FUEL_OK&RESOLUTION_300))
stopifnot(nrow(x)==nrow(w),!anyDuplicated(x[,c('REGION','SOURCE_UID','WINDOW')]))
write_parquet(x,file.path(out,'restricted-window-eligibility.parquet'))
# Verify local fuel integration against source endpoint differences wherever both
# are supported; this does not force locally supported windows to pass whole-air fuel QC.
check<-x |> filter(REGION=='CHN',FUEL_OK,is.finite(FROM_FUEL),is.finite(TO_FUEL)) |>
 mutate(ERROR=abs(FUEL_KG-(TO_FUEL-FROM_FUEL)))
stopifnot(all(check$ERROR<=2e-6))
write_csv(check |>group_by(WINDOW) |> summarise(COMPARED=n(),MAX_FUEL_ERROR_KG=max(ERROR),.groups='drop'),file.path(out,'aggregate-local-fuel-validation.csv'))
whole<-x |> filter(WINDOW=='Whole airborne') |>select(REGION,SOURCE_UID,WHOLE_FUEL_OK=FUEL_OK)
recovery<-x |> filter(REGION=='CHN') |>left_join(select(cq,SOURCE_UID,STUDY_EXCLUDE),by='SOURCE_UID') |>left_join(whole,by=c('REGION','SOURCE_UID')) |>
 group_by(WINDOW,FAMILY) |>summarise(FUEL_TIME_N=sum(FUEL_OK),SUPPORTED_DESPITE_COMMON_COHORT_HOLD=sum(FUEL_OK&STUDY_EXCLUDE),LOCAL_FUEL_WHEN_WHOLE_AIRBORNE_UNSUPPORTED=sum(FUEL_OK&!WHOLE_FUEL_OK),.groups='drop')
write_csv(recovery,file.path(out,'aggregate-local-support-recovery.csv'))

summary<-x |> group_by(REGION,WINDOW,FAMILY) |> summarise(INPUT=n(),ORDERED_ENDPOINTS=sum(ORDERED),TIME_N=sum(TIME_OK),PROFILE_N=sum(PROFILE_OK),PROFILE_FUEL_N=sum(PROFILE_FUEL_OK),PROFILE_300_N=sum(PROFILE_300_OK),FUEL_TIME_N=sum(FUEL_OK),DISTANCE_N=sum(DISTANCE_OK),KG_NM_N=sum(DISTANCE_RATE_OK),FUEL_TIME_30SEC_N=sum(FUEL_OK&RESOLUTION_30),FUEL_TIME_300SEC_N=sum(FUEL_OK&RESOLUTION_300),.groups='drop')
summary<-summary |> mutate(FUEL_TIME_30SEC_N=if_else(FAMILY%in%c('Whole','Macro'),NA_integer_,FUEL_TIME_30SEC_N),FUEL_TIME_300SEC_N=if_else(FAMILY%in%c('Whole','Macro'),NA_integer_,FUEL_TIME_300SEC_N))
write_csv(summary,file.path(out,'aggregate-window-support.csv'))
# Per-metric support: no global profile or distance gate preselects these cells.
long<-bind_rows(lapply(c('TIME_OK','PROFILE_OK','PROFILE_FUEL_OK','PROFILE_FUEL_300_OK','FUEL_OK','FUEL_30_OK','FUEL_300_OK','DISTANCE_RATE_OK'),function(metric)x |> filter(.data[[metric]]) |> transmute(REGION,SOURCE_UID,TYPE,BAND100,WINDOW,FAMILY,METRIC=metric)))
cells<-long |> group_by(REGION,TYPE,BAND100,WINDOW,FAMILY,METRIC) |> summarise(N=n_distinct(SOURCE_UID),.groups='drop') |>
 pivot_wider(names_from=REGION,values_from=N,values_fill=0) |> mutate(PAIRED_SUPPORT=CHN>=30&EUR>=30)
write_csv(cells,file.path(out,'aggregate-type-stage-window-support.csv'))
paired<-cells |> filter(PAIRED_SUPPORT) |> group_by(WINDOW,FAMILY,METRIC) |> summarise(CELLS=n(),CHN=sum(CHN),EUR=sum(EUR),.groups='drop')
write_csv(paired,file.path(out,'aggregate-paired-support.csv'))
source_counts<-meta |> count(REGION,TYPE) |> pivot_wider(names_from=REGION,values_from=n,values_fill=0)
write_csv(source_counts,file.path(out,'aggregate-aircraft-overlap.csv'))
method<-events |> filter(MST%in%c('TOC','TOD')) |> count(REGION,MST,MST_METHOD,name='FLIGHTS')
write_csv(method,file.path(out,'aggregate-boundary-methods.csv'))
variants<-ew |> filter(FAMILY%in%c('Whole','Macro','Pressure','ARP'),FUEL_OK,is.finite(ORIGINAL_FUEL_KG)) |> group_by(WINDOW) |> summarise(N=n(),DIFFERENT_AIRBORNE_FUEL_VARIANTS=sum(abs(FUEL_KG-ORIGINAL_FUEL_KG)>1e-6),.groups='drop')
write_csv(variants,file.path(out,'aggregate-eur-fuel-convention.csv'))
# Keep a strict overlap for a paired whole/climb/enroute/descent decomposition as
# a sensitivity only; do not impose it on independently supported fine windows.
complete<-x |> filter(FAMILY%in%c('Whole','Macro')) |> group_by(REGION,SOURCE_UID) |> summarise(N=sum(FUEL_OK),.groups='drop') |> group_by(REGION) |> summarise(ALL_FOUR_FUEL_WINDOWS=sum(N==4),.groups='drop')
write_csv(complete,file.path(out,'aggregate-complete-partition.csv'))
# Source level products are available for the profile adapter. Counts here do not
# certify identical detector performance or imply continuity when a tag is absent.
lev<-bind_rows(readc('CHN-level-segments') |> transmute(REGION='CHN',SOURCE_UID,LEVEL_CONTEXT_PHASE,DURATION_SEC,START_ALT_FT,END_ALT_FT),
 as.data.frame(read_parquet(file.path(eurd,'EUR-level-segments-parallel.parquet'))) |> transmute(REGION='EUR',SOURCE_UID,LEVEL_CONTEXT_PHASE,DURATION_SEC,START_ALT_FT,END_ALT_FT)) |>
 mutate(COMMON_DURATION_SPAN=is.finite(DURATION_SEC)&DURATION_SEC>=120&is.finite(START_ALT_FT)&is.finite(END_ALT_FT)&abs(END_ALT_FT-START_ALT_FT)<=1000)
write_csv(lev |> group_by(REGION,LEVEL_CONTEXT_PHASE) |> summarise(SOURCE_SEGMENTS=n(),FLIGHTS=n_distinct(SOURCE_UID),SEGMENTS_GE_120SEC_WITHIN_1000FT=sum(COMMON_DURATION_SPAN),FLIGHTS_WITH_QUALIFYING_SOURCE_SEGMENT=n_distinct(SOURCE_UID[COMMON_DURATION_SPAN]),.groups='drop'),file.path(out,'aggregate-source-level-products.csv'))

writeLines(capture.output(sessionInfo()),file.path(out,'runtime.txt'))
print(summary |> filter(FAMILY%in%c('Whole','Macro','Pressure')),n=30,width=Inf)
cat('Common fuel/time cells\n');print(filter(paired,METRIC=='FUEL_OK'),n=30)
