# CHN-only candidate. Load legacy-core.R into the same isolated environment first.
chn_version <- "2.0.0-candidate.5"
chn_config <- function(overrides = list()) {
  defaults <- list(max_gap_sec = 5, max_position_gap_sec = 15, max_repair_share = 0.01, max_speed_kt = 750,
    max_ground_speed_kt = 120, max_bridge_turn_deg = 45, repair_review_path = NULL, airport_reference_path = NULL,
    max_vertical_rate_fpm = 12000, max_bridge_vertical_rate_fpm = 6000,
    max_sample_gap_sec = 30, clock_column = NULL, fuel_flow_unit = "auto",
    min_level_sec = 10, min_cruise_sec = 120, phase12_min_sec = 3,
    min_ground_sec = 30, phase_codes_confirmed = TRUE, require_airport_metadata = FALSE, max_plots = 12)
  if (length(setdiff(names(overrides), names(defaults)))) stop("Unknown configuration field")
  cfg <- utils::modifyList(defaults, overrides)
  numeric_fields <- setdiff(names(defaults), c("clock_column", "fuel_flow_unit", "phase_codes_confirmed", "require_airport_metadata", "repair_review_path", "airport_reference_path"))
  if (!all(vapply(cfg[numeric_fields], function(x) length(x) == 1 && is.finite(x) && x >= 0, TRUE))) stop("Invalid numeric configuration")
  if (cfg$max_repair_share > 1 || cfg$max_sample_gap_sec <= 0 || cfg$max_speed_kt <= 0) stop("Invalid repair limits")
  if(cfg$max_position_gap_sec>15 || cfg$max_bridge_turn_deg>180 || cfg$max_ground_speed_kt<=0)stop("Invalid position bridge limits; ceiling is 15 seconds")
  cfg
}

# A review can release a repair-share hold only; it cannot release missing data,
# an implausible bridge, time ambiguity, or another domain's failure.
chn_review_approved <- function(path,cfg,domain,share) {
  if(is.null(cfg$repair_review_path))return(FALSE)
  reviews<-readr::read_csv(cfg$repair_review_path,col_types=readr::cols(.default="c"))
  required<-c("SHA256","DOMAIN","DECISION","HELPER_VERSION","MAX_REPAIR_SHARE","EVIDENCE")
  if(!all(required%in%names(reviews)))stop("Invalid repair review manifest")
  hash<-digest::digest(file=path,algo="sha256")
  r<-reviews[reviews$SHA256==hash & reviews$DOMAIN==domain & reviews$DECISION=="approve_airborne" &
    reviews$HELPER_VERSION==chn_version,,drop=FALSE]
  if(nrow(r)!=1L)return(FALSE)
  limit<-suppressWarnings(as.numeric(r$MAX_REPAIR_SHARE))
  is.finite(limit) && limit>=share && !is.na(r$EVIDENCE) && nzchar(r$EVIDENCE)
}

chn_bearing <- function(a,b) {
  la<-c(a[1],b[1])*pi/180;dl<-(b[2]-a[2])*pi/180
  atan2(sin(dl)*cos(la[2]),cos(la[1])*sin(la[2])-sin(la[1])*cos(la[2])*cos(dl))*180/pi
}

# QAR channels can be multiplexed: valid position samples arrive on different
# frames, or a sampled value is held until its next update. Align those channels
# before testing joint motion. Long gaps and boundary padding remain absent.
chn_align_channel <- function(x,time,cfg,kind="latitude",latitude=NULL) {
  cfg$max_gap_sec<-cfg$max_position_gap_sec
  t<-as.numeric(time);out<-x;aligned<-rep(FALSE,length(x));finite<-which(is.finite(x)&is.finite(t))
  if(length(finite)<2 || any(diff(t)<0,na.rm=TRUE))return(list(values=out,aligned=aligned,regular=FALSE,cadence_sec=NA_real_))
  step<-stats::median(diff(t)[diff(t)>0],na.rm=TRUE);sample_dt<-diff(t[finite])
  mode_dt<-as.numeric(names(sort(table(round(sample_dt,3)),decreasing=TRUE))[1])
  regular<-mean(!is.finite(x))>0.25 && mode_dt>1.5*step && mean(abs(sample_dt-mode_dt)<0.01)>0.95
  gaps<-chn_runs(!is.finite(x))
  for(r in seq_len(nrow(gaps))) {
    a<-gaps$start[r]-1L;b<-gaps$end[r]+1L
    limit<-if(regular)min(cfg$max_gap_sec,mode_dt+0.01) else min(cfg$max_gap_sec,5)
    if(a>=1&&b<=length(x)&&all(is.finite(c(x[a],x[b],t[a],t[b])))&&t[b]>t[a]&&t[b]-t[a]<=limit) {
      idx<-(a+1L):(b-1L);out[idx]<-x[a]+(t[idx]-t[a])/(t[b]-t[a])*(x[b]-x[a]);aligned[idx]<-TRUE
    }
  }
  # Detect a repeated update cadence, not ordinary stationary taxi samples.
  changes<-which(c(TRUE,diff(x)!=0));changes<-changes[is.finite(x[changes])]
  cd<-diff(t[changes]);short<-cd[is.finite(cd)&cd>1.5*step&cd<=cfg$max_gap_sec]
  cadence<-if(length(short))as.numeric(names(sort(table(round(short,3)),decreasing=TRUE))[1]) else NA_real_
  held_regular<-length(cd)>20 && is.finite(cadence) && mean(abs(cd-cadence)<0.01,na.rm=TRUE)>0.7
  if(held_regular)for(k in seq_len(length(changes)-1L)) {
    a<-changes[k];b<-changes[k+1L];dt<-t[b]-t[a]
    distance<-abs(x[b]-x[a])*60*if(kind=="longitude"&&!is.null(latitude))abs(cos(latitude[a]*pi/180)) else 1
    if(b>a+1L&&is.finite(dt)&&dt>0&&dt<=min(cfg$max_gap_sec,cadence+0.01)&&is.finite(distance)&&distance/dt*3600<=cfg$max_speed_kt) {
      idx<-(a+1L):(b-1L);out[idx]<-x[a]+(t[idx]-t[a])/dt*(x[b]-x[a]);aligned[idx]<-TRUE
    }
  }
  list(values=out,aligned=aligned,regular=regular||held_regular,
    cadence_sec=if(held_regular)cadence else if(regular)mode_dt else step)
}
# BEGIN BUNDLED AIRPORT LOOKUP
.chn_bundled_airports <- function() {
  tibble::tribble(~ICAO,~LAT,~LON,~AIRPORT_NAME,
    "RKSI",37.469101,126.450996,"Incheon International Airport",
    "WMKK",2.74558,101.709999,"Kuala Lumpur International Airport",
    "ZBAA",40.080101013183594,116.58499908447266,"Beijing Capital International Airport",
    "ZBAD",39.509945,116.41092,"Beijing Daxing International Airport",
    "ZBHH",40.849658,111.824598,"Hohhot Baita International Airport",
    "ZBLA",49.205002,119.824997,"Hulunbuir Hailar Airport",
    "ZBLL",37.683333,111.142778,"Lüliang Dawu Airport",
    "ZBSJ",38.280701,114.696999,"Shijiazhuang Zhengding International Airport",
    "ZBTJ",39.124401092499994,117.346000671,"Tianjin Binhai International Airport",
    "ZGDY",29.1028,110.443001,"Zhangjiajie Hehua International Airport",
    "ZGFS",23.0825,113.070833,"Foshan Shadi Airport",
    "ZGGG",23.392401,113.299004,"Guangzhou Baiyun International Airport",
    "ZGHA",28.189199,113.220001,"Changsha Huanghua International Airport",
    "ZGHY",26.72208,112.617958,"Hengyang Nanyue Airport",
    "ZGHZ",23.049999,114.599998,"Huizhou Pingtan Airport",
    "ZGNN",22.608544,108.175335,"Nanning Wuxu Airport",
    "ZGSD",22.006399,113.375999,"Zhuhai Jinwan Airport",
    "ZGSZ",22.639299,113.810997,"Shenzhen Bao'an International Airport",
    "ZHCC",34.526497,113.849165,"Zhengzhou Xinzheng International Airport",
    "ZHHH",30.774798,114.213723,"Wuhan Tianhe International Airport",
    "ZHNY",32.982696,112.617467,"Nanyang Jiangying Airport",
    "ZHSY",32.592889,110.906296,"Shiyan Wudangshan Airport",
    "ZJHK",19.9349,110.459,"Haikou Meilan International Airport",
    "ZLDH",40.161098,94.809196,"Dunhuang Mogao International Airport",
    "ZLLL",36.515202,103.620003,"Lanzhou Zhongchuan International Airport",
    "ZLXY",34.447102,108.751999,"Xi'an Xianyang International Airport",
    "ZPPP",25.110313,102.936743,"Kunming Changshui International Airport",
    "ZSAM",24.54400062561035,118.12799835205078,"Xiamen Gaoqi International Airport",
    "ZSDY",37.50137,118.789863,"Dongying Shengli Airport",
    "ZSFZ",25.934669,119.66318,"Fuzhou Changle International Airport",
    "ZSHC",30.23609,120.428865,"Hangzhou Xiaoshan International Airport",
    "ZSJH",30.7403,117.6856,"Chizhou Jiuhuashan Airport",
    "ZSNB",29.82670021057129,121.46199798583984,"Ningbo Lishe International Airport",
    "ZSNJ",31.735032,118.865949,"Nanjing Lukou International Airport",
    "ZSPD",31.1434,121.805,"Shanghai Pudong International Airport",
    "ZSSS",31.198104,121.33426,"Shanghai Hongqiao International Airport",
    "ZSWA",31.1045,118.66687,"Wuhu Xuanzhou Airport",
    "ZSWX",31.494400024399997,120.429000854,"Sunan Shuofang International Airport",
    "ZSWZ",27.910572,120.853465,"Wenzhou Longwan International Airport",
    "ZSYW",29.342095,120.03116,"Yiwu Airport",
    "ZSZS",29.9342,122.362,"Zhoushan Putuoshan Airport",
    "ZUCK",29.712254,106.651895,"Chongqing Jiangbei International Airport",
    "ZUGY",26.541466,106.803331,"Guiyang Longdongbao International Airport",
    "ZUMY",31.428101,104.740997,"Mianyang Nanjiao Airport",
    "ZUTF",30.31252,104.441284,"Chengdu Tianfu International Airport",
    "ZUYI",25.083423,104.960804,"Xingyi Wanfenglin Airport",
    "ZUZY",27.810723,107.247189,"Zunyi Xinzhou Airport",
    "ZWWW",43.907101,87.474197,"Ürümqi Tianshan International Airport",
    "ZWYN",43.955799,81.330299,"Yining Airport",
    "ZYCC",43.996201,125.684998,"Changchun Longjia International Airport"
  ) |> dplyr::mutate(COORDINATE_SOURCE="OurAirports 2025-08-31",
    SOURCE_COMMIT="65beeb51c64fa411eb113c5d6680715309cd808a", COORDINATE_STATUS="airport_coordinate_proxy_for_ARP")
}
# END BUNDLED AIRPORT LOOKUP

# Accept a prepared ICAO/LAT/LON table or the public OurAirports airports.csv.
# Coordinates are a sourced airport-reference proxy, not a certified AIP ARP.
chn_validate_airports <- function(d) {
  if(!all(c("ICAO","LAT","LON")%in%names(d)))stop("Airport table requires ICAO, LAT, LON")
  d$ICAO<-toupper(trimws(as.character(d$ICAO)))
  d$LAT<-suppressWarnings(as.numeric(d$LAT));d$LON<-suppressWarnings(as.numeric(d$LON))
  if(any(is.na(d$ICAO)|!grepl("^[A-Z]{4}$",d$ICAO))||anyDuplicated(d$ICAO))stop("Invalid or duplicated airport ICAO reference")
  if(any(!is.finite(d$LAT)|!is.finite(d$LON)|abs(d$LAT)>90|abs(d$LON)>180|(d$LAT==0&d$LON==0)))stop("Invalid airport reference coordinates")
  for(col in c("AIRPORT_NAME","COORDINATE_SOURCE","SOURCE_COMMIT","COORDINATE_STATUS"))if(!col%in%names(d))d[[col]]<-rep(if(col=="COORDINATE_SOURCE")"caller_supplied_airport_reference"else"",nrow(d))
  tibble::as_tibble(d)
}
chn_airports <- function(path=NULL) {
  if(is.null(path))return(chn_validate_airports(.chn_bundled_airports()))
  d<-readr::read_csv(path,col_types=readr::cols(.default="c"))
  if(all(c("latitude_deg","longitude_deg")%in%names(d))) {
    icao<-if("icao_code"%in%names(d))d$icao_code else rep(NA_character_,nrow(d))
    explicit<-unique(icao[!is.na(icao)&nzchar(icao)])
    fallback<-is.na(icao)|!nzchar(icao)
    if("ident"%in%names(d)){missing<-is.na(icao)|!nzchar(icao);icao[missing]<-d$ident[missing]}
    name<-if("name"%in%names(d))d$name else rep("",nrow(d))
    keep<-!is.na(icao)&grepl("^[A-Z]{4}$",icao)&(!fallback|!icao%in%explicit)
    if("type"%in%names(d))keep<-keep&!is.na(d$type)&d$type!="closed_airport"
    d<-tibble::tibble(ICAO=icao[keep],LAT=d$latitude_deg[keep],LON=d$longitude_deg[keep],AIRPORT_NAME=name[keep],
      COORDINATE_SOURCE="supplied_OurAirports_file",COORDINATE_STATUS="airport_coordinate_proxy_for_ARP")
  } else if(all(c("ICAO","ARP_LAT","ARP_LON")%in%names(d))) {
    d$LAT<-d$ARP_LAT;d$LON<-d$ARP_LON
  }
  chn_validate_airports(d)
}
chn_min <- function(x) if (any(is.finite(x))) min(x[is.finite(x)]) else NA_real_
chn_max <- function(x) if (any(is.finite(x))) max(x[is.finite(x)]) else NA_real_
chn_median <- function(x) if (any(is.finite(x))) stats::median(x[is.finite(x)]) else NA_real_
chn_runs <- function(x) {
  x[is.na(x)] <- FALSE
  r <- rle(x); e <- cumsum(r$lengths); s <- e-r$lengths+1L
  data.frame(start = s[r$values], end = e[r$values])
}
chn_issue <- function(code, domain, status = "unresolved", rows = 0L, detail = "")
  tibble::tibble(CODE = code, DOMAIN = domain, STATUS = status, ROWS = as.integer(rows), DETAIL = detail)
chn_clock <- function(raw, date, cfg) {
  cols <- grep("^TIME([.][0-9]+)?$", names(raw), value = TRUE)
  if (!length(cols)) stop("No clock column")
  parse <- function(col) {
    sec <- tryCatch(suppressWarnings(as.numeric(hms::as_hms(raw[[col]]))), error = function(e) rep(NA_real_, nrow(raw)))
    dd <- diff(sec)
    rollover <- dd < -43200 & head(sec,-1) >= 18*3600 & tail(sec,-1) <= 6*3600
    rollover[is.na(rollover)] <- FALSE
    fixed <- dd + ifelse(rollover,86400,0)
    # Augmented exports can repeat one observation hundreds of times. Score
    # distinct physical observations, so replication cannot dilute clock faults
    # or create a false tie between a progressing clock and an auxiliary counter.
    physical <- intersect(c("LATP","LONP",grep("^ALT_STD",names(raw),value=TRUE),
      "FF1C","FF2C","FF3C","FF4C","GS","FLIGHT_PHASE"),names(raw))
    keys <- unique(c(col,physical));keep <- !duplicated(raw[,..keys])
    s <- sec[keep];d <- diff(s)
    midnight <- d < -43200 & head(s,-1)>=18*3600 & tail(s,-1)<=6*3600
    midnight[is.na(midnight)] <- FALSE;d <- d+ifelse(midnight,86400,0)
    score <- mean(is.finite(s)) - 3*mean(d < 0, na.rm=TRUE) - mean(d==0,na.rm=TRUE) - mean(d>cfg$max_sample_gap_sec,na.rm=TRUE)
    if (!is.finite(score)) score <- -Inf
    list(sec=sec, rollover=rollover, delta=fixed, score=score,scored_rows=sum(keep))
  }
  candidates <- lapply(cols,parse); scores <- vapply(candidates,`[[`,0,"score")
  selected <- if (!is.null(cfg$clock_column)) match(toupper(cfg$clock_column),cols) else which.max(scores)
  if (length(selected)!=1 || is.na(selected)) stop("Configured clock column is absent")
  c <- candidates[[selected]]
  clock <- as.POSIXct(date,tz="UTC") + c$sec + cumsum(c(0,c$rollover))*86400
  ambiguous <- FALSE
  if (is.null(cfg$clock_column) && length(cols)>1) {
    other <- which(seq_along(cols)!=selected & abs(scores-scores[selected]) < 0.05)
    ambiguous <- any(vapply(other,function(i) !isTRUE(all.equal(c$sec,candidates[[i]]$sec)),TRUE))
  }
  list(time=clock,column=cols[selected],valid=all(is.finite(as.numeric(clock))) && all(diff(as.numeric(clock))>=0), ambiguous=ambiguous,
       evidence=tibble::tibble(COLUMN=cols,SCORE=scores,SELECTED=seq_along(cols)==selected,
         RAW_ROWS=nrow(raw),SCORED_ROWS=vapply(candidates,`[[`,0L,"scored_rows")))
}

# Repair only bracketed intervals, with limits in elapsed seconds rather than rows.
# Coordinates interpolate jointly; no extrapolation, extrapolated padding, or
# conversion of an entirely absent channel to zero is permitted.
chn_repair <- function(values, time, kind, cfg, gs = NULL, ground = NULL) {
  x <- as.matrix(values); storage.mode(x) <- "double"; original <- x
  n <- nrow(x); t <- as.numeric(time); repaired <- rep(FALSE,n)
  valid <- apply(x,1,function(v) all(is.finite(v)))
  if (kind=="position") valid <- valid & abs(x[,1])<=90 & abs(x[,2])<=180 & !(x[,1]==0 & x[,2]==0)
  if (kind=="altitude") valid <- valid & x[,1]>=-2000 & x[,1]<=65000
  if (kind=="fuel") valid <- valid & apply(x,1,function(v) all(v>=0))
  x[!valid,] <- NA_real_
  bridge_ok <- function(a,b) {
    dt <- t[b]-t[a]
    if (!is.finite(dt) || dt<=0 || dt>cfg$max_gap_sec || !all(is.finite(x[c(a,b),]))) return(FALSE)
    if (kind=="position") {
      distance <- fuel_haversine_nm(x[a,1],x[a,2],x[b,1],x[b,2])
      if (!is.finite(distance) || distance/dt*3600 > cfg$max_speed_kt) return(FALSE)
      if (!is.null(gs) && any(is.finite(gs[a:b]))) {
        expected <- mean(gs[a:b],na.rm=TRUE)*dt/3600
        if (distance > max(0.15,3*expected)) return(FALSE)
      }
      on_ground<-!is.null(ground)&&all(ground[a:b])
      if(on_ground && distance/dt*3600>cfg$max_ground_speed_kt)return(FALSE)
      # Longer airborne bridges need straight, observed approach/departure
      # support. A taxi turn may remain imprecise but cannot affect airborne QC.
      if(dt>5 && !on_ground) {
        left<-which(t>=t[a]-15 & seq_len(n)<a & apply(is.finite(x),1,all))
        right<-which(t<=t[b]+15 & seq_len(n)>b & apply(is.finite(x),1,all))
        if(!length(left)||!length(right))return(FALSE)
        before<-left[1];after<-tail(right,1)
        bearings<-c(chn_bearing(x[before,],x[a,]),chn_bearing(x[a,],x[b,]),chn_bearing(x[b,],x[after,]))
        turns<-abs((diff(bearings)+180)%%360-180)
        if(any(!is.finite(turns))||any(turns>cfg$max_bridge_turn_deg))return(FALSE)
      }
    }
    if (kind=="altitude" && abs(x[b,1]-x[a,1])/dt*60 > cfg$max_bridge_vertical_rate_fpm) return(FALSE)
    if (kind=="fuel" && any(pmax(x[a,],x[b,])/pmax(pmin(x[a,],x[b,]),1)>4)) {
      # Zero flow is an observed engine state, not an invalid ratio denominator.
      # Permit a bounded start/shutdown transition only with ground evidence.
      ground_transition <- !is.null(ground) && isTRUE(ground[a]) && isTRUE(ground[b]) && any(x[c(a,b),]==0)
      if(!ground_transition)return(FALSE)
    }
    TRUE
  }
  interpolate <- function(a,b) {
    idx <- seq.int(a+1L,b-1L); w <- (t[idx]-t[a])/(t[b]-t[a])
    for (k in seq_len(ncol(x))) {
      delta <- x[b,k]-x[a,k]
      if (kind=="position" && k==2L) delta <- (delta+180)%%360-180
      x[idx,k] <<- x[a,k]+w*delta
    }
    repaired[idx] <<- TRUE
  }
  if (n>2 && cfg$max_gap_sec>0) {
    gaps <- chn_runs(!valid)
    for (r in seq_len(nrow(gaps))) {
      a <- gaps$start[r]-1L;b<-gaps$end[r]+1L
      if (a>=1 && b<=n && bridge_ok(a,b)) interpolate(a,b)
    }
    if (kind %in% c("position","altitude")) {
      # An excursion must return to a plausible bracket within the same short
      # time limit. Persistent changes and edge jumps are never smoothed away.
      initial_dt<-diff(t)
      initial_delta<-if(kind=="position")fuel_haversine_nm(head(x[,1],-1),head(x[,2],-1),tail(x[,1],-1),tail(x[,2],-1)) else abs(diff(x[,1]))
      initial_limit<-if(kind=="position")cfg$max_speed_kt/3600 else cfg$max_vertical_rate_fpm/60
      candidates<-which(is.finite(initial_delta)&is.finite(initial_dt)&initial_dt>0&initial_delta/initial_dt>initial_limit)
      for(i in candidates[candidates<n-1L]) {
        dt <- t[i+1L]-t[i]
        value <- if (kind=="position") fuel_haversine_nm(x[i,1],x[i,2],x[i+1L,1],x[i+1L,2]) else abs(x[i+1L,1]-x[i,1])
        limit <- if (kind=="position") cfg$max_speed_kt/3600 else cfg$max_vertical_rate_fpm/60
        bad <- is.finite(value) && is.finite(dt) && dt>0 && value/dt>limit
        if (bad) {
          found <- FALSE;j<-i+2L
          while (j<=n && is.finite(t[j]-t[i]) && t[j]-t[i]<=cfg$max_gap_sec) {
            if (bridge_ok(i,j)) {interpolate(i,j);found<-TRUE;break}
            j<-j+1L
          }
        }
      }
    }
  }
  remaining <- !apply(x,1,function(v) all(is.finite(v)))
  if (n>1 && kind %in% c("position","altitude")) {
    dt <- diff(t)
    delta <- if (kind=="position") fuel_haversine_nm(head(x[,1],-1),head(x[,2],-1),tail(x[,1],-1),tail(x[,2],-1)) else abs(diff(x[,1]))
    limit <- if (kind=="position") cfg$max_speed_kt/3600 else cfg$max_vertical_rate_fpm/60
    bad <- which(is.finite(delta) & is.finite(dt) & dt>0 & delta/dt>limit)
    remaining[unique(c(bad,bad+1L))] <- TRUE
  }
  list(values=x,original=original,repaired=repaired,unresolved=remaining,
       over_budget=mean(repaired)>cfg$max_repair_share)
}

fuel_read_chn_qar_csv <- function(path,date=NULL,fuel_flow_unit=NULL,config=chn_config()) {
  cfg <- chn_config(config);if (!is.null(fuel_flow_unit)) cfg$fuel_flow_unit<-fuel_flow_unit
  meta <- fuel_parse_chn_filename(path);if (is.null(date)) date<-meta$DATE[[1]]
  if (is.na(date)) stop("Cannot establish source date from filename")
  raw <- data.table::fread(path,check.names=TRUE);names(raw)<-make.names(toupper(names(raw)),unique=TRUE)
  if (!nrow(raw)) stop("Empty QAR table")
  raw$SOURCE_ROW<-seq_len(nrow(raw));clock<-chn_clock(raw,date,cfg)
  time<-clock$time;issues<-list();add<-function(x) issues[[length(issues)+1L]]<<-x
  if (!clock$valid) add(chn_issue("invalid_clock","time"))
  if (clock$ambiguous) add(chn_issue("ambiguous_clock","time"))
  col <- function(name) if (name %in% names(raw)) suppressWarnings(as.numeric(raw[[name]])) else rep(NA_real_,nrow(raw))
  altcols<-grep("^ALT_STD",names(raw),value=TRUE)
  altitude<-if(length(altcols)) rowMeans(as.matrix(raw[,..altcols]),na.rm=TRUE) else rep(NA_real_,nrow(raw))
  altitude[!is.finite(altitude)]<-NA_real_
  gs<-col("GS");phase<-if("FLIGHT_PHASE"%in%names(raw)) as.character(raw$FLIGHT_PHASE) else rep(NA_character_,nrow(raw))
  positions<-cbind(col("LATP"),col("LONP"))
  required_ff<-if(grepl("^(A340|A380|B747)",gsub("[^A-Z0-9]","",meta$TYPE))) paste0("FF",1:4,"C") else c("FF1C","FF2C")
  flows<-sapply(required_ff,col);if(is.null(dim(flows)))flows<-matrix(flows,ncol=length(required_ff))
  if (!all(required_ff%in%names(raw))) add(chn_issue("missing_engine_flow_column","fuel"))
  # Exact duplicate observations can be removed. Different measurements sharing
  # a timestamp remain unresolved; no artificial subsecond clock is invented.
  signature<-data.frame(time=as.numeric(time),positions,altitude,flows,phase,gs)
  drop<-duplicated(signature)
  if(any(drop)) {
    add(chn_issue("identical_observations_deduplicated","time","repaired",sum(drop)))
    keep<-!drop;raw<-raw[keep,];time<-time[keep];altitude<-altitude[keep];positions<-positions[keep,,drop=FALSE];flows<-flows[keep,,drop=FALSE];phase<-phase[keep];gs<-gs[keep]
  }
  source_positions<-positions
  la<-chn_align_channel(positions[,1],time,cfg,"latitude")
  lo<-chn_align_channel(positions[,2],time,cfg,"longitude",la$values)
  positions<-cbind(la$values,lo$values);aligned<-la$aligned|lo$aligned
  if(any(aligned))add(chn_issue("position_channels_aligned","distance",if(la$regular||lo$regular)"info" else "repaired",sum(aligned),"Bounded channel alignment; original samples retained"))
  # Preserve all recorded rows: unsupported ground positions cannot change timing.
  n<-nrow(raw);dt<-c(diff(as.numeric(time)),0)
  if(any(!is.finite(dt)) || any(head(dt,-1)<=0)) add(chn_issue("nonunique_or_backward_time","time",rows=sum(!is.finite(dt)|dt<0)))
  if(any(dt>cfg$max_sample_gap_sec,na.rm=TRUE)) add(chn_issue("sampling_gap","time",rows=sum(dt>cfg$max_sample_gap_sec,na.rm=TRUE)))
  position_cfg<-cfg;position_cfg$max_gap_sec<-cfg$max_position_gap_sec
  ground<-phase%in%c("1","2","3","12","13","14") & (is.na(gs)|gs<80)
  pos<-chn_repair(positions,time,"position",position_cfg,gs,ground=ground)
  # A finite nonzero coordinate can still be a frozen recording. Require
  # independent evidence of motion, and never "heal" a freeze beyond 15 sec.
  ias<-if("IASC"%in%names(raw))col("IASC")else col("IAS")
  moving<-phase%in%as.character(6:11) & ((is.finite(gs)&gs>80)|(is.na(gs)&is.finite(ias)&ias>80))
  same<-c(FALSE,abs(diff(pos$values[,1]))<1e-10 & abs(diff(pos$values[,2]))<1e-10)
  flat<-chn_runs(same & moving & rowSums(is.finite(pos$values))==2)
  frozen<-rep(FALSE,n)
  for(j in seq_len(nrow(flat))) {
    a<-max(1L,flat$start[j]-1L);b<-flat$end[j]
    if(is.finite(as.numeric(time[b]-time[a],units="secs"))&&as.numeric(time[b]-time[a],units="secs")>15)frozen[a:b]<-TRUE
  }
  pos$unresolved<-pos$unresolved|frozen
  if(any(frozen))add(chn_issue("position_frozen_while_moving","distance",rows=sum(frozen),detail="Position held >15 sec during source airborne phase and independent GS/IAS >80 kt; no path manufactured"))
  # Irregular missing-channel interpolation counts towards the anomaly budget;
  # regular multiplexed-channel alignment is separately reported as sampling.
  alignment_anomaly<-(la$aligned & !la$regular)|(lo$aligned & !lo$regular)
  if(mean(alignment_anomaly|pos$repaired)>cfg$max_repair_share)pos$over_budget<-TRUE
  alt<-chn_repair(matrix(altitude,ncol=1),time,"altitude",cfg)
  # Candidate fuel spikes are bounded gaps rather than unrestricted rolling
  # replacement. Missing engines are never silently included as zero flow.
  fsum<-rowSums(flows)
  detection_flow<-fsum;detection_flow[!is.finite(detection_flow)]<-chn_median(fsum)
  spike<-if(any(is.finite(detection_flow)))fuel_clean_flow_spikes(detection_flow)$FF_SPIKE_FLAG & is.finite(fsum) else rep(FALSE,n)
  flows_for_repair<-flows;flows_for_repair[spike,]<-NA_real_
  fuel<-chn_repair(flows_for_repair,time,"fuel",cfg,
    ground=phase%in%c("1","2","3","14") & (is.na(gs)|gs<80))
  for (item in list(list("position","distance",pos),list("altitude","profile",alt),list("fuel","fuel",fuel))) {
    r<-item[[3]]
    if(any(r$repaired)) add(chn_issue(paste0(item[[1]],"_interpolated"),item[[2]],"repaired",sum(r$repaired)))
    if(any(r$unresolved)) add(chn_issue(paste0(item[[1]],"_unresolved"),item[[2]],rows=sum(r$unresolved)))
    if(r$over_budget) add(chn_issue(paste0(item[[1]],"_repair_budget"),item[[2]],rows=sum(r$repaired)))
  }
  pos_ok<-!any(pos$unresolved) && !pos$over_budget
  alt_ok<-!any(alt$unresolved) && !alt$over_budget
  fuel_ok<-!any(fuel$unresolved) && !fuel$over_budget && all(required_ff%in%names(raw))
  time_ok<-clock$valid && !clock$ambiguous && all(is.finite(dt)) && all(head(dt,-1)>0) && all(dt<=cfg$max_sample_gap_sec)
  # Eligibility is evaluated on the observed source airborne window. Its
  # interval support is [ATOT,ALDT); the ALDT position/altitude endpoint is needed.
  atot<-if(isTRUE(cfg$phase_codes_confirmed))which(phase%in%as.character(6:11))[1] else NA_integer_
  aldt<-if(!is.na(atot))chn_first_run(phase=="12",time,cfg$phase12_min_sec,atot) else NA_integer_
  window_ok<-!is.na(atot)&&!is.na(aldt)&&atot<aldt
  air_rows<-if(window_ok)atot:aldt else integer()
  air_intervals<-if(window_ok)atot:(aldt-1L) else integer()
  interval_time_ok<-is.finite(dt)&dt>0&dt<=cfg$max_sample_gap_sec
  air_time_ok<-window_ok && clock$valid && !clock$ambiguous && all(interval_time_ok[air_intervals])
  # Never integrate backwards or across unknown gaps, even in diagnostic tables.
  int_dt<-dt;int_dt[!interval_time_ok]<-NA_real_;int_dt[n]<-0
  legs<-function(p) c(if(n>1)fuel_haversine_nm(head(p[,1],-1),head(p[,2],-1),tail(p[,1],-1),tail(p[,2],-1)) else numeric(),0)
  rawlegs<-legs(positions);cleanlegs<-legs(pos$values)
  share<-function(repaired)if(window_ok)sum(dt[air_intervals]*repaired[air_intervals])/sum(dt[air_intervals]) else NA_real_
  shares<-c(position=share(pos$repaired|alignment_anomaly),altitude=share(alt$repaired),fuel=share(fuel$repaired))
  approved<-setNames(rep(FALSE,3),names(shares))
  for(domain in names(shares))if(is.finite(shares[domain])&&shares[domain]>cfg$max_repair_share)
    approved[domain]<-chn_review_approved(path,cfg,domain,shares[domain])
  cap_ok<-function(kind)is.finite(shares[kind])&&(shares[kind]<=cfg$max_repair_share||approved[kind])
  air_pos_ok<-window_ok && !any(pos$unresolved[air_rows]) && cap_ok("position")
  air_alt_ok<-window_ok && !any(alt$unresolved[air_rows]) && cap_ok("altitude")
  # Outgoing fuel at ALDT belongs to ground operation; it is not required for
  # consumed airborne fuel. Position at ALDT does bound the final airborne leg.
  air_fuel_ok<-window_ok && !any(fuel$unresolved[air_intervals]) && cap_ok("fuel") && all(required_ff%in%names(raw))
  scores_distance<-if(pos_ok)cleanlegs else rep(NA_real_,n)
  unit<-fuel_infer_flow_unit(rowSums(fuel$values),int_dt,scores_distance,meta$TYPE[[1]],requested_unit=cfg$fuel_flow_unit)
  unit_ok<-!isTRUE(unit$FF_UNIT_REVIEW_REQUIRED[[1]])
  if(!unit_ok)add(chn_issue("fuel_unit_review","fuel"))
  factor<-unit$FF_KG_PER_RAW_UNIT[[1]];flow<-rowSums(fuel$values)*factor
  at_time<-function(increments)c(0,if(n>1)head(cumsum(increments),-1) else numeric())
  air_cumulative<-function(increments,ok) {
    out<-rep(NA_real_,n)
    if(isTRUE(ok))out[air_rows]<-c(0,cumsum(increments[air_intervals]))
    out
  }
  full_dist<-if(pos_ok&&time_ok)at_time(cleanlegs) else rep(NA_real_,n)
  full_fuel<-if(fuel_ok&&time_ok&&unit_ok)at_time(flow*int_dt/3600) else rep(NA_real_,n)
  air_dist<-air_cumulative(cleanlegs,air_pos_ok&&air_time_ok)
  air_fuel<-air_cumulative(flow*int_dt/3600,air_fuel_ok&&air_time_ok&&unit_ok)
  canonical_dist<-if(pos_ok&&time_ok)full_dist else air_dist
  canonical_fuel<-if(fuel_ok&&time_ok&&unit_ok)full_fuel else air_fuel
  distance_reference<-if(pos_ok&&time_ok)"record_start" else "ATOT_supported_window"
  fuel_reference<-if(fuel_ok&&time_ok&&unit_ok)"record_start" else "ATOT_supported_window"
  tr<-tibble::tibble(TIME=time,LAT=pos$values[,1],LON=pos$values[,2],ALT_FT=alt$values[,1],
    GS=gs,IASC=if("IASC"%in%names(raw))as.numeric(raw$IASC) else if("IAS"%in%names(raw))as.numeric(raw$IAS) else rep(NA_real_,n),
    FLIGHT_PHASE_RAW=phase,DT_SEC=int_dt,DISTANCE_NM=cleanlegs,
    DIST_FLOWN_NM=canonical_dist,FULL_RECORD_DIST_FLOWN_NM=full_dist,
    AIRBORNE_DIST_FLOWN_NM=air_dist,AIRBORNE_FUEL_KG=air_fuel,
    FULL_RECORD_FUEL_KG=full_fuel,CANONICAL_DISTANCE_REFERENCE=distance_reference,CANONICAL_FUEL_REFERENCE=fuel_reference,
    DIST_FLOWN_NM_DIAGNOSTIC=at_time(rawlegs),
    FF_TOTAL_RAW=rowSums(flows),FF_TOTAL_RAW_KGPH=rowSums(flows)*factor,FF_TOTAL_KGPH=flow,
    FF_SPIKE_FLAG=spike,FUEL_BURNT_KG=flow*int_dt/3600,
    FUEL_BURNT_KG_ORIGINAL=rowSums(flows)*factor*int_dt/3600,
    TOT_FUEL_KG=canonical_fuel,
    TOT_FUEL_KG_ORIGINAL=at_time(rowSums(flows)*factor*int_dt/3600),
    POSITION_REPAIRED=pos$repaired,ALTITUDE_REPAIRED=alt$repaired,FUEL_REPAIRED=fuel$repaired,
    POSITION_UNRESOLVED=pos$unresolved,POSITION_FROZEN=frozen,ALTITUDE_UNRESOLVED=alt$unresolved,FUEL_UNRESOLVED=fuel$unresolved,
    POSITION_ALIGNMENT_ANOMALY=alignment_anomaly,
    SOURCE_ROW=raw$SOURCE_ROW,LAT_SOURCE=source_positions[,1],LON_SOURCE=source_positions[,2],ALT_SOURCE_FT=altitude,POSITION_ALIGNED=aligned)
  for(name in names(unit))tr[[name]]<-unit[[name]][[1]]
  for(name in names(meta))tr[[name]]<-meta[[name]][[1]]
  attr(tr,"issues")<-dplyr::bind_rows(chn_issue("","",rows=0)[0,],dplyr::bind_rows(issues))
  attr(tr,"quality")<-list(time=time_ok,fuel=fuel_ok&&unit_ok,distance=pos_ok,profile=alt_ok,
    air_time=air_time_ok,air_fuel=air_fuel_ok&&unit_ok,air_distance=air_pos_ok,air_profile=air_alt_ok,
    window_ok=window_ok,atot=atot,aldt=aldt,repair_share=shares,repair_approved=approved,
    latitude_cadence_sec=la$cadence_sec,longitude_cadence_sec=lo$cadence_sec,clock_clear=clock$valid&&!clock$ambiguous)
  attr(tr,"repair_results")<-list(position=pos,altitude=alt,fuel=fuel)
  attr(tr,"clock")<-clock$evidence;attr(tr,"clock_column")<-clock$column;attr(tr,"config")<-cfg
  tr
}

fuel_first_up_crossing_index <- function(value,threshold,row_min=1L,row_max=length(value)) {
  idx<-which(seq_along(value)>=row_min & seq_along(value)<=row_max & dplyr::lag(value)<threshold & value>=threshold)
  if(length(idx))idx[1] else NA_integer_
}
fuel_last_down_crossing_index <- function(value,threshold,row_min=1L,row_max=length(value)) {
  idx<-which(seq_along(value)>=row_min & seq_along(value)<=row_max & dplyr::lag(value)>threshold & value<=threshold)
  if(length(idx))tail(idx,1) else NA_integer_
}
chn_first_run <- function(cond,time,min_sec,after=0L) {
  cond[seq_along(cond)<=after]<-FALSE;r<-chn_runs(cond)
  if(!nrow(r))return(NA_integer_)
  dur<-as.numeric(time[r$end])-as.numeric(time[r$start])
  k<-which(is.finite(dur)&dur>=min_sec)
  if(length(k))r$start[k[1]] else NA_integer_
}
fuel_vfe_toc_tod <- function(trj,dlto,alto) {
  fail<-list(TOC=NA_integer_,TOD=NA_integer_,TOC_LEVEL_ID=NA_character_,TOD_LEVEL_ID=NA_character_,SEARCH_METHOD="unresolved_sustained_profile")
  if(is.na(dlto)||is.na(alto)||dlto>=alto)return(fail)
  cfg<-attr(trj,"config");if(is.null(cfg))cfg<-chn_config()
  # Detect complete altitude/time level segments BEFORE consulting geometry.
  # Reuse the level-table IDs and boundaries; never clip a segment at a circle.
  levels<-fuel_level_segment_candidates(trj,dlto,alto,cfg$min_level_sec)
  levels<-levels[is.finite(levels$LEVEL_DURATION_SEC)&levels$LEVEL_DURATION_SEC>=cfg$min_cruise_sec,]
  if(!nrow(levels))return(fail)
  profile<-fuel_vertical_profile(trj);row<-seq_len(nrow(profile));win<-row>=dlto&row<=alto
  choose<-function(column,departure) {
    context<-rep(FALSE,nrow(trj));discriminates<-FALSE
    if(column%in%names(trj)) {
      d<-trj[[column]];outside<-which(win&is.finite(d)&d>200)
      bound<-if(length(outside))if(departure)min(outside)else max(outside)else if(departure)alto+1L else dlto-1L
      context<-win&is.finite(d)&d<=200&if(departure)row<bound else row>bound
      discriminates<-any(context)&&length(outside)>0L
    }
    method<-if(discriminates)if(departure)"departure_200nm_ceiling_context"else"arrival_200nm_ceiling_context"else"near_ceiling_profile_fallback"
    top<-chn_max(profile$ALT_SMOOTH_FT[if(any(context))context else win]);floor<-top-max(1000,top*0.03)
    eligible<-which(is.finite(levels$LEVEL_ALTITUDE_FT)&levels$LEVEL_ALTITUDE_FT>=floor)
    # The radius chooses the relevant altitude context, never a timestamp.
    # Select complete profile levels even if they end before, start after, or
    # span the circle crossing; terminal lower level-offs remain separate.
    list(index=if(length(eligible))if(departure)eligible[1]else tail(eligible,1)else NA_integer_,method=method)
  }
  dep<-choose("DIST_FROM_DEP_NM",TRUE);arr<-choose("DIST_TO_ARR_NM",FALSE)
  if(is.na(dep$index)||is.na(arr$index))return(fail)
  selected<-c(dep$index,arr$index);method<-paste(dep$method,arr$method,sep=";")
  first<-selected[1];last<-tail(selected,1)
  toc<-levels$START_ROW_ID[first];tod<-levels$END_ROW_ID[last]
  climbed<-any(row>=dlto&row<=toc&is.finite(profile$VERTICAL_RATE_FPM)&profile$VERTICAL_RATE_FPM>300)
  descent<-fuel_first_sustained_index(row>tod&row<=alto&profile$ALT_SMOOTH_FT>=3000&
    is.finite(profile$VERTICAL_RATE_FPM)&profile$VERTICAL_RATE_FPM<=-300,
    profile$DT_SEC_PREV,min_duration_sec=cfg$min_cruise_sec)
  # A partial profile can support one boundary without supporting its partner.
  list(TOC=if(climbed)toc else NA_integer_,TOD=if(!is.na(descent)&&tod>toc)tod else NA_integer_,
    TOC_LEVEL_ID=if(climbed)levels$LEVEL_SEGMENT_ID[first]else NA_character_,
    TOD_LEVEL_ID=if(!is.na(descent)&&tod>toc)levels$LEVEL_SEGMENT_ID[last]else NA_character_,SEARCH_METHOD=method)
}
fuel_level_segment_candidates <- function(trj,start_row=1L,end_row=nrow(trj),min_duration_sec=10) {
  if(is.na(start_row))start_row<-1L;if(is.na(end_row))end_row<-nrow(trj)
  p<-fuel_vertical_profile(trj);row<-seq_len(nrow(p))
  cond<-p$IS_LEVEL & row>start_row & row<=end_row & p$ALT_FT>=3000
  runs<-chn_runs(cond);if(!nrow(runs))return(fuel_empty_level_segments())
  starts<-pmax(start_row,runs$start-1L);ends<-runs$end
  duration<-as.numeric(p$TIME[ends])-as.numeric(p$TIME[starts])
  keep<-is.finite(duration)&duration>=min_duration_sec
  starts<-starts[keep];ends<-ends[keep];duration<-duration[keep]
  if(!length(starts))return(fuel_empty_level_segments())
  tibble::tibble(LEVEL_SEGMENT_ID=sprintf("%s-LVL%03d",trj$SOURCE_UID[[1]],seq_along(starts)),
    LEVEL_SEGMENT_ORDER=seq_along(starts),START_ROW_ID=starts,END_ROW_ID=ends,LEVEL_DURATION_SEC=duration,
    LEVEL_DISTANCE_NM=trj$DIST_FLOWN_NM[ends]-trj$DIST_FLOWN_NM[starts],
    LEVEL_FUEL_KG=trj$TOT_FUEL_KG[ends]-trj$TOT_FUEL_KG[starts],
    LEVEL_ALTITUDE_FT=vapply(seq_along(starts),function(i)chn_median(trj$ALT_FT[starts[i]:ends[i]]),0),
    START_ALT_FT=trj$ALT_FT[starts],END_ALT_FT=trj$ALT_FT[ends],
    START_DIST_FLOWN_NM=trj$DIST_FLOWN_NM[starts],END_DIST_FLOWN_NM=trj$DIST_FLOWN_NM[ends],
    START_FUEL_KG=trj$TOT_FUEL_KG[starts],END_FUEL_KG=trj$TOT_FUEL_KG[ends])
}
fuel_level_context_phase <- function(level_start,level_end,toc,tod) {
  if(is.na(toc)||is.na(tod))return(rep("UNKNOWN",length(level_start)))
  ifelse(level_end<=toc,"CLIMB",ifelse(level_start>=tod,"DESCENT","ENROUTE"))
}

fuel_chn_milestones <- function(trj,airport_meta=chn_airports()) {
  cfg<-attr(trj,"config");quality<-attr(trj,"quality")
  if(is.null(cfg))cfg<-chn_config()
  if(is.null(quality))quality<-list(distance=TRUE)
  trj<-fuel_append_airport_distances(trj,airport_meta)
  if(!isTRUE(quality$air_distance)){trj$DIST_FROM_DEP_NM<-NA_real_;trj$DIST_TO_ARR_NM<-NA_real_}
  attr(trj,"config")<-cfg
  row<-seq_len(nrow(trj));phase<-suppressWarnings(as.numeric(trj$FLIGHT_PHASE_RAW))
  dep_rows<-which(phase%in%c(1,2,3)&row<which.max(replace(trj$ALT_FT,!is.finite(trj$ALT_FT),-Inf)))
  dep_ground<-chn_median(trj$ALT_FT[if(length(dep_rows))head(dep_rows,300) else head(row,300)])
  atot<-fuel_first_index(phase%in%6:11)
  if(is.na(atot))atot<-fuel_first_index(trj$GS>80 & trj$ALT_FT-dep_ground>100)
  erwy<-fuel_first_index(phase%in%c(3,5))
  if(!is.na(atot) && (is.na(erwy)||erwy>=atot))erwy<-fuel_last_index(row<atot & trj$GS>20 & trj$ALT_FT-dep_ground<100)
  if(is.na(erwy)&&!is.na(atot))erwy<-max(1L,atot-1L)
  aldt<-if(!is.na(atot)&&isTRUE(cfg$phase_codes_confirmed))chn_first_run(phase==12,trj$TIME,cfg$phase12_min_sec,atot) else NA_integer_
  # A pressure-ground reference is estimated only from observed arrival taxi
  # samples, with minimum support. It is not a conversion of pressure altitude
  # into geometric altitude and never changes ALT_FT/flight-level anchors.
  ground_rows<-which(phase==14 & row>if(!is.na(aldt))aldt else if(!is.na(atot))atot else nrow(trj))
  ground_rows<-ground_rows[is.finite(trj$ALT_FT[ground_rows])]
  supported<-length(ground_rows)>=2 && diff(range(as.numeric(trj$TIME[ground_rows])))>=cfg$min_ground_sec
  arr_ground<-if(supported)chn_median(trj$ALT_FT[ground_rows]) else NA_real_
  if(is.na(aldt)&&is.finite(arr_ground)&&!is.na(atot))
    aldt<-chn_first_run(trj$ALT_FT-arr_ground<=100 & trj$GS<80,trj$TIME,5,atot)
  dlto<-if(!is.na(atot)&&is.finite(dep_ground))fuel_first_up_crossing_index(trj$ALT_FT-dep_ground,3000,atot,if(!is.na(aldt))aldt else nrow(trj)) else NA_integer_
  vfe<-fuel_vfe_toc_tod(trj,atot,aldt)
  alto<-if(!is.na(vfe$TOD)&&is.finite(arr_ground))fuel_last_down_crossing_index(trj$ALT_FT-arr_ground,3000,vfe$TOD,aldt) else NA_integer_
  total<-chn_max(trj$AIRBORNE_DIST_FLOWN_NM);remaining<-total-trj$AIRBORNE_DIST_FLOWN_NM
  ascend_end<-if(!is.na(vfe$TOC))vfe$TOC else if(!is.na(aldt))aldt else nrow(trj)
  descent_start<-if(!is.na(vfe$TOD))vfe$TOD else nrow(trj)
  atot_bound<-if(!is.na(atot))atot else 1L;aldt_bound<-if(!is.na(aldt))aldt else nrow(trj)
  values<-c(1L,erwy,atot,dlto,
    fuel_first_index(trj$AIRBORNE_DIST_FLOWN_NM>=40),fuel_first_index(trj$AIRBORNE_DIST_FLOWN_NM>=100),fuel_first_index(trj$AIRBORNE_DIST_FLOWN_NM>=200),
    vapply(c(7500,10000,18000),function(h)fuel_first_up_crossing_index(trj$ALT_FT,h,atot_bound,ascend_end),1L),
    vfe$TOC,vfe$TOD,
    vapply(c(18000,10000,7500),function(h)fuel_last_down_crossing_index(trj$ALT_FT,h,descent_start,aldt_bound),1L),
    fuel_first_index(row>atot_bound & remaining<=200),fuel_first_index(row>atot_bound & remaining<=100),fuel_first_index(row>atot_bound & remaining<=40),
    alto,aldt,if(!is.na(aldt))fuel_first_index(row>=aldt & phase==14) else NA_integer_,nrow(trj))
  labels<-c("AOBT","ERWY","ATOT","DLTO","D040","D100","D200","D_FL075","D_FL100","D_FL180","TOC","TOD","A_FL180","A_FL100","A_FL075","A200","A100","A040","ALTO","ALDT","XRWY","AIBT")
  idx<-tibble::tibble(MST=labels,ROW_ID=as.integer(values),MST_METHOD="derived_chn_v2_profile")
  idx$MST_METHOD[idx$MST=="ATOT"]<-"source_airborne_phase_or_speed_altitude"
  idx$MST_METHOD[idx$MST=="ALDT"]<-if(any(phase==12,na.rm=TRUE)&&isTRUE(cfg$phase_codes_confirmed))"source_landing_phase_onset" else "derived_arrival_ground_pressure_speed"
  idx$MST_METHOD[idx$MST%in%c("DLTO","ALTO")]<-"derived_3000ft_relative_to_observed_field_pressure"
  idx$MST_METHOD[grepl("^[DA]_FL",idx$MST)]<-"derived_pressure_altitude_crossing"
  idx$MST_METHOD[grepl("^[DA][0-9]",idx$MST)]<-"derived_along_track_distance"
  idx$MST_METHOD[idx$MST%in%c("TOC","TOD")]<-paste0("derived_sustained_vertical_profile:",vfe$SEARCH_METHOD)
  idx$LEVEL_SEGMENT_ID<-NA_character_
  idx$LEVEL_SEGMENT_ID[idx$MST=="TOC"]<-vfe$TOC_LEVEL_ID
  idx$LEVEL_SEGMENT_ID[idx$MST=="TOD"]<-vfe$TOD_LEVEL_ID
  lev<-fuel_level_segment_candidates(trj,atot_bound,aldt_bound,cfg$min_level_sec)
  lev$LEVEL_CONTEXT_PHASE<-fuel_level_context_phase(lev$START_ROW_ID,lev$END_ROW_ID,vfe$TOC,vfe$TOD)
  for(which_end in c("START","END")) {
    li<-lev;li$ROW_ID<-li[[paste0(which_end,"_ROW_ID")]];li$MST<-paste0("LVL_",which_end)
    li$MST_METHOD<-paste0("derived_vrate_300fpm_min",cfg$min_level_sec,"s")
    idx<-dplyr::bind_rows(idx,dplyr::select(li,dplyr::any_of(c("MST","ROW_ID","MST_METHOD","LEVEL_SEGMENT_ID","LEVEL_DURATION_SEC","LEVEL_DISTANCE_NM","LEVEL_FUEL_KG","LEVEL_CONTEXT_PHASE"))))
  }
  ms<-fuel_snapshot_rows(trj,idx)
  for(name in c("DIST_FLOWN_NM_DIAGNOSTIC","AIRBORNE_DIST_FLOWN_NM","AIRBORNE_FUEL_KG","CANONICAL_DISTANCE_REFERENCE","CANONICAL_FUEL_REFERENCE"))
    ms[[name]]<-trj[[name]][ms$ROW_ID]
  attr(ms,"ground_pressure")<-c(departure=dep_ground,arrival=arr_ground)
  ms
}

chn_process_flight <- function(path,config=chn_config(),airport_meta=NULL,keep_trajectory=FALSE) {
  config<-chn_config(config)
  airport_meta<-if(is.null(airport_meta))chn_airports(config$airport_reference_path)else chn_validate_airports(airport_meta)
  tr<-fuel_read_chn_qar_csv(path,config=config);ms<-fuel_chn_milestones(tr,airport_meta)
  issues<-attr(tr,"issues");q<-attr(tr,"quality");cfg<-attr(tr,"config")
  add<-function(x)issues<<-dplyr::bind_rows(issues,x)
  if(!isTRUE(cfg$phase_codes_confirmed))add(chn_issue("phase_code_contract_unconfirmed","phases"))
  if(!all(c(tr$ADEP[1],tr$ADES[1])%in%airport_meta$ICAO))add(chn_issue("airport_metadata_missing","configuration",if(isTRUE(cfg$require_airport_metadata))"unresolved" else "info",detail="Explicit airborne-profile fallback; airport distance search unavailable"))
  row<-function(mst){r<-ms$ROW_ID[ms$MST==mst];if(length(r))r[1] else NA_integer_}
  core<-vapply(c("ATOT","TOC","TOD","ALDT"),row,1L)
  observed_boundaries_ok<-all(is.finite(core)) && all(diff(core)>0)
  lto<-vapply(c("ATOT","DLTO","TOC","TOD","ALTO","ALDT"),row,1L)
  lto_ok<-all(is.finite(lto))&&all(diff(lto)>0)
  phase_ok<-q$air_time && q$air_profile && isTRUE(cfg$phase_codes_confirmed) && observed_boundaries_ok
  # Preserve the full-record finding, and state independently whether it blocks
  # the current study. Ground recording defects remain visible in the ledger.
  issues$SOURCE_STATUS<-issues$STATUS
  issues$STUDY_RELEVANT<-issues$STATUS=="unresolved"
  rr<-attr(tr,"repair_results")
  rows<-if(q$window_ok)q$atot:q$aldt else seq_len(nrow(tr))
  intervals<-if(q$window_ok)q$atot:(q$aldt-1L) else seq_len(nrow(tr))
  for(kind in c("position","altitude","fuel")) {
    idx<-if(kind=="fuel")intervals else rows
    bad<-!q$window_ok||any(rr[[kind]]$unresolved[idx])
    issues$STUDY_RELEVANT[issues$CODE==paste0(kind,"_unresolved")]<-bad
    if(kind=="position")issues$STUDY_RELEVANT[issues$CODE=="position_frozen_while_moving"]<-bad
    cap<-!q$window_ok||!is.finite(q$repair_share[kind])||
      (q$repair_share[kind]>cfg$max_repair_share&&!q$repair_approved[kind])
    issues$STUDY_RELEVANT[issues$CODE==paste0(kind,"_repair_budget")]<-cap
    if(isTRUE(q$repair_approved[kind])) {
      approved_issue<-chn_issue(paste0(kind,"_repair_share_review_approved"),kind,"reviewed",
        detail="Input SHA256 and helper version matched the restricted review; only the share hold is released")
      approved_issue$STUDY_RELEVANT<-FALSE;issues<-dplyr::bind_rows(issues,approved_issue)
    } else if(q$window_ok&&is.finite(q$repair_share[kind])&&q$repair_share[kind]>cfg$max_repair_share) {
      z<-chn_issue(paste0("airborne_",kind,"_repair_budget"),kind,
        detail="More than 1% of airborne exposure repaired; review is required")
      z$STUDY_RELEVANT<-TRUE;issues<-dplyr::bind_rows(issues,z)
    }
  }
  ti<-issues$CODE%in%c("invalid_clock","ambiguous_clock","nonunique_or_backward_time","sampling_gap")
  issues$STUDY_RELEVANT[ti]<-!q$air_time
  outside<-issues$STATUS=="unresolved" & !issues$STUDY_RELEVANT
  issues$STATUS[outside]<-"out_of_scope"
  if(!observed_boundaries_ok)add(chn_issue("profile_boundaries_unresolved","phases",detail="Required ordered ATOT/TOC/TOD/ALDT events are absent or contradictory"))
  if(!q$window_ok)add(chn_issue("airborne_window_unresolved","coverage"))
  if(!lto_ok)add(chn_issue("lto_boundaries_unavailable","phases","info",detail="Ancillary LTO boundaries do not gate the airborne primary cohort"))
  issues$STUDY_RELEVANT[is.na(issues$STUDY_RELEVANT)]<-issues$STATUS[is.na(issues$STUDY_RELEVANT)]=="unresolved"
  boundary_failure<-if(!observed_boundaries_ok)"missing_or_unordered_events" else if(!q$air_time)"clock_or_sampling" else if(!q$air_profile)"altitude_quality" else if(!isTRUE(cfg$phase_codes_confirmed))"phase_code_contract" else ""
  unresolved<-issues$STATUS=="unresolved" & issues$STUDY_RELEVANT
  excluded<-any(unresolved)||!phase_ok||!q$air_fuel||!q$air_distance
  status<-if(excluded)"INVESTIGATE_EXCLUDE" else if(any(issues$STATUS%in%c("repaired","reviewed","out_of_scope")))"REPAIRED_INCLUDED" else "PASS"
  meta<-fuel_parse_chn_filename(path)
  qc<-dplyr::bind_cols(meta,tibble::tibble(HELPER_VERSION=chn_version,ROWS=nrow(tr),CLOCK_COLUMN=attr(tr,"clock_column"),
    TIME_VALID=q$time,FUEL_VALID=q$fuel,DISTANCE_VALID=q$distance,PROFILE_DATA_VALID=q$profile,PHASE_BOUNDARIES_VALID=phase_ok,
    BOUNDARY_FAILURE_CAUSE=boundary_failure,
    AIRBORNE_WINDOW_SUPPORTED=q$window_ok,AIRBORNE_TIME_VALID=q$air_time,AIRBORNE_FUEL_VALID=q$air_fuel,
    AIRBORNE_DISTANCE_VALID=q$air_distance,AIRBORNE_PROFILE_VALID=q$air_profile,LTO_BOUNDARIES_VALID=lto_ok,
    WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE=q$air_time&&q$air_fuel,
    GROUND_TIME_VALID=q$time,
    AIRBORNE_POSITION_REPAIR_SHARE=q$repair_share["position"],
    AIRBORNE_ALTITUDE_REPAIR_SHARE=q$repair_share["altitude"],AIRBORNE_FUEL_REPAIR_SHARE=q$repair_share["fuel"],
    POSITION_SHARE_REVIEW_APPROVED=q$repair_approved["position"],
    LATITUDE_CADENCE_SEC=q$latitude_cadence_sec,LONGITUDE_CADENCE_SEC=q$longitude_cadence_sec,
    CANONICAL_DISTANCE_REFERENCE=tr$CANONICAL_DISTANCE_REFERENCE[1],CANONICAL_FUEL_REFERENCE=tr$CANONICAL_FUEL_REFERENCE[1],
    ELIGIBLE_FUEL_TIME=q$air_time&&q$air_fuel&&phase_ok,ELIGIBLE_DISTANCE=q$air_time&&q$air_distance&&phase_ok,
    STUDY_EXCLUDE=excluded,PROBLEM_FLIGHT=excluded,STATUS=status,
    UNRESOLVED_REASONS=paste(unique(issues$CODE[unresolved]),collapse=";"),
    REPAIRED_REASONS=paste(unique(issues$CODE[issues$STATUS=="repaired"]),collapse=";"),
    POSITION_REPAIRED_ROWS=sum(tr$POSITION_REPAIRED),POSITION_FROZEN_ROWS=sum(tr$POSITION_FROZEN),ALTITUDE_REPAIRED_ROWS=sum(tr$ALTITUDE_REPAIRED),FUEL_REPAIRED_ROWS=sum(tr$FUEL_REPAIRED),
    RAW_DIAGNOSTIC_PATH_NM=chn_max(tr$DIST_FLOWN_NM_DIAGNOSTIC),CANONICAL_PATH_NM=chn_max(tr$DIST_FLOWN_NM),
    RAW_DIAGNOSTIC_FUEL_KG=chn_max(tr$TOT_FUEL_KG_ORIGINAL),CANONICAL_FUEL_KG=chn_max(tr$TOT_FUEL_KG),
    FF_UNIT_INFERRED=tr$FF_UNIT_INFERRED[1],FF_UNIT_CONFIDENCE=tr$FF_UNIT_CONFIDENCE[1],
    DEPARTURE_GROUND_PRESSURE_FT=attr(ms,"ground_pressure")[["departure"]],ARRIVAL_GROUND_PRESSURE_FT=attr(ms,"ground_pressure")[["arrival"]],
    AIRPORT_METADATA_COMPLETE=all(c(tr$ADEP[1],tr$ADES[1])%in%airport_meta$ICAO),
    POSITION_ALIGNED_ROWS=sum(tr$POSITION_ALIGNED)))
  ph<-fuel_phase_summaries(ms);lv<-fuel_level_segments_from_milestones(ms)
  physical<-fuel_phase_summaries(ms,tibble::tribble(~PHASE,~FROM_MST,~TO_MST,
    "CLIMB","ATOT","TOC","CRUISE","TOC","TOD","DESCENT","TOD","ALDT"))
  ph$TIMING_VALID<-vapply(seq_len(nrow(ph)),function(i) {
    a<-row(ph$FROM_MST[i]);b<-row(ph$TO_MST[i]);dt<-tr$DT_SEC[if(b>a)a:(b-1L) else integer()]
    (if(q$window_ok&&a>=q$atot&&b<=q$aldt)q$air_time else q$time)&&is.finite(ph$DURATION_MIN[i])&&ph$DURATION_MIN[i]>=0&&all(is.finite(dt)&dt>0&dt<=cfg$max_sample_gap_sec)
  },TRUE)
  ph$ELIGIBLE_FUEL_TIME<-ph$TIMING_VALID & is.finite(ph$FUEL_KG)
  ph$ELIGIBLE_DISTANCE<-ph$TIMING_VALID & is.finite(ph$DISTANCE_NM)
  ph$PARTITION<-"legacy_LTO_nine_phase"
  ph$CANONICAL_DISTANCE_REFERENCE<-tr$CANONICAL_DISTANCE_REFERENCE[1]
  ph$CANONICAL_FUEL_REFERENCE<-tr$CANONICAL_FUEL_REFERENCE[1]
  physical$PARTITION<-"physical_airborne"
  physical$ELIGIBLE_FUEL_TIME<-q$air_time&&q$air_profile&&q$air_fuel
  physical$ELIGIBLE_DISTANCE<-q$air_time&&q$air_profile&&q$air_distance
  physical$CANONICAL_DISTANCE_REFERENCE<-tr$CANONICAL_DISTANCE_REFERENCE[1]
  physical$CANONICAL_FUEL_REFERENCE<-tr$CANONICAL_FUEL_REFERENCE[1]
  # Unknown ground coverage cannot contaminate airborne endpoint subtraction.
  a<-q$atot;b<-q$aldt
  air_value<-function(x)if(q$window_ok)x[b]-x[a] else NA_real_
  airborne<-tibble::tibble(SOURCE_UID=tr$SOURCE_UID[1],PARTITION="physical_airborne",
    START_TIME=if(q$window_ok)tr$TIME[a] else as.POSIXct(NA),END_TIME=if(q$window_ok)tr$TIME[b] else as.POSIXct(NA),
    DURATION_MIN=if(q$air_time)as.numeric(tr$TIME[b]-tr$TIME[a],units="mins") else NA_real_,
    FUEL_KG=air_value(tr$AIRBORNE_FUEL_KG),DISTANCE_NM=air_value(tr$AIRBORNE_DIST_FLOWN_NM),
    ELIGIBLE_FUEL_TIME=q$air_time&&q$air_fuel,ELIGIBLE_DISTANCE=q$air_time&&q$air_distance)
  airborne$KG_PER_MIN<-if(airborne$ELIGIBLE_FUEL_TIME&&airborne$DURATION_MIN>0)airborne$FUEL_KG/airborne$DURATION_MIN else NA_real_
  airborne$KG_PER_NM<-if(airborne$ELIGIBLE_FUEL_TIME&&airborne$ELIGIBLE_DISTANCE&&airborne$DISTANCE_NM>0)airborne$FUEL_KG/airborne$DISTANCE_NM else NA_real_
  diagnostic_ms<-ms;diagnostic_ms$DIST_FLOWN_NM<-ms$DIST_FLOWN_NM_DIAGNOSTIC
  diagnostic_ph<-fuel_phase_summaries(diagnostic_ms)
  stamp<-function(d) {
    for(name in c("HELPER_VERSION","STUDY_EXCLUDE","PROBLEM_FLIGHT","STATUS","ELIGIBLE_FUEL_TIME","ELIGIBLE_DISTANCE"))if(!name%in%names(d))d[[name]]<-rep(qc[[name]][1],nrow(d))
    d
  }
  for(name in c("SOURCE_UID","HELPER_VERSION"))issues[[name]]<-rep(if(name=="SOURCE_UID")meta$SOURCE_UID else chn_version,nrow(issues))
  repairs<-tr[tr$POSITION_REPAIRED|tr$POSITION_ALIGNED|tr$ALTITUDE_REPAIRED|tr$FUEL_REPAIRED,c("SOURCE_UID","SOURCE_ROW","TIME","LAT_SOURCE","LON_SOURCE","LAT","LON","ALT_SOURCE_FT","ALT_FT","FF_TOTAL_RAW_KGPH","FF_TOTAL_KGPH","POSITION_REPAIRED","POSITION_ALIGNED","ALTITUDE_REPAIRED","FUEL_REPAIRED")]
  result<-list(qc=qc,milestones=stamp(ms),phases=stamp(ph),levels=stamp(lv),diagnostic_phases=stamp(diagnostic_ph),
       airborne_phases=stamp(physical),airborne_summary=stamp(airborne),issues=issues,repairs=repairs,clock=attr(tr,"clock"),trajectory=if(keep_trajectory)tr else NULL)
  chn_enrich_result(result,tr,path,cfg,airport_meta)
}

chn_plot_diagnostics <- function(result,path) {
  tr<-result$trajectory;if(is.null(tr)||!nrow(tr))return(invisible(FALSE))
  elapsed<-as.numeric(tr$TIME-tr$TIME[1],units="mins")
  grDevices::png(path,width=1400,height=1000,res=125)
  on.exit(grDevices::dev.off(),add=TRUE)
  graphics::par(mfrow=c(2,2),mar=c(4,4,3,1),oma=c(0,0,3,0))
  lineplot<-function(raw,clean,label,ylab) {
    finite_values<-c(raw,clean);finite_values<-finite_values[is.finite(finite_values)]
    if(!length(finite_values)){graphics::plot.new();graphics::title(label);graphics::text(.5,.5,"No observations / unavailable");return(invisible(NULL))}
    limits<-range(finite_values)
    graphics::plot(elapsed,raw,type="l",col="grey55",xlab="Elapsed minutes",ylab=ylab,ylim=limits,main=label)
    graphics::lines(elapsed,clean,col="#126e82",lwd=1.3)
    graphics::legend("topleft",c("Source / diagnostic","Candidate (valid domains)"),col=c("grey55","#126e82"),lty=1,bty="n",cex=.8)
  }
  lineplot(tr$ALT_SOURCE_FT,tr$ALT_FT,"Pressure altitude","ft")
  lon<-c(tr$LON_SOURCE,tr$LON);lat<-c(tr$LAT_SOURCE,tr$LAT)
  if(any(is.finite(lon)&is.finite(lat))) {
    graphics::plot(tr$LON_SOURCE,tr$LAT_SOURCE,type="l",col="grey55",xlab="Longitude",ylab="Latitude",main="Position: source excursions remain visible",xlim=range(lon,finite=TRUE),ylim=range(lat,finite=TRUE))
    graphics::lines(tr$LON,tr$LAT,col="#126e82")
  } else {graphics::plot.new();graphics::title("No position observations")}
  lineplot(tr$DIST_FLOWN_NM_DIAGNOSTIC,tr$DIST_FLOWN_NM,"Cumulative path: invalid canonical distances are absent","NM")
  lineplot(tr$TOT_FUEL_KG_ORIGINAL,tr$TOT_FUEL_KG,"Cumulative fuel at sample timestamp","kg")
  graphics::mtext(paste(result$qc$SOURCE_UID,result$qc$STATUS,sep=" — "),outer=TRUE,cex=.9)
  invisible(TRUE)
}

# Great-circle airport radii and cumulative flown track length are independent.
# Keep reference metadata for every radial anchor; no per-flight offsets exist.
chn_arp_reference <- function(code,airport_meta) {
  z<-airport_meta[airport_meta$ICAO==code,,drop=FALSE]
  if(nrow(z)!=1L)return(list(lat=NA_real_,lon=NA_real_,method="airport_reference_missing",source="",status="missing"))
  list(lat=z$LAT[1],lon=z$LON[1],method="great_circle_haversine_airport_coordinate_proxy",
    source=z$COORDINATE_SOURCE[1],status=z$COORDINATE_STATUS[1])
}

chn_enrich_result <- function(result,tr,path,cfg,airport_meta) {
  q<-attr(tr,"quality");n<-nrow(tr);t<-as.numeric(tr$TIME);uid<-tr$SOURCE_UID[1]
  ms<-result$milestones;row<-function(label){x<-ms$ROW_ID[ms$MST==label];if(length(x))x[1]else NA_integer_}
  a<-q$atot;b<-q$aldt;win<-if(q$window_ok)a:b else seq_len(n)
  interval_time<-isTRUE(q$clock_clear)&is.finite(tr$DT_SEC)&tr$DT_SEC>0&tr$DT_SEC<=cfg$max_sample_gap_sec
  if(n>1)interval_time[-1]<-interval_time[-1] & (is.finite(tr$DT_SEC[-n])&tr$DT_SEC[-n]>0)
  interval_fuel<-interval_time & !tr$FUEL_UNRESOLVED & is.finite(tr$FF_TOTAL_KGPH) & !tr$FF_UNIT_REVIEW_REQUIRED
  interval_position<-interval_time & !tr$POSITION_UNRESOLVED & c(!tail(tr$POSITION_UNRESOLVED,-1),FALSE)&is.finite(tr$DISTANCE_NM)
  profile_sample<-!tr$ALTITUDE_UNRESOLVED&is.finite(tr$ALT_FT)
  arp<-list(departure=chn_arp_reference(tr$ADEP[1],airport_meta),arrival=chn_arp_reference(tr$ADES[1],airport_meta))
  s<-tr$AIRBORNE_DIST_FLOWN_NM;remaining<-if(q$window_ok)tail(s[win],1)-s else rep(NA_real_,n)
  specs<-dplyr::bind_rows(
    tibble::tibble(MST=paste0("D_FL",c("075","100","180")),THRESHOLD=c(7500,10000,18000),KIND="pressure_altitude",DIRECTION="up",REFERENCE="standard_pressure_ft"),
    tibble::tibble(MST=paste0("A_FL",c("180","100","075")),THRESHOLD=c(18000,10000,7500),KIND="pressure_altitude",DIRECTION="down",REFERENCE="standard_pressure_ft"),
    tibble::tibble(MST=paste0("D",c("040","100","200")),THRESHOLD=c(40,100,200),KIND="departure_arp",DIRECTION="up",REFERENCE="great_circle_from_departure_ARP"),
    tibble::tibble(MST=paste0("A",c("200","100","040")),THRESHOLD=c(200,100,40),KIND="arrival_arp",DIRECTION="down",REFERENCE="great_circle_to_arrival_ARP"),
    tibble::tibble(MST=paste0("D_ATOT",c("040","100","200")),THRESHOLD=c(40,100,200),KIND="departure_airborne",DIRECTION="up",REFERENCE="along_track_from_ATOT"),
    tibble::tibble(MST=paste0("A_ALDT",c("200","100","040")),THRESHOLD=c(200,100,40),KIND="arrival_airborne",DIRECTION="down",REFERENCE="along_track_to_ALDT"))
  levels<-result$levels;candidates<-list();availability<-list()
  for(k in seq_len(nrow(specs))) {
    sp<-specs[k,];x<-switch(sp$KIND,pressure_altitude=tr$ALT_FT,departure_arp=fuel_haversine_nm(tr$LAT,tr$LON,arp$departure$lat,arp$departure$lon),
      arrival_arp=fuel_haversine_nm(tr$LAT,tr$LON,arp$arrival$lat,arp$arrival$lon),departure_airborne=s,arrival_airborne=remaining)
    left<-if(n>1)head(x,-1)else numeric();right<-if(n>1)tail(x,-1)else numeric()
    crosses<-if(sp$DIRECTION=="up")left<sp$THRESHOLD&right>=sp$THRESHOLD else left>sp$THRESHOLD&right<=sp$THRESHOLD
    ii<-which(is.finite(left)&is.finite(right)&crosses & seq_along(left)%in%win & (seq_along(left)+1L)%in%win)
    z<-NULL
    if(length(ii)) {
      jj<-ii+1L;w<-(sp$THRESHOLD-x[ii])/(x[jj]-x[ii]);dt<-t[jj]-t[ii]
      if(sp$KIND%in%c("departure_arp","arrival_arp")) {
        ref<-arp[[if(sp$KIND=="departure_arp")"departure"else"arrival"]]
        lo<-rep(0,length(ii));hi<-rep(1,length(ii));dlon<-(tr$LON[jj]-tr$LON[ii]+180)%%360-180
        # Resolve the radius on the same piecewise-linear repaired coordinates.
        # Vector bisection retains the source bracket and avoids radial residual
        # from merely interpolating the scalar endpoint distances.
        for(iter in seq_len(40L)) {
          mid<-(lo+hi)/2;val<-fuel_haversine_nm(tr$LAT[ii]+mid*(tr$LAT[jj]-tr$LAT[ii]),tr$LON[ii]+mid*dlon,ref$lat,ref$lon)
          lower<-if(sp$DIRECTION=="up")val<sp$THRESHOLD else val>sp$THRESHOLD
          lo[lower]<-mid[lower];hi[!lower]<-mid[!lower]
        }
        w<-(lo+hi)/2
      }
      z<-tr[jj,intersect(names(ms),names(tr)),drop=FALSE]
      z$TIME<-as.POSIXct(t[ii]+w*dt,origin="1970-01-01",tz="UTC")
      for(col in intersect(c("ALT_FT","TOT_FUEL_KG","TOT_FUEL_KG_ORIGINAL","DIST_FLOWN_NM","AIRBORNE_FUEL_KG","AIRBORNE_DIST_FLOWN_NM","DIST_FLOWN_NM_DIAGNOSTIC"),names(z)))
        z[[col]]<-tr[[col]][ii]+w*(tr[[col]][jj]-tr[[col]][ii])
      z$LAT<-tr$LAT[ii]+w*(tr$LAT[jj]-tr$LAT[ii]);z$LON<-(tr$LON[ii]+w*((tr$LON[jj]-tr$LON[ii]+180)%%360-180)+180)%%360-180
      z$DIST_FROM_DEP_NM<-fuel_haversine_nm(z$LAT,z$LON,arp$departure$lat,arp$departure$lon)
      z$DIST_TO_ARR_NM<-fuel_haversine_nm(z$LAT,z$LON,arp$arrival$lat,arp$arrival$lon)
      z$MST<-sp$MST;z$MST_GROUP<-if(sp$KIND=="pressure_altitude")"flight_level_anchor"else"distance_anchor"
      z$MST_METHOD<-if(sp$KIND%in%c("departure_arp","arrival_arp"))"great_circle_radius_bisection_on_linear_position_bracket"else"linear_crossing_on_supported_sample_interval";z$ROW_ID<-jj
      z$CANDIDATE_ID<-paste0(uid,"-",sp$MST,"-X",sprintf("%04d",seq_along(ii)))
      z$BRACKET_FROM_ROW<-ii;z$BRACKET_TO_ROW<-jj;z$BRACKET_FROM_SOURCE_ROW<-tr$SOURCE_ROW[ii];z$BRACKET_TO_SOURCE_ROW<-tr$SOURCE_ROW[jj]
      z$BRACKET_SEC<-dt;z$CROSSING_FRACTION<-w;z$THRESHOLD<-sp$THRESHOLD;z$THRESHOLD_REFERENCE<-sp$REFERENCE
      z$INTERPOLATED_THRESHOLD_RESIDUAL<-if(sp$KIND=="departure_arp")z$DIST_FROM_DEP_NM-sp$THRESHOLD else if(sp$KIND=="arrival_arp")z$DIST_TO_ARR_NM-sp$THRESHOLD else rep(0,nrow(z))
      z$ARP_LAT<-if(sp$KIND%in%c("departure_arp","arrival_arp"))ref$lat else NA_real_
      z$ARP_LON<-if(sp$KIND%in%c("departure_arp","arrival_arp"))ref$lon else NA_real_
      z$ARP_COORDINATE_SOURCE<-if(sp$KIND%in%c("departure_arp","arrival_arp"))ref$source else NA_character_
      z$ARP_COORDINATE_STATUS<-if(sp$KIND%in%c("departure_arp","arrival_arp"))ref$status else NA_character_
      z$LEFT_RESIDUAL<-x[ii]-sp$THRESHOLD;z$RIGHT_RESIDUAL<-x[jj]-sp$THRESHOLD;z$NEAREST_SAMPLE_RESIDUAL<-pmin(abs(z$LEFT_RESIDUAL),abs(z$RIGHT_RESIDUAL))
      local<-if(sp$KIND=="pressure_altitude")profile_sample[ii]&profile_sample[jj]else interval_position[ii]
      limit<-if(sp$KIND=="pressure_altitude")cfg$max_gap_sec else cfg$max_position_gap_sec
      z$SUPPORTED<-interval_time[ii]&local&is.finite(dt)&dt>0&dt<=limit
      z$SUPPORT_REASON<-ifelse(z$SUPPORTED,"supported",ifelse(dt>limit,"bracket_too_wide","clock_or_channel_unsupported"))
      z$SUPPRESS_LEVEL_ASSOCIATED<-FALSE;z$ASSOCIATED_LEVEL_ID<-NA_character_
      if(sp$KIND=="pressure_altitude"&&nrow(levels))for(j in seq_len(nrow(z))) {
        lev<-which(levels$START_ROW_ID<=ii[j]&levels$END_ROW_ID>=jj[j])
        if(length(lev)==1L){z$SUPPRESS_LEVEL_ASSOCIATED[j]<-TRUE;z$ASSOCIATED_LEVEL_ID[j]<-levels$LEVEL_SEGMENT_ID[lev]}
      }
      z$SELECTED<-FALSE;eligible<-which(z$SUPPORTED&!z$SUPPRESS_LEVEL_ASSOCIATED)
      if(length(eligible))z$SELECTED[if(sp$DIRECTION=="up")eligible[1]else tail(eligible,1)]<-TRUE
      z$SELECTION_RULE<-if(sp$DIRECTION=="up")"first_supported_upward_crossing"else"last_supported_downward_crossing"
      candidates[[k]]<-z
    }
    ref_ok<-if(sp$KIND=="departure_arp")is.finite(arp$departure$lat)else if(sp$KIND=="arrival_arp")is.finite(arp$arrival$lat)else TRUE
    complete_domain<-q$window_ok&&q$air_time&&if(sp$KIND=="pressure_altitude")q$air_profile else q$air_distance
    count<-if(is.null(z))0L else nrow(z);selected<-if(is.null(z))0L else sum(z$SELECTED)
    suppressed<-if(is.null(z))0L else sum(z$SUPPORTED&z$SUPPRESS_LEVEL_ASSOCIATED)
    status<-if(!ref_ok)"REFERENCE_UNSUPPORTED"else if(selected>0)"AVAILABLE"else if(suppressed>0)"LEVEL_REPRESENTED"else if(count>0)"UNRESOLVED_CROSSING"else if(complete_domain)"NOT_REACHED_IN_SUPPORTED_WINDOW"else"DATA_OR_WINDOW_UNSUPPORTED"
    availability[[k]]<-tibble::tibble(SOURCE_UID=uid,MST=sp$MST,THRESHOLD=sp$THRESHOLD,REFERENCE=sp$REFERENCE,
      CANDIDATES=count,SELECTED=selected,LEVEL_ASSOCIATED=suppressed,AVAILABILITY=status,
      REFERENCE_METHOD=if(sp$KIND=="departure_arp")arp$departure$method else if(sp$KIND=="arrival_arp")arp$arrival$method else sp$REFERENCE)
  }
  ca<-dplyr::bind_rows(candidates)
  if(!nrow(ca))ca<-tibble::tibble(SOURCE_UID=character(),MST=character(),CANDIDATE_ID=character(),SUPPORTED=logical(),SUPPRESS_LEVEL_ASSOCIATED=logical(),SELECTED=logical())
  av<-dplyr::bind_rows(availability)
  keep<-!grepl("^[DA][0-9]{3}$|^[DA]_FL[0-9]{3}$",ms$MST)
  enriched<-dplyr::bind_rows(ms[keep,,drop=FALSE],ca[ca$SELECTED,,drop=FALSE])
  enriched$DIST_FROM_DEP_NM<-fuel_haversine_nm(enriched$LAT,enriched$LON,arp$departure$lat,arp$departure$lon)
  enriched$DIST_TO_ARR_NM<-fuel_haversine_nm(enriched$LAT,enriched$LON,arp$arrival$lat,arp$arrival$lon)
  # Distance at an operational event is not supported by an unresolved position.
  valid_position<-!tr$POSITION_UNRESOLVED[pmin(n,pmax(1L,enriched$ROW_ID))]
  bracketed<-!is.na(enriched$BRACKET_FROM_ROW)
  valid_position[bracketed]<-!tr$POSITION_UNRESOLVED[enriched$BRACKET_FROM_ROW[bracketed]]&!tr$POSITION_UNRESOLVED[enriched$BRACKET_TO_ROW[bracketed]]
  enriched$DIST_FROM_DEP_NM[!valid_position]<-NA_real_;enriched$DIST_TO_ARR_NM[!valid_position]<-NA_real_
  enriched$EVENT_ID<-ifelse(!is.na(enriched$CANDIDATE_ID),enriched$CANDIDATE_ID,
    paste0(uid,"-",enriched$MST,"-",enriched$ROW_ID,"-",ifelse(is.na(enriched$LEVEL_SEGMENT_ID),"",enriched$LEVEL_SEGMENT_ID)))
  enriched$MST_METHOD[enriched$MST%in%c("AOBT","AIBT")]<-"record_edge_proxy"
  enriched<-enriched[order(enriched$TIME,enriched$ROW_ID,enriched$MST),]
  # Local quantities never subtract across an unsupported span. Left-rectangle
  # fuel accounting also applies to fractional threshold times.
  integrate<-function(start,end) {
    if(!isTRUE(q$clock_clear)||!is.finite(start)||!is.finite(end)||end<=start||n<2)
      return(list(time=FALSE,fuel=NA_real_,distance=NA_real_,fuel_ok=FALSE,distance_ok=FALSE))
    weight<-pmax(0,pmin(t[-1],end)-pmax(t[-n],start));idx<-which(weight>0)
    inside<-which(t[-n]>=start&t[-n]<end)
    tok<-length(idx)>0&&all(interval_time[union(idx,inside)])&&abs(sum(weight)-(end-start))<1e-5
    fk<-tok&&all(interval_fuel[idx]);pk<-tok&&all(interval_position[idx])
    list(time=tok,fuel=if(fk)sum(tr$FF_TOTAL_KGPH[idx]*weight[idx]/3600)else NA_real_,
      distance=if(pk)sum(tr$DISTANCE_NM[idx]*weight[idx]/tr$DT_SEC[idx])else NA_real_,fuel_ok=fk,distance_ok=pk)
  }
  # Retain every supported unsuppressed crossing in the finer partition, rather
  # than dropping repeated crossings when choosing a convenience representative.
  fine<-dplyr::bind_rows(enriched,ca[ca$SUPPORTED&!ca$SUPPRESS_LEVEL_ASSOCIATED,,drop=FALSE])
  if(q$window_ok)fine<-fine[as.numeric(fine$TIME)>=t[a]&as.numeric(fine$TIME)<=t[b],]else fine<-fine[0,]
  breakpoints<-sort(unique(as.numeric(fine$TIME)));intervals<-list()
  if(length(breakpoints)>1)for(i in seq_len(length(breakpoints)-1L)) {
    start<-breakpoints[i];end<-breakpoints[i+1L];v<-integrate(start,end)
    toc<-row("TOC");tod<-row("TOD")
    macro<-if(!is.na(toc)&&end<=t[toc]+1e-6)"CLIMB"else if(!is.na(tod)&&start>=t[tod]-1e-6)"DESCENT"else if(!is.na(toc)&&!is.na(tod)&&start>=t[toc]-1e-6&&end<=t[tod]+1e-6)"CRUISE"else"UNKNOWN"
    intervals[[i]]<-tibble::tibble(SOURCE_UID=uid,INTERVAL_ID=paste0(uid,"-FINE",sprintf("%04d",i)),PARTITION="fine_airborne_crossings_and_levels",
      MACRO_PHASE=macro,START_TIME=as.POSIXct(start,origin="1970-01-01",tz="UTC"),END_TIME=as.POSIXct(end,origin="1970-01-01",tz="UTC"),
      FROM_EVENTS=paste(sort(unique(fine$MST[abs(as.numeric(fine$TIME)-start)<1e-6])),collapse=";"),
      TO_EVENTS=paste(sort(unique(fine$MST[abs(as.numeric(fine$TIME)-end)<1e-6])),collapse=";"),
      DURATION_MIN=(end-start)/60,FUEL_KG=v$fuel,DISTANCE_NM=v$distance,
      ALTITUDE_CHANGE_FT={idx<-which(t>=start & t<=end); bracket<-which(t[-n]<end & t[-1]>start); good<-length(bracket)>0&&all(profile_sample[unique(c(bracket,bracket+1L,idx))]); if(good)diff(stats::approx(t,tr$ALT_FT,xout=c(start,end),ties="ordered")$y)else NA_real_},
      ELIGIBLE_FUEL_TIME=v$fuel_ok&&(is.na(q$repair_share["fuel"])||q$repair_share["fuel"]<=cfg$max_repair_share||q$repair_approved["fuel"]),
      ELIGIBLE_DISTANCE=v$distance_ok&&(is.na(q$repair_share["position"])||q$repair_share["position"]<=cfg$max_repair_share||q$repair_approved["position"]))
  }
  intervals<-dplyr::bind_rows(intervals)
  supported<-chn_runs(interval_fuel);coverage<-list();boundary_rows<-integer()
  for(i in seq_len(nrow(supported))) {
    first<-supported$start[i];last<-supported$end[i]+1L
    cuts<-sort(unique(c(first,last,if(q$window_ok)c(a,b)else integer())));cuts<-cuts[cuts>=first&cuts<=last]
    if(length(cuts)>1)for(j in seq_len(length(cuts)-1L)) {
      from<-cuts[j];to<-cuts[j+1L];v<-integrate(t[from],t[to]);idx<-from:(to-1L)
      share<-sum(tr$DT_SEC[idx]*tr$FUEL_REPAIRED[idx])/sum(tr$DT_SEC[idx])
      reviewed<-q$window_ok&&from>=a&&to<=b&&q$repair_approved["fuel"]
      coverage[[paste(i,j)]]<-tibble::tibble(SOURCE_UID=uid,COVERAGE_ID=paste0(uid,"-COV",i,"-",j),WINDOW=if(q$window_ok&&from>=a&&to<=b)"AIRBORNE_SUPPORTED_RUN"else"RECORD_SUPPORTED_RUN",
        START_ROW=from,END_ROW=to,START_TIME=tr$TIME[from],END_TIME=tr$TIME[to],DURATION_MIN=(t[to]-t[from])/60,
        FUEL_KG=v$fuel,DISTANCE_NM=v$distance,FUEL_REPAIR_SHARE=share,ELIGIBLE_FUEL_TIME=v$fuel_ok&&(share<=cfg$max_repair_share||reviewed),
        ELIGIBLE_DISTANCE=v$distance_ok)
      boundary_rows<-c(boundary_rows,from,to)
    }
  }
  coverage<-dplyr::bind_rows(coverage)
  points<-sort(unique(c(1L,n,enriched$ROW_ID,if(nrow(ca))c(ca$BRACKET_FROM_ROW,ca$BRACKET_TO_ROW)else integer(),boundary_rows)))
  points<-points[is.finite(points)&points>=1&points<=n]
  data_points<-tr[points,intersect(c("SOURCE_UID","TIME","SOURCE_ROW","LAT","LON","ALT_FT","FF_TOTAL_KGPH","TOT_FUEL_KG","AIRBORNE_FUEL_KG","DIST_FLOWN_NM","AIRBORNE_DIST_FLOWN_NM","CANONICAL_DISTANCE_REFERENCE","CANONICAL_FUEL_REFERENCE","POSITION_UNRESOLVED","POSITION_FROZEN","ALTITUDE_UNRESOLVED","FUEL_UNRESOLVED"),names(tr)),drop=FALSE]
  data_points$ROW_ID<-points
  full<-tibble::tibble(SOURCE_UID=uid,WINDOW="FULL_RECORD",START_TIME=tr$TIME[1],END_TIME=tr$TIME[n],BOUNDS_METHOD="record_edges_proxy",
    DURATION_MIN=if(q$time)diff(range(t))/60 else NA_real_,FUEL_KG=if(q$fuel&&q$time)tail(tr$FULL_RECORD_FUEL_KG,1)else NA_real_,
    DISTANCE_NM=if(q$distance&&q$time)tail(tr$FULL_RECORD_DIST_FLOWN_NM,1)else NA_real_,
    ELIGIBLE_FUEL_TIME=q$time&&q$fuel,ELIGIBLE_DISTANCE=q$time&&q$distance)
  air<-result$airborne_summary;air$WINDOW<-"WHOLE_AIRBORNE";air$BOUNDS_METHOD<-"source_airborne_to_landing_phase_onset"
  flights<-dplyr::bind_rows(full,air)
  target<-av[!grepl("ATOT|ALDT",av$MST),]
  resolved<-all(target$AVAILABILITY%in%c("AVAILABLE","LEVEL_REPRESENTED","NOT_REACHED_IN_SUPPORTED_WINDOW"))
  result$qc$ENRICHED_ANCHORS_RESOLVED<-resolved
  result$qc$ALL_12_ARP_FL_ANCHORS_PRESENT<-all(target$AVAILABILITY%in%c("AVAILABLE","LEVEL_REPRESENTED"))
  result$qc$ARP_DEP_REFERENCE_SUPPORTED<-is.finite(arp$departure$lat)
  result$qc$ARP_ARR_REFERENCE_SUPPORTED<-is.finite(arp$arrival$lat)
  result$qc$CROSSING_CANDIDATES<-nrow(ca);result$qc$SUPPORTED_FUEL_TIME_RUNS<-nrow(coverage)
  tag<-function(d){for(col in c("HELPER_VERSION","STUDY_EXCLUDE","PROBLEM_FLIGHT","STATUS"))d[[col]]<-rep(result$qc[[col]][1],nrow(d));d}
  result$levels$DETECTION_METHOD<-rep("31_sample_median_abs_vrate_le_300fpm_alt_ge_3000ft",nrow(result$levels))
  result$levels$MIN_DURATION_SEC<-rep(cfg$min_level_sec,nrow(result$levels))
  result$milestones<-tag(enriched);result$milestone_candidates<-tag(ca);result$milestone_availability<-tag(av)
  result$phase_intervals<-tag(intervals);result$fuel_time_coverage<-tag(coverage);result$supported_data_points<-tag(data_points);result$flight_summaries<-tag(flights)
  result
}
