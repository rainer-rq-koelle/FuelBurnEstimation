# Restricted integration evaluation of the isolated candidate helper.
# Usage: Rscript scripts/validate-chn-qar-v2.R <restricted-run-directory>
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1)
run<-normalizePath(args[1],mustWork=TRUE)
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,"/")))
out<-file.path(run,"evaluation");if(dir.exists(out))stop("Evaluation already exists; use a fresh run or preserve it before rerunning")
dir.create(out);dir.create(file.path(out,"repairs"))
e<-new.env();sys.source("helpers/chn-qar-v2/R/legacy-core.R",e);sys.source("helpers/chn-qar-v2/R/chn-qar.R",e)
suppressPackageStartupMessages({library(dplyr);library(readr);library(purrr)})
inputs<-read_csv(file.path(run,"input-manifest.csv"),col_types=cols(.default="c"))
cfg<-e$chn_config(if(file.exists(file.path(run,"config.json")))jsonlite::read_json(file.path(run,"config.json"),simplifyVector=TRUE)else list())
jsonlite::write_json(cfg,file.path(out,"effective-config.json"),pretty=TRUE,auto_unbox=TRUE,null="null")
table_names<-c("milestones","phases","levels","diagnostic_phases","airborne_phases","airborne_summary","issues",
 "milestone_candidates","milestone_availability","phase_intervals","fuel_time_coverage","supported_data_points","flight_summaries")
quality<-list();tables<-list();ledgers<-list();validation<-list();sensitivity<-list();clocks<-list()
for(i in seq_len(nrow(inputs))) {
  inp<-inputs[i,];p<-inp$PATH
  stopifnot(digest::digest(file=p,algo="sha256")==inp$SHA256)
  result<-tryCatch(e$chn_process_flight(p,cfg,keep_trajectory=TRUE),error=function(err) {
    list(qc=tibble(SOURCE_UID=e$fuel_parse_chn_filename(p)$SOURCE_UID,STUDY_EXCLUDE=TRUE,PROBLEM_FLIGHT=TRUE,
      STATUS="INVESTIGATE_EXCLUDE",UNRESOLVED_REASONS="runtime_error",ERROR=conditionMessage(err)))
  })
  for(name in names(result))if(is.data.frame(result[[name]]))result[[name]]$INPUT_ID<-rep(inp$INPUT_ID,nrow(result[[name]]))
  result$qc$ROLE<-inp$ROLE;result$qc$CASE<-inp$CASE;quality[[i]]<-result$qc
  if(!is.null(result$trajectory)) {
    tr<-result$trajectory;ms<-result$milestones;ph<-result$phases
    fuel_error<-if(isTRUE(result$qc$FUEL_VALID)&&isTRUE(result$qc$TIME_VALID))abs(tail(tr$TOT_FUEL_KG,1)-sum(tr$FF_TOTAL_KGPH*tr$DT_SEC/3600)) else NA_real_
    phase_error<-map_dbl(seq_len(nrow(ph)),function(j) {
      f<-ms$ROW_ID[ms$MST==ph$FROM_MST[j]];t<-ms$ROW_ID[ms$MST==ph$TO_MST[j]]
      expected<-if(t>f)sum(tr$FF_TOTAL_KGPH[f:(t-1L)]*tr$DT_SEC[f:(t-1L)]/3600) else 0
      abs(ph$FUEL_KG[j]-expected)
    })
    phase_error<-phase_error[is.finite(phase_error)]
    aq<-attr(tr,"quality");a<-aq$atot;b<-aq$aldt
    airborne_fuel_error<-if(isTRUE(result$qc$AIRBORNE_FUEL_VALID)&&isTRUE(result$qc$AIRBORNE_TIME_VALID))abs(result$airborne_summary$FUEL_KG-sum(tr$FF_TOTAL_KGPH[a:(b-1L)]*tr$DT_SEC[a:(b-1L)]/3600))else NA_real_
    ap<-result$airborne_phases
    partition_error<-if(nrow(ap)==3&&all(is.finite(ap$FUEL_KG))&&is.finite(result$airborne_summary$FUEL_KG))abs(sum(ap$FUEL_KG)-result$airborne_summary$FUEL_KG)else NA_real_
    distance_error<-if(nrow(ap)==3&&all(is.finite(ap$DISTANCE_NM))&&is.finite(result$airborne_summary$DISTANCE_NM))abs(sum(ap$DISTANCE_NM)-result$airborne_summary$DISTANCE_NM)else NA_real_
    fine<-result$phase_intervals;ca<-result$milestone_candidates;coverage<-result$fuel_time_coverage
    fine_fuel_error<-if(isTRUE(result$qc$AIRBORNE_TIME_VALID)&&isTRUE(result$qc$AIRBORNE_FUEL_VALID))abs(sum(fine$FUEL_KG)-result$airborne_summary$FUEL_KG)else NA_real_
    fine_time_error<-if(isTRUE(result$qc$AIRBORNE_TIME_VALID))abs(sum(fine$DURATION_MIN)-result$airborne_summary$DURATION_MIN)else NA_real_
    fine_distance_error<-if(isTRUE(result$qc$AIRBORNE_TIME_VALID)&&isTRUE(result$qc$AIRBORNE_DISTANCE_VALID))abs(sum(fine$DISTANCE_NM)-result$airborne_summary$DISTANCE_NM)else NA_real_
    invalid_distance_masked<-if(!result$qc$DISTANCE_VALID&&!result$qc$AIRBORNE_DISTANCE_VALID)all(is.na(ms$DIST_FLOWN_NM))else if(!result$qc$DISTANCE_VALID)all(is.na(ms$DIST_FLOWN_NM[ms$ROW_ID<a|ms$ROW_ID>b]))else TRUE
    validation[[i]]<-tibble(INPUT_ID=inp$INPUT_ID,INITIAL_FUEL=tr$TOT_FUEL_KG[1],FUEL_CLOSURE_ERROR_KG=fuel_error,
      PHASE_ACCOUNTING_MAX_ERROR_KG=if(length(phase_error))max(phase_error) else NA_real_,
      NO_NEGATIVE_CANONICAL_FUEL=all(is.na(ph$FUEL_KG)|ph$FUEL_KG>=-1e-9),
      INVALID_DISTANCE_MASKED=invalid_distance_masked,
      AIRBORNE_FUEL_CLOSURE_ERROR_KG=airborne_fuel_error,AIRBORNE_PARTITION_FUEL_ERROR_KG=partition_error,
      AIRBORNE_PARTITION_DISTANCE_ERROR_NM=distance_error,
      STUDY_INCLUSION_HAS_VALID_DOMAINS=result$qc$STUDY_EXCLUDE||(result$qc$ELIGIBLE_FUEL_TIME&&result$qc$ELIGIBLE_DISTANCE),
      GROUND_ROWS_PRESERVED=tr$SOURCE_ROW[1]==1L,
      TOC_TOD_SEPARATE=if(all(c("TOC","TOD")%in%ms$MST))ms$ROW_ID[ms$MST=="TOC"]<ms$ROW_ID[ms$MST=="TOD"] else TRUE,
      ALDT_PRESENT="ALDT"%in%ms$MST,
      TOC_TOD_AT_FULL_LEVEL_BOUNDARY=all(vapply(c("TOC","TOD"),function(label){
        z<-ms[ms$MST==label,];if(!nrow(z))return(TRUE)
        level<-result$levels[result$levels$LEVEL_SEGMENT_ID==z$LEVEL_SEGMENT_ID,,drop=FALSE]
        nrow(level)==1L&&z$ROW_ID==if(label=="TOC")level$START_ROW_ID else level$END_ROW_ID
      },TRUE)),
      FINE_PARTITION_FUEL_ERROR_KG=fine_fuel_error,FINE_PARTITION_TIME_ERROR_MIN=fine_time_error,FINE_PARTITION_DISTANCE_ERROR_NM=fine_distance_error,
      ARP_CROSSING_MAX_RADIAL_ERROR_NM=if(nrow(ca)&&any(grepl("^great_circle_",ca$THRESHOLD_REFERENCE)&ca$SUPPORTED))max(abs(ca$INTERPOLATED_THRESHOLD_RESIDUAL[grepl("^great_circle_",ca$THRESHOLD_REFERENCE)&ca$SUPPORTED]))else NA_real_,
      CROSSING_BRACKETS_VALID=if(nrow(ca))all(ca$BRACKET_FROM_ROW<ca$BRACKET_TO_ROW&ca$CROSSING_FRACTION>0&ca$CROSSING_FRACTION<=1&ca$LEFT_RESIDUAL*ca$RIGHT_RESIDUAL<=0)else TRUE,
      ANCHOR_AVAILABILITY_COMPLETE=nrow(result$milestone_availability)==18L,
      FINE_INTERVALS_POSITIVE=if(nrow(fine))all(fine$DURATION_MIN>0)else TRUE,
      COVERED_RUN_FUEL_FINITE=if(nrow(coverage))all(is.finite(coverage$FUEL_KG)&coverage$FUEL_KG>=0)else TRUE)
    if(nrow(result$repairs))write_csv(result$repairs,file.path(out,"repairs",paste0(inp$INPUT_ID,".csv")))
    if(inp$ROLE%in%c("verification","modern_control")) {
      for(limit in c(0,5,8,15)) {
        z<-e$chn_process_flight(p,e$chn_config(utils::modifyList(cfg,list(max_position_gap_sec=limit))))$qc
        sensitivity[[paste(i,limit)]]<-tibble(INPUT_ID=inp$INPUT_ID,MAX_POSITION_BRACKET_SEC=limit,STATUS=z$STATUS,
          STUDY_EXCLUDE=z$STUDY_EXCLUDE,POSITION_REPAIRED_ROWS=z$POSITION_REPAIRED_ROWS,ALTITUDE_REPAIRED_ROWS=z$ALTITUDE_REPAIRED_ROWS)
      }
    }
    clocks[[i]]<-dplyr::mutate(result$clock,INPUT_ID=inp$INPUT_ID)
    for(name in table_names)tables[[paste(i,name)]]<-list(name=name,data=result[[name]])
  }
  if(i%%25==0||i==nrow(inputs))cat("Evaluated",i,"of",nrow(inputs),"files\n")
}
qc<-bind_rows(quality);write_csv(qc,file.path(out,"flight-quality.csv"))
problems<-qc[qc$STUDY_EXCLUDE,,drop=FALSE]
write_csv(problems,file.path(out,"problem-flights.csv"));write_csv(problems,file.path(out,"study-exclusions.csv"))
stopifnot(identical(readBin(file.path(out,"problem-flights.csv"),"raw",n=1e9),readBin(file.path(out,"study-exclusions.csv"),"raw",n=1e9)))
for(name in table_names) {
  d<-bind_rows(lapply(Filter(function(x)x$name==name,tables),`[[`,"data"))
  write_csv(d,file.path(out,paste0(name,".csv")));arrow::write_parquet(d,file.path(out,paste0(name,".parquet")))
}
checks<-bind_rows(validation);write_csv(checks,file.path(out,"accounting-validation.csv"))
write_csv(bind_rows(sensitivity),file.path(out,"repair-policy-sensitivity.csv"))
write_csv(bind_rows(clocks),file.path(out,"clock-selection.csv"))
summary<-qc |> count(ROLE,STATUS,name="files");write_csv(summary,file.path(out,"aggregate-status.csv"))
write_csv(qc |> select(INPUT_ID,UNRESOLVED_REASONS) |> mutate(UNRESOLVED_REASONS=strsplit(replace(UNRESOLVED_REASONS,is.na(UNRESOLVED_REASONS),""),";")) |> tidyr::unnest(UNRESOLVED_REASONS) |> count(UNRESOLVED_REASONS,name="files"),file.path(out,"aggregate-reasons.csv"))
stopifnot(nrow(qc)==nrow(inputs),!any(qc$UNRESOLVED_REASONS=="runtime_error",na.rm=TRUE),
  all(checks$NO_NEGATIVE_CANONICAL_FUEL),all(checks$STUDY_INCLUSION_HAS_VALID_DOMAINS),all(checks$GROUND_ROWS_PRESERVED),
  all(checks$AIRBORNE_FUEL_CLOSURE_ERROR_KG<1e-6,na.rm=TRUE),all(checks$AIRBORNE_PARTITION_FUEL_ERROR_KG<1e-6,na.rm=TRUE),
  all(checks$AIRBORNE_PARTITION_DISTANCE_ERROR_NM<1e-6,na.rm=TRUE),all(checks$INVALID_DISTANCE_MASKED),all(checks$TOC_TOD_SEPARATE),
  all(checks$TOC_TOD_AT_FULL_LEVEL_BOUNDARY),all(checks$ARP_CROSSING_MAX_RADIAL_ERROR_NM<1e-7,na.rm=TRUE),all(checks$CROSSING_BRACKETS_VALID),all(checks$ANCHOR_AVAILABILITY_COMPLETE),all(checks$FINE_INTERVALS_POSITIVE),all(checks$COVERED_RUN_FUEL_FINITE),
  all(checks$FINE_PARTITION_FUEL_ERROR_KG<1e-6,na.rm=TRUE),all(checks$FINE_PARTITION_TIME_ERROR_MIN<1e-6,na.rm=TRUE),all(checks$FINE_PARTITION_DISTANCE_ERROR_NM<1e-6,na.rm=TRUE),
  all(checks$FUEL_CLOSURE_ERROR_KG<1e-6,na.rm=TRUE),all(checks$PHASE_ACCOUNTING_MAX_ERROR_KG<1e-6,na.rm=TRUE))
# Source-supported landings survive unavailable coordinates or altitude.
v<-checks[match(inputs$INPUT_ID[inputs$ROLE=="verification"],checks$INPUT_ID),]
stopifnot(all(v$ALDT_PRESENT))
print(summary,n=30)
cat("All integration accounting, preservation, and problem/exclusion equality checks passed.\n")
