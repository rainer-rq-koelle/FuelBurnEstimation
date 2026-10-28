# Common research definitions over supplied native altitude-time knots.
# No source detector labels enter classification; unknown is never continuous.
paper_profile_labels <- c('Continuous at stated scale','Lightly interrupted','Heavily interrupted','Unknown')

paper_profile_class <- function(n, seconds, duration, longest, eligible=TRUE,
                               max_n=2, max_share=.20, max_longest=180) {
  out <- rep('Unknown',length(n))
  valid <- eligible & is.finite(n) & is.finite(seconds) & is.finite(duration) &
    duration>0 & is.finite(longest)
  out[valid & n==0] <- paper_profile_labels[1]
  light <- valid & n>0 & n<=max_n & seconds/duration<=max_share+1e-10 & longest<=max_longest+1e-7
  out[light] <- paper_profile_labels[2]
  out[valid & n>0 & !light] <- paper_profile_labels[3]
  out
}

paper_profile_clip <- function(trace, from, to, direction=1, rate_limit=300) {
  empty <- list(ORDERED=FALSE,DURATION_SEC=to-from,BRACKETED_SEC=0,
    ALTITUDE_KNOWN_SEC=0,MAX_NATIVE_GAP_SEC=Inf,REVERSE_PROGRESS_FT=NA_real_,steps=NULL)
  if(!all(is.finite(c(from,to))) || to<=from)return(empty)
  empty$ORDERED <- TRUE
  z <- trace[trace$T<to & trace$T1>from,,drop=FALSE]
  if(!nrow(z))return(empty)
  gap <- z$T1-z$T
  left <- pmax(z$T,from);right <- pmin(z$T1,to);dt <- right-left
  a <- z$H+(z$H1-z$H)*(left-z$T)/gap
  b <- z$H+(z$H1-z$H)*(right-z$T)/gap
  known <- is.finite(a)&is.finite(b)&gap>0
  rate <- (b-a)/dt*60
  list(ORDERED=TRUE,DURATION_SEC=to-from,BRACKETED_SEC=sum(dt),
    ALTITUDE_KNOWN_SEC=sum(dt[known]),MAX_NATIVE_GAP_SEC=max(gap),
    REVERSE_PROGRESS_FT=sum(abs(b-a)[known & direction*rate < -rate_limit]),
    steps=data.frame(T=left,T1=right,H=a,H1=b,DT=dt,GAP=gap,RATE=rate,KNOWN=known))
}

paper_profile_episodes <- function(clip, min_level_sec, max_gap_sec, rate_limit=300, min_intervals=2L) {
  z <- clip$steps
  empty <- data.frame(START=double(),END=double(),DURATION_SEC=double(),NATIVE_INTERVALS=integer(),
    MEAN_ALT_FT=double(),MIN_ALT_FT=double(),MAX_ALT_FT=double(),LEFT_CENSORED=logical(),RIGHT_CENSORED=logical())
  if(is.null(z)||!nrow(z))return(empty)
  ok <- z$KNOWN & z$GAP<=max_gap_sec+1e-7 & abs(z$RATE)<=rate_limit+1e-7
  ok[is.na(ok)] <- FALSE
  # Gaps and non-level motion break episodes. Never join across an unknown span.
  runs <- rle(ok);end <- cumsum(runs$lengths);start <- end-runs$lengths+1L
  ii <- which(runs$values)
  ans <- lapply(ii,function(i) {
    k <- start[i]:end[i];duration<-sum(z$DT[k])
    if(duration+1e-7<min_level_sec || length(k)<min_intervals)return(NULL)
    data.frame(START=z$T[k[1]],END=z$T1[tail(k,1)],DURATION_SEC=duration,NATIVE_INTERVALS=length(k),
      MEAN_ALT_FT=sum(z$DT[k]*(z$H[k]+z$H1[k])/2)/duration,
      MIN_ALT_FT=min(c(z$H[k],z$H1[k])),MAX_ALT_FT=max(c(z$H[k],z$H1[k])),
      LEFT_CENSORED=k[1]==1L,RIGHT_CENSORED=tail(k,1)==nrow(z))
  })
  ans <- Filter(Negate(is.null),ans)
  if(length(ans))do.call(rbind,ans)else empty
}

paper_profile_measure <- function(clip, spec, time_ok=TRUE, config, as_frame=TRUE, source_profile_ok=TRUE) {
  full <- clip$ORDERED && abs(clip$BRACKETED_SEC-clip$DURATION_SEC)<1e-4 &&
    abs(clip$ALTITUDE_KNOWN_SEC-clip$DURATION_SEC)<1e-4
  coverage <- full && clip$MAX_NATIVE_GAP_SEC<=spec$MAX_GAP_SEC+1e-7
  status <- if(!isTRUE(time_ok)||!clip$ORDERED)'Unsupported window time' else
    if(!isTRUE(source_profile_ok))'Source altitude support unavailable' else
    if(!full)'Incomplete altitude bracketing' else
    if(!coverage)'Native gap exceeds limit' else
    if(clip$DURATION_SEC+1e-7<spec$MIN_LEVEL_SEC)'Window shorter than feature scale' else
    if(clip$REVERSE_PROGRESS_FT>config$maximum_reverse_progress_ft+1e-7)'Material vertical reversal' else 'Classifiable'
  eligible <- identical(status,'Classifiable')
  ep <- if(eligible)paper_profile_episodes(clip,spec$MIN_LEVEL_SEC,spec$MAX_GAP_SEC,
    config$vertical_rate_limit_fpm,1L)else NULL
  # In the coarse sensitivity, a lone long low-rate span is not evidence of zero
  # interruption merely because it fails the minimum native-interval rule.
  if(eligible && any(ep$NATIVE_INTERVALS<config$minimum_native_intervals_per_episode)) {
    eligible<-FALSE;status<-'Insufficient intervals for episode';ep<-NULL
  }
  n <- if(eligible)nrow(ep)else NA_integer_
  seconds <- if(eligible)sum(ep$DURATION_SEC)else NA_real_
  longest <- if(eligible && n>0)max(ep$DURATION_SEC)else if(eligible)0 else NA_real_
  label <- paper_profile_class(n,seconds,clip$DURATION_SEC,longest,eligible,
    config$light_maximum_interruptions,config$light_maximum_level_share,config$light_maximum_longest_sec)
  out<-list(SPEC=spec$SPEC,MIN_LEVEL_SEC=spec$MIN_LEVEL_SEC,MAX_GAP_SEC=spec$MAX_GAP_SEC,
    COVERAGE_OK=coverage,PROFILE_ELIGIBLE=eligible,PROFILE_STATUS=status,PROFILE_CLASS=label,
    BRACKETED_SEC=clip$BRACKETED_SEC,ALTITUDE_KNOWN_SEC=clip$ALTITUDE_KNOWN_SEC,
    MAX_NATIVE_GAP_SEC=clip$MAX_NATIVE_GAP_SEC,REVERSE_PROGRESS_FT=clip$REVERSE_PROGRESS_FT,
    INTERRUPTION_N=n,LEVEL_SEC=seconds,LEVEL_SHARE=seconds/clip$DURATION_SEC,LONGEST_SEC=longest,
    LEVEL_ALT_MIN_FT=if(eligible&&n>0)min(ep$MIN_ALT_FT)else NA_real_,
    LEVEL_ALT_MEAN_FT=if(eligible&&n>0)sum(ep$MEAN_ALT_FT*ep$DURATION_SEC)/seconds else NA_real_,
    BOUNDARY_EPISODE_N=if(eligible)sum(ep$LEFT_CENSORED|ep$RIGHT_CENSORED)else NA_integer_)
  if(as_frame)as.data.frame(out)else out
}

paper_profile_read_config <- function(path='config/paper-profile-classes-2026-10-27.json') {
  cfg <- jsonlite::read_json(path,simplifyVector=TRUE)
  cfg$config_path<-path
  cfg$base<-paper_ref_config(cfg$base_config)
  cfg$output<-file.path(cfg$base$store,cfg$output_directory)
  stopifnot(startsWith(cfg$output,file.path(cfg$base$store,'derived/paper/')))
  cfg
}

paper_profile_fingerprint <- function(cfg) {
  paths<-c(cfg$config_path,'R/paper-profile-classes.R','scripts/18-characterise-paper-interruptions.R',
    'tests/paper-profile-classes.R',cfg$base$config_path,cfg$base$input_manifest,paper_reference_sources())
  tibble::tibble(PATH=paths,SHA256=vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE))
}

load_paper_profile_classes <- function(path='config/paper-profile-classes-2026-10-27.json') {
  cfg<-paper_profile_read_config(path)
  x<-readRDS(file.path(cfg$output,'analysis.rds'))
  stopifnot(identical(x$source_fingerprint,paper_profile_fingerprint(cfg)))
  m<-x$input_manifest
  p<-ifelse(startsWith(m$PATH,'data-store/'),file.path(cfg$base$store,substring(m$PATH,12)),m$PATH)
  stopifnot(all(m$SHA256==vapply(p,digest::digest,character(1),algo='sha256',file=TRUE)))
  x
}
