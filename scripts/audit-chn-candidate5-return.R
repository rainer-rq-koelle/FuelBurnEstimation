# Reproduce a returned candidate.5 run without altering the helper or releases.
# Usage: Rscript scripts/audit-chn-candidate5-return.R <restricted-audit-directory> [exact-candidate.5-helper-directory]
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)%in%c(1L,2L))
run<-normalizePath(args[1],mustWork=TRUE)
helper<-normalizePath(if(length(args)==2L)args[2]else 'helpers/chn-qar-v2',mustWork=TRUE)
store<-normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,'/')))
suppressPackageStartupMessages({library(dplyr);library(readr)})
ret<-dirname(list.files(file.path(run,'returned'),'run-manifest.json',recursive=TRUE,full.names=TRUE)[1])
manifest<-jsonlite::read_json(file.path(ret,'run-manifest.json'),simplifyVector=TRUE)
if(manifest$helper_version!='2.0.0-candidate.5'||digest::digest(file=file.path(helper,'R/chn-qar.R'),algo='sha256')!=manifest$source_functions_sha256)
 stop('Pass the exact candidate.5 helper directory extracted from the preserved source ZIP')
e<-new.env();sys.source(file.path(helper,'R/legacy-core.R'),e);sys.source(file.path(helper,'R/chn-qar.R'),e)
cfg<-e$chn_config(manifest$configuration)
airport_path<-if(is.null(cfg$airport_reference_path))file.path(helper,'data/airports.csv')else cfg$airport_reference_path
stopifnot(digest::digest(file=airport_path,algo='sha256')==manifest$airport_reference_sha256)
airports<-e$chn_airports(airport_path)
inputs<-read_csv(file.path(run,'local-input-manifest.csv'),show_col_types=FALSE)
out<-file.path(run,'reproduction');dir.create(out,showWarnings=FALSE)
cache<-file.path(out,'flight-results-with-trajectories.rds')
if(file.exists(cache)) {
 results<-readRDS(cache);w<-read_csv(file.path(out,'warnings.csv'),show_col_types=FALSE)
} else {
results<-list();warnings<-list()
for(i in seq_len(nrow(inputs))) {
 inp<-inputs[i,];stopifnot(digest::digest(file=inp$PATH,algo='sha256')==inp$SHA256)
 z<-withCallingHandlers(e$chn_process_flight(inp$PATH,cfg,airport_meta=airports,keep_trajectory=TRUE),warning=function(w){
  warnings[[length(warnings)+1L]]<<-tibble(INPUT_ID=inp$INPUT_ID,SOURCE_UID=inp$SOURCE_UID,WARNING=conditionMessage(w),CALL=paste(deparse(conditionCall(w)),collapse=' '),STACK=paste(vapply(sys.calls(),function(c)paste(deparse(c),collapse=' '),''),collapse='\n'))
  invokeRestart('muffleWarning')
 })
 for(n in names(z))if(is.data.frame(z[[n]]))z[[n]]$INPUT_ID<-rep(inp$INPUT_ID,nrow(z[[n]]))
 results[[i]]<-z
 cat(i,'of',nrow(inputs),'processed\n')
}
saveRDS(results,file.path(out,'flight-results-with-trajectories.rds'))
w<-bind_rows(warnings);write_csv(w,file.path(out,'warnings.csv'))
}
pairs<-c(milestones='CHN-canonical-milestones',phases='CHN-phase-summaries',levels='CHN-level-segments',diagnostic_phases='CHN-diagnostic-phase-summaries',airborne_phases='CHN-airborne-phase-summaries',airborne_summary='CHN-airborne-summaries',milestone_candidates='CHN-milestone-candidates',milestone_availability='CHN-milestone-availability',phase_intervals='CHN-phase-intervals',fuel_time_coverage='CHN-fuel-time-coverage',supported_data_points='CHN-supported-data-points',flight_summaries='CHN-flight-summaries',qc='CHN-flight-quality',issues='CHN-issue-ledger',repairs='CHN-repair-log')
comparisons<-list();differences<-list()
for(n in names(pairs)) {
 a<-bind_rows(lapply(results,`[[`,n));b<-as.data.frame(arrow::read_parquet(file.path(ret,paste0(pairs[[n]],'.parquet'))))
 if(!n%in%c('qc','issues','repairs')&&nrow(a)) {
  qc<-bind_rows(lapply(results,`[[`,'qc'));k<-match(a$INPUT_ID,qc$INPUT_ID)
  for(col in c('STUDY_EXCLUDE','PROBLEM_FLIGHT','STATUS'))a[[col]]<-qc[[col]][k]
 }
 write_csv(a,file.path(out,paste0(pairs[[n]],'.csv')))
 stopifnot(nrow(a)==nrow(b),setequal(names(a),names(b)))
 for(col in names(a)) {
  x<-a[[col]];y<-b[[col]];num<-is.numeric(x)||inherits(x,'POSIXt');delta<-rep(NA_real_,length(x))
  if(num) {x<-as.numeric(x);y<-as.numeric(y);delta<-abs(x-y);same<-(is.na(x)&is.na(y))|(!is.na(x)&!is.na(y)&(x==y|delta<=2e-6))}
  else same<-(is.na(x)&is.na(y))|(!is.na(x)&!is.na(y)&as.character(x)==as.character(y))
  bad<-which(is.na(same)|!same)
  comparisons[[length(comparisons)+1L]]<-tibble(TABLE=pairs[[n]],COLUMN=col,ROWS=length(x),DIFFERENCES=length(bad),MAX_ABS_DELTA=if(any(is.finite(delta)))max(delta[is.finite(delta)])else NA_real_)
  if(length(bad))differences[[length(differences)+1L]]<-tibble(TABLE=pairs[[n]],COLUMN=col,ROW=bad,LOCAL=as.character(x[bad]),RETURNED=as.character(y[bad]))
 }
}
write_csv(bind_rows(comparisons),file.path(out,'table-field-comparison.csv'))
write_csv(bind_rows(differences),file.path(out,'table-differences.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'runtime.txt'))
cat('Warnings:',nrow(w),'; differing fields:',sum(bind_rows(comparisons)$DIFFERENCES>0),'\n')
