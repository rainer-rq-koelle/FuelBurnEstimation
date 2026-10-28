#!/usr/bin/env Rscript
# Review the offline aggregates and extend only analysis-derived lookup views.
# Source products, eligibility, and the manuscript are read-only here.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(arrow);library(ggplot2)})
source('R/paper-window-references.R')
x<-load_paper_window_references();cfg<-x$config
source('R/paper-profile-classes.R')
pc<-load_paper_profile_classes()
batch<-'outputs/offline-paper-2026-10-28-001'
out<-'notes/results/descent-enroute-lookup-2026-10-28'
restricted<-file.path(cfg$store,'derived/paper/descent-enroute-lookup/PAPER-LOOKUP-2026-10-28-001')
dir.create(out,recursive=TRUE,showWarnings=FALSE);dir.create(restricted,recursive=TRUE,showWarnings=FALSE)
manifest<-read_csv(file.path(batch,'product-manifest.csv'),show_col_types=FALSE)
stopifnot(all(manifest$SHA256==vapply(file.path(batch,manifest$FILE),digest::digest,character(1),algo='sha256',file=TRUE)))
stopifnot(jsonlite::read_json(file.path(batch,'status.json'))$state=='complete')
mapping<-read_csv(file.path(batch,'type_mapping.csv'),show_col_types=FALSE)
stopifnot(!anyDuplicated(mapping$TYPE))
gcd_group<-function(v)as.character(cut(v,c(0,300,500,700,1000,Inf),right=FALSE,
  labels=c('0-<300','300-<500','500-<700','700-<1000','>=1000')))
q<-function(v,p){v<-v[is.finite(v)];if(length(v)<30)NA_real_ else unname(quantile(v,p,type=7))}
avg<-function(v){v<-v[is.finite(v)];if(length(v))mean(v)else NA_real_}
# Ground window rows retain BAND100 but omit GCD_NM in the adopted adapter.
# Join the existing flight metadata; never turn a missing stratum into a paired
# distance group, and do not modify the underlying adapter or source products.
meta<-x$flights |>select(REGION,SOURCE_UID,FLIGHT_GCD_NM=GCD_NM,FLIGHT_TYPE=TYPE)
w<-paper_metric_values(x$windows) |>left_join(meta,by=c('REGION','SOURCE_UID'))
stopifnot(all(w$TYPE==w$FLIGHT_TYPE),all(is.finite(w$FLIGHT_GCD_NM)),
  all(abs(w$GCD_NM-w$FLIGHT_GCD_NM)<1e-7,na.rm=TRUE))
metadata_join_audit<-w |>group_by(REGION,WINDOW) |>
  summarise(ROWS=n(),MISSING_WINDOW_GCD=sum(!is.finite(GCD_NM)),.groups='drop')
w<-w |>mutate(GCD_NM=FLIGHT_GCD_NM,GCD_GROUP=gcd_group(GCD_NM)) |>left_join(mapping,by='TYPE')
stopifnot(!anyNA(w$GCD_GROUP),!anyNA(w$FLEET))
metrics<-c('FUEL_KG','DURATION_MIN','KG_MIN','KG_NM','FLOWN_NM')
summarise_metrics<-function(data,keys)bind_rows(lapply(metrics,function(metric)data |>
  group_by(across(all_of(keys))) |>summarise(OPPORTUNITIES=n(),N=sum(is.finite(.data[[metric]])),
    MEAN=avg(.data[[metric]]),P20=q(.data[[metric]],.2),P50=q(.data[[metric]],.5),P80=q(.data[[metric]],.8),.groups='drop') |>
  mutate(METRIC=metric,STATUS=case_when(N==0~'No eligible observations',N<30~'Sparse: percentiles suppressed',TRUE~'Populated'))))
keys<-c('REGION','TYPE','FLEET','GCD_GROUP','WINDOW','PROFILE_AXIS','PROFILE_CLASS')
pair_support<-function(grid,key=keys)grid |>select(all_of(setdiff(key,'REGION')),METRIC,REGION,N) |>
  pivot_wider(names_from=REGION,values_from=N,values_fill=0) |>mutate(PAIRED_SUPPORT=CHN>=30&EUR>=30)
add_pairs<-function(grid,key=keys)grid |>left_join(pair_support(grid,key) |>select(-CHN,-EUR),
  by=c(setdiff(key,'REGION'),'METRIC'))

# Current marginal lookup, exact-type before any fleet pooling.
marginal<-w |>mutate(PROFILE_AXIS='Marginal baseline',PROFILE_CLASS='All profiles')
lookup<-add_pairs(summarise_metrics(marginal,keys))
reconcile<-lookup |>group_by(REGION,WINDOW,METRIC) |>summarise(N=sum(N),.groups='drop') |>
  inner_join(x$overview |>select(REGION,WINDOW,METRIC,BASE_N=N),by=c('REGION','WINDOW','METRIC'))
stopifnot(nrow(reconcile)==nrow(x$overview),all(reconcile$N==reconcile$BASE_N))

# The cached common enroute cohort has actual residence reconstruction. Retain
# that narrower cohort explicitly, rather than claiming all broad-band flights.
alt<-x$enroute$flight_metrics |>filter(WINDOW=='Source') |>
  select(REGION,SOURCE_UID,MEAN_ALT_FT,KNOWN_SHARE,GAP_SHARE,HIGH_SHARE)
stopifnot(!anyDuplicated(alt[,c('REGION','SOURCE_UID')]))
en<-w |>filter(WINDOW=='Enroute source window') |>inner_join(alt,by=c('REGION','SOURCE_UID')) |>
  mutate(PROFILE_AXIS='Source-window time-weighted mean pressure altitude',
    PROFILE_CLASS=case_when(!is.finite(MEAN_ALT_FT)~'Altitude unobserved',MEAN_ALT_FT<30000~'Below FL300',
      MEAN_ALT_FT<34000~'FL300-339',TRUE~'FL340+'))
alt_grid<-add_pairs(summarise_metrics(en,keys))
alt_exact<-add_pairs(summarise_metrics(en,c(keys,'BAND100')),c(keys,'BAND100'))
en_composition<-en |>group_by(REGION,TYPE,GCD_GROUP,PROFILE_CLASS) |>
  summarise(N=n(),FUEL_N=sum(is.finite(FUEL_KG)),KG_NM_N=sum(is.finite(KG_NM)),ALT_MEAN=avg(MEAN_ALT_FT),
    GAP_SHARE_MEAN=avg(GAP_SHARE),DURATION_P50=q(DURATION_MIN,.5),FLOWN_NM_P50=q(FLOWN_NM,.5),
    KG_NM_P20=q(KG_NM,.2),KG_NM_P50=q(KG_NM,.5),KG_NM_P80=q(KG_NM,.8),.groups='drop')

# Source tags are within-source positive evidence, not a common class detector.
read_role<-function(name)bind_rows(lapply(cfg$manifest$LOCAL_PATH[basename(cfg$manifest$LOCAL_PATH)==name],read_parquet))
levels<-bind_rows(read_role('CHN-level-segments.parquet') |>mutate(REGION='CHN'),
  read_role('EUR-level-segments-parallel.parquet') |>mutate(REGION='EUR')) |>
  transmute(REGION,SOURCE_UID,L_START=as.numeric(START_TIME),L_END=as.numeric(END_TIME),START_ALT_FT,END_ALT_FT) |>
  filter(is.finite(L_START),is.finite(L_END),L_END>L_START,is.finite(START_ALT_FT),is.finite(END_ALT_FT),
    abs(END_ALT_FT-START_ALT_FT)/(L_END-L_START)*60<=300)
overlaps<-levels |>arrange(REGION,SOURCE_UID,L_START,L_END) |>group_by(REGION,SOURCE_UID) |>
  summarise(BAD=any(L_START<lag(cummax(L_END))-1e-6,na.rm=TRUE),.groups='drop')
stopifnot(!any(overlaps$BAD))
z<-w |>filter(WINDOW%in%cfg$core_windows,TIME_OK,coalesce(PROFILE_OK,FALSE)) |>
  mutate(A=as.numeric(START_TIME),B=as.numeric(END_TIME))
seg<-z |>left_join(levels,by=join_by(REGION,SOURCE_UID,A<L_END,B>L_START),relationship='many-to-many') |>
  mutate(CLIP_START=pmax(A,L_START),CLIP_END=pmin(B,L_END),LEVEL_SEC=coalesce(pmax(0,CLIP_END-CLIP_START),0))
tag<-seg |>group_by(REGION,SOURCE_UID,WINDOW) |>
  summarise(TAGGED_SECONDS=sum(LEVEL_SEC[LEVEL_SEC>=20]),LEVEL_N=sum(LEVEL_SEC>=20),
    LONGEST_SEC=max(c(0,LEVEL_SEC[LEVEL_SEC>=20])),.groups='drop') |>
  rename(LEVEL_SEC=TAGGED_SECONDS)
z<-z |>left_join(tag,by=c('REGION','SOURCE_UID','WINDOW')) |>
  mutate(LEVEL_MIN=LEVEL_SEC/60,LEVEL_SHARE=LEVEL_SEC/(DURATION_MIN*60),
    LEVEL_GROUP=case_when(LEVEL_SEC==0~'No >=20s source tag',LEVEL_SEC<=60~'>0-1 min',LEVEL_SEC<=120~'>1-2 min',
      LEVEL_SEC<=300~'>2-5 min',TRUE~'>5 min'),
    TIME_GROUP=as.character(cut(DURATION_MIN,c(0,5,6,7,8,10,15,Inf),right=FALSE,
      labels=c('<5','5-<6','6-<7','7-<8','8-<10','10-<15','>=15'))))
stopifnot(all(z$LEVEL_SEC<=z$DURATION_MIN*60+1e-5),all(z$LONGEST_SEC<=z$LEVEL_SEC+1e-5),
  sum(z$LEVEL_N)==sum(seg$LEVEL_SEC>=20),
  abs(sum(z$LEVEL_SEC)-sum(seg$LEVEL_SEC[seg$LEVEL_SEC>=20]))<1e-5)
level_summary<-function(data,ks)data |>group_by(across(all_of(ks))) |>
  summarise(N=n(),FUEL_N=sum(is.finite(FUEL_KG)),FUEL_P20=q(FUEL_KG,.2),FUEL_P50=q(FUEL_KG,.5),FUEL_P80=q(FUEL_KG,.8),
    FUEL_MEAN=avg(FUEL_KG),TIME_P50=q(DURATION_MIN,.5),TIME_MEAN=avg(DURATION_MIN),
    LEVEL_P50=q(LEVEL_MIN,.5),LEVEL_MEAN=avg(LEVEL_MIN),LEVEL_SHARE_P50=q(LEVEL_SHARE,.5),
    TAGGED_N=sum(LEVEL_N>0),MULTIPLE_N=sum(LEVEL_N>=2),LONGEST_P50=q(LONGEST_SEC/60,.5),
    GCD_MEAN=avg(GCD_NM),.groups='drop')
level_keys<-c('REGION','TYPE','GCD_GROUP','WINDOW')
level_grid<-level_summary(z,c(level_keys,'LEVEL_GROUP'))
time_grid<-level_summary(z,c(level_keys,'TIME_GROUP'))
time_exact<-level_summary(z,c(level_keys,'BAND100','TIME_GROUP'))
route_grid<-level_summary(z,c(level_keys,'ADEP','ADES','LEVEL_GROUP'))
thresholds<-bind_rows(lapply(c(2,5),function(t)z |>mutate(CUT_MIN=t,EXPOSURE=if_else(LEVEL_MIN>t,paste0('>',t,' min'),paste0('<=',t,' min'))) |>
  level_summary(c(level_keys,'CUT_MIN','EXPOSURE'))))
source_criteria<-z |>group_by(across(all_of(level_keys))) |>
  summarise(N=n(),NO_TAG=sum(LEVEL_N==0),ONE_TAG=sum(LEVEL_N==1),MULTIPLE_TAGS=sum(LEVEL_N>=2),
    COUNT_GE3=sum(LEVEL_N>=3),SHARE_GT20=sum(LEVEL_SHARE>.2),LONGEST_GT180=sum(LONGEST_SEC>180),
    TOTAL_GT2=sum(LEVEL_MIN>2),TOTAL_GT5=sum(LEVEL_MIN>5),DURATION_GE5=sum(DURATION_MIN>=5),.groups='drop')
# These are not fixed-coverage common classes. Report the raw conditions rather
# than borrowing the continuous/light/heavy labels from the native-point model.
tag_lookup<-z |>mutate(PROFILE_AXIS='Source-native tagged time; source-specific detector',PROFILE_CLASS=LEVEL_GROUP)
tag_lookup<-add_pairs(summarise_metrics(tag_lookup,keys)) |>
  mutate(PAIRED_SUPPORT=FALSE,STATUS=if_else(N>=30,'Source-specific reference; common class not assigned',STATUS))
compact_tag_lookup<-z |>mutate(PROFILE_AXIS='Source-native tagged time; compact exposure bins',
  PROFILE_CLASS=case_when(LEVEL_MIN<=2~'<=2 min',LEVEL_MIN<=5~'>2-5 min',TRUE~'>5 min')) |>
  summarise_metrics(keys) |>add_pairs() |>
  mutate(PAIRED_SUPPORT=FALSE,STATUS=if_else(N>=30,'Source-specific reference; common class not assigned',STATUS))
duration_lookup<-z |>mutate(PROFILE_AXIS='Traversal duration; not interruption class',PROFILE_CLASS=TIME_GROUP)
duration_lookup<-add_pairs(summarise_metrics(duration_lookup,keys))
lower_time_check<-z |>filter(WINDOW=='Descent FL100-FL075',DURATION_MIN>=2,DURATION_MIN<3) |>
  level_summary(c(level_keys,'BAND100'))

# EUR sector-group context uses independent phase support (including source-zero
# enroute durations explicitly), rather than removing short profiles globally.
context<-w |>filter(WINDOW%in%c('Climb source window','Enroute source window','Descent source window')) |>
  group_by(REGION,TYPE,GCD_GROUP,WINDOW) |>summarise(INPUT=n(),TIME_N=sum(TIME_OK),
    SOURCE_ZERO_N=sum(is.finite(as.numeric(END_TIME)-as.numeric(START_TIME))&as.numeric(END_TIME)==as.numeric(START_TIME)),
    DURATION_P20=q(DURATION_MIN,.2),DURATION_P50=q(DURATION_MIN,.5),DURATION_P80=q(DURATION_MIN,.8),
    AIR_SHARE_P50=q(DURATION_MIN/SOURCE_AIR_MIN,.5),.groups='drop')

reserved<-lookup |>filter(WINDOW%in%cfg$core_windows,METRIC=='FUEL_KG',PAIRED_SUPPORT) |>
  select(REGION,TYPE,FLEET,GCD_GROUP,WINDOW) |>distinct() |>
  crossing(PROFILE_CLASS=c('Continuous at stated scale','Lightly interrupted','Heavily interrupted'),METRIC=metrics) |>
  mutate(PROFILE_AXIS='Common native-point interruption class; 120s feature / 60s gap',OPPORTUNITIES=NA_integer_,
    N=NA_integer_,MEAN=NA_real_,P20=NA_real_,P50=NA_real_,P80=NA_real_,PAIRED_SUPPORT=FALSE,
    STATUS='Reserved; no adopted paired class reference')
lookup_all<-bind_rows(lookup,alt_grid,duration_lookup,tag_lookup,compact_tag_lookup,reserved)
stopifnot(!anyDuplicated(lookup_all[,c(keys,'METRIC')]),all(is.na(lookup_all$P50[lookup_all$N<30])))
metadata<-w |>distinct(REGION,WINDOW,FAMILY,BOUNDARY_SCHEME,FUEL_SOURCE,FUEL_CONVENTION,DISTANCE_BASIS,ENGINE_GROUP)
lookup_all<-lookup_all |>left_join(metadata,by=c('REGION','WINDOW')) |>
  mutate(INPUT_RELEASE=cfg$analysis_id,REFERENCE_STATUS=if_else(is.na(N),'Reserved; no estimated reference',
    'Descriptive observed distributions; no inferred saving'))
lookup_wide<-lookup_all |>select(-OPPORTUNITIES) |>pivot_wider(names_from=METRIC,
  values_from=c(N,MEAN,P20,P50,P80,STATUS,PAIRED_SUPPORT))
support<-lookup_all |>filter(PAIRED_SUPPORT) |>group_by(PROFILE_AXIS,WINDOW,METRIC) |>
  summarise(PAIRED_CELLS=n()/2,CHN_N=sum(N[REGION=='CHN']),EUR_N=sum(N[REGION=='EUR']),.groups='drop')
alt_contrasts<-alt_exact |>filter(METRIC=='KG_NM',PAIRED_SUPPORT) |>
  select(TYPE,BAND100,PROFILE_CLASS,REGION,N,P20,P50,P80) |>
  pivot_wider(names_from=REGION,values_from=c(N,P20,P50,P80)) |>
  mutate(CENTRAL_OVERLAP_LOW=pmax(P20_CHN,P20_EUR),CENTRAL_OVERLAP_HIGH=pmin(P80_CHN,P80_EUR),
    CENTRAL_OVERLAP_WIDTH=pmax(0,CENTRAL_OVERLAP_HIGH-CENTRAL_OVERLAP_LOW),
    MEDIAN_CHN_OVER_EUR=P50_CHN/P50_EUR)
exact_wide<-alt_exact |>left_join(metadata,by=c('REGION','WINDOW')) |>select(-OPPORTUNITIES) |>
  pivot_wider(names_from=METRIC,values_from=c(N,MEAN,P20,P50,P80,STATUS,PAIRED_SUPPORT))
technology<-alt_exact |>filter(METRIC=='KG_NM',TYPE%in%c('A20N','A320'),BAND100==600,PROFILE_CLASS=='FL300-339',N>=30) |>
  select(REGION,TYPE,N,P20,P50,P80) |>pivot_wider(names_from=TYPE,values_from=c(N,P20,P50,P80)) |>
  mutate(NEWER_MEDIAN_RELATIVE_TO_OLDER=P50_A20N/P50_A320,
    NEWER_MEDIAN_PERCENT_LOWER=100*(1-NEWER_MEDIAN_RELATIVE_TO_OLDER),BAND100=600,PROFILE_CLASS='FL300-339')
compatibility<-w |>filter(WINDOW%in%cfg$core_windows,TIME_OK) |>
  group_by(REGION,WINDOW) |>summarise(TIME_N=n(),DURATION_P50=q(DURATION_MIN,.5),
    AT_LEAST_TEN_MIN_N=sum(DURATION_MIN>=10),AT_LEAST_TEN_MIN_SHARE=mean(DURATION_MIN>=10),.groups='drop') |>
  mutate(MINIMUM_LIGHT_WINDOW_MIN=120/.2/60,
    RULE='A 120s episode can meet a <=20% share only when window duration is >=10 min')
near<-en |>filter((TYPE=='A20N'&GCD_NM>=650&GCD_NM<700)|
  (TYPE=='A21N'&GCD_NM>=570&GCD_NM<600))
near_enroute<-summarise_metrics(near,c(keys,'BAND100'))
near_descent<-z |>filter((TYPE=='A20N'&GCD_NM>=650&GCD_NM<700)|
  (TYPE=='A21N'&GCD_NM>=570&GCD_NM<600)) |>
  level_summary(c(level_keys,'BAND100','TIME_GROUP'))
products<-list(lookup_grid=lookup_all,lookup_wide=lookup_wide,paired_support=support,
  altitude_conditioned_enroute=alt_grid,altitude_conditioned_enroute_exact=alt_exact,enroute_altitude_composition=en_composition,
  enroute_exact_cell_contrasts=alt_contrasts,closer_distance_enroute=near_enroute,closer_distance_descent=near_descent,
  lookup_exact_enroute_wide=exact_wide,lower_descent_two_three_minutes=lower_time_check,
  primary_common_class_support=pc$support |>filter(SPEC==pc$config$primary_spec),
  modern_older_same_altitude=technology,feature_share_compatibility=compatibility,
  descent_level_groups=filter(level_grid,startsWith(WINDOW,'Descent')),
  fine_window_time_groups=time_grid,fine_window_time_groups_exact=time_exact,
  fine_window_level_thresholds=thresholds,fine_window_source_criteria=source_criteria,
  fine_window_route_level_groups=route_grid,phase_sector_context=context,
  window_flight_metadata_join=metadata_join_audit)
for(n in names(products)){
  stopifnot(!'SOURCE_UID'%in%names(products[[n]]));write_csv(products[[n]],file.path(out,paste0(n,'.csv')))
}
write_parquet(z,file.path(restricted,'restricted-fine-window-levels.parquet'))
write_parquet(en,file.path(restricted,'restricted-enroute-altitude-fuel.parquet'))

# Result figures use central descriptive ranges, not confidence intervals.
cols<-c(CHN='#A33A32',EUR='#245C89')
theme_note<-theme_bw(base_size=11)+theme(legend.position='bottom',panel.grid.minor=element_blank())
dg<-level_grid |>filter(TYPE%in%c('A20N','A21N'),GCD_GROUP=='500-<700',WINDOW=='Descent FL180-FL100',FUEL_N>=30) |>
  mutate(LEVEL_GROUP=factor(LEVEL_GROUP,levels=c('No >=20s source tag','>0-1 min','>1-2 min','>2-5 min','>5 min')))
p<-ggplot(dg,aes(LEVEL_GROUP,FUEL_P50,color=REGION))+geom_linerange(aes(ymin=FUEL_P20,ymax=FUEL_P80),
  position=position_dodge(width=.5))+geom_point(position=position_dodge(width=.5),size=2)+
  facet_wrap(~TYPE,ncol=1)+scale_color_manual(values=cols)+theme_note+
  labs(x='Total source-tagged level time in FL180-100 (source-specific detectors)',y='Descent fuel kg: P20 / P50 / P80',color=NULL)+
  theme(axis.text.x=element_text(size=9))
ggsave(file.path(out,'descent-level-time-fuel.png'),p,width=9,height=7,dpi=170)
ggsave(file.path(out,'descent-level-time-fuel.pdf'),p,width=9,height=7)
ag<-alt_exact |>filter(METRIC=='KG_NM',PAIRED_SUPPORT) |>
  mutate(CELL=paste(TYPE,paste0(BAND100,'-',BAND100+99),'NM',PROFILE_CLASS))
p<-ggplot(ag,aes(P50,CELL,color=REGION))+geom_linerange(aes(xmin=P20,xmax=P80),
  orientation='y',position=position_dodge(width=.5))+geom_point(position=position_dodge(width=.5),size=2)+
  scale_color_manual(values=cols)+theme_note+labs(x='Enroute kg per flown NM: P20 / P50 / P80',y=NULL,color=NULL)
ggsave(file.path(out,'enroute-altitude-conditioned-kg-nm.png'),p,width=9,height=5,dpi=170)
ggsave(file.path(out,'enroute-altitude-conditioned-kg-nm.pdf'),p,width=9,height=5)
cx<-context |>filter(REGION=='EUR',TYPE%in%c('A20N','A21N'),WINDOW=='Enroute source window') |>
  mutate(GCD_GROUP=factor(GCD_GROUP,levels=c('0-<300','300-<500','500-<700','700-<1000','>=1000')))
p<-ggplot(cx,aes(GCD_GROUP,DURATION_P50,color=TYPE,group=TYPE))+
  geom_linerange(aes(ymin=DURATION_P20,ymax=DURATION_P80),position=position_dodge(width=.15))+
  geom_point(position=position_dodge(width=.15),size=2)+theme_note+
  labs(x='Airport GCD group (NM)',y='EUR source enroute minutes: P20 / P50 / P80',color='Aircraft')
ggsave(file.path(out,'sector-groups-enroute-duration.png'),p,width=8,height=4.8,dpi=170)
ggsave(file.path(out,'sector-groups-enroute-duration.pdf'),p,width=8,height=4.8)
invisible(paper_ref_config())
invisible(load_paper_profile_classes())
paths<-unique(c('scripts/21-review-descent-enroute-lookup.R',cfg$config_path,cfg$input_manifest,paper_reference_sources(),
  file.path(cfg$output,'analysis.rds'),file.path(batch,'product-manifest.csv'),
  'R/paper-profile-classes.R','config/paper-profile-classes-2026-10-27.json',file.path(pc$config$output,'analysis.rds'),
  file.path(out,'README.md')))
write_csv(tibble(PATH=paths,SHA256=vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE)),file.path(out,'source-manifest.csv'))
write_csv(select(cfg$manifest,PATH,SHA256),file.path(out,'input-manifest.csv'))
write_csv(pc$input_manifest |>select(-any_of('LOCAL_PATH')),file.path(out,'profile-input-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
saveRDS(products,file.path(restricted,'analysis.rds'))
files<-list.files(out,pattern='\\.(csv|png|pdf|md|txt)$',full.names=TRUE)
files<-files[basename(files)!='product-manifest.csv']
write_csv(tibble(FILE=basename(files),SHA256=vapply(files,digest::digest,character(1),algo='sha256',file=TRUE)),
  file.path(out,'product-manifest.csv'))
print(support |>filter(METRIC%in%c('FUEL_KG','KG_NM'),WINDOW%in%c(cfg$core_windows,'Enroute source window')),n=60)
cat('Review aggregates:',out,'\n')
