# Read-only support assessment using supplied operational/pressure milestones.
# Usage: Rscript scripts/assess-paper-lower-ground-support.R <new restricted directory>
# No decoder, canonical write, new threshold generation or manuscript adoption.
suppressPackageStartupMessages({library(arrow);library(dplyr);library(tidyr);library(readr)})
args <- commandArgs(trailingOnly=TRUE); stopifnot(length(args)==1L)
store <- normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
out <- normalizePath(args[1],mustWork=TRUE)
stopifnot(startsWith(out,paste0(store,'/')),length(list.files(out,all.files=TRUE,no..=TRUE))==0L)
base <- file.path(store,'derived/paper/eligibility-comparability/PAPER-2026-10-27-001')
cd <- file.path(store,'derived/chn/verification/CHN-2026-10-27-001/returned')
ed <- file.path(store,'derived/eur/parallel-preprocessing/EUR-2026-10-13-002')
cn <- c('CHN-canonical-milestones','CHN-phase-intervals','CHN-phase-summaries','CHN-flight-quality')
cf <- unlist(lapply(cn,function(n)sort(list.files(cd,paste0('^',n,'[.]parquet$'),recursive=TRUE,full.names=TRUE))))
ef <- file.path(ed,c('EUR-canonical-milestones-parallel.parquet','EUR-phase-summaries-parallel.parquet'))
inputs <- c(cf,ef,file.path(base,c('restricted-flight-strata.csv','restricted-window-eligibility.parquet')))
hashes <- vapply(inputs,digest::digest,character(1),algo='sha256',file=TRUE)
readc <- function(n)bind_rows(lapply(cf[basename(cf)==paste0(n,'.parquet')],read_parquet))
cm <- readc(cn[1]); ci <- readc(cn[2]); cp <- readc(cn[3]); cq <- readc(cn[4])
em <- read_parquet(ef[1]); ep <- read_parquet(ef[2])
meta <- read_csv(file.path(base,'restricted-flight-strata.csv'),show_col_types=FALSE)
stopifnot(nrow(meta)==27924,!anyDuplicated(meta[,c('REGION','SOURCE_UID')]))

defs <- tribble(~WINDOW,~FROM,~TO,~FAMILY,
 'Climb-out source LTO','ATOT','DLTO','Source_LTO',
 'Climb source LTO-FL075','DLTO','D_FL075','Lower_pressure',
 'Climb FL075-FL100','D_FL075','D_FL100','Pressure',
 'Climb FL100-FL180','D_FL100','D_FL180','Pressure',
 'Climb FL180-source TOC','D_FL180','TOC','Upper_context',
 'Descent source TOD-FL180','TOD','A_FL180','Upper_context',
 'Descent FL180-FL100','A_FL180','A_FL100','Pressure',
 'Descent FL100-FL075','A_FL100','A_FL075','Pressure',
 'Descent FL075-source LTO','A_FL075','ALTO','Lower_pressure',
 'Approach-landing source LTO','ALTO','ALDT','Source_LTO',
 'Takeoff-FL075','ATOT','D_FL075','Pressure_terminal',
 'FL075-landing','A_FL075','ALDT','Pressure_terminal')
ms <- bind_rows(cm |>select(SOURCE_UID,MST,TIME,ALT_FT,TOT_FUEL_KG,TOT_FUEL_KG_ORIGINAL,DIST_FLOWN_NM) |>mutate(REGION='CHN'),
 em |>select(SOURCE_UID,MST,TIME,ALT_FT,TOT_FUEL_KG,TOT_FUEL_KG_ORIGINAL,DIST_FLOWN_NM) |>mutate(REGION='EUR')) |>
 inner_join(select(meta,REGION,SOURCE_UID,ATOT,ALDT),by=c('REGION','SOURCE_UID')) |>
 filter(MST%in%unique(c(defs$FROM,defs$TO)),is.finite(as.numeric(TIME)),TIME>=ATOT,TIME<=ALDT) |>
 arrange(REGION,SOURCE_UID,MST,TIME) |>group_by(REGION,SOURCE_UID,MST) |>
 slice(if(first(MST)%in%c('A_FL180','A_FL100','A_FL075'))n()else 1L) |>ungroup()
w <- crossing(meta,defs) |>
 left_join(ms |>transmute(REGION,SOURCE_UID,FROM=MST,START_TIME=TIME,FROM_ALT=ALT_FT,FROM_FUEL=TOT_FUEL_KG,FROM_ORIGINAL=TOT_FUEL_KG_ORIGINAL,FROM_DIST=DIST_FLOWN_NM),by=c('REGION','SOURCE_UID','FROM')) |>
 left_join(ms |>transmute(REGION,SOURCE_UID,TO=MST,END_TIME=TIME,TO_ALT=ALT_FT,TO_FUEL=TOT_FUEL_KG,TO_ORIGINAL=TOT_FUEL_KG_ORIGINAL,TO_DIST=DIST_FLOWN_NM),by=c('REGION','SOURCE_UID','TO')) |>
 mutate(DURATION_MIN=as.numeric(difftime(END_TIME,START_TIME,units='mins')),ORDERED=is.finite(DURATION_MIN)&DURATION_MIN>0,
 FUEL_KG=TO_FUEL-FROM_FUEL,ORIGINAL_FUEL_KG=TO_ORIGINAL-FROM_ORIGINAL,FLOWN_NM=TO_DIST-FROM_DIST)
p <- ci |>arrange(SOURCE_UID,START_TIME,END_TIME) |>group_by(SOURCE_UID) |>
 mutate(C_TIME=cumsum(DURATION_MIN),C_FUEL=cumsum(if_else(is.finite(FUEL_KG),FUEL_KG,0)),
 C_DIST=cumsum(if_else(is.finite(DISTANCE_NM),DISTANCE_NM,0)),
 C_BAD_FUEL=cumsum(!coalesce(ELIGIBLE_FUEL_TIME&is.finite(FUEL_KG)&FUEL_KG>=0,FALSE)),
 C_BAD_DIST=cumsum(!coalesce(ELIGIBLE_DISTANCE&is.finite(DISTANCE_NM)&DISTANCE_NM>=0,FALSE))) |>ungroup()
zero <- p |>group_by(SOURCE_UID) |>slice_head(n=1) |>ungroup() |>
 transmute(SOURCE_UID,TIME=START_TIME,C_TIME=0,C_FUEL=0,C_DIST=0,C_BAD_FUEL=0,C_BAD_DIST=0)
p <- bind_rows(zero,p |>transmute(SOURCE_UID,TIME=END_TIME,C_TIME,C_FUEL,C_DIST,C_BAD_FUEL,C_BAD_DIST))
stopifnot(!anyDuplicated(p[,c('SOURCE_UID','TIME')]))
cw <- w |>filter(REGION=='CHN') |>
 left_join(p |>rename(START_TIME=TIME) |>rename_with(~paste0('START_',.x),starts_with('C_')),by=c('SOURCE_UID','START_TIME')) |>
 left_join(p |>rename(END_TIME=TIME) |>rename_with(~paste0('END_',.x),starts_with('C_')),by=c('SOURCE_UID','END_TIME')) |>
 left_join(select(cq,SOURCE_UID,AIRBORNE_TIME_VALID),by='SOURCE_UID') |>
 mutate(COVERED=coalesce(abs(END_C_TIME-START_C_TIME-DURATION_MIN)<1e-5,FALSE),
 LOCAL_FUEL=COVERED&coalesce(END_C_BAD_FUEL==START_C_BAD_FUEL,FALSE),
 LOCAL_DIST=COVERED&coalesce(END_C_BAD_DIST==START_C_BAD_DIST,FALSE),
 TIME_OK=ORDERED&(AIRBORNE_TIME_VALID|LOCAL_FUEL),
 FUEL_KG=if_else(LOCAL_FUEL,END_C_FUEL-START_C_FUEL,NA_real_),
 FLOWN_NM=if_else(LOCAL_DIST,END_C_DIST-START_C_DIST,NA_real_),
 FUEL_OK=TIME_OK&LOCAL_FUEL&is.finite(FUEL_KG)&FUEL_KG>0,
 DISTANCE_OK=TIME_OK&LOCAL_DIST&is.finite(FLOWN_NM)&FLOWN_NM>0&FLOWN_NM/DURATION_MIN*60<=750)
check <- cw |>filter(FUEL_OK,is.finite(FROM_FUEL),is.finite(TO_FUEL)) |>
 mutate(ERROR=abs(FUEL_KG-(TO_FUEL-FROM_FUEL)))
stopifnot(all(check$ERROR<=2e-6))
write_csv(check |>group_by(WINDOW) |>summarise(N=n(),MAX_ERROR_KG=max(ERROR),.groups='drop'),file.path(out,'aggregate-local-fuel-validation.csv'))
ew <- w |>filter(REGION=='EUR') |>mutate(TIME_OK=ORDERED,
 FUEL_OK=TIME_OK&SOURCE_CORE_TIMING_OK&is.finite(FUEL_KG)&FUEL_KG>0,
 DISTANCE_OK=TIME_OK&SOURCE_CORE_TIMING_OK&is.finite(FLOWN_NM)&FLOWN_NM>0&FLOWN_NM/DURATION_MIN*60<=750)
cols <- c(names(w),'TIME_OK','FUEL_OK','DISTANCE_OK')
air <- bind_rows(select(cw,all_of(cols)),select(ew,all_of(cols)))
# Existing windows must reproduce the independent prior assessment exactly.
old <- read_parquet(file.path(base,'restricted-window-eligibility.parquet'))
shared <- intersect(unique(old$WINDOW),defs$WINDOW)
verify <- air |>filter(WINDOW%in%shared) |>select(REGION,SOURCE_UID,WINDOW,TIME_OK,FUEL_OK,DISTANCE_OK) |>
 inner_join(old |>select(REGION,SOURCE_UID,WINDOW,TIME_OK,FUEL_OK,DISTANCE_OK),by=c('REGION','SOURCE_UID','WINDOW'),suffix=c('','.old'))
stopifnot(nrow(verify)==length(shared)*nrow(meta),all(verify$TIME_OK==verify$TIME_OK.old),
 all(verify$FUEL_OK==verify$FUEL_OK.old),all(verify$DISTANCE_OK==verify$DISTANCE_OK.old))

# Ground support comes from the delivered phase quantities, without fabricating
# a full-record cumulative fuel prefix when only airborne fuel is supported.
gd <- tribble(~PHASE,~WINDOW,
 'TAXI_OUT','Taxi-out recorded segment','TAKE_OFF_ROLL','Takeoff roll source segment',
 'RUNWAY_EXIT','Landing-roll/runway-exit source segment','TAXI_IN','Taxi-in recorded segment')
ground <- bind_rows(cp |>filter(PHASE%in%gd$PHASE) |>mutate(REGION='CHN'),
 ep |>filter(PHASE%in%gd$PHASE) |>mutate(REGION='EUR',TIMING_VALID=TRUE,ELIGIBLE_FUEL_TIME=TRUE,ELIGIBLE_DISTANCE=TRUE)) |>
 inner_join(gd,by='PHASE') |>
 left_join(select(meta,REGION,SOURCE_UID,TYPE_CANONICAL=TYPE,BAND100,SOURCE_CORE_TIMING_OK),by=c('REGION','SOURCE_UID')) |>
 transmute(REGION,SOURCE_UID,TYPE=TYPE_CANONICAL,ADEP,ADES,BAND100,SOURCE_CORE_TIMING_OK,WINDOW,FAMILY='Ground',FROM=FROM_MST,TO=TO_MST,
 START_TIME,END_TIME,DURATION_MIN,FUEL_KG,ORIGINAL_FUEL_KG=FUEL_KG_ORIGINAL,FLOWN_NM=DISTANCE_NM,
 ORDERED=is.finite(DURATION_MIN)&DURATION_MIN>0,
 TIME_OK=ORDERED&coalesce(TIMING_VALID,FALSE),
 FUEL_OK=TIME_OK&coalesce(ELIGIBLE_FUEL_TIME,FALSE)&is.finite(FUEL_KG)&FUEL_KG>0&(REGION=='CHN'|SOURCE_CORE_TIMING_OK),
 # Count positive supplied ground distances under their source eligibility.
 # This is quantity availability, not independent validation of a ground track.
 DISTANCE_OK=TIME_OK&coalesce(ELIGIBLE_DISTANCE,FALSE)&is.finite(FLOWN_NM)&FLOWN_NM>0)
x <- bind_rows(air,ground) |>mutate(DISTANCE_RATE_OK=FUEL_OK&DISTANCE_OK)
stopifnot(!anyDuplicated(x[,c('REGION','SOURCE_UID','WINDOW')]),!anyNA(x$TYPE),!anyNA(x$BAND100),
 !anyNA(x$TIME_OK),!anyNA(x$FUEL_OK),!anyNA(x$DISTANCE_RATE_OK))
write_parquet(x,file.path(out,'restricted-window-eligibility.parquet'))
summary <- x |>group_by(REGION,WINDOW,FAMILY,FROM,TO) |>summarise(INPUT=n(),ORDERED_N=sum(ORDERED),
 TIME_N=sum(TIME_OK),FUEL_TIME_N=sum(FUEL_OK),KG_NM_N=sum(DISTANCE_RATE_OK),.groups='drop')
write_csv(summary,file.path(out,'aggregate-window-support.csv'))
long <- x |>select(REGION,SOURCE_UID,TYPE,BAND100,WINDOW,FAMILY,TIME_OK,FUEL_OK,DISTANCE_RATE_OK) |>
 pivot_longer(c(TIME_OK,FUEL_OK,DISTANCE_RATE_OK),names_to='METRIC',values_to='PASS') |>filter(PASS)
cells <- long |>count(REGION,TYPE,BAND100,WINDOW,FAMILY,METRIC,name='N') |>
 pivot_wider(names_from=REGION,values_from=N,values_fill=0) |>mutate(PAIRED_SUPPORT=CHN>=30&EUR>=30)
write_csv(cells,file.path(out,'aggregate-type-stage-window-support.csv'))
write_csv(cells |>filter(PAIRED_SUPPORT) |>group_by(WINDOW,FAMILY,METRIC) |>
 summarise(CELLS=n(),CHN=sum(CHN),EUR=sum(EUR),.groups='drop'),file.path(out,'aggregate-paired-support.csv'))
write_csv(x |>filter(REGION=='EUR',FUEL_OK,is.finite(ORIGINAL_FUEL_KG)) |>group_by(WINDOW) |>
 summarise(N=n(),VARIANT_DIFF_N=sum(abs(FUEL_KG-ORIGINAL_FUEL_KG)>1e-6),
 MEDIAN_DELIVERED_OVER_ORIGINAL=median(FUEL_KG/ORIGINAL_FUEL_KG),.groups='drop'),file.path(out,'aggregate-eur-fuel-convention.csv'))
ops <- bind_rows(cm |>filter(MST%in%c('DLTO','ALTO')) |>mutate(REGION='CHN'),em |>filter(MST%in%c('DLTO','ALTO')) |>mutate(REGION='EUR'))
write_csv(ops |>mutate(AIRPORT=if_else(MST=='DLTO',ADEP,ADES)) |>group_by(REGION,MST,AIRPORT,MST_METHOD) |>
 summarise(N=n(),ALT_P20=quantile(ALT_FT,.2,na.rm=TRUE),ALT_P50=median(ALT_FT,na.rm=TRUE),ALT_P80=quantile(ALT_FT,.8,na.rm=TRUE),.groups='drop'),file.path(out,'aggregate-lto-boundary-context.csv'))
write_csv(ground |>group_by(REGION,WINDOW) |>summarise(SOURCE_ROWS=n(),
 ZERO_DURATION_N=sum(is.finite(DURATION_MIN)&DURATION_MIN==0),
 NEGATIVE_DURATION_N=sum(is.finite(DURATION_MIN)&DURATION_MIN<0),
 MISSING_DURATION_N=sum(!is.finite(DURATION_MIN)),
 POSITIVE_TIME_ZERO_DISTANCE_N=sum(TIME_OK&is.finite(FLOWN_NM)&FLOWN_NM==0),.groups='drop'),file.path(out,'aggregate-ground-limitations.csv'))
stopifnot(identical(hashes,vapply(inputs,digest::digest,character(1),algo='sha256',file=TRUE)))
write_csv(tibble(PATH=if_else(startsWith(inputs,paste0(store,'/')),paste0('data-store/',substring(inputs,nchar(store)+2L)),inputs),SHA256=hashes),file.path(out,'input-manifest.csv'))
write_csv(tibble(PATH='scripts/assess-paper-lower-ground-support.R',SHA256=digest::digest('scripts/assess-paper-lower-ground-support.R',algo='sha256',file=TRUE)),file.path(out,'source-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'runtime.txt'))
print(summary,n=40,width=Inf)
print(cells |>filter(PAIRED_SUPPORT,METRIC=='FUEL_OK') |>group_by(WINDOW) |>summarise(CELLS=n(),CHN=sum(CHN),EUR=sum(EUR),.groups='drop'),n=30)
