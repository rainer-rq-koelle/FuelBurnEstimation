# Scientific accounting checks: altitude crossings, clipping and phase semantics.
source("R/enroute-level-exposure.R")
suppressPackageStartupMessages(library(dplyr))
eq <- function(a,b)stopifnot(isTRUE(all.equal(a,b,tolerance=1e-9)))
eq(enroute_band_seconds(0,600,35000,35000,120,420),c(0,0,0,300,0))
# A ramp crosses FL300 at 60 s and FL340 at 300 s; a clipped window retains
# exactly 120 s below FL340 and 180 s above it.
eq(enroute_band_seconds(0,600,29000,39000,180,480),c(0,0,120,180,0))
eq(enroute_band_seconds(0,600,39000,29000,120,420),c(0,0,120,180,0))
eq(enroute_band_seconds(0,600,35000,35000,700,900),numeric(5))
eq(enroute_band_seconds(0,600,34000,34000,0,600),c(0,0,0,600,0))
trace<-data.frame(TIME=c(0,300),T1=c(300,900),ALT_FT=c(29000,34000),H1=c(34000,34000))
integral<-enroute_integrate_trace(trace,0,900)
eq(integral$seconds,c(0,60,240,600,0))
eq(integral$known_seconds,900)
eq(integral$gap_seconds,600)
eq(enroute_integrate_trace(trace,0,900,max_gap=300)$seconds,c(0,60,240,0,0))
# Sparse sampled intervals beyond 300 seconds do not create a continuous level.
p <- data.frame(SOURCE_UID="test",TIME=c(0,60,120,600,660,720),ALT_FT=35000)
l <- enroute_m3_levels(p)
eq(l$DURATION_SEC,c(120,120))
eq(l$START_TIME,c(0,600))
eq(nrow(enroute_m3_levels(data.frame(SOURCE_UID="none",TIME=c(0,60,120),ALT_FT=c(1000,5000,10000)))),0L)
eq(nrow(enroute_m3_levels(data.frame(SOURCE_UID="short",TIME=c(0,60),ALT_FT=c(35000,35000)))),0L)
# A gradual step must not discard the preceding and following long plateaus.
p<-data.frame(SOURCE_UID="step",TIME=seq(0,1200,60),
  ALT_FT=c(rep(34000,6),seq(34200,36000,200),rep(36000,5)))
l<-enroute_m3_levels(p)
stopifnot(nrow(l)>=2,any(l$START_TIME==0),max(l$END_TIME)==1200)
# The shared rule uses physical level boundaries, not the 200 NM crossing time.
f <- data.frame(REGION="CHN",SOURCE_UID="test",dep_lat=0,dep_lon=0,arr_lat=0,arr_lon=10)
p <- data.frame(TIME=c(0,120,240,360,480,600,720,840,960),
                ALT_FT=c(1000,10000,35000,35000,35000,35000,35000,10000,1000),
                LAT=0,LON=c(0,1,2,3,5,7,8,9,10))
l <- data.frame(START_TIME=240,END_TIME=720,LEVEL_ALT_FT=35000)
b <- enroute_choose_boundaries(p,l,f)
eq(b$TOC_LEVEL,240);eq(b$TOD_LEVEL,720)
# Move the radius crossing within the same plateau; event times must not move.
p$LON[4] <- 4
b2 <- enroute_choose_boundaries(p,l,f)
eq(b2$TOC_LEVEL,240);eq(b2$TOD_LEVEL,720)
cat("Enroute exposure accounting and boundary tests passed.\n")
