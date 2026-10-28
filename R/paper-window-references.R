# Versioned paper adapter over the checked, source-specific eligibility views.
# Canonical products are read-only. Flight/event/window views stay restricted.
paper_ref_q <- function(x, min_n=30L) {
  x <- x[is.finite(x)]
  if(length(x)<min_n)return(c(P20=NA_real_,P50=NA_real_,P80=NA_real_))
  setNames(unname(stats::quantile(x,c(.2,.5,.8),type=7)),c('P20','P50','P80'))
}

paper_metric_values <- function(x) {
  # Independent time support; fuel rates require the relevant local fuel support.
  x$KG_MIN <- ifelse(x$FUEL_OK,x$FUEL_KG/x$DURATION_MIN,NA_real_)
  x$KG_NM <- ifelse(x$DISTANCE_RATE_OK,x$FUEL_KG/x$FLOWN_NM,NA_real_)
  x$FUEL_KG[!x$FUEL_OK] <- NA_real_
  x$DURATION_MIN[!x$TIME_OK] <- NA_real_
  x$FLOWN_NM[!x$DISTANCE_RATE_OK] <- NA_real_
  x
}

paper_ref_config <- function(path='config/paper-analysis-2026-10-27.json',verify=TRUE) {
  cfg <- jsonlite::read_json(path,simplifyVector=TRUE)
  cfg$config_path <- path
  cfg$store <- normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
  manifest <- readr::read_csv(cfg$input_manifest,show_col_types=FALSE)
  manifest$LOCAL_PATH <- ifelse(startsWith(manifest$PATH,'data-store/'),
    file.path(cfg$store,substring(manifest$PATH,12)),manifest$PATH)
  stopifnot(!anyDuplicated(manifest$PATH),all(file.exists(manifest$LOCAL_PATH)))
  if(verify)stopifnot(all(manifest$SHA256==vapply(manifest$LOCAL_PATH,digest::digest,character(1),algo='sha256',file=TRUE)))
  cfg$manifest <- manifest
  cfg$output <- file.path(cfg$store,cfg$output_directory)
  stopifnot(startsWith(cfg$output,file.path(cfg$store,'derived/paper/')))
  cfg
}

paper_reference_sources <- function() c('R/paper-window-references.R','R/enroute-level-exposure.R',
  'scripts/16-build-paper-window-references.R','scripts/assess-chn-eur-paper-support.R',
  'scripts/assess-paper-lower-ground-support.R','scripts/assess-paper-profile-resolution.R')

paper_reference_fingerprint <- function(cfg) {
  paths <- c(cfg$config_path,cfg$input_manifest,paper_reference_sources())
  tibble::tibble(PATH=paths,SHA256=vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE))
}

paper_ref_summarise <- function(windows,min_n=30L) {
  keys <- c('REGION','TYPE','BAND100','WINDOW')
  values <- paper_metric_values(windows) |>
    dplyr::select(dplyr::all_of(keys),FUEL_KG,DURATION_MIN,KG_MIN,KG_NM,FLOWN_NM) |>
    tidyr::pivot_longer(c(FUEL_KG,DURATION_MIN,KG_MIN,KG_NM,FLOWN_NM),names_to='METRIC',values_to='VALUE')
  out <- values |>dplyr::group_by(dplyr::across(dplyr::all_of(c(keys,'METRIC')))) |>
    dplyr::summarise(N=sum(is.finite(VALUE)),Q=list(paper_ref_q(VALUE,min_n)),.groups='drop') |>
    dplyr::mutate(P20=vapply(Q,`[`,0,1),P50=vapply(Q,`[`,0,2),P80=vapply(Q,`[`,0,3)) |>dplyr::select(-Q)
  cells <- windows |>dplyr::distinct(TYPE,BAND100)
  full <- tidyr::crossing(cells,REGION=c('CHN','EUR'),WINDOW=unique(windows$WINDOW),
    METRIC=c('FUEL_KG','DURATION_MIN','KG_MIN','KG_NM','FLOWN_NM')) |>
    dplyr::left_join(out,by=c(keys,'METRIC')) |>dplyr::mutate(N=dplyr::coalesce(N,0L),
      STATUS=dplyr::case_when(N==0~'No eligible observations',N<min_n~'Sparse: percentile suppressed',TRUE~'Populated'))
  paired <- full |>dplyr::select(-P20,-P50,-P80,-STATUS) |>
    tidyr::pivot_wider(names_from=REGION,values_from=N,values_fill=0) |>
    dplyr::mutate(PAIRED_SUPPORT=CHN>=min_n&EUR>=min_n)
  full <- full |>dplyr::left_join(dplyr::select(paired,TYPE,BAND100,WINDOW,METRIC,PAIRED_SUPPORT),by=c('TYPE','BAND100','WINDOW','METRIC'))
  list(grid=full,paired=paired)
}

build_paper_window_references <- function(cfg=paper_ref_config(),with_enroute=TRUE) {
  suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow);library(ggplot2)})
  base <- file.path(cfg$store,cfg$base_view)
  lower <- file.path(cfg$store,cfg$lower_ground_view)
  flights <- read_csv(file.path(base,'restricted-flight-strata.csv'),show_col_types=FALSE)
  a <- read_parquet(file.path(base,'restricted-window-eligibility.parquet'))
  b <- read_parquet(file.path(lower,'restricted-window-eligibility.parquet'))
  shared <- intersect(unique(a$WINDOW),unique(b$WINDOW))
  check <- a |>filter(WINDOW%in%shared) |>select(REGION,SOURCE_UID,WINDOW,TIME_OK,FUEL_OK,DISTANCE_RATE_OK) |>
    inner_join(b |>select(REGION,SOURCE_UID,WINDOW,TIME_OK,FUEL_OK,DISTANCE_RATE_OK),by=c('REGION','SOURCE_UID','WINDOW'),suffix=c('','.lower'))
  stopifnot(nrow(check)==length(shared)*nrow(flights),all(check$TIME_OK==check$TIME_OK.lower),
    all(check$FUEL_OK==check$FUEL_OK.lower),all(check$DISTANCE_RATE_OK==check$DISTANCE_RATE_OK.lower))
  windows <- bind_rows(a,b |>filter(!WINDOW%in%unique(a$WINDOW))) |>
    mutate(ANALYSIS_ID=cfg$analysis_id,ENGINE_GROUP='Not stratified',PROFILE_CLASS='All profiles',
      PROFILE_AXIS='Marginal reference',
      FUEL_SOURCE=if_else(REGION=='CHN','QAR integrated','EUR model, delivered'),
      BOUNDARY_SCHEME=case_when(FAMILY=='Pressure'~'Directional standard-pressure crossings',
        FAMILY=='Ground'~'Source operational ground boundaries',
        FAMILY=='Pressure_terminal'~'Source takeoff/landing and standard-pressure crossing',
        FAMILY%in%c('Source_LTO','Lower_pressure')&REGION=='CHN'~'Source 3000-ft field-pressure increment',
        FAMILY%in%c('Source_LTO','Lower_pressure')~'Source EUR LTO altitude boundary',
        FAMILY=='ARP'~'Airport-centred GCD radius',TRUE~'Source ATOT/TOC/TOD/ALDT'),
      DISTANCE_BASIS=if_else(FAMILY=='Ground','Supplied ground distance','Supplied flown phase distance'),
      FUEL_CONVENTION=if_else(REGION=='EUR'&WINDOW=='Takeoff roll source segment','Delivered roll fuel, already adjusted by 0.8','Delivered source fuel'),
      PROFILE_STATE=if_else(is.na(PROFILE_OK),'Coverage not assessed for this descriptor',
        if_else(PROFILE_OK,'Profile support available; interruption class unassigned','Unknown or unsupported profile coverage')))
  stopifnot(nrow(flights)==27924,!anyDuplicated(windows[,c('REGION','SOURCE_UID','WINDOW')]),
    !anyNA(windows$FUEL_OK),!anyNA(windows$TIME_OK),!anyNA(windows$DISTANCE_RATE_OK))
  # The cohort views are explicitly source-pinned, rather than a global filter.
  support <- windows |>group_by(REGION,WINDOW,FAMILY,FROM,TO) |>
    summarise(INPUT=n(),TIME_N=sum(TIME_OK),FUEL_N=sum(FUEL_OK),KG_NM_N=sum(DISTANCE_RATE_OK),
      PROFILE_N=sum(coalesce(PROFILE_OK,FALSE)),.groups='drop')
  expected <- read_csv('notes/results/paper-cohort-mapping-2026-10-27/aggregate-window-support.csv',show_col_types=FALSE)
  got <- support |>inner_join(select(expected,REGION,WINDOW,TIME_EXPECT=TIME_N,FUEL_EXPECT=FUEL_TIME_N,KG_EXPECT=KG_NM_N),by=c('REGION','WINDOW'))
  stopifnot(nrow(got)==nrow(expected),all(got$TIME_N==got$TIME_EXPECT),all(got$FUEL_N==got$FUEL_EXPECT),all(got$KG_NM_N==got$KG_EXPECT))
  sums <- paper_ref_summarise(windows,cfg$minimum_reference_n)
  metadata <- windows |>distinct(REGION,WINDOW,FAMILY,FROM,TO,ENGINE_GROUP,PROFILE_CLASS,PROFILE_AXIS,
    FUEL_SOURCE,BOUNDARY_SCHEME,DISTANCE_BASIS,FUEL_CONVENTION,ANALYSIS_ID)
  grid <- sums$grid |>left_join(metadata,by=c('REGION','WINDOW'))
  wide <- grid |>pivot_wider(names_from=METRIC,values_from=c(N,P20,P50,P80,STATUS,PAIRED_SUPPORT))
  pairs <- sums$paired
  paired_support <- pairs |>filter(PAIRED_SUPPORT) |>group_by(WINDOW,METRIC) |>
    summarise(CELLS=n(),CHN=sum(CHN),EUR=sum(EUR),.groups='drop')
  key_metrics <- c('DURATION_MIN','FUEL_KG','KG_MIN','KG_NM','FLOWN_NM')
  overview <- bind_rows(lapply(unique(windows$WINDOW),function(w) {
    z <- paper_metric_values(filter(windows,WINDOW==w))
    z |>select(REGION,all_of(key_metrics)) |>pivot_longer(-REGION,names_to='METRIC',values_to='VALUE') |>
      group_by(REGION,METRIC) |>summarise(N=sum(is.finite(VALUE)),Q=list(paper_ref_q(VALUE,cfg$minimum_reference_n)),.groups='drop') |>
      mutate(WINDOW=w,P20=vapply(Q,`[`,0,1),P50=vapply(Q,`[`,0,2),P80=vapply(Q,`[`,0,3)) |>select(-Q)
  }))
  # Event/candidate views preserve the returned selection, methods and availability.
  read_role <- function(name) {
    f <- cfg$manifest$LOCAL_PATH[basename(cfg$manifest$LOCAL_PATH)==paste0(name,'.parquet')]
    stopifnot(length(f)>0)
    bind_rows(lapply(f,function(p)read_parquet(p) |>mutate(INPUT_FILE=sub(paste0('^',cfg$store,'/'),'data-store/',p))))
  }
  cm <- read_role('CHN-canonical-milestones'); em <- read_role('EUR-canonical-milestones-parallel')
  ops <- c('AOBT','ERWY','ATOT','DLTO','TOC','TOD','ALTO','ALDT','XRWY','AIBT',
    'D_FL075','D_FL100','D_FL180','A_FL180','A_FL100','A_FL075','D040','D100','D200','A200','A100','A040')
  events <- bind_rows(cm |>mutate(REGION='CHN'),em |>mutate(REGION='EUR')) |>
    filter(MST%in%ops) |>arrange(REGION,SOURCE_UID,MST,TIME) |>group_by(REGION,SOURCE_UID,MST) |>
    slice(if(first(MST)%in%c('A_FL180','A_FL100','A_FL075','A200','A100','A040'))n()else 1L) |>ungroup() |>
    select(any_of(c('REGION','SOURCE_UID','MST','TIME','ALT_FT','MST_METHOD','CANDIDATE_ID','BRACKET_SEC','INPUT_FILE')))
  candidates <- bind_rows(read_role('CHN-milestone-candidates') |>mutate(REGION='CHN'),
    read_role('EUR-milestone-crossing-candidates') |>mutate(REGION='EUR')) |>
    select(any_of(c('REGION','SOURCE_UID','MST','TIME','CANDIDATE_ID','SUPPORTED','SELECTED','SELECTION_RULE',
      'SUPPRESS_LEVEL_ASSOCIATED','SUPPORT_REASON','BRACKET_SEC','M3_BRACKET_GAP_SEC','MST_METHOD','M3_METHOD','INPUT_FILE')))
  availability <- read_role('CHN-milestone-availability') |>mutate(REGION='CHN')
  cq <- read_role('CHN-flight-quality')
  inventory <- flights |>group_by(REGION) |>summarise(INPUT=n(),AIRPORTS=n_distinct(c(ADEP,ADES)),
    ROUTES=n_distinct(paste(ADEP,ADES)),TYPES=n_distinct(TYPE),GCD_MIN=min(GCD_NM),GCD_P50=median(GCD_NM),GCD_MAX=max(GCD_NM),
    FIRST_ATOT_UTC=as.character(min(as.Date(ATOT,tz='UTC'),na.rm=TRUE)),LAST_ATOT_UTC=as.character(max(as.Date(ATOT,tz='UTC'),na.rm=TRUE)),.groups='drop')
  types <- flights |>count(TYPE,REGION,name='N') |>pivot_wider(names_from=REGION,values_from=N,values_fill=0) |>arrange(desc(CHN))
  dates <- flights |>mutate(ATOT_UTC_MONTH=if_else(is.na(ATOT),'Missing ATOT',format(ATOT,'%Y-%m',tz='UTC'))) |>count(REGION,ATOT_UTC_MONTH,name='N')
  # Independent enroute cohort: time/profile support, not fine-window fuel support.
  en <- windows |>filter(WINDOW=='Enroute source window',TIME_OK,coalesce(PROFILE_OK,FALSE))
  ens <- en |>count(TYPE,BAND100,REGION) |>pivot_wider(names_from=REGION,values_from=n,values_fill=0) |>
    mutate(COMMON=CHN>=cfg$minimum_reference_n&EUR>=cfg$minimum_reference_n)
  en <- en |>left_join(select(ens,TYPE,BAND100,COMMON),by=c('TYPE','BAND100')) |>
    left_join(select(cq,SOURCE_UID,CHN_CONTEXT_OK=AIRBORNE_DISTANCE_VALID),by='SOURCE_UID') |>
    mutate(TIME_ATOT=ATOT,TIME_ALDT=ALDT,TIME_TOC=START_TIME,TIME_TOD=END_TIME,ENROUTE_MIN=DURATION_MIN,
      dep_lat=DLAT,dep_lon=DLON,arr_lat=ALAT,arr_lon=ALON,
      DISTANCE_CONTEXT_OK=REGION=='EUR'|coalesce(CHN_CONTEXT_OK,FALSE))
  enroute <- if(with_enroute)build_enroute_exposure(list(profiles=en),store=cfg$store,chn_dir=file.path(cfg$store,cfg$chn_directory))else NULL
  # Retain source originals, including the already adjusted EUR roll convention.
  convention <- windows |>filter(REGION=='EUR',FUEL_OK,is.finite(ORIGINAL_FUEL_KG)) |>group_by(WINDOW) |>
    summarise(N=n(),DIFFERENT_N=sum(abs(FUEL_KG-ORIGINAL_FUEL_KG)>1e-6),
      DELIVERED_OVER_ORIGINAL_P50=median(FUEL_KG/ORIGINAL_FUEL_KG),.groups='drop')
  profile_state <- windows |>group_by(REGION,WINDOW,PROFILE_STATE) |>summarise(N=n(),FUEL_N=sum(FUEL_OK),.groups='drop')
  stopifnot(all(is.na(grid$P50[grid$N<cfg$minimum_reference_n])),
    all((paired_support |>filter(WINDOW%in%cfg$core_windows,METRIC=='FUEL_KG'))$CELLS==8))
  list(config=cfg,flights=flights,windows=windows,events=events,candidates=candidates,availability=availability,
    inventory=inventory,types=types,dates=dates,support=support,grid=grid,wide_grid=wide,
    paired_support=paired_support,paired_cells=pairs,overview=overview,enroute=enroute,enroute_support=ens,
    fuel_convention=convention,profile_state=profile_state,source_fingerprint=paper_reference_fingerprint(cfg))
}

load_paper_window_references <- function(config='config/paper-analysis-2026-10-27.json') {
  cfg <- paper_ref_config(config)
  cache <- file.path(cfg$output,'analysis.rds')
  if(!file.exists(cache))stop('Build the adopted paper view with Rscript scripts/16-build-paper-window-references.R')
  result <- readRDS(cache)
  stopifnot(identical(result$config$analysis_id,cfg$analysis_id),
    identical(result$source_fingerprint,paper_reference_fingerprint(cfg)))
  result
}

paper_reference_plot <- function(x,window,metric='FUEL_KG',kind='interval') {
  colors <- c(CHN='#A33A32',EUR='#245C89')
  p <- x$paired_cells |>filter(WINDOW==window,METRIC==metric,PAIRED_SUPPORT) |>select(TYPE,BAND100)
  label <- switch(metric,FUEL_KG='Window fuel (kg)',DURATION_MIN='Window duration (min)',KG_MIN='Fuel rate (kg/min)',KG_NM='Fuel rate (kg/NM)')
  if(kind=='interval') {
    z <- x$grid |>filter(WINDOW==window,METRIC==metric,PAIRED_SUPPORT) |>mutate(CELL=paste(TYPE,BAND100))
    ggplot(z,aes(P50,CELL,color=REGION)) +geom_linerange(aes(xmin=P20,xmax=P80),position=position_dodge(width=.5),orientation='y') +
      geom_point(position=position_dodge(width=.5),size=1.8) +scale_color_manual(values=colors) +labs(x=label,y=NULL,color=NULL)
  } else {
    z <- paper_metric_values(x$windows |>filter(WINDOW==window) |>semi_join(p,by=c('TYPE','BAND100')))
    ggplot(z,aes(.data[[metric]],color=REGION)) +stat_ecdf(linewidth=.6) +facet_wrap(~TYPE+BAND100,scales='free_x',ncol=2) +
      scale_color_manual(values=colors) +labs(x=label,y='Cumulative flight share',color=NULL)
  }
}

paper_terminal_plot <- function(x,side='Departure',metric='FUEL_KG') {
  opts <- if(side=='Departure')c('Climb-out source LTO','Takeoff-FL075')else c('Approach-landing source LTO','FL075-landing')
  z <- x$grid |>filter(WINDOW%in%opts,METRIC==metric,PAIRED_SUPPORT) |>mutate(CELL=paste(TYPE,BAND100),
    OPTION=factor(WINDOW,levels=opts,labels=if(side=='Departure')c('ATOT to source 3000 ft','ATOT to FL075')else c('Source 3000 ft to ALDT','FL075 to ALDT')))
  ggplot(z,aes(P50,CELL,color=REGION)) +geom_linerange(aes(xmin=P20,xmax=P80),position=position_dodge(width=.5),orientation='y') +
    geom_point(position=position_dodge(width=.5),size=1.5) +facet_wrap(~OPTION,ncol=1,scales='free_x') +
    scale_color_manual(values=c(CHN='#A33A32',EUR='#245C89')) +labs(x=if(metric=='FUEL_KG')'Window fuel (kg)'else 'Duration (min)',y=NULL,color=NULL)
}
