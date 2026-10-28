#!/usr/bin/env Rscript
# Exploratory aggregates only. No source repair, package installation, or network calls.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow);library(ggplot2)})
source('R/paper-window-references.R')
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==2L,grepl('^[A-Za-z0-9-]+$',args[2]))
out <- normalizePath(args[1],mustWork=TRUE)
stopifnot(startsWith(out,paste0(normalizePath('outputs'),'/offline-paper-')))
run_id <- args[2]
completed <- character()
atomic_rds <- function(value,path) {saveRDS(value,paste0(path,'.tmp'));stopifnot(file.rename(paste0(path,'.tmp'),path))}
status <- function(state,stage,message=NULL) {
  z <- list(run_id=run_id,state=state,stage=stage,completed=completed,pid=Sys.getpid(),
    updated_utc=format(Sys.time(),tz='UTC',usetz=TRUE),message=message)
  path <- file.path(out,'status.json')
  jsonlite::write_json(z,paste0(path,'.tmp'),auto_unbox=TRUE,pretty=TRUE)
  stopifnot(file.rename(paste0(path,'.tmp'),path))
  cat(z$updated_utc,state,stage,if(is.null(message))''else message,'\n')
}
q <- function(v,p) {v<-v[is.finite(v)];if(length(v)<30)NA_real_ else unname(quantile(v,p,type=7))}
avg <- function(v) {v<-v[is.finite(v)];if(length(v))mean(v)else NA_real_}
group_gcd <- function(v) as.character(cut(v,c(0,300,500,700,1000,Inf),right=FALSE,
  labels=c('0-<300','300-<500','500-<700','700-<1000','>=1000')))
fleet <- function(v) case_when(
  v%in%c('A20N','A21N','B38M','B39M','B737-MAX','C919','BCS1','BCS3','E290','E295')~'Newer single-aisle',
  v%in%c('A318','A319','A320','A321','B734','B735','B737','B738','B739','B752')~'Older single-aisle',
  v%in%c('A306','A332','A333','A339','A346','A359','A388','B772','B77L','B77W','B788','B789')~'Widebody',
  TRUE~'Other / unclassified')
reference_summary <- function(data,keys) bind_rows(lapply(
  c('FUEL_KG','DURATION_MIN','KG_MIN','KG_NM','FLOWN_NM'),function(metric) {
    data |>group_by(across(all_of(keys))) |>
      summarise(OPPORTUNITIES=n(),N=sum(is.finite(.data[[metric]])),
        MEAN=avg(.data[[metric]]),P20=q(.data[[metric]],.2),P50=q(.data[[metric]],.5),P80=q(.data[[metric]],.8),
        .groups='drop') |>mutate(METRIC=metric,STATUS=case_when(N==0~'No support',N<30~'Sparse: percentiles suppressed',TRUE~'Populated'))
  }))

main <- function() {
  status('running','verify-inputs')
  x <- load_paper_window_references() # verifies all 110 pinned inputs and adapter code
  cfg <- x$config
  checkpoint_dir <- file.path(cfg$store,'derived/paper/offline-exploration',run_id)
  dir.create(checkpoint_dir,recursive=TRUE,showWarnings=FALSE)
  paths <- unique(c('scripts/20-offline-paper-exploration.R','scripts/run-offline-paper-batch.py',
    cfg$config_path,cfg$input_manifest,paper_reference_sources(),file.path(cfg$output,'analysis.rds')))
  pins <- tibble(PATH=paths,SHA256=vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE))
  fingerprint <- list(inputs=select(cfg$manifest,PATH,SHA256),code_and_cache=pins)
  fp <- file.path(checkpoint_dir,'fingerprint.rds')
  if(file.exists(fp))stopifnot(identical(readRDS(fp),fingerprint))else atomic_rds(fingerprint,fp)
  write_csv(pins,file.path(out,'source-manifest.csv'))
  write_csv(fingerprint$inputs,file.path(out,'input-manifest.csv'))
  writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
  stage <- function(name,fn) {
    status('running',name)
    file <- file.path(checkpoint_dir,paste0(name,'.rds'))
    if(file.exists(file)) {
      z<-readRDS(file);cat('Resuming from completed checkpoint:',name,'\n')
    } else {
      z<-fn();stopifnot(is.list(z),length(z)>0,!is.null(names(z)))
      stopifnot(all(vapply(z,function(d)!any(c('SOURCE_UID','CANDIDATE_ID')%in%names(d)),logical(1))))
      atomic_rds(z,file)
    }
    for(n in names(z)) {
      dest<-file.path(out,paste0(n,'.csv'));write_csv(z[[n]],paste0(dest,'.tmp'))
      stopifnot(file.rename(paste0(dest,'.tmp'),dest))
    }
    completed<<-c(completed,name);status('running',paste0(name,'-saved'))
    invisible(z)
  }
  f <- x$flights |>mutate(GCD_GROUP=group_gcd(GCD_NM),FLEET=fleet(TYPE))
  stopifnot(!anyNA(f$GCD_GROUP),sum(count(f,REGION)$n)==27924L)
  w <- paper_metric_values(x$windows) |>mutate(GCD_GROUP=group_gcd(GCD_NM),FLEET=fleet(TYPE))
  stage('01-sample',function() list(
    type_distance_inventory=f |>count(REGION,TYPE,FLEET,GCD_GROUP,name='N') |>
      complete(nesting(TYPE,FLEET,GCD_GROUP),REGION=c('CHN','EUR'),fill=list(N=0)),
    fleet_distance_inventory=f |>count(REGION,FLEET,GCD_GROUP,name='N') |>
      complete(nesting(FLEET,GCD_GROUP),REGION=c('CHN','EUR'),fill=list(N=0)),
    type_mapping=f |>distinct(TYPE,FLEET) |>arrange(FLEET,TYPE),
    route_inventory=f |>group_by(REGION,TYPE,FLEET,GCD_GROUP,ADEP,ADES) |>
      summarise(N=n(),GCD_MEAN=mean(GCD_NM),.groups='drop')))
  stage('02-references',function() {
    exact <- reference_summary(w,c('REGION','TYPE','FLEET','GCD_GROUP','WINDOW'))
    paired <- exact |>select(TYPE,FLEET,GCD_GROUP,WINDOW,METRIC,REGION,N) |>
      pivot_wider(names_from=REGION,values_from=N,values_fill=0) |>
      mutate(PAIRED_N30=CHN>=30&EUR>=30)
    stopifnot(all(is.na(exact$P50[exact$N<30])))
    list(type_reference_grid=exact,fleet_reference_grid=reference_summary(w,c('REGION','FLEET','GCD_GROUP','WINDOW')),
      paired_type_support=paired)
  })
  stage('03-duration',function() {
    z<-w |>filter(WINDOW%in%cfg$core_windows,TIME_OK) |>
      mutate(TIME_GROUP=as.character(cut(DURATION_MIN,c(0,3,4,5,8,Inf),right=FALSE,
        labels=c('<3','3-<4','4-<5','5-<8','>=8'))))
    list(duration_conditioned_fuel=reference_summary(z,c('REGION','TYPE','FLEET','GCD_GROUP','WINDOW','TIME_GROUP')))
  })
  stage('04-source-levels',function() {
    read_role<-function(name)bind_rows(lapply(cfg$manifest$LOCAL_PATH[basename(cfg$manifest$LOCAL_PATH)==name],read_parquet))
    levels<-bind_rows(read_role('CHN-level-segments.parquet') |>mutate(REGION='CHN'),
      read_role('EUR-level-segments-parallel.parquet') |>mutate(REGION='EUR')) |>
      transmute(REGION,SOURCE_UID,L_START=as.numeric(START_TIME),L_END=as.numeric(END_TIME),START_ALT_FT,END_ALT_FT) |>
      filter(is.finite(L_START),is.finite(L_END),L_END>L_START,is.finite(START_ALT_FT),is.finite(END_ALT_FT),
        abs(END_ALT_FT-START_ALT_FT)/(L_END-L_START)*60<=300)
    overlaps<-levels |>arrange(REGION,SOURCE_UID,L_START,L_END) |>group_by(REGION,SOURCE_UID) |>
      summarise(BAD=any(L_START<lag(cummax(L_END))-1e-6,na.rm=TRUE),.groups='drop')
    stopifnot(!any(overlaps$BAD))
    z<-w |>filter(WINDOW%in%c(cfg$core_windows,'Climb source window','Descent source window','Enroute source window'),
      TIME_OK,coalesce(PROFILE_OK,FALSE)) |>mutate(A=as.numeric(START_TIME),B=as.numeric(END_TIME))
    seg<-z |>left_join(levels,by=join_by(REGION,SOURCE_UID,A<L_END,B>L_START),relationship='many-to-many') |>
      mutate(CLIP_START=pmax(A,L_START),CLIP_END=pmin(B,L_END),LEVEL_SEC=coalesce(pmax(0,CLIP_END-CLIP_START),0),
        MID_ALT=START_ALT_FT+(END_ALT_FT-START_ALT_FT)*((CLIP_START+CLIP_END)/2-L_START)/(L_END-L_START))
    tagged<-seg |>group_by(REGION,SOURCE_UID,WINDOW) |>
      summarise(LEVEL_SEC_20=sum(LEVEL_SEC[LEVEL_SEC>=20]),LEVEL_N_20=sum(LEVEL_SEC>=20),
        LEVEL_SEC_60=sum(LEVEL_SEC[LEVEL_SEC>=60]),LEVEL_N_60=sum(LEVEL_SEC>=60),
        LEVEL_SEC_120=sum(LEVEL_SEC[LEVEL_SEC>=120]),LEVEL_N_120=sum(LEVEL_SEC>=120),.groups='drop')
    z<-z |>left_join(tagged,by=c('REGION','SOURCE_UID','WINDOW')) |>
      mutate(TAG_GROUP=case_when(LEVEL_SEC_20==0~'No >=20s source tag',LEVEL_SEC_20<=60~'>0-1 min tagged',
        LEVEL_SEC_20<=120~'>1-2 min tagged',TRUE~'>2 min tagged'),REMAINDER_MIN=DURATION_MIN-LEVEL_SEC_20/60)
    stopifnot(all(z$LEVEL_SEC_20<=z$DURATION_MIN*60+1e-5),all(z$REMAINDER_MIN>=-1e-5))
    summarise_levels<-function(data,keys) data |>group_by(across(all_of(keys))) |>
      summarise(N=n(),FUEL_N=sum(is.finite(FUEL_KG)),FUEL_MEAN=avg(FUEL_KG),FUEL_P20=q(FUEL_KG,.2),
        FUEL_P50=q(FUEL_KG,.5),FUEL_P80=q(FUEL_KG,.8),TIME_MEAN=avg(DURATION_MIN),TIME_P50=q(DURATION_MIN,.5),
        LEVEL20_MEAN=avg(LEVEL_SEC_20/60),LEVEL20_P50=q(LEVEL_SEC_20/60,.5),
        LEVEL20_COUNT_P50=q(LEVEL_N_20,.5),TAG20_N=sum(LEVEL_N_20>0),TAG60_N=sum(LEVEL_N_60>0),
        TAG120_N=sum(LEVEL_N_120>0),REMAINDER_MEAN=avg(REMAINDER_MIN),.groups='drop')
    route<-summarise_levels(z,c('REGION','TYPE','FLEET','GCD_GROUP','WINDOW','ADEP','ADES'))
    reverse<-route |>select(REGION,TYPE,GCD_GROUP,WINDOW,ADEP,ADES,N,FUEL_P50,TIME_P50,LEVEL20_MEAN) |>
      rename(REV_N=N,REV_FUEL_P50=FUEL_P50,REV_TIME_P50=TIME_P50,REV_LEVEL20_MEAN=LEVEL20_MEAN,REV_ADEP=ADES,REV_ADES=ADEP)
    list(source_level_exposure=summarise_levels(z,c('REGION','TYPE','FLEET','GCD_GROUP','WINDOW')),
      source_tag_conditioned_fuel=summarise_levels(z,c('REGION','TYPE','FLEET','GCD_GROUP','WINDOW','TAG_GROUP')),
      reverse_routes=route |>left_join(reverse,by=c('REGION','TYPE','GCD_GROUP','WINDOW','ADEP'='REV_ADEP','ADES'='REV_ADES')),
      source_level_altitudes=seg |>filter(LEVEL_SEC>=20,is.finite(MID_ALT)) |>
        mutate(ALTITUDE_BAND_FT=floor(MID_ALT/1000)*1000) |>group_by(REGION,TYPE,GCD_GROUP,WINDOW,ALTITUDE_BAND_FT) |>
        summarise(EPISODES=n(),FLIGHTS=n_distinct(SOURCE_UID),TAGGED_MIN=sum(LEVEL_SEC)/60,.groups='drop'))
  })
  stage('05-enroute',function() {
    # Regroup the EXISTING common enroute cohort; do not claim expanded coverage.
    meta<-f |>select(REGION,SOURCE_UID,GCD_GROUP,FLEET)
    e<-x$enroute$exposure |>left_join(meta,by=c('REGION','SOURCE_UID'))
    m<-x$enroute$flight_metrics |>left_join(meta,by=c('REGION','SOURCE_UID'))
    list(enroute_existing_cohort=e |>group_by(REGION,TYPE,FLEET,GCD_GROUP,WINDOW,BAND) |>
        summarise(N=n(),MEAN_MIN=avg(MINUTES),P20_MIN=q(MINUTES,.2),P50_MIN=q(MINUTES,.5),P80_MIN=q(MINUTES,.8),
          MEAN_SHARE=avg(SHARE),.groups='drop'),
      enroute_existing_cohort_metrics=m |>group_by(REGION,TYPE,FLEET,GCD_GROUP,WINDOW) |>
        summarise(N=n(),TIME_P50=q(ENROUTE_MIN,.5),ALT_FT_P20=q(MEAN_ALT_FT,.2),ALT_FT_P50=q(MEAN_ALT_FT,.5),
          ALT_FT_P80=q(MEAN_ALT_FT,.8),KNOWN_SHARE_MEAN=avg(KNOWN_SHARE),GAP_SHARE_MEAN=avg(GAP_SHARE),.groups='drop'))
  })
  status('running','figures-and-final-verification')
  inv<-read_csv(file.path(out,'fleet_distance_inventory.csv'),show_col_types=FALSE) |>
    mutate(GCD_GROUP=factor(GCD_GROUP,levels=c('0-<300','300-<500','500-<700','700-<1000','>=1000')))
  p<-ggplot(inv,aes(GCD_GROUP,N,fill=FLEET))+geom_col()+facet_wrap(~REGION,ncol=1)+
    theme_bw(base_size=11)+theme(legend.position='bottom')+
    labs(x='Airport GCD group (NM)',y='Flights in supplied sample',fill=NULL)
  ggsave(file.path(out,'sample-distance-fleet.png'),p,width=9,height=7,dpi=160)
  z<-read_csv(file.path(out,'type_reference_grid.csv'),show_col_types=FALSE) |>
    filter(TYPE%in%c('A20N','A21N','A320','A321','B738','A333'),METRIC=='FUEL_KG',
      WINDOW%in%c('Climb FL100-FL180','Descent FL180-FL100'),N>=30)
  p<-ggplot(z,aes(P50,GCD_GROUP,color=REGION))+geom_linerange(aes(xmin=P20,xmax=P80),
    position=position_dodge(width=.5),orientation='y')+geom_point(position=position_dodge(width=.5))+
    facet_wrap(~TYPE+WINDOW,scales='free_x',ncol=3)+scale_color_manual(values=c(CHN='#A33A32',EUR='#245C89'))+
    theme_bw(base_size=9)+theme(legend.position='bottom')+labs(x='Fuel kg: P20 / P50 / P80 (n >= 30)',y='Airport GCD group (NM)',color=NULL)
  ggsave(file.path(out,'pressure-window-fuel.png'),p,width=12,height=10,dpi=160)
  invisible(paper_ref_config()) # after-run verification of the same 110 input hashes
  stopifnot(identical(pins$SHA256,vapply(pins$PATH,digest::digest,character(1),algo='sha256',file=TRUE)))
  writeLines(c('# Offline paper exploration',
    paste('Run:',run_id),'',
    'Exploratory aggregates for review; the manuscript and canonical inputs are unchanged.',
    'GCD groups are [0,300), [300,500), [500,700), [700,1000), [1000,Inf) NM.',
    'Absent groups describe the supplied samples, not regional traffic availability.',
    'Exact aircraft types remain primary. Fleet groups are reporting categories; pooled fuel mixes types, weights, and engines.',
    'B737-MAX stays as supplied, with no inferred variant. Engine groups remain unstratified.',
    'Each metric uses its own eligibility; P20/P50/P80 use type-7 quantiles and require 30 finite observations.',
    'Reference rows are marginal over profiles; duration groups and native tag groups are exploratory qualifiers, not common continuous/light/heavy classes.',
    'kg/NM uses supplied eligible flown phase distance. No ground distance proxy or extra 0.8 adjustment is applied.',
    'Source level tags differ between regions: associations and reverse-route patterns are within-source evidence, not comparable interruption prevalence.',
    'Tagged segments are clipped to each window before 20/60/120-second thresholds; no source tag does not establish continuous flight.',
    'Time outside source tags is a remainder, not verified active climb/descent. Enroute level time is ordinary cruise context, not automatically inefficiency.',
    'Altitude residence uses the existing common enroute cohort and existing Source/Level-envelope boundaries; broad GCD labels do not expand that cohort.',
    'Fuel is CHN QAR-integrated versus delivered EUR model fuel. Airspace/procedure explanations remain hypotheses; mass and payload are unobserved.',
    '', 'Resume with the same launcher command. Completed RDS stages are reused only when code, cached analysis, and all pinned inputs match.',
    'Sleep pauses computing. Reopening the lid normally resumes the running process; after termination, rerun the launcher.',
    'Check status.json and batch.log. No network connection, model calls, or package installation is used.'),file.path(out,'README.md'))
  products<-list.files(out,pattern='\\.(csv|png|md|txt)$',full.names=TRUE)
  products<-products[!basename(products)%in%c('product-manifest.csv','exit-code.txt')]
  write_csv(tibble(FILE=basename(products),SHA256=vapply(products,digest::digest,character(1),algo='sha256',file=TRUE)),
    file.path(out,'product-manifest.csv'))
  status('complete','all-stages','Inputs unchanged; exploratory outputs ready for review.')
}
tryCatch(main(),error=function(e){status('failed','error',conditionMessage(e));quit(status=1)})
