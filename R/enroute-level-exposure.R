# Reconstructed pressure-altitude residence, with an independent sustained-level
# / 200-NM-context TOC/TOD sensitivity. No source releases are modified.
enroute_band_seconds <- function(start, end, alt_start, alt_end, from, to,
                                 breaks=c(0,24000,30000,34000,38000,Inf)) {
  answer <- numeric(length(breaks)-1L)
  if (!all(is.finite(c(start,end,alt_start,alt_end,from,to))) || end<=start || to<=from) return(answer)
  lo <- max(start,from); hi <- min(end,to)
  if (hi<=lo) return(answer)
  altitude <- function(t) alt_start+(alt_end-alt_start)*(t-start)/(end-start)
  cuts <- c(lo,hi)
  if (alt_end!=alt_start) {
    crossings <- start+(breaks[is.finite(breaks)]-alt_start)/(alt_end-alt_start)*(end-start)
    cuts <- sort(unique(c(cuts,crossings[crossings>lo & crossings<hi])))
  }
  bins <- findInterval(altitude((head(cuts,-1)+tail(cuts,-1))/2),breaks,rightmost.closed=TRUE)
  for (j in seq_along(bins)) if (bins[j]>=1 && bins[j]<=length(answer)) answer[bins[j]] <- answer[bins[j]]+diff(cuts)[j]
  answer
}

enroute_integrate_trace <- function(trace,from,to,max_gap=Inf,breaks=c(0,24000,30000,34000,38000,Inf)) {
  duration<-trace$T1-trace$TIME
  lo<-pmax(trace$TIME,from);hi<-pmin(trace$T1,to)
  ok<-is.finite(duration)&duration>0&duration<=max_gap&hi>lo&is.finite(trace$ALT_FT)&is.finite(trace$H1)
  z<-trace[ok,];lo<-lo[ok];hi<-hi[ok];duration<-duration[ok]
  a<-z$ALT_FT+(z$H1-z$ALT_FT)*(lo-z$TIME)/duration
  b<-z$ALT_FT+(z$H1-z$ALT_FT)*(hi-z$TIME)/duration
  span<-abs(b-a);dt<-hi-lo;low<-pmin(a,b);high<-pmax(a,b)
  seconds<-vapply(seq_len(length(breaks)-1L),function(k) {
    flat<-span==0&a>=breaks[k]&a<breaks[k+1]
    sum(dt[flat])+sum(dt[span>0]*pmax(0,pmin(high[span>0],breaks[k+1])-pmax(low[span>0],breaks[k]))/span[span>0])
  },numeric(1))
  list(seconds=seconds,altitude_integral=sum(dt*(a+b)/2),gap_seconds=sum(dt[duration>300]),known_seconds=sum(dt))
}

enroute_m3_levels <- function(points, max_gap_sec=300, min_level_sec=120, max_drift_ft=1000) {
  steps <- points |> dplyr::arrange(SOURCE_UID,TIME) |> dplyr::group_by(SOURCE_UID) |>
    dplyr::mutate(T1=dplyr::lead(TIME), H1=dplyr::lead(ALT_FT), DT=T1-TIME,
      QUALIFIED=dplyr::coalesce(DT>0 & DT<=max_gap_sec & ALT_FT>=3000 & H1>=3000 & abs(H1-ALT_FT)/DT*60<=300,FALSE),
      RUN=cumsum(QUALIFIED!=dplyr::lag(QUALIFIED,default=FALSE))) |> dplyr::ungroup()
  # Split a low-rate run when altitude span exceeds the plateau tolerance.
  # Rejecting the ENTIRE run would also discard long valid plateaus before or
  # after a slow step climb. Keep the original M3 knots for residence integration.
  groups <- split(dplyr::filter(steps,QUALIFIED),paste(steps$SOURCE_UID[steps$QUALIFIED],steps$RUN[steps$QUALIFIED]))
  empty<-tibble::tibble(SOURCE_UID=character(),START_TIME=double(),END_TIME=double(),
    START_ALT_FT=double(),END_ALT_FT=double(),DURATION_SEC=double(),LEVEL_ALT_FT=double(),
    ALT_SPAN_FT=double(),TRACE=list(),REGION=character(),LEVEL_ID=character())
  if(!length(groups))return(empty)
  output<-dplyr::bind_rows(lapply(groups,function(g) {
    chunks<-list(); start<-1L; low<-g$ALT_FT[1]; high<-low
    emit<-function(a,b) {
      if(b<a)return(NULL)
      z<-g[a:b,]
      if(sum(z$DT)<min_level_sec)return(NULL)
      data.frame(SOURCE_UID=g$SOURCE_UID[1],START_TIME=z$TIME[1],END_TIME=tail(z$T1,1),
        START_ALT_FT=z$ALT_FT[1],END_ALT_FT=tail(z$H1,1),DURATION_SEC=sum(z$DT),
        LEVEL_ALT_FT=sum(z$DT*(z$ALT_FT+z$H1)/2)/sum(z$DT),
        ALT_SPAN_FT=max(c(z$ALT_FT,z$H1))-min(c(z$ALT_FT,z$H1)),
        TRACE=I(list(z[,c("TIME","T1","ALT_FT","H1")])) )
    }
    for(j in seq_len(nrow(g))) {
      new_low<-min(low,g$ALT_FT[j],g$H1[j]);new_high<-max(high,g$ALT_FT[j],g$H1[j])
      if(new_high-new_low>max_drift_ft) {
        chunks[[length(chunks)+1L]]<-emit(start,j-1L)
        start<-j;low<-min(g$ALT_FT[j],g$H1[j]);high<-max(g$ALT_FT[j],g$H1[j])
        # A single step crossing more than the tolerance is a transition.
        if(high-low>max_drift_ft){start<-j+1L;low<-g$H1[j];high<-low}
      } else {low<-new_low;high<-new_high}
    }
    chunks[[length(chunks)+1L]]<-emit(start,nrow(g))
    dplyr::bind_rows(chunks)
  }))
  if(!nrow(output))return(empty)
  output |> dplyr::mutate(REGION="EUR",LEVEL_ID=paste0(SOURCE_UID,"-M3-",dplyr::row_number()))
}

enroute_choose_boundaries <- function(points, levels, flight) {
  # Use the entire airborne profile. Airport circles establish altitude context;
  # the actual boundaries are entry/exit of COMPLETE qualifying level intervals.
  points <- points[order(points$TIME),]
  levels <- levels[order(levels$START_TIME),]
  fail <- data.frame(REGION=flight$REGION,SOURCE_UID=flight$SOURCE_UID,
    TOC_LEVEL=NA_real_,TOD_LEVEL=NA_real_,DEP_CONTEXT="unavailable",ARR_CONTEXT="unavailable")
  if (!nrow(levels) || !nrow(points)) return(fail)
  gcd <- function(lat,lon,lat0,lon0) {
    rad<-pi/180; a<-sin((lat-lat0)*rad/2)^2+cos(lat*rad)*cos(lat0*rad)*sin((lon-lon0)*rad/2)^2
    3440.065*2*asin(sqrt(pmin(1,pmax(0,a))))
  }
  dep <- gcd(points$LAT,points$LON,flight$dep_lat,flight$dep_lon)
  arr <- gcd(points$LAT,points$LON,flight$arr_lat,flight$arr_lon)
  ceiling <- function(distance,departure) {
    outside <- which(is.finite(distance) & distance>200)
    limit <- if (length(outside)) if (departure) min(points$TIME[outside]) else max(points$TIME[outside]) else if (departure) Inf else -Inf
    context <- is.finite(distance) & distance<=200 & if(departure) points$TIME<limit else points$TIME>limit
    available <- any(context & is.finite(points$ALT_FT)) && length(outside)>0
    h <- if(available) max(points$ALT_FT[context],na.rm=TRUE) else max(points$ALT_FT,na.rm=TRUE)
    list(floor=h-max(1000,.03*h),method=if(available) "airport_200NM_context" else "airborne_ceiling_fallback")
  }
  departure <- ceiling(dep,TRUE); arrival <- ceiling(arr,FALSE)
  initial <- which(levels$LEVEL_ALT_FT>=departure$floor)
  final <- which(levels$LEVEL_ALT_FT>=arrival$floor)
  if(!length(initial)||!length(final)) return(fail)
  a<-levels$START_TIME[initial[1]]; b<-levels$END_TIME[tail(final,1)]
  # Physical climb/descent evidence; do not invent a zero-duration enroute phase.
  climb <- any(points$TIME<a & points$ALT_FT<levels$LEVEL_ALT_FT[initial[1]]-1000,na.rm=TRUE)
  descent <- any(points$TIME>b & points$ALT_FT<levels$LEVEL_ALT_FT[tail(final,1)]-1000,na.rm=TRUE)
  if(!climb||!descent||b<=a) return(fail)
  data.frame(REGION=flight$REGION,SOURCE_UID=flight$SOURCE_UID,TOC_LEVEL=a,TOD_LEVEL=b,
    DEP_CONTEXT=departure$method,ARR_CONTEXT=arrival$method)
}

build_enroute_exposure <- function(profiles, store=Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store")) {
  suppressPackageStartupMessages({library(dplyr);library(tidyr);library(arrow)})
  flights <- profiles$profiles |> filter(COMMON)
  chn_dir <- Sys.getenv("FUELBURN_PAPER_CHN_DIR",unset=file.path(store,"derived/chn/verification/CHN-2026-10-18-001/returned-batches"))
  level_files <- sort(list.files(chn_dir,"^CHN-level-segments.parquet$",recursive=TRUE,full.names=TRUE))
  milestone_files <- sort(list.files(chn_dir,"^CHN-canonical-milestones.parquet$",recursive=TRUE,full.names=TRUE))
  stopifnot(length(level_files)==14,length(milestone_files)==14)
  m3_files <- file.path(store,"raw/eur/source-sample",sprintf("m3-ctfm-2025-%02d.parquet",6:8))
  keys <- c("REGION","SOURCE_UID")
  chn_levels <- bind_rows(lapply(level_files,read_parquet)) |> mutate(REGION="CHN") |>
    semi_join(flights,by=keys) |> transmute(REGION,SOURCE_UID,LEVEL_ID=LEVEL_SEGMENT_ID,
      START_TIME=as.numeric(START_TIME),END_TIME=as.numeric(END_TIME),START_ALT_FT,END_ALT_FT,
      LEVEL_ALT_FT=(START_ALT_FT+END_ALT_FT)/2,DURATION_SEC=as.numeric(END_TIME-START_TIME),
      ALT_SPAN_FT=abs(END_ALT_FT-START_ALT_FT)) |>
    filter(is.finite(START_TIME),is.finite(END_TIME),DURATION_SEC>=120,ALT_SPAN_FT<=1000,
      is.finite(LEVEL_ALT_FT),LEVEL_ALT_FT>=3000,LEVEL_ALT_FT<=50000)
  chn_points <- bind_rows(lapply(milestone_files,function(p) read_parquet(p,col_select=c("SOURCE_UID","TIME","ALT_FT","LAT","LON")))) |>
    mutate(REGION="CHN",TIME=as.numeric(TIME)) |> semi_join(flights,by=keys)
  eur_points <- bind_rows(lapply(m3_files,function(p) read_parquet(p,col_select=c("FLIGHT_ID","TIME_OVER","FLIGHT_LEVEL","LATITUDE","LONGITUDE")))) |>
    transmute(REGION="EUR",SOURCE_UID=as.character(FLIGHT_ID),TIME=as.numeric(TIME_OVER),ALT_FT=as.numeric(FLIGHT_LEVEL)*100,LAT=LATITUDE,LON=LONGITUDE) |>
    semi_join(flights,by=keys)
  points <- bind_rows(chn_points,eur_points) |>
    inner_join(flights |> select(all_of(keys),TIME_ATOT,TIME_ALDT),by=keys) |>
    filter(TIME>=as.numeric(TIME_ATOT),TIME<=as.numeric(TIME_ALDT),is.finite(ALT_FT),ALT_FT>=0,ALT_FT<=50000) |>
    select(all_of(c(keys,"TIME","ALT_FT","LAT","LON"))) |> distinct()
  time_keys<-points[,c(keys,"TIME")]
  repeated<-duplicated(time_keys)|duplicated(time_keys,fromLast=TRUE)
  if(any(repeated))points<-bind_rows(points[!repeated,],points[repeated,] |>
    group_by(across(all_of(c(keys,"TIME")))) |>
    summarise(ALT_FT=median(ALT_FT),LAT=median(LAT,na.rm=TRUE),LON=median(LON,na.rm=TRUE),.groups="drop"))
  levels <- bind_rows(chn_levels,enroute_m3_levels(filter(points,REGION=="EUR"))) |>
    inner_join(flights |> select(all_of(keys),TIME_ATOT,TIME_ALDT),by=keys) |>
    filter(START_TIME>=as.numeric(TIME_ATOT),END_TIME<=as.numeric(TIME_ALDT)) |>
    select(-TIME_ATOT,-TIME_ALDT) |> arrange(REGION,SOURCE_UID,START_TIME,END_TIME)
  overlap <- levels |> group_by(across(all_of(keys))) |>
    summarise(OVERLAP=any(START_TIME<lag(cummax(END_TIME))-1e-6,na.rm=TRUE),.groups="drop")
  stopifnot(!any(overlap$OVERLAP))
  point_groups <- split(points,paste(points$REGION,points$SOURCE_UID))
  level_groups <- split(levels,paste(levels$REGION,levels$SOURCE_UID))
  alternative <- bind_rows(lapply(seq_len(nrow(flights)),function(i) {
    f<-flights[i,]; id<-paste(f$REGION,f$SOURCE_UID)
    p<-point_groups[[id]]; l<-level_groups[[id]]
    if(is.null(p))p<-points[0,];if(is.null(l))l<-levels[0,]
    enroute_choose_boundaries(p,l,f)
  }))
  boundaries <- flights |> left_join(alternative,by=keys) |>
    mutate(LEVEL_BOUNDARY_OK=is.finite(TOC_LEVEL)&is.finite(TOD_LEVEL)&TOD_LEVEL>TOC_LEVEL,
      TOC_SHIFT_MIN=(TOC_LEVEL-as.numeric(TIME_TOC))/60,
      TOD_SHIFT_MIN=(TOD_LEVEL-as.numeric(TIME_TOD))/60,
      DURATION_SHIFT_MIN=(TOD_LEVEL-TOC_LEVEL)/60-ENROUTE_MIN)
  windows <- bind_rows(
    boundaries |> transmute(REGION,SOURCE_UID,TYPE,BAND100,WINDOW="Source",FROM=as.numeric(TIME_TOC),TO=as.numeric(TIME_TOD)),
    boundaries |> filter(LEVEL_BOUNDARY_OK) |> transmute(REGION,SOURCE_UID,TYPE,BAND100,WINDOW="Level envelope",FROM=TOC_LEVEL,TO=TOD_LEVEL))
  labels <- c("<FL240","FL240-299","FL300-339","FL340-379",">=FL380")
  exposure <- bind_rows(lapply(seq_len(nrow(windows)),function(i) {
    w<-windows[i,]; id<-paste(w$REGION,w$SOURCE_UID);l<-level_groups[[id]]
    p<-point_groups[[id]];if(is.null(p))p<-points[0,];p<-p[order(p$TIME),]
    trace<-data.frame(TIME=head(p$TIME,-1),T1=tail(p$TIME,-1),ALT_FT=head(p$ALT_FT,-1),H1=tail(p$ALT_FT,-1))
    residence<-enroute_integrate_trace(trace,w$FROM,w$TO)
    resolved<-enroute_integrate_trace(trace,w$FROM,w$TO,max_gap=300)
    # Qualified intervals are disjoint and internally contiguous, so their
    # clipped union duration does not require reintegrating altitude knots.
    level_seconds<-if(is.null(l))0 else sum(pmax(0,pmin(l$END_TIME,w$TO)-pmax(l$START_TIME,w$FROM)))
    sec<-residence$seconds
    total<-w$TO-w$FROM;stopifnot(sum(sec)<=total+1e-5)
    data.frame(REGION=w$REGION,SOURCE_UID=w$SOURCE_UID,TYPE=w$TYPE,BAND100=w$BAND100,WINDOW=w$WINDOW,
      BAND=c(labels,"Unbracketed"),SECONDS=c(sec,pmax(0,total-sum(sec))),PHASE_SECONDS=total,
      RESOLVED_SECONDS=c(resolved$seconds,pmax(0,total-sum(resolved$seconds))),
      LEVEL_SECONDS=level_seconds,GAP_SECONDS=residence$gap_seconds,
      MEAN_ALT_FT=if(sum(sec)>0)residence$altitude_integral/sum(sec) else NA_real_)
  })) |> mutate(MINUTES=SECONDS/60,SHARE=SECONDS/PHASE_SECONDS,
    BAND=factor(BAND,levels=c(labels,"Unbracketed")))
  flight_metrics <- exposure |> group_by(REGION,SOURCE_UID,TYPE,BAND100,WINDOW) |>
    summarise(ENROUTE_MIN=first(PHASE_SECONDS)/60,MEAN_ALT_FT=first(MEAN_ALT_FT),
      LEVEL_MIN=first(LEVEL_SECONDS)/60,LEVEL_SHARE=first(LEVEL_SECONDS)/first(PHASE_SECONDS),
      KNOWN_SHARE=sum(SHARE[BAND!="Unbracketed"]),
      GAP_SHARE=first(GAP_SECONDS)/first(PHASE_SECONDS),
      HIGH_SHARE=sum(SHARE[BAND%in%c("FL340-379",">=FL380")]),.groups="drop")
  support <- flight_metrics |> count(TYPE,BAND100,WINDOW,REGION) |>
    pivot_wider(names_from=REGION,values_from=n,values_fill=0) |> mutate(COMMON=CHN>=30&EUR>=30)
  # Boundary sensitivity uses identical flights in both windows, not different
  # denominators that could turn cohort composition into an apparent rule effect.
  paired_ids <- boundaries |> filter(LEVEL_BOUNDARY_OK) |> select(all_of(keys))
  paired <- flight_metrics |> semi_join(paired_ids,by=keys)
  q <- function(x,p)if(any(is.finite(x)))unname(quantile(x[is.finite(x)],p,type=7))else NA_real_
  summarise_metrics <- function(x) x |> group_by(REGION,TYPE,BAND100,WINDOW) |>
    summarise(N=n(),ALTITUDE_N=sum(is.finite(MEAN_ALT_FT)),
      ENROUTE_P50=median(ENROUTE_MIN),LEVEL_MIN_P50=median(LEVEL_MIN),LEVEL_SHARE_P50=median(LEVEL_SHARE),
      MEAN_ALT_P20=q(MEAN_ALT_FT,.2),MEAN_ALT_P50=q(MEAN_ALT_FT,.5),MEAN_ALT_P80=q(MEAN_ALT_FT,.8),
      KNOWN_SHARE_P50=median(KNOWN_SHARE),GAP_SHARE_P50=median(GAP_SHARE),
      HIGH_SHARE_MEAN=mean(HIGH_SHARE),.groups="drop")
  summary <- summarise_metrics(flight_metrics)
  paired_summary <- summarise_metrics(paired)
  band_summary <- exposure |> group_by(REGION,TYPE,BAND100,WINDOW,BAND) |>
    summarise(N=n(),MEAN_MIN=mean(MINUTES),P20_MIN=q(MINUTES,.2),P50_MIN=q(MINUTES,.5),P80_MIN=q(MINUTES,.8),
      MEAN_SHARE=mean(SHARE),RESOLVED_MEAN_SHARE=mean(RESOLVED_SECONDS/PHASE_SECONDS),.groups="drop")
  boundary_summary <- boundaries |> group_by(REGION,TYPE,BAND100) |>
    summarise(N=n(),PAIRED_N=sum(LEVEL_BOUNDARY_OK),
      TOC_SHIFT_P50=q(TOC_SHIFT_MIN,.5),TOD_SHIFT_P50=q(TOD_SHIFT_MIN,.5),
      DURATION_SHIFT_P50=q(DURATION_SHIFT_MIN,.5),
      TOC_WITHIN_60S=sum(abs(TOC_SHIFT_MIN)<=1,na.rm=TRUE),TOD_WITHIN_60S=sum(abs(TOD_SHIFT_MIN)<=1,na.rm=TRUE),.groups="drop")
  stopifnot(all(abs((exposure |> group_by(REGION,SOURCE_UID,WINDOW) |> summarise(s=sum(SHARE),.groups="drop"))$s-1)<1e-8))
  inputs<-c(level_files,m3_files)
  list(exposure=exposure,flight_metrics=flight_metrics,boundaries=boundaries,summary=summary,
    paired_summary=paired_summary,band_summary=band_summary,boundary_summary=boundary_summary,support=support,
    provenance=tibble::tibble(PATH=inputs,SHA256=vapply(inputs,digest::digest,character(1),algo="sha256",file=TRUE)))
}

plot_enroute_exposure <- function(x) {
  data <- x$band_summary |> dplyr::filter(WINDOW=="Source") |>
    dplyr::mutate(CELL=paste(TYPE,paste0(BAND100,"-",BAND100+99),REGION))
  ggplot2::ggplot(data,ggplot2::aes(100*MEAN_SHARE,CELL,fill=BAND)) +
    ggplot2::geom_col(width=.75) + ggplot2::scale_fill_manual(values=c("#C7DCEB","#85B8D7","#468CB9","#245C89","#17324D","#D6D6D6"),drop=FALSE) +
    ggplot2::scale_x_continuous(limits=c(0,100),expand=ggplot2::expansion(mult=c(0,.01))) +
    ggplot2::labs(x="Mean flight share of TOC-TOD time (%)",y=NULL,fill=NULL) +
    ggplot2::theme_bw(base_size=8) + ggplot2::theme(legend.position="bottom",legend.text=ggplot2::element_text(size=6),panel.grid.minor=ggplot2::element_blank()) +
    ggplot2::guides(fill=ggplot2::guide_legend(nrow=2,byrow=TRUE))
}
