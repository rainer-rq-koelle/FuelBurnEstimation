# Descriptive lookup pilot. Source-region remains part of every row key.
# All-profiles rows are marginal baselines, not assigned profile classes.
lookup_quantiles <- function(x,min_n=30) {
  x<-x[is.finite(x)]
  if(length(x)<min_n)return(c(P20=NA_real_,P50=NA_real_,P80=NA_real_))
  setNames(unname(quantile(x,c(.2,.5,.8),type=7)),c("P20","P50","P80"))
}

lookup_enroute_class <- function(x) {
  ifelse(!is.finite(x),"Altitude unobserved",ifelse(x<30000,"Below FL300",ifelse(x<34000,"FL300-339","FL340+")))
}

build_paper_lookup <- function(profiles,enroute,store=Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),min_n=30) {
  suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow)})
  f<-profiles$profiles |> filter(COMMON)
  keys<-c("REGION","SOURCE_UID")
  chn_dir<-Sys.getenv("FUELBURN_PAPER_CHN_DIR",unset=file.path(store,"derived/chn/verification/CHN-2026-10-18-001/returned-batches"))
  unit_files<-sort(list.files(chn_dir,"^CHN-fuel-flow-unit-qc.csv$",recursive=TRUE,full.names=TRUE))
  flow_files<-sort(list.files(chn_dir,"^CHN-qar-fuel-flow-qc.csv$",recursive=TRUE,full.names=TRUE))
  stopifnot(length(unit_files)==14,length(flow_files)==14)
  unit<-bind_rows(lapply(unit_files,read_csv,show_col_types=FALSE)) |>
    transmute(SOURCE_UID,UNIT_OK=!review_required & unit_confidence=="high" &
      inferred_unit%in%c("kg/h","lb/h") & is.finite(selected_total_fuel_kg) & selected_total_fuel_kg>0)
  flow<-bind_rows(lapply(flow_files,read_csv,show_col_types=FALSE)) |>
    transmute(SOURCE_UID,FLOW_OK=is.finite(spike_share)&spike_share<=.01 &
      is.finite(total_fuel_kg_raw)&total_fuel_kg_raw>0 &
      is.finite(fuel_delta_kg)&abs(fuel_delta_kg)/total_fuel_kg_raw<=.05)
  stopifnot(!anyDuplicated(unit$SOURCE_UID),!anyDuplicated(flow$SOURCE_UID))
  f<-f |> left_join(unit,by="SOURCE_UID") |> left_join(flow,by="SOURCE_UID") |>
    mutate(SOURCE_FUEL_OK=REGION=="EUR"|coalesce(UNIT_OK&FLOW_OK,FALSE))
  phases<-bind_rows(lapply(c("Climb","Enroute","Descent"),function(phase) {
    from<-switch(phase,Climb="ATOT",Enroute="TOC",Descent="TOD")
    to<-switch(phase,Climb="TOC",Enroute="TOD",Descent="ALDT")
    f |> transmute(REGION,SOURCE_UID,TYPE,BAND100,PHASE=phase,
      DURATION_MIN=as.numeric(difftime(.data[[paste0("TIME_",to)]],.data[[paste0("TIME_",from)]],units="mins")),
      FUEL_KG=.data[[paste0("TOT_FUEL_KG_",to)]]-.data[[paste0("TOT_FUEL_KG_",from)]],
      FLOWN_NM=.data[[paste0("DIST_FLOWN_NM_",to)]]-.data[[paste0("DIST_FLOWN_NM_",from)]],
      SOURCE_FUEL_OK,DISTANCE_OK)
  })) |> mutate(FUEL_OK=SOURCE_FUEL_OK&is.finite(FUEL_KG)&FUEL_KG>0&is.finite(DURATION_MIN)&DURATION_MIN>0,
    DISTANCE_RATE_OK=FUEL_OK&DISTANCE_OK&is.finite(FLOWN_NM)&FLOWN_NM>0,
    KG_MIN=if_else(FUEL_OK,FUEL_KG/DURATION_MIN,NA_real_),
    KG_NM=if_else(DISTANCE_RATE_OK,FUEL_KG/FLOWN_NM,NA_real_))
  # Source-window altitude classes use fixed thresholds across both regions.
  alt<-enroute$flight_metrics |> filter(WINDOW=="Source") |>
    transmute(REGION,SOURCE_UID,PROFILE_CLASS=lookup_enroute_class(MEAN_ALT_FT))
  stopifnot(!anyDuplicated(alt[,keys]))
  stopifnot(nrow(anti_join(f,alt,by=keys))==0)
  marginal<-phases |> mutate(ROW_KIND="Marginal baseline",PROFILE_CLASS="All profiles")
  conditioned<-phases |> filter(PHASE=="Enroute") |> left_join(alt,by=keys) |> mutate(ROW_KIND="Profile-conditioned")
  rows<-bind_rows(marginal,conditioned) |> mutate(ENGINE_GROUP="Not stratified",
    PHASE_SCHEME="Source ATOT-TOC-TOD-ALDT",
    FUEL_SOURCE=if_else(REGION=="CHN","QAR-integrated, delivered","PRU model, delivered"))
  # No use of GCD as a phase-distance denominator. Each metric has its own n.
  values<-rows |> mutate(FUEL_KG=if_else(FUEL_OK,FUEL_KG,NA_real_),
    FLOWN_NM=if_else(DISTANCE_RATE_OK,FLOWN_NM,NA_real_)) |>
    pivot_longer(c(FUEL_KG,DURATION_MIN,KG_MIN,KG_NM,FLOWN_NM),names_to="METRIC",values_to="VALUE")
  group<-c("REGION","TYPE","ENGINE_GROUP","BAND100","PHASE","ROW_KIND","PROFILE_CLASS","PHASE_SCHEME","FUEL_SOURCE","METRIC")
  summary<-values |> group_by(across(all_of(group))) |>
    summarise(N_FLIGHTS=n_distinct(SOURCE_UID),N=sum(is.finite(VALUE)),
      P20=lookup_quantiles(VALUE,min_n)[1],P50=lookup_quantiles(VALUE,min_n)[2],P80=lookup_quantiles(VALUE,min_n)[3],.groups="drop")
  cells<-profiles$support |> filter(COMMON) |> select(TYPE,BAND100)
  marginal_grid<-tidyr::crossing(cells,REGION=c("CHN","EUR"),PHASE=c("Climb","Enroute","Descent")) |>
    mutate(ROW_KIND="Marginal baseline",PROFILE_CLASS="All profiles")
  enroute_grid<-tidyr::crossing(cells,REGION=c("CHN","EUR"),PROFILE_CLASS=c("Below FL300","FL300-339","FL340+","Altitude unobserved")) |>
    mutate(PHASE="Enroute",ROW_KIND="Profile-conditioned")
  planned_grid<-tidyr::crossing(cells,REGION=c("CHN","EUR"),PHASE=c("Climb","Descent"),
    PROFILE_CLASS=c("Continuous","Lightly interrupted","Heavily interrupted","Unknown coverage")) |>mutate(ROW_KIND="Planned class")
  grid<-bind_rows(marginal_grid,enroute_grid,planned_grid) |>
    tidyr::crossing(METRIC=c("FUEL_KG","DURATION_MIN","KG_MIN","KG_NM","FLOWN_NM")) |>
    mutate(ENGINE_GROUP="Not stratified") |>
    left_join(summary,by=c("REGION","TYPE","ENGINE_GROUP","BAND100","PHASE","ROW_KIND","PROFILE_CLASS","METRIC")) |>
    mutate(N_FLIGHTS=if_else(ROW_KIND=="Planned class",NA_integer_,coalesce(N_FLIGHTS,0L)),
      N=if_else(ROW_KIND=="Planned class",NA_integer_,coalesce(N,0L)),
      STATUS=case_when(ROW_KIND=="Planned class"~"Class not assigned",N==0~"No eligible observations",N<min_n~"Sparse: percentile suppressed",TRUE~"Populated"),
      PHASE_SCHEME=coalesce(PHASE_SCHEME,"Source ATOT-TOC-TOD-ALDT"),
      PROFILE_AXIS=case_when(ROW_KIND=="Marginal baseline"~"Unconditioned",PHASE=="Enroute"~"Time-weighted pressure altitude",TRUE~"Phase interruption"),
      FUEL_SOURCE=coalesce(FUEL_SOURCE,if_else(REGION=="CHN","QAR-integrated, delivered","PRU model, delivered")))
  paired_support<-grid |>select(TYPE,BAND100,PHASE,ROW_KIND,PROFILE_CLASS,METRIC,REGION,N) |>
    pivot_wider(names_from=REGION,values_from=N) |>mutate(PAIRED_SUPPORT=coalesce(CHN>=min_n&EUR>=min_n,FALSE))
  grid<-grid |>left_join(select(paired_support,-CHN,-EUR),by=c("TYPE","BAND100","PHASE","ROW_KIND","PROFILE_CLASS","METRIC"))
  wide_grid<-grid |>select(-N_FLIGHTS) |>pivot_wider(names_from=METRIC,
    values_from=c(N,P20,P50,P80,STATUS,PAIRED_SUPPORT))
  # Reconcile pooled and class-specific counts; classes form a partition, not
  # additional independent flights. Quantiles are NEVER averaged across classes.
  stopifnot(nrow(rows |>filter(ROW_KIND=="Marginal baseline"))==3*nrow(f),
    all(is.na(grid$P50[grid$STATUS!="Populated"])))
  checks<-rows |>filter(PHASE=="Enroute") |>count(REGION,TYPE,BAND100,ROW_KIND) |>
    pivot_wider(names_from=ROW_KIND,values_from=n)
  stopifnot(all(checks$`Marginal baseline`==checks$`Profile-conditioned`))
  support_grid<-grid |>filter(METRIC=="FUEL_KG",ROW_KIND=="Profile-conditioned") |>
    select(TYPE,BAND100,PROFILE_CLASS,REGION,N) |>pivot_wider(names_from=REGION,values_from=N) |>
    mutate(PAIRED_SUPPORT=CHN>=min_n&EUR>=min_n)
  # Audit the supplied original/delivered convention for the actual airborne
  # partition, independently of the finer phase table's ground roll labels.
  eur_file<-file.path(store,"derived/eur/parallel-preprocessing/EUR-2026-10-13-002/EUR-canonical-milestones-parallel.parquet")
  eur<-read_parquet(eur_file,col_select=c("SOURCE_UID","MST","TOT_FUEL_KG","TOT_FUEL_KG_ORIGINAL")) |>
    semi_join(filter(f,REGION=="EUR"),by="SOURCE_UID") |>filter(MST%in%c("ATOT","TOC","TOD","ALDT")) |>
    mutate(DIFFERENCE=TOT_FUEL_KG-TOT_FUEL_KG_ORIGINAL) |>group_by(SOURCE_UID) |>
    summarise(AIRBORNE_VARIANT_CHANGE=max(DIFFERENCE)-min(DIFFERENCE),.groups="drop")
  variant_audit<-tibble::tibble(REGION="EUR",N=nrow(eur),AIRBORNE_VARIANTS_IDENTICAL=sum(abs(eur$AIRBORNE_VARIANT_CHANGE)<1e-6))
  inputs<-c(unit_files,flow_files)
  list(grid=grid,wide_grid=wide_grid,profile_support=support_grid,paired_support=paired_support,
    quality_summary=phases |>group_by(REGION,PHASE) |>summarise(PROFILE_N=n(),FUEL_N=sum(FUEL_OK),DISTANCE_N=sum(DISTANCE_RATE_OK),.groups="drop"),
    variant_audit=variant_audit,flight_rows=rows,
    provenance=tibble::tibble(PATH=inputs,SHA256=vapply(inputs,digest::digest,character(1),algo="sha256",file=TRUE)))
}
