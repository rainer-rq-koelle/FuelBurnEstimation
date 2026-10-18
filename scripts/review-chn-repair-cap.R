# Restricted individual evidence for the 22 historical candidate.2 repair holds.
# Produces measurements and review recommendations, never an approval manifest.
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)%in%c(2,3))
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
runs<-vapply(args,normalizePath,"",mustWork=TRUE)
for(run in runs)stopifnot(startsWith(run,paste0(store,"/")))
suppressPackageStartupMessages({library(readr);library(dplyr)})
e<-new.env();sys.source("helpers/chn-qar-v2/R/legacy-core.R",e);sys.source("helpers/chn-qar-v2/R/chn-qar.R",e)
inputs<-read_csv(file.path(runs[2],"input-manifest.csv"),show_col_types=FALSE)
old<-read_csv(file.path(runs[1],"triage/reference-classification.csv"),show_col_types=FALSE)
ids<-old$INPUT_ID[old$REVIEW_CLASS=="repair_share_policy_review"]
if(length(args)==3) {
  extra_path<-normalizePath(args[3],mustWork=TRUE);stopifnot(startsWith(extra_path,paste0(store,"/")))
  extra<-read_csv(extra_path,show_col_types=FALSE)
  ids<-unique(c(ids,extra$INPUT_ID[grepl("repair_budget",extra$UNRESOLVED_REASONS)]))
}
cases<-list();bridges<-list()
for(id in ids) {
  inp<-inputs[match(id,inputs$INPUT_ID),];stopifnot(digest::digest(file=inp$PATH,algo="sha256")==inp$SHA256)
  z<-e$chn_process_flight(inp$PATH,keep_trajectory=TRUE);tr<-z$trajectory;q<-attr(tr,"quality");rr<-attr(tr,"repair_results")
  pos<-e$chn_runs(tr$POSITION_REPAIRED);all_turns<-numeric();all_speeds<-numeric();all_brackets<-numeric()
  for(i in seq_len(nrow(pos))) {
    a<-pos$start[i]-1L;b<-pos$end[i]+1L;tt<-as.numeric(tr$TIME);xy<-cbind(tr$LAT,tr$LON)
    l<-which(tt>=tt[a]-15&seq_len(nrow(tr))<a);r<-which(tt<=tt[b]+15&seq_len(nrow(tr))>b)
    before<-if(length(l))l[1] else a;after<-if(length(r))tail(r,1)else b
    bs<-e$fuel_haversine_nm(xy[a,1],xy[a,2],xy[b,1],xy[b,2])/(tt[b]-tt[a])*3600
    bearing<-c(e$chn_bearing(xy[before,],xy[a,]),e$chn_bearing(xy[a,],xy[b,]),e$chn_bearing(xy[b,],xy[after,]))
    turn<-max(abs((diff(bearing)+180)%%360-180));gap<-tt[b]-tt[a]
    all_turns<-c(all_turns,turn);all_speeds<-c(all_speeds,bs);all_brackets<-c(all_brackets,gap)
    bridges[[paste(id,i)]]<-tibble(INPUT_ID=id,START_SOURCE_ROW=tr$SOURCE_ROW[a],END_SOURCE_ROW=tr$SOURCE_ROW[b],
      BRACKET_SEC=gap,BRIDGE_SPEED_KT=bs,MAX_NEIGHBOUR_TURN_DEG=turn,
      ORIGINAL_DISPLACEMENT_MAX_NM=max(e$fuel_haversine_nm(tr$LAT_SOURCE[a:b],tr$LON_SOURCE[a:b],tr$LAT[a:b],tr$LON[a:b]),na.rm=TRUE))
  }
  air<-q$atot:q$aldt;ints<-q$atot:(q$aldt-1L)
  position_case<-q$repair_share["position"]>e$chn_config()$max_repair_share
  evidence_pass<-q$air_time && q$air_profile && q$air_fuel && !any(tr$POSITION_UNRESOLVED[air]) &&
    length(all_brackets)>0 && all(all_brackets<=5) && all(all_speeds<=750) && all(is.finite(all_turns)&all_turns<=45)
  cases[[id]]<-tibble(INPUT_ID=id,ROLE=inp$ROLE,SOURCE_UID=z$qc$SOURCE_UID,SHA256=inp$SHA256,HELPER_VERSION=e$chn_version,
    DOMAIN=if(position_case)"position"else"fuel",AIR_POSITION_REPAIR_SHARE=q$repair_share["position"],
    AIR_FUEL_REPAIR_SHARE=q$repair_share["fuel"],POSITION_BRIDGES=length(all_brackets),
    MAX_BRACKET_SEC=if(length(all_brackets))max(all_brackets)else NA_real_,
    MAX_BRIDGE_SPEED_KT=if(length(all_speeds))max(all_speeds)else NA_real_,
    MAX_NEIGHBOUR_TURN_DEG=if(length(all_turns))max(all_turns)else NA_real_,
    NO_AIRBORNE_FUEL_REPAIRS=!any(tr$FUEL_REPAIRED[ints]),NO_AIRBORNE_POSITION_GAPS=!any(tr$POSITION_UNRESOLVED[air]),
    REVIEW_RECOMMENDATION=if(position_case)if(evidence_pass)"position_share_approval_supported"else"retain_for_investigation" else
      if(q$air_fuel&&q$repair_share["fuel"]==0)"airborne_unaffected_ground_fuel_hold_retained"else"retain_for_investigation")
  write_csv(z$repairs,file.path(runs[2],"review",paste0(id,"-repairs.csv")))
}
write_csv(bind_rows(cases),file.path(runs[2],"review/individual-cap-review.csv"))
write_csv(bind_rows(bridges),file.path(runs[2],"review/individual-position-bridges.csv"))
print(count(bind_rows(cases),REVIEW_RECOMMENDATION),n=20)
