# Counterfactual diagnostics only; do not adopt these settings as study policy.
# Requires completed evaluation + summarize-chn-reference-triage.R in a restricted run.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1)
run<-normalizePath(args[1],mustWork=TRUE)
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,"/")))
suppressPackageStartupMessages({library(dplyr);library(readr)})
src<-file.path(run,"provenance/candidate2")
e<-new.env();sys.source(file.path(src,"R/legacy-core.R"),e);sys.source(file.path(src,"R/chn-qar.R"),e)
inputs<-read_csv(file.path(run,"input-manifest.csv"),show_col_types=FALSE)
x<-read_csv(file.path(run,"triage/reference-classification.csv"),show_col_types=FALSE)
out<-file.path(run,"triage")
paths<-file.path(out,c("budget-counterfactual-reproduced.csv","position-bracket-sensitivity-reproduced.csv"))
if(any(file.exists(paths)))stop("Preserve earlier probes; use a fresh analysis run")
budget<-lapply(x$INPUT_ID[grepl("repair_budget",x$UNRESOLVED_REASONS)],function(id){
  z<-e$chn_process_flight(inputs$PATH[match(id,inputs$INPUT_ID)],e$chn_config(list(max_repair_share=1)),keep_trajectory=TRUE)
  tr<-z$trajectory;phase<-as.numeric(tr$FLIGHT_PHASE_RAW);a<-which(phase%in%6:11)[1]
  b<-e$chn_first_run(phase==12,tr$TIME,3,if(is.na(a))0 else a)
  air<-seq_len(nrow(tr))>=a & seq_len(nrow(tr))<=b
  tibble(INPUT_ID=id,SOURCE_UID=z$qc$SOURCE_UID,ROWS=nrow(tr),COUNTERFACTUAL_STATUS=z$qc$STATUS,
    REMAINING_REASONS=z$qc$UNRESOLVED_REASONS,FUEL_REPAIR_SHARE=mean(tr$FUEL_REPAIRED),
    POSITION_REPAIR_SHARE=mean(tr$POSITION_REPAIRED),FUEL_REPAIRS_AIRBORNE=sum(tr$FUEL_REPAIRED&air),
    POSITION_REPAIRS_AIRBORNE=sum(tr$POSITION_REPAIRED&air),
    RAW_FUEL_KG=sum(tr$FF_TOTAL_RAW_KGPH*tr$DT_SEC/3600),CLEAN_FUEL_KG=sum(tr$FF_TOTAL_KGPH*tr$DT_SEC/3600),
    RAW_PATH_NM=tail(tr$DIST_FLOWN_NM_DIAGNOSTIC,1),CLEAN_PATH_NM=tail(tr$DIST_FLOWN_NM,1))
})
write_csv(bind_rows(budget),paths[1])
position<-list()
for(id in x$INPUT_ID[x$REVIEW_CLASS=="airborne_motion_or_altitude_review"])for(sec in c(5,8,10)){
  z<-e$chn_process_flight(inputs$PATH[match(id,inputs$INPUT_ID)],e$chn_config(list(max_gap_sec=sec)))
  p<-z$issues$ROWS[z$issues$CODE=="position_unresolved"]
  position[[paste(id,sec)]]<-tibble(INPUT_ID=id,BRACKET_SEC=sec,STATUS=z$qc$STATUS,REASONS=z$qc$UNRESOLVED_REASONS,
    POSITION_REPAIRED_ROWS=z$qc$POSITION_REPAIRED_ROWS,POSITION_UNRESOLVED_ROWS=if(length(p))sum(p)else 0)
}
write_csv(bind_rows(position),paths[2])
