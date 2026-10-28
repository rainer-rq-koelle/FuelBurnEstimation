# Resolution sensitivity for primary profile windows; outputs remain restricted.
# Usage: Rscript scripts/assess-paper-profile-resolution.R <restricted assessment directory>
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow)})
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
store<-normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
out<-normalizePath(args[1],mustWork=TRUE);stopifnot(startsWith(out,paste0(store,'/')))
x<-read_parquet(file.path(out,'restricted-window-eligibility.parquet')) |> filter(WINDOW%in%c('Climb FL100-FL180','Descent FL180-FL100'))
m3<-bind_rows(lapply(file.path(store,'raw/eur/source-sample',sprintf('m3-ctfm-2025-%02d.parquet',6:8)),function(p)as.data.frame(read_parquet(p,col_select=c('FLIGHT_ID','TIME_OVER','FLIGHT_LEVEL'))))) |>
 transmute(SOURCE_UID=as.character(FLIGHT_ID),T=as.numeric(TIME_OVER),ALT=as.numeric(FLIGHT_LEVEL)*100) |> filter(is.finite(T),is.finite(ALT),ALT>=0,ALT<=50000) |> distinct(SOURCE_UID,T) |> arrange(SOURCE_UID,T) |>
 group_by(SOURCE_UID) |> mutate(LEFT_T=T,RIGHT_T=lead(T),GAP=RIGHT_T-LEFT_T) |> ungroup() |> filter(GAP>30) |> select(SOURCE_UID,LEFT_T,RIGHT_T,GAP)
e<-x |> filter(REGION=='EUR') |> mutate(START_NUM=as.numeric(START_TIME),END_NUM=as.numeric(END_TIME)) |>
 left_join(m3,by=join_by(SOURCE_UID,START_NUM<RIGHT_T,END_NUM>LEFT_T),relationship='many-to-many') |> group_by(SOURCE_UID,WINDOW) |> summarise(MAX_GAP=if(any(is.finite(GAP)))max(GAP,na.rm=TRUE)else 0,.groups='drop')
# CHN zero is a sentinel: local QC already limits source gaps to <=30 sec.
# It is not a claim of zero sampling interval or independently dense M3 support.
x<-x |>left_join(e,by=c('SOURCE_UID','WINDOW')) |>mutate(MAX_GAP=if_else(REGION=='CHN',0,MAX_GAP))
g<-crossing(x,LIMIT=c(30,60,120,300)) |>mutate(CLASS_CANDIDATE=FUEL_OK&PROFILE_OK&MAX_GAP<=LIMIT)
write_parquet(g,file.path(out,'restricted-primary-profile-resolution.parquet'))
s<-g |>group_by(REGION,WINDOW,LIMIT) |>summarise(PROFILE_FUEL_N=sum(CLASS_CANDIDATE),.groups='drop');write_csv(s,file.path(out,'aggregate-primary-profile-resolution.csv'))
p<-g |>filter(CLASS_CANDIDATE) |>group_by(REGION,WINDOW,LIMIT,TYPE,BAND100) |>summarise(N=n_distinct(SOURCE_UID),.groups='drop') |>pivot_wider(names_from=REGION,values_from=N,values_fill=0) |>mutate(PAIRED=CHN>=30&EUR>=30)
write_csv(p,file.path(out,'aggregate-profile-resolution-cells.csv'))
write_csv(p |>filter(PAIRED) |>group_by(WINDOW,LIMIT) |>summarise(CELLS=n(),CHN=sum(CHN),EUR=sum(EUR),.groups='drop'),file.path(out,'aggregate-paired-profile-resolution.csv'))
print(s);print(p |>filter(PAIRED) |>group_by(WINDOW,LIMIT) |>summarise(CELLS=n(),CHN=sum(CHN),EUR=sum(EUR),.groups='drop'))
