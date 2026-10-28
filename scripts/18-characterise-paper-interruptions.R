#!/usr/bin/env Rscript
# Analysis-only common interruption definitions. All flight-level outputs restricted.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow);library(ggplot2)})
source('R/paper-window-references.R');source('R/paper-profile-classes.R')
cfg<-paper_profile_read_config()
study<-load_paper_window_references()
store<-cfg$base$store
point_files<-sort(list.files(file.path(store,cfg$base$chn_directory),'^CHN-supported-data-points.parquet$',recursive=TRUE,full.names=TRUE))
run_files<-sort(list.files(file.path(store,cfg$base$chn_directory),'^run-manifest.json$',recursive=TRUE,full.names=TRUE))
stopifnot(length(point_files)==14,length(run_files)==14)
extra<-c(point_files,run_files)
inputs<-bind_rows(select(cfg$base$manifest,PATH,SHA256),tibble(PATH=sub(paste0('^',store,'/'),'data-store/',extra),
  SHA256=vapply(extra,digest::digest,character(1),algo='sha256',file=TRUE)))
stopifnot(!anyDuplicated(inputs$PATH))
dir.create(cfg$output,recursive=TRUE,showWarnings=FALSE)
dir.create(cfg$snapshot_directory,recursive=TRUE,showWarnings=FALSE)
windows<-study$windows |>filter(WINDOW%in%c(cfg$base$core_windows,cfg$base$terminal_options,'Climb source window','Descent source window')) |>
  mutate(SOURCE_PROFILE_OK=coalesce(PROFILE_OK,TRUE),SOURCE_PROFILE_GATE_KNOWN=!is.na(PROFILE_OK)) |>
  select(REGION,SOURCE_UID,TYPE,BAND100,WINDOW,FROM,TO,START_TIME,END_TIME,
    DURATION_MIN,TIME_OK,FUEL_OK,DISTANCE_RATE_OK,FUEL_KG,FLOWN_NM,SOURCE_PROFILE_OK,SOURCE_PROFILE_GATE_KNOWN) |>
  mutate(DIRECTION=if_else(grepl('^Climb|^Takeoff',WINDOW),1,-1),KEY=paste(REGION,SOURCE_UID))
cat('Read native altitude points; no source level boundaries are inserted.\n')
cache_file<-file.path(cfg$output,'restricted-native-interval-cache.rds')
# Only the deterministic native-interval preparation affects this cache.
cache_key<-digest::digest(list(inputs,'native-interval-preparation-v1'),algo='sha256')
cached<-if(file.exists(cache_file))readRDS(cache_file)else NULL
if(!is.null(cached)&&identical(cached$key,cache_key)) {
  native_summary<-cached$summary;steps<-cached$steps
} else {
chn<-bind_rows(lapply(point_files,function(p)read_parquet(p,col_select=c('SOURCE_UID','TIME','ALT_FT','ALTITUDE_UNRESOLVED')))) |>
  transmute(REGION='CHN',SOURCE_UID,T=as.numeric(TIME),H=if_else(coalesce(ALTITUDE_UNRESOLVED,TRUE),NA_real_,ALT_FT))
eur<-bind_rows(lapply(file.path(store,'raw/eur/source-sample',sprintf('m3-ctfm-2025-%02d.parquet',6:8)),
  function(p)read_parquet(p,col_select=c('FLIGHT_ID','TIME_OVER','FLIGHT_LEVEL')))) |>
  transmute(REGION='EUR',SOURCE_UID=as.character(FLIGHT_ID),T=as.numeric(TIME_OVER),H=as.numeric(FLIGHT_LEVEL)*100)
native<-bind_rows(chn,eur) |>filter(is.finite(T)) |>mutate(H=if_else(is.finite(H)&H>=0&H<=50000,H,NA_real_)) |>
  group_by(REGION,SOURCE_UID,T) |>summarise(H=if(all(is.finite(H))&&max(H)-min(H)<1e-5)first(H)else NA_real_,.groups='drop') |>
  arrange(REGION,SOURCE_UID,T) |>group_by(REGION,SOURCE_UID) |>mutate(T1=lead(T),H1=lead(H)) |>ungroup() |>
  mutate(KEY=paste(REGION,SOURCE_UID))
native_summary<-native |>group_by(REGION,SOURCE_UID) |>summarise(KNOTS=n(),MEDIAN_GAP_SEC=median(T1-T,na.rm=TRUE),
  MAX_GAP_SEC=max(T1-T,na.rm=TRUE),.groups='drop') |>group_by(REGION) |>summarise(FLIGHTS=n(),
    KNOTS_P50=median(KNOTS),WITHIN_FLIGHT_MEDIAN_GAP_P50=median(MEDIAN_GAP_SEC),MAX_GAP_P50=median(MAX_GAP_SEC),.groups='drop')
steps<-native |>filter(is.finite(T1),T1>T) |>select(KEY,T,T1,H,H1)
saveRDS(list(key=cache_key,summary=native_summary,steps=steps),cache_file)
rm(native,chn,eur)
}
rm(cached)
step_groups<-split(seq_len(nrow(steps)),steps$KEY)
window_groups<-split(seq_len(nrow(windows)),windows$KEY)
specs<-cfg$feature_specs
spec_list<-lapply(seq_len(nrow(specs)),function(k)as.list(specs[k,]))
cat('Measure',length(window_groups),'flight profiles in',nrow(specs),'feature/coverage specifications.\n')
rows<-vector('list',length(window_groups));counter<-0L
for(key in names(window_groups)) {
  counter<-counter+1L
  wi<-window_groups[[key]];pi<-step_groups[[key]]
  trace<-if(is.null(pi))steps[0,]else steps[pi,]
  result<-lapply(wi,function(j) {
    w<-windows[j,]
    clip<-paper_profile_clip(trace,as.numeric(w$START_TIME),as.numeric(w$END_TIME),w$DIRECTION,cfg$vertical_rate_limit_fpm)
    lapply(spec_list,function(sp)paper_profile_measure(clip,sp,w$TIME_OK,cfg,as_frame=FALSE,source_profile_ok=w$SOURCE_PROFILE_OK))
  })
  rows[[counter]]<-bind_cols(windows[rep(wi,each=nrow(specs)),],bind_rows(unlist(result,recursive=FALSE)))
  if(counter%%2000L==0L)cat('Measured',counter,'flights.\n')
}
x<-bind_rows(rows) |>select(-KEY)
rm(rows,step_groups,window_groups,steps)
stopifnot(nrow(x)==nrow(windows)*nrow(specs),!anyNA(x$PROFILE_CLASS),
  all(x$PROFILE_CLASS[!x$PROFILE_ELIGIBLE]=='Unknown'))
primary<-filter(x,SPEC==cfg$primary_spec)

# Source level segments are a second evidence axis, not a common detector or coverage.
read_manifest_role<-function(name)bind_rows(lapply(cfg$base$manifest$LOCAL_PATH[basename(cfg$base$manifest$LOCAL_PATH)==name],read_parquet))
levels<-bind_rows(read_manifest_role('CHN-level-segments.parquet') |>mutate(REGION='CHN'),
  read_manifest_role('EUR-level-segments-parallel.parquet') |>mutate(REGION='EUR')) |>
  transmute(REGION,SOURCE_UID,L_START=as.numeric(START_TIME),L_END=as.numeric(END_TIME),
    LEVEL_SEC=as.numeric(END_TIME-START_TIME),START_ALT_FT,END_ALT_FT) |>
  filter(is.finite(L_START),is.finite(L_END),LEVEL_SEC>0,is.finite(START_ALT_FT),is.finite(END_ALT_FT),
    abs(END_ALT_FT-START_ALT_FT)/LEVEL_SEC*60<=cfg$vertical_rate_limit_fpm)
evidence<-windows |>transmute(REGION,SOURCE_UID,WINDOW,TYPE,BAND100,TIME_OK,FUEL_OK,A=as.numeric(START_TIME),B=as.numeric(END_TIME)) |>
  left_join(levels,by=join_by(REGION,SOURCE_UID,A<L_END,B>L_START),relationship='many-to-many') |>
  mutate(CLIPPED_SEC=pmax(0,pmin(B,L_END)-pmax(A,L_START)),QUALIFIES=coalesce(CLIPPED_SEC>=120-1e-7,FALSE)) |>
  group_by(REGION,SOURCE_UID,WINDOW,TYPE,BAND100) |>
  summarise(TIME_OK=first(TIME_OK),FUEL_OK=first(FUEL_OK),HAS_NATIVE_LEVEL_EVIDENCE=any(QUALIFIES),
    QUALIFYING_NATIVE_SEGMENTS=sum(QUALIFIES),.groups='drop') |>
  left_join(primary |>select(REGION,SOURCE_UID,WINDOW,PROFILE_ELIGIBLE,PROFILE_CLASS),by=c('REGION','SOURCE_UID','WINDOW'))

support<-x |>group_by(SPEC,MIN_LEVEL_SEC,MAX_GAP_SEC,REGION,WINDOW) |>summarise(INPUT=n(),TIME_N=sum(TIME_OK),
  FULL_BRACKET_N=sum(TIME_OK&abs(ALTITUDE_KNOWN_SEC-DURATION_MIN*60)<1e-4,na.rm=TRUE),
  COVERAGE_N=sum(TIME_OK&COVERAGE_OK),CLASSIFIABLE_N=sum(PROFILE_ELIGIBLE),
  CLASSIFIABLE_FUEL_N=sum(PROFILE_ELIGIBLE&FUEL_OK),
  CONTINUOUS_N=sum(PROFILE_CLASS==paper_profile_labels[1]),LIGHT_N=sum(PROFILE_CLASS==paper_profile_labels[2]),
  HEAVY_N=sum(PROFILE_CLASS==paper_profile_labels[3]),UNKNOWN_N=sum(PROFILE_CLASS=='Unknown'),
  CONTINUOUS_FUEL_N=sum(PROFILE_CLASS==paper_profile_labels[1]&FUEL_OK),
  LIGHT_FUEL_N=sum(PROFILE_CLASS==paper_profile_labels[2]&FUEL_OK),
  HEAVY_FUEL_N=sum(PROFILE_CLASS==paper_profile_labels[3]&FUEL_OK),.groups='drop')
status<-x |>count(SPEC,REGION,WINDOW,PROFILE_STATUS,name='N')
classes<-x |>group_by(SPEC,REGION,WINDOW,PROFILE_CLASS) |>summarise(N=n(),FUEL_N=sum(FUEL_OK),TIME_N=sum(TIME_OK),.groups='drop') |>
  complete(SPEC,REGION,WINDOW,PROFILE_CLASS=paper_profile_labels,fill=list(N=0L,FUEL_N=0L,TIME_N=0L))
# Complete every class/type/stage slot; zero support is observable rather than absent.
cells<-crossing(windows |>distinct(TYPE,BAND100),SPEC=specs$SPEC,WINDOW=unique(windows$WINDOW),
  REGION=c('CHN','EUR'),PROFILE_CLASS=paper_profile_labels) |>
  left_join(x |>group_by(SPEC,REGION,TYPE,BAND100,WINDOW,PROFILE_CLASS) |>
    summarise(N=n(),FUEL_N=sum(FUEL_OK),.groups='drop'),by=c('SPEC','REGION','TYPE','BAND100','WINDOW','PROFILE_CLASS')) |>
  mutate(N=coalesce(N,0L),FUEL_N=coalesce(FUEL_N,0L))
pairs<-cells |>pivot_wider(names_from=REGION,values_from=c(N,FUEL_N),values_fill=0) |>
  mutate(PAIRED_PROFILE=PROFILE_CLASS!='Unknown'&N_CHN>=cfg$minimum_reference_n&N_EUR>=cfg$minimum_reference_n,
    PAIRED_FUEL=PROFILE_CLASS!='Unknown'&FUEL_N_CHN>=cfg$minimum_reference_n&FUEL_N_EUR>=cfg$minimum_reference_n)
paired_support<-pairs |>group_by(SPEC,WINDOW,PROFILE_CLASS) |>summarise(PROFILE_CELLS=sum(PAIRED_PROFILE),FUEL_CELLS=sum(PAIRED_FUEL),
  CHN=sum(FUEL_N_CHN[PAIRED_FUEL]),EUR=sum(FUEL_N_EUR[PAIRED_FUEL]),.groups='drop')
native_evidence<-evidence |>group_by(REGION,WINDOW) |>summarise(TIME_N=sum(TIME_OK),
  SOURCE_LEVEL_EVIDENCE_N=sum(TIME_OK&HAS_NATIVE_LEVEL_EVIDENCE),SOURCE_LEVEL_EVIDENCE_FUEL_N=sum(FUEL_OK&HAS_NATIVE_LEVEL_EVIDENCE),
  COMMON_CLASSIFIABLE_WITH_SOURCE_LEVEL_N=sum(PROFILE_ELIGIBLE&HAS_NATIVE_LEVEL_EVIDENCE),.groups='drop')
native_cells<-evidence |>group_by(REGION,TYPE,BAND100,WINDOW) |>summarise(TIME_N=sum(TIME_OK),
  SOURCE_LEVEL_EVIDENCE_N=sum(TIME_OK&HAS_NATIVE_LEVEL_EVIDENCE),.groups='drop')
thresholds<-tibble(SCENARIO=c('Primary','Light share 10%','Light share 30%','Light max 1 interruption','Light max 3 interruptions',
  'Light longest 120s','Light longest 240s'),MAX_N=c(2,2,2,1,3,2,2),MAX_SHARE=c(.2,.1,.3,.2,.2,.2,.2),MAX_LONGEST=c(180,180,180,180,180,120,240))
sensitivity<-bind_rows(lapply(seq_len(nrow(thresholds)),function(i) {
  th<-thresholds[i,]
  primary |>mutate(PROFILE_CLASS=paper_profile_class(INTERRUPTION_N,LEVEL_SEC,DURATION_MIN*60,LONGEST_SEC,
    PROFILE_ELIGIBLE,th$MAX_N,th$MAX_SHARE,th$MAX_LONGEST),SCENARIO=th$SCENARIO) |>
    group_by(SCENARIO,REGION,WINDOW,PROFILE_CLASS) |>summarise(N=n(),FUEL_N=sum(FUEL_OK),.groups='drop')
})) |>complete(SCENARIO,REGION,WINDOW,PROFILE_CLASS=paper_profile_labels,fill=list(N=0L,FUEL_N=0L))
# Independent metric-specific references. Unknown is exported but never a paired profile class.
values<-paper_metric_values(primary) |>select(REGION,TYPE,BAND100,WINDOW,PROFILE_CLASS,FUEL_KG,DURATION_MIN,KG_MIN,KG_NM) |>
  pivot_longer(c(FUEL_KG,DURATION_MIN,KG_MIN,KG_NM),names_to='METRIC',values_to='VALUE')
refs<-values |>group_by(REGION,TYPE,BAND100,WINDOW,PROFILE_CLASS,METRIC) |>
  summarise(N=sum(is.finite(VALUE)),Q=list(paper_ref_q(VALUE,cfg$minimum_reference_n)),.groups='drop') |>
  mutate(P20=vapply(Q,`[`,0,1),P50=vapply(Q,`[`,0,2),P80=vapply(Q,`[`,0,3),
    PERCENTILE_STATUS=if_else(N>=cfg$minimum_reference_n,'Populated','Suppressed: n < 30')) |>select(-Q)
defs<-tibble(CLASS=paper_profile_labels,DEFINITION=c('No qualifying episode in a completely resolved window at the stated feature scale',
  '1-2 qualifying episodes, level share <=20%, longest <=180 seconds; all three limits required',
  'At least 3 episodes OR level share >20% OR longest >180 seconds',
  'Unsupported time, incomplete altitude/gap coverage, window shorter than feature scale, or material reversal'))

write_parquet(x,file.path(cfg$output,'restricted-profile-class-ledger.parquet'))
write_parquet(evidence,file.path(cfg$output,'restricted-source-level-evidence.parquet'))
products<-list(support=support,status=status,class_counts=classes,cell_support=pairs,paired_support=paired_support,
  native_level_evidence=native_evidence,native_level_cell_evidence=native_cells,
  native_point_summary=native_summary,threshold_sensitivity=sensitivity,thresholds=thresholds,
  class_definitions=defs,feature_specs=specs,class_references=refs)
result<-c(list(config=cfg,input_manifest=inputs,source_fingerprint=paper_profile_fingerprint(cfg)),products)
saveRDS(result,file.path(cfg$output,'analysis.rds'))
for(name in names(products))write_csv(products[[name]],file.path(cfg$snapshot_directory,paste0(name,'.csv')))
write_csv(inputs,file.path(cfg$snapshot_directory,'input-manifest.csv'))
write_csv(result$source_fingerprint,file.path(cfg$snapshot_directory,'source-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(cfg$snapshot_directory,'session-info.txt'))
for(file in list.files(cfg$snapshot_directory,'[.]csv$',full.names=TRUE))stopifnot(!'SOURCE_UID'%in%names(read_csv(file,show_col_types=FALSE)))
# Verify every adopted input after writing only new derived outputs.
paths<-ifelse(startsWith(inputs$PATH,'data-store/'),file.path(store,substring(inputs$PATH,12)),inputs$PATH)
stopifnot(all(inputs$SHA256==vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE)))
cat('Primary support:\n');print(filter(support,SPEC==cfg$primary_spec),n=25,width=180)
cat('Paired primary fuel cells:\n');print(filter(paired_support,SPEC==cfg$primary_spec,FUEL_CELLS>0),n=30)
cat('Native segment evidence (not a common detector):\n');print(native_evidence,n=25)
cat('Canonical/source hashes unchanged. Aggregate snapshot:',cfg$snapshot_directory,'\n')
