# Compare position limits on the eight earlier reference bracket-review cases.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==2)
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
runs<-vapply(args,normalizePath,"",mustWork=TRUE)
for(run in runs)stopifnot(startsWith(run,paste0(store,"/")))
suppressPackageStartupMessages({library(readr);library(dplyr)})
e<-new.env();sys.source("helpers/chn-qar-v2/R/legacy-core.R",e);sys.source("helpers/chn-qar-v2/R/chn-qar.R",e)
old<-read_csv(file.path(runs[1],"triage/reference-classification.csv"),show_col_types=FALSE)
ids<-old$INPUT_ID[old$REVIEW_CLASS=="airborne_motion_or_altitude_review"]
m<-read_csv(file.path(runs[2],"input-manifest.csv"),show_col_types=FALSE)
cfg<-jsonlite::read_json(file.path(runs[2],"config.json"),simplifyVector=TRUE)
out<-file.path(runs[2],"position-limit-reference-probe.csv");if(file.exists(out))stop("Probe already exists")
rows<-list()
for(id in ids)for(limit in c(5,8,15)) {
  z<-e$chn_process_flight(m$PATH[match(id,m$INPUT_ID)],e$chn_config(utils::modifyList(cfg,list(max_position_gap_sec=limit))))
  rows[[paste(id,limit)]]<-tibble(INPUT_ID=id,MAX_POSITION_BRACKET_SEC=limit,STUDY_EXCLUDE=z$qc$STUDY_EXCLUDE,
    POSITION_REPAIRED_ROWS=z$qc$POSITION_REPAIRED_ROWS,REASONS=z$qc$UNRESOLVED_REASONS)
}
write_csv(bind_rows(rows),out)
print(count(bind_rows(rows),MAX_POSITION_BRACKET_SEC,STUDY_EXCLUDE,name="files"),n=20)
