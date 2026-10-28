# Investigate candidate.1 rejections; all flight-level outputs stay restricted.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1)
run<-normalizePath(args[1],mustWork=TRUE)
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,"/")))
suppressPackageStartupMessages({library(dplyr);library(readr);library(purrr)})
e<-new.env();sys.source(file.path(run,"provenance/candidate1/R/legacy-core.R"),e);sys.source(file.path(run,"provenance/candidate1/R/chn-qar.R"),e)
inputs<-read_csv(file.path(run,"input-manifest.csv"),col_types=cols(.default="c")) |> filter(ROLE=="historical_reference")
clock_original<-e$chn_clock;repair_original<-e$chn_repair
captured<-list();clock_rows<-list()
e$chn_repair<-function(values,time,kind,cfg,gs=NULL) {
  r<-repair_original(values,time,kind,cfg,gs)
  captured[[kind]]<<-list(result=r,time=time,values=as.matrix(values))
  r
}
e$chn_clock<-function(raw,date,cfg) {
  base<-clock_original(raw,date,cfg)
  candidates<-grep("^TIME([.][0-9]+)?$",names(raw),value=TRUE)
  physical_cols<-intersect(c("LATP","LONP",grep("^ALT_STD",names(raw),value=TRUE),"FF1C","FF2C","FF3C","FF4C","GS","FLIGHT_PHASE"),names(raw))
  clock_rows<<-map_dfr(candidates,function(col) {
    keys<-unique(c(col,physical_cols));keep<-!duplicated(as.data.frame(raw[,..keys]))
    reduced<-raw[keep,];one<-clock_original(reduced,date,e$chn_config(list(clock_column=col)))
    sec<-as.numeric(one$time);dd<-diff(sec)
    tibble(COLUMN=col,RAW_ROWS=nrow(raw),DISTINCT_OBSERVATIONS=sum(keep),RAW_SCORE=base$evidence$SCORE[base$evidence$COLUMN==col],
      COLLAPSED_SCORE=one$evidence$SCORE[one$evidence$COLUMN==col],BACKWARD_STEPS=sum(dd<0,na.rm=TRUE),
      REPEATED_STEPS=sum(dd==0,na.rm=TRUE),LONG_STEPS=sum(dd>30,na.rm=TRUE),CLOCK_VALID=one$valid,
      ELAPSED_MIN=if(all(is.finite(sec)))diff(range(sec))/60 else NA_real_)
  })
  base
}
all_metrics<-list();all_blocks<-list();all_clocks<-list()
for(i in seq_len(nrow(inputs))) {
  inp<-inputs[i,];captured<-list();clock_rows<-list()
  tr<-e$fuel_read_chn_qar_csv(inp$PATH)
  all_clocks[[i]]<-mutate(clock_rows,INPUT_ID=inp$INPUT_ID)
  phase<-suppressWarnings(as.numeric(tr$FLIGHT_PHASE_RAW));n<-nrow(tr)
  start<-which(phase%in%6:11)[1];finish<-e$chn_first_run(phase==12,tr$TIME,3,if(is.na(start))0 else start)
  in_air<-if(is.na(start)||is.na(finish))rep(NA,n) else seq_len(n)>=start & seq_len(n)<=finish
  original<-data.table::fread(inp$PATH,check.names=TRUE);names(original)<-make.names(toupper(names(original)),unique=TRUE)
  ffcols<-intersect(c("FF1C","FF2C"),names(original));raw_ff<-if(length(ffcols)==2)as.matrix(original[tr$SOURCE_ROW,..ffcols]) else matrix(NA_real_,n,2)
  raw_bad_fuel<-apply(raw_ff,1,function(x)any(!is.finite(x)|x<0))
  metric<-tibble(INPUT_ID=inp$INPUT_ID,SOURCE_UID=tr$SOURCE_UID[1],ROWS=n,START_ROW=start,END_ROW=finish,
    OBSERVED_FUEL_BAD_ROWS=sum(raw_bad_fuel),SOURCE_FLOW_COLUMNS=length(ffcols),
    SPIKE_CANDIDATE_ROWS=sum(tr$FF_SPIKE_FLAG),AIRBORNE_WINDOW_SUPPORTED=!is.na(start)&&!is.na(finish))
  for(kind in c("fuel","position","altitude")) {
    z<-captured[[kind]];bad<-z$result$unresolved;repaired<-z$result$repaired
    metric[[paste0(kind,"_bad_rows")]]<-sum(bad)
    metric[[paste0(kind,"_bad_airborne_rows")]]<-sum(bad & in_air,na.rm=TRUE)
    metric[[paste0(kind,"_repaired_rows")]]<-sum(repaired)
    metric[[paste0(kind,"_repaired_share")]]<-mean(repaired)
    metric[[paste0(kind,"_over_budget")]]<-z$result$over_budget
    if(kind=="fuel")metric$FUEL_BAD_ROWS_CREATED_BY_SPIKE_RULE<-sum(bad & !raw_bad_fuel)
    blocks<-e$chn_runs(bad)
    if(nrow(blocks))all_blocks[[paste(i,kind)]]<-map_dfr(seq_len(nrow(blocks)),function(j) {
      a<-blocks$start[j];b<-blocks$end[j];before<-max(1L,a-1L);after<-min(n,b+1L)
      tibble(INPUT_ID=inp$INPUT_ID,DOMAIN=kind,START_ROW=a,END_ROW=b,START_SOURCE_ROW=tr$SOURCE_ROW[a],END_SOURCE_ROW=tr$SOURCE_ROW[b],
        START_TIME=as.character(tr$TIME[a]),END_TIME=as.character(tr$TIME[b]),ROWS=b-a+1L,
        BRACKET_SEC=as.numeric(tr$TIME[after])-as.numeric(tr$TIME[before]),
        ENDPOINT=a==1L||b==n,AIRBORNE_ROWS=sum(in_air[a:b],na.rm=TRUE),
        PHASE_CODES=paste(sort(unique(phase[a:b])),collapse=";"),
        SOURCE_MISSING_OR_NEGATIVE=if(kind=="fuel")sum(raw_bad_fuel[a:b]) else sum(!is.finite(z$values[a:b,,drop=FALSE])),
        BEFORE_TOTAL=if(kind=="fuel")sum(raw_ff[before,]) else NA_real_,AFTER_TOTAL=if(kind=="fuel")sum(raw_ff[after,]) else NA_real_,
        BRACKET_HAS_ENGINE_ZERO=kind=="fuel"&&any(raw_ff[c(before,after),]==0,na.rm=TRUE))
    })
  }
  all_metrics[[i]]<-metric
  if(i%%25==0||i==nrow(inputs))cat("Diagnosed",i,"of",nrow(inputs),"reference files\n")
}
out<-file.path(run,"triage")
write_csv(bind_rows(all_metrics),file.path(out,"reference-metrics.csv"))
write_csv(bind_rows(all_blocks),file.path(out,"unresolved-blocks.csv"))
write_csv(bind_rows(all_clocks),file.path(out,"clock-replication-evidence.csv"))
