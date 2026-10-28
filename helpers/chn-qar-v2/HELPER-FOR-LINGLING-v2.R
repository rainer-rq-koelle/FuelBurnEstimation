#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly=TRUE)
if(length(args)<2 || length(args)>3) stop("Usage: Rscript HELPER-FOR-LINGLING-v2.R <QAR directory or ZIP> <NEW restricted output directory> [config.json]")
entry <- grep("^--file=",commandArgs(),value=TRUE)
root <- dirname(normalizePath(sub("^--file=","",entry[[1]]),mustWork=TRUE))
required <- c("dplyr","tibble","readr","purrr","data.table","zoo","hms","arrow","digest","jsonlite")
missing <- required[!vapply(required,requireNamespace,TRUE,quietly=TRUE)]
if(length(missing))stop("Install required R packages first: ",paste(missing,collapse=", "))
env <- new.env(parent=globalenv())
sys.source(file.path(root,"R/legacy-core.R"),envir=env)
sys.source(file.path(root,"R/chn-qar.R"),envir=env)
cfg <- env$chn_config(if(length(args)==3)jsonlite::read_json(args[3],simplifyVector=TRUE) else list())
airports<-env$chn_airports(cfg$airport_reference_path)
input <- normalizePath(path.expand(args[1]),mustWork=TRUE)
output <- path.expand(args[2])
dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
output <- file.path(normalizePath(dirname(output),mustWork=TRUE),basename(output))
if(grepl("/(processed|parallel-preprocessing)(/|$)",output))stop("Output must be a new candidate directory, outside protected production paths")
if(dir.exists(output) && length(list.files(output,all.files=TRUE,no..=TRUE)))stop("Refusing to overwrite an existing output directory")
dir.create(output,recursive=TRUE,showWarnings=FALSE)
safe_extract <- function(zip,dest) {
  members<-utils::unzip(zip,list=TRUE)$Name
  if(any(grepl("(^[/\\\\]|^[A-Za-z]:|(^|[/\\\\])[.][.]([/\\\\]|$))",members)))stop("Unsafe ZIP member path")
  dir.create(dest,recursive=TRUE,showWarnings=FALSE);utils::unzip(zip,exdir=dest)
}
if(dir.exists(input))source_dir<-input else if(grepl("[.]zip$",input,ignore.case=TRUE)) {
  source_dir<-file.path(output,"source-input");safe_extract(input,source_dir)
} else stop("Input must be a directory or ZIP")
files <- list.files(source_dir,"[.]csv$",recursive=TRUE,full.names=TRUE,ignore.case=TRUE)
if(!length(files)) {
  nested<-list.files(source_dir,"[.]zip$",recursive=TRUE,full.names=TRUE,ignore.case=TRUE)
  for(i in seq_along(nested))safe_extract(nested[i],file.path(output,"nested-input",sprintf("%03d",i)))
  files<-list.files(file.path(output,"nested-input"),"[.]csv$",recursive=TRUE,full.names=TRUE,ignore.case=TRUE)
}
files<-sort(files[!grepl("(^|/)__MACOSX/",files)&!startsWith(basename(files),".")])
if(!length(files))stop("No QAR CSV files found")
results<-list();input_manifest<-list();plots<-0L
for(i in seq_along(files)) {
  p<-files[i];hash<-digest::digest(file=p,algo="sha256")
  result<-tryCatch(env$chn_process_flight(p,config=cfg,airport_meta=airports,keep_trajectory=TRUE),error=function(e){
    meta<-env$fuel_parse_chn_filename(p)
    qc<-dplyr::bind_cols(meta,tibble::tibble(HELPER_VERSION=env$chn_version,STUDY_EXCLUDE=TRUE,PROBLEM_FLIGHT=TRUE,STATUS="INVESTIGATE_EXCLUDE",UNRESOLVED_REASONS="processing_error",ERROR=conditionMessage(e)))
    list(qc=qc,issues=dplyr::bind_cols(meta["SOURCE_UID"],env$chn_issue("processing_error","input",detail=conditionMessage(e))))
  })
  id<-sprintf("INPUT%05d",i)
  if(!is.null(result$trajectory)&&plots<cfg$max_plots&&(i<=3||isTRUE(result$qc$STUDY_EXCLUDE))) {
    dir.create(file.path(output,"profile-plots"),showWarnings=FALSE)
    env$chn_plot_diagnostics(result,file.path(output,"profile-plots",paste0(id,".png")));plots<-plots+1L
  }
  result$trajectory<-NULL
  for(name in names(result))if(is.data.frame(result[[name]]))result[[name]]$INPUT_ID<-rep(id,nrow(result[[name]]))
  results[[i]]<-result
  input_manifest[[i]]<-tibble::tibble(INPUT_ID=id,SOURCE_UID=env$fuel_parse_chn_filename(p)$SOURCE_UID,INPUT_FILE=p,SHA256=hash,BYTES=file.info(p)$size)
  if(i%%25==0 || i==length(files))cat("Processed",i,"of",length(files),"files\n")
}
combine<-function(name)dplyr::bind_rows(lapply(results,`[[`,name))
qc<-combine("qc");issues<-combine("issues")
# Conflicting exports of a flight cannot silently become duplicate study flights.
dup<-duplicated(qc$SOURCE_UID)|duplicated(qc$SOURCE_UID,fromLast=TRUE)
if(any(dup)) {
  qc$STUDY_EXCLUDE[dup]<-TRUE;qc$PROBLEM_FLIGHT[dup]<-TRUE;qc$STATUS[dup]<-"INVESTIGATE_EXCLUDE"
  qc$UNRESOLVED_REASONS[dup]<-paste0(qc$UNRESOLVED_REASONS[dup],";duplicate_source_uid")
  issues<-dplyr::bind_rows(issues,tibble::tibble(SOURCE_UID=qc$SOURCE_UID[dup],INPUT_ID=qc$INPUT_ID[dup],CODE="duplicate_source_uid",DOMAIN="identity",STATUS="unresolved",ROWS=0L,DETAIL="Multiple input exports share this flight identifier"))
}
write_table<-function(d,name,parquet=TRUE) {
  if(!ncol(d))d<-tibble::tibble(SOURCE_UID=character())
  readr::write_csv(d,file.path(output,paste0(name,".csv")))
  if(parquet)arrow::write_parquet(d,file.path(output,paste0(name,".parquet")))
}
for(pair in list(c("milestones","CHN-canonical-milestones"),c("phases","CHN-phase-summaries"),c("levels","CHN-level-segments"),c("diagnostic_phases","CHN-diagnostic-phase-summaries"),c("airborne_phases","CHN-airborne-phase-summaries"),c("airborne_summary","CHN-airborne-summaries"),
 c("milestone_candidates","CHN-milestone-candidates"),c("milestone_availability","CHN-milestone-availability"),
 c("phase_intervals","CHN-phase-intervals"),c("fuel_time_coverage","CHN-fuel-time-coverage"),
 c("supported_data_points","CHN-supported-data-points"),c("flight_summaries","CHN-flight-summaries"))) {
  d<-combine(pair[1]);if(nrow(d)) {
    k<-match(d$INPUT_ID,qc$INPUT_ID)
    for(n in c("STUDY_EXCLUDE","PROBLEM_FLIGHT","STATUS"))d[[n]]<-qc[[n]][k]
  }
  write_table(d,pair[2])
}
problem<-qc[qc$STUDY_EXCLUDE,,drop=FALSE]
write_table(qc,"CHN-flight-quality")
write_table(problem,"CHN-problem-flights")
write_table(problem,"CHN-study-exclusions")
stopifnot(identical(readBin(file.path(output,"CHN-problem-flights.csv"),"raw",n=1e9),readBin(file.path(output,"CHN-study-exclusions.csv"),"raw",n=1e9)))
write_table(issues,"CHN-issue-ledger")
write_table(combine("repairs"),"CHN-repair-log")
write_table(dplyr::bind_rows(input_manifest),"input-manifest",FALSE)
review_hash<-NULL
if(!is.null(cfg$repair_review_path)) {
  review_hash<-digest::digest(file=cfg$repair_review_path,algo="sha256")
  if(!file.copy(cfg$repair_review_path,file.path(output,"repair-review-used.csv")))stop("Cannot preserve review manifest")
}
readr::write_csv(airports,file.path(output,"airports-used.csv"))
airport_source<-if(is.null(cfg$airport_reference_path))file.path(root,"data/airports.csv")else cfg$airport_reference_path
airport_hash<-digest::digest(file=airport_source,algo="sha256")
airport_provenance<-if(is.null(cfg$airport_reference_path))jsonlite::read_json(file.path(root,"data/airports-provenance.json"),simplifyVector=TRUE)else list(source="user_supplied_airport_reference")
if(!is.null(cfg$airport_reference_path)&&!file.copy(cfg$airport_reference_path,file.path(output,"airport-reference-source-used.csv")))stop("Cannot preserve airport reference source")
jsonlite::write_json(list(airport_reference_sha256=airport_hash,airport_reference_provenance=airport_provenance,
 airport_distance_definition="great_circle_radius_from_or_to_airport_coordinate_proxy",profile_event_definition="altitude_time_whole_level_boundaries_with_200nm_selection_context",flown_distance_definition="cumulative_short_great_circle_legs_on_repaired_track; separate_ATOT_zero_airborne_quantity",
 helper_version=env$chn_version,configuration=cfg,repair_review_sha256=review_hash,phase_code_contract="Legacy helper numeric phases; ALDT is landing-phase onset, not independently observed wheel touchdown",created_utc=format(Sys.time(),tz="UTC",usetz=TRUE),source_functions_sha256=digest::digest(file=file.path(root,"R/chn-qar.R"),algo="sha256")),file.path(output,"run-manifest.json"),pretty=TRUE,auto_unbox=TRUE,null="null")
writeLines(capture.output(sessionInfo()),file.path(output,"runtime.txt"))
hash_files<-sort(list.files(output,recursive=TRUE,full.names=TRUE))
writeLines(vapply(hash_files,function(p)paste(digest::digest(file=p,algo="sha256"),substring(p,nchar(output)+2L),sep="  "),""),file.path(output,"checksums.sha256"))
cat("Candidate helper",env$chn_version,"completed:",nrow(qc),"input files;",sum(qc$STUDY_EXCLUDE),"investigation/study exclusions.\n")
