source('R/paper-profile-classes.R')
cfg<-jsonlite::read_json('config/paper-profile-classes-2026-10-27.json',simplifyVector=TRUE)
spec<-cfg$feature_specs[cfg$feature_specs$SPEC==cfg$primary_spec,]
trace<-function(t,h)data.frame(T=head(t,-1),T1=tail(t,-1),H=head(h,-1),H1=tail(h,-1))
# Same physical trace has the same class irrespective of region or fuel metadata.
t<-seq(0,1200,60);h<-10000+pmin(t,120)*15+pmax(0,t-240)*15
z<-paper_profile_clip(trace(t,h),0,1200)
m<-paper_profile_measure(z,spec,TRUE,cfg)
stopifnot(m$PROFILE_CLASS=='Lightly interrupted',m$INTERRUPTION_N==1,m$LEVEL_SEC==120,m$LONGEST_SEC==120)
# No qualifying episode is distinct from an unobserved plateau in one long gap.
continuous<-paper_profile_measure(paper_profile_clip(trace(c(0,60,120),c(10000,12000,14000)),0,120),spec,TRUE,cfg)
gap<-paper_profile_measure(paper_profile_clip(trace(c(0,120),c(10000,10000)),0,120),spec,TRUE,cfg)
stopifnot(continuous$PROFILE_CLASS==paper_profile_labels[1],gap$PROFILE_CLASS=='Unknown',is.na(gap$INTERRUPTION_N))
coarse<-spec;coarse$MAX_GAP_SEC<-120
stopifnot(paper_profile_measure(paper_profile_clip(trace(c(0,120),c(10000,10000)),0,120),coarse,TRUE,cfg)$PROFILE_STATUS=='Insufficient intervals for episode')
stopifnot(paper_profile_measure(z,spec,TRUE,cfg,source_profile_ok=FALSE)$PROFILE_STATUS=='Source altitude support unavailable')
# Original bracketing gaps count even if only a short part overlaps the window.
clip<-paper_profile_clip(trace(c(-100,100,160),c(10000,10000,12000)),0,160)
stopifnot(clip$MAX_NATIVE_GAP_SEC==200,!paper_profile_measure(clip,spec,TRUE,cfg)$COVERAGE_OK)
# Exact class limits are inclusive for light; one exceedance is enough for heavy.
stopifnot(identical(paper_profile_class(c(0,2,3,1,1),c(0,180,180,201,181),rep(1000,5),c(0,180,100,120,181)),
 c(paper_profile_labels[1:2],rep(paper_profile_labels[3],3))))
stopifnot(paper_profile_class(1,200,1000,180)=='Lightly interrupted',
 paper_profile_class(1,200.1,1000,180)=='Heavily interrupted')
# Missing altitude cannot be bridged; short windows cannot become tautological continuous.
bad<-trace(c(0,60,120),c(10000,NA,14000))
stopifnot(paper_profile_measure(paper_profile_clip(bad,0,120),spec,TRUE,cfg)$PROFILE_CLASS=='Unknown',
 paper_profile_measure(paper_profile_clip(trace(c(0,30,60),c(10000,12000,14000)),0,60),spec,TRUE,cfg)$PROFILE_STATUS=='Window shorter than feature scale')
# Reversals are outside a monotone/level-interrupted taxonomy, rather than continuous.
rev<-paper_profile_measure(paper_profile_clip(trace(c(0,60,120),c(10000,9000,14000)),0,120),spec,TRUE,cfg)
stopifnot(rev$PROFILE_STATUS=='Material vertical reversal',rev$PROFILE_CLASS=='Unknown')
# Qualifying run duration is its intersection with this window; no borrowing outside.
ep<-paper_profile_episodes(paper_profile_clip(trace(c(0,60,120,180),rep(10000,4)),90,180),120,60)
stopifnot(nrow(ep)==0)
cat('Common physical rules, native-gap provenance, unknown coverage, feature scale, clipping, reversals and class boundaries passed.\n')
