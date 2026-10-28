source('R/paper-window-references.R')
stopifnot(all(is.na(paper_ref_q(c(1:29,NA,Inf)))),paper_ref_q(1:30)['P50']==15.5)
z <- data.frame(FUEL_OK=c(TRUE,FALSE,TRUE),TIME_OK=c(TRUE,TRUE,TRUE),
 DISTANCE_RATE_OK=c(FALSE,FALSE,TRUE),FUEL_KG=c(100,200,900),DURATION_MIN=c(1,10,20),FLOWN_NM=c(NA,10,100))
v <- paper_metric_values(z)
# Geometry/other-fuel failures cannot remove independently valid local quantities.
stopifnot(v$FUEL_KG[1]==100,is.na(v$KG_NM[1]),v$DURATION_MIN[2]==10,
 is.na(v$FUEL_KG[2]),v$KG_MIN[3]==45,v$KG_NM[3]==9)
# Individual-rate percentile, not a ratio of fuel/time percentiles.
stopifnot(paper_ref_q(c(100,100,900)/c(1,10,20),min_n=3)['P50']==45)
cat('Window-specific metric eligibility, percentile support and individual-rate quantiles passed.\n')
