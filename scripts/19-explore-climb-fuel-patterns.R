#!/usr/bin/env Rscript
# Result-led FL100--180 exploration. No canonical/source/eligibility products change.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow);library(ggplot2)})
source('R/paper-window-references.R')
x<-load_paper_window_references()
cfg<-x$config
out<-'notes/results/paper-climb-patterns-2026-10-27'
restricted<-file.path(cfg$store,'derived/paper/climb-patterns/PAPER-CLIMB-PATTERNS-2026-10-27-001')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
dir.create(restricted,recursive=TRUE,showWarnings=FALSE)
meta<-x$flights |>select(REGION,SOURCE_UID,ADEP,ADES,GCD_NM)
w<-x$windows |>filter(WINDOW=='Climb FL100-FL180',FUEL_OK) |>
  select(-any_of(c('ADEP','ADES','GCD_NM'))) |>left_join(meta,by=c('REGION','SOURCE_UID')) |>
  mutate(TIME_BAND=cut(DURATION_MIN,c(0,3,4,5,Inf),right=FALSE,labels=c('<3','3-4','4-5','>=5')))
read_role<-function(name)bind_rows(lapply(cfg$manifest$LOCAL_PATH[basename(cfg$manifest$LOCAL_PATH)==name],read_parquet))
levels<-bind_rows(read_role('CHN-level-segments.parquet') |>mutate(REGION='CHN'),
  read_role('EUR-level-segments-parallel.parquet') |>mutate(REGION='EUR')) |>
  transmute(REGION,SOURCE_UID,L_START=as.numeric(START_TIME),L_END=as.numeric(END_TIME),START_ALT_FT,END_ALT_FT) |>
  filter(is.finite(L_START),is.finite(L_END),L_END>L_START,is.finite(START_ALT_FT),is.finite(END_ALT_FT),
    abs(END_ALT_FT-START_ALT_FT)/(L_END-L_START)*60<=300)
overlap<-levels |>arrange(REGION,SOURCE_UID,L_START,L_END) |>group_by(REGION,SOURCE_UID) |>
  summarise(OVERLAP=any(L_START<lag(cummax(L_END))-1e-6,na.rm=TRUE),.groups='drop')
stopifnot(!any(overlap$OVERLAP))
segments<-w |>mutate(A=as.numeric(START_TIME),B=as.numeric(END_TIME)) |>
  left_join(levels,by=join_by(REGION,SOURCE_UID,A<L_END,B>L_START),relationship='many-to-many') |>
  mutate(CLIP_START=pmax(A,L_START),CLIP_END=pmin(B,L_END),
    LEVEL_SEC=coalesce(pmax(0,CLIP_END-CLIP_START),0),
    LEVEL_MID_ALT=START_ALT_FT+(END_ALT_FT-START_ALT_FT)*((CLIP_START+CLIP_END)/2-L_START)/(L_END-L_START))
ld<-segments |>group_by(REGION,SOURCE_UID) |>
  summarise(LEVEL_SEC_20=sum(LEVEL_SEC[LEVEL_SEC>=20]),LEVEL_N_20=sum(LEVEL_SEC>=20),
    LEVEL_SEC_60=sum(LEVEL_SEC[LEVEL_SEC>=60]),LEVEL_N_60=sum(LEVEL_SEC>=60),
    LEVEL_SEC_120=sum(LEVEL_SEC[LEVEL_SEC>=120]),LEVEL_N_120=sum(LEVEL_SEC>=120),.groups='drop')
w<-w |>left_join(ld,by=c('REGION','SOURCE_UID')) |>
  mutate(across(c(LEVEL_SEC_20,LEVEL_N_20,LEVEL_SEC_60,LEVEL_N_60,LEVEL_SEC_120,LEVEL_N_120),
    ~if_else(coalesce(PROFILE_OK,FALSE),as.numeric(.x),NA_real_)),
    REMAINDER_MIN=DURATION_MIN-LEVEL_SEC_20/60,
    TAG_GROUP=case_when(is.na(LEVEL_SEC_20)~'Unknown source altitude support',
      LEVEL_SEC_20==0~'No >=20s source tag',LEVEL_SEC_20<=60~'>0-1 min tagged',
      LEVEL_SEC_20<=120~'>1-2 min tagged',TRUE~'>2 min tagged'))
stopifnot(all(w$LEVEL_SEC_20<=w$DURATION_MIN*60+1e-5,na.rm=TRUE),
  all(abs(w$DURATION_MIN-w$LEVEL_SEC_20/60-w$REMAINDER_MIN)<1e-7,na.rm=TRUE))

# Percentiles retain the existing n>=30 rule. Means are descriptive with their n.
q<-function(v,p)if(sum(is.finite(v))>=30)unname(quantile(v[is.finite(v)],p,type=7))else NA_real_
avg<-function(v)if(any(is.finite(v)))mean(v[is.finite(v)])else NA_real_
summarise_patterns<-function(data,keys) data |>group_by(across(all_of(keys))) |>
  summarise(N=n(),GCD_MEAN=mean(GCD_NM),FUEL_MEAN=mean(FUEL_KG),FUEL_P20=q(FUEL_KG,.2),
    FUEL_P50=q(FUEL_KG,.5),FUEL_P80=q(FUEL_KG,.8),TIME_MEAN=mean(DURATION_MIN),TIME_P50=q(DURATION_MIN,.5),
    KG_MIN_P50=q(FUEL_KG/DURATION_MIN,.5),LONG_N=sum(DURATION_MIN>=5),LONG_SHARE=mean(DURATION_MIN>=5),
    SOURCE_PROFILE_N=sum(is.finite(LEVEL_SEC_20)),TAGGED_20_N=sum(LEVEL_N_20>0,na.rm=TRUE),
    TAGGED_60_N=sum(LEVEL_N_60>0,na.rm=TRUE),TAGGED_120_N=sum(LEVEL_N_120>0,na.rm=TRUE),
    LEVEL20_MEAN=avg(LEVEL_SEC_20/60),LEVEL20_P50=q(LEVEL_SEC_20/60,.5),
    LEVEL20_COUNT_P50=q(LEVEL_N_20,.5),REMAINDER_MEAN=avg(REMAINDER_MIN),REMAINDER_P50=q(REMAINDER_MIN,.5),.groups='drop')
duration<-summarise_patterns(w,c('REGION','TYPE','BAND100','TIME_BAND'))
stage<-summarise_patterns(w,c('REGION','TYPE','BAND100'))
routes<-summarise_patterns(w,c('REGION','TYPE','BAND100','ADEP','ADES'))
tagged<-summarise_patterns(w,c('REGION','TYPE','BAND100','TAG_GROUP'))
a<-filter(w,TYPE=='A20N',BAND100==600)
modern<-filter(w,TYPE%in%c('A20N','A21N'),BAND100==600)
modern_summary<-summarise_patterns(modern,c('REGION','TYPE','BAND100'))
near<-w |>filter((TYPE=='A20N'&GCD_NM>=650&GCD_NM<700)|
  (TYPE=='A21N'&GCD_NM>=570&GCD_NM<600)) |>filter(DURATION_MIN>=3,DURATION_MIN<4)
near_summary<-summarise_patterns(near,c('REGION','TYPE')) |>
  mutate(GCD_SENSITIVITY_BAND=if_else(TYPE=='A20N','650-699 NM','570-599 NM'),DURATION_BAND='3 <= minutes < 4')
long_episode_counts<-a |>filter(DURATION_MIN>=5) |>count(REGION,LEVEL_N_20,name='N')
location<-segments |>filter(TYPE=='A20N',BAND100==600,REGION=='CHN',PROFILE_OK,LEVEL_SEC>=20) |>
  mutate(ALTITUDE_BAND_FT=floor(LEVEL_MID_ALT/1000)*1000) |>group_by(ADEP,ADES,ALTITUDE_BAND_FT) |>
  summarise(EPISODES=n(),FLIGHTS=n_distinct(SOURCE_UID),TAGGED_MIN=sum(LEVEL_SEC)/60,.groups='drop')

# Equal-size subsampling describes the fixed observed sample, not population CI.
set.seed(20261027)
chn_long<-a$DURATION_MIN[a$REGION=='CHN']>=5
eur_long<-a$DURATION_MIN[a$REGION=='EUR']>=5
draws<-replicate(5000,mean(sample(eur_long,length(chn_long),replace=FALSE)))
equal_n<-tibble(CHN_N=length(chn_long),EUR_N=length(eur_long),SUBSAMPLE_N=length(chn_long),
  CHN_LONG_SHARE=mean(chn_long),EUR_LONG_SHARE=mean(eur_long),DRAWS=length(draws),SEED=20261027,
  EUR_SUBSAMPLE_P025=unname(quantile(draws,.025)),EUR_SUBSAMPLE_P50=median(draws),EUR_SUBSAMPLE_P975=unname(quantile(draws,.975)))
direction<-routes |>filter(REGION=='CHN',TYPE=='A20N',BAND100==600,ADEP%in%c('ZSSS','ZLXY'),ADES%in%c('ZSSS','ZLXY'))
dout<-filter(direction,ADEP=='ZSSS');din<-filter(direction,ADEP=='ZLXY')
decomposition<-tibble(TYPE='A20N',GCD_NM=dout$GCD_MEAN,
  OUTBOUND_N=dout$N,INBOUND_N=din$N,TOTAL_TIME_GAP=dout$TIME_MEAN-din$TIME_MEAN,
  TAGGED_TIME_GAP=dout$LEVEL20_MEAN-din$LEVEL20_MEAN,REMAINDER_GAP=dout$REMAINDER_MEAN-din$REMAINDER_MEAN,
  TAGGED_FRACTION_OF_TIME_GAP=TAGGED_TIME_GAP/TOTAL_TIME_GAP,FUEL_MEAN_GAP=dout$FUEL_MEAN-din$FUEL_MEAN)
stopifnot(abs(decomposition$TOTAL_TIME_GAP-decomposition$TAGGED_TIME_GAP-decomposition$REMAINDER_GAP)<1e-7,
  length(unique(direction$GCD_MEAN))==1L,nrow(near_summary)==4L,all(near_summary$N>=30))

products<-list(modern_overview=modern_summary,duration_bands=duration,stage_bands=stage,
  routes=routes,source_tag_exposure=tagged,closer_distance_comparison=near_summary,
  long_window_episode_counts=long_episode_counts,chn_level_altitudes=location,
  equal_size_subsampling=equal_n,same_route_decomposition=decomposition)
for(name in names(products))write_csv(products[[name]],file.path(out,paste0(name,'.csv')))
write_parquet(w,file.path(restricted,'restricted-flight-window-patterns.parquet'))
write_parquet(filter(segments,LEVEL_SEC>0),file.path(restricted,'restricted-source-level-intersections.parquet'))
write_csv(select(cfg$manifest,PATH,SHA256),file.path(out,'input-manifest.csv'))
sources<-c('scripts/19-explore-climb-fuel-patterns.R','R/paper-climb-patterns.R',cfg$config_path,cfg$input_manifest,paper_reference_sources())
write_csv(tibble(PATH=sources,SHA256=vapply(sources,digest::digest,character(1),algo='sha256',file=TRUE)),file.path(out,'source-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))

theme_note<-theme_bw(base_size=10)+theme(legend.position='bottom',panel.grid.minor=element_blank())
cols<-c(CHN='#A33A32',EUR='#245C89')
p1<-ggplot(near,aes(FUEL_KG,color=REGION))+stat_ecdf(linewidth=.85)+
  facet_wrap(~TYPE,ncol=1,scales='free_x',labeller=as_labeller(c(A20N='A320neo: 650-699 NM',A21N='A321neo: 570-599 NM')))+
  scale_color_manual(values=cols,labels=c(CHN='China',EUR='Europe'))+
  labs(title='Fuel for similar climb times and closer sector distances',subtitle='FL100 to FL180; 3 <= traversal minutes < 4',
    x='Window fuel (kg)',y='Cumulative flight share',color=NULL)+theme_note
ggsave(file.path(out,'similar-time-fuel.png'),p1,width=7,height=6,dpi=180)
ggsave(file.path(out,'similar-time-fuel.pdf'),p1,width=7,height=6)
pdata<-direction |>transmute(ROUTE=if_else(ADEP=='ZSSS',"Shanghai to Xi'an\n(n = 94)","Xi'an to Shanghai\n(n = 93)"),
  `Source-tagged level time`=LEVEL20_MEAN,`Time outside tagged levels`=REMAINDER_MEAN) |>
  pivot_longer(-ROUTE,names_to='COMPONENT',values_to='MINUTES')
p2<-ggplot(pdata,aes(ROUTE,MINUTES,fill=factor(COMPONENT,levels=c('Source-tagged level time','Time outside tagged levels'))))+
  geom_col(width=.55)+scale_fill_manual(values=c('#A33A32','#91B0C5'))+
  labs(title='Different climb profiles on the same Chinese airport pair',
    subtitle='A320neo; FL100 to FL180; same 664 NM sector distance',x=NULL,y='Mean window duration (min)',fill=NULL)+
  theme_note+theme(legend.text=element_text(size=9))
ggsave(file.path(out,'same-route-time-components.png'),p2,width=7,height=4.6,dpi=180)
ggsave(file.path(out,'same-route-time-components.pdf'),p2,width=7,height=4.6)
p3<-ggplot(filter(a,REGION=='CHN'),aes(DURATION_MIN,FUEL_KG,color=LEVEL_SEC_20/60))+
  geom_point(size=2,alpha=.8)+scale_color_viridis_c(option='C')+
  labs(title='Longer traversals coincide with greater source-tagged level exposure',
    subtitle='Chinese A320neo sample; same 664 NM airport pair; both directions',
    x='FL100-FL180 duration (min)',y='Window fuel (kg)',color='Tagged level\ntime (min)')+theme_note
ggsave(file.path(out,'chn-time-fuel-level-exposure.png'),p3,width=7,height=4.8,dpi=180)
ggsave(file.path(out,'chn-time-fuel-level-exposure.pdf'),p3,width=7,height=4.8)
saveRDS(c(list(input_manifest=select(cfg$manifest,PATH,SHA256),
  source_fingerprint=read_csv(file.path(out,'source-manifest.csv'),show_col_types=FALSE),
  settings=list(analysis_id='PAPER-CLIMB-PATTERNS-2026-10-27-001',source_level_min_sec=c(20,60,120),
    source_endpoint_rate_max_fpm=300,minimum_percentile_n=30,duration_breaks=c(0,3,4,5,Inf),
    closer_A20N_gcd_nm=c(650,700),closer_A21N_gcd_nm=c(570,600),seed=20261027,subsampling_draws=5000),
  plots=list(similar_fuel=p1,route_components=p2,time_fuel_levels=p3)),products),file.path(restricted,'analysis.rds'))

# No input mutation, no identifier columns in exported aggregate CSVs.
stopifnot(all(cfg$manifest$SHA256==vapply(cfg$manifest$LOCAL_PATH,digest::digest,character(1),algo='sha256',file=TRUE)))
for(p in list.files(out,'[.]csv$',full.names=TRUE))stopifnot(!'SOURCE_UID'%in%names(read_csv(p,show_col_types=FALSE)))
cat('Closer-distance fuel comparison:\n');print(near_summary,width=180)
cat('Same-distance route decomposition:\n');print(decomposition,width=180)
cat('Long-window source episode counts:\n');print(long_episode_counts)
cat('Equal-size subsampling:\n');print(equal_n,width=180)
cat('Source-native associations only; canonical inputs unchanged. Snapshot:',out,'\n')
