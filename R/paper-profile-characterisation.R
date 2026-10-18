# Read-only analysis of pinned study inputs. No source data are repaired here.
# All flight-level outputs stay in the Git-ignored outputs directory.
build_paper_profiles <- function(store = Sys.getenv("FUELBURN_DATA_STORE", ".fuelburn-data-store")) {
  suppressPackageStartupMessages({
    library(dplyr); library(tidyr); library(arrow); library(ggplot2)
  })
  eur_dir <- file.path(store, "derived/eur/parallel-preprocessing/EUR-2026-10-13-002")
  chn_dir <- file.path(store, "derived/chn/verification/CHN-2026-10-18-001/returned-batches")
  chn_files <- sort(list.files(chn_dir, "^CHN-canonical-milestones.parquet$", recursive = TRUE, full.names = TRUE))
  stopifnot(length(chn_files) == 14L)
  eur_file <- file.path(eur_dir, "EUR-canonical-milestones-parallel.parquet")
  airport_files <- c("helpers/chn-qar-v2/data/airports.csv", "notes/reference-data/EUR-airport-coordinates-2024-12-27.csv")
  chn <- bind_rows(lapply(chn_files, function(f) read_parquet(f) |>
    mutate(BATCH = basename(dirname(f)), REGION = "CHN")))
  eur <- read_parquet(eur_file) |> mutate(BATCH = source_batch, REGION = "EUR")
  # Exact ICAO designators; unresolved B737-MAX is deliberately not assigned a variant.
  type_map <- c("A330-300"="A333", "A330-200"="A332", "B737-800"="B738",
                "B737-700"="B737", "A321-NEO"="A21N", "A320-NEO"="A20N",
                "B777-300ER"="B77W", "B787-9"="B789", "A350-900"="A359")
  m <- bind_rows(chn, eur) |> mutate(TYPE = recode(TYPE, !!!type_map))
  # No repeated identifiers across batches or inconsistent flight metadata allowed.
  stopifnot(!any((m |> distinct(REGION, SOURCE_UID, BATCH) |> count(REGION, SOURCE_UID))$n > 1))
  ids <- m |> distinct(REGION, SOURCE_UID, TYPE, ADEP, ADES, BATCH)
  stopifnot(nrow(ids) == nrow(distinct(ids, REGION, SOURCE_UID)))
  ap_c <- read.csv(airport_files[1]) |> transmute(ICAO, LAT, LON)
  ap_e <- read.csv(airport_files[2]) |> transmute(ICAO, LAT = ARP_LAT, LON = ARP_LON)
  ap <- bind_rows(ap_c, ap_e) |> distinct(ICAO, .keep_all = TRUE)
  gcd <- function(lat1, lon1, lat2, lon2) {
    r <- pi/180
    a <- sin((lat2-lat1)*r/2)^2 + cos(lat1*r)*cos(lat2*r)*sin((lon2-lon1)*r/2)^2
    3440.065 * 2 * asin(sqrt(pmin(1, pmax(0, a))))
  }
  core <- m |> filter(MST %in% c("ATOT", "TOC", "TOD", "ALDT"))
  stopifnot(!any((core |> count(REGION, SOURCE_UID, MST))$n > 1))
  w <- core |> select(REGION, SOURCE_UID, MST, TIME, ALT_FT, LAT, LON, TOT_FUEL_KG, DIST_FLOWN_NM) |>
    pivot_wider(names_from = MST, values_from = c(TIME, ALT_FT, LAT, LON, TOT_FUEL_KG, DIST_FLOWN_NM))
  f <- ids |> left_join(w, by = c("REGION", "SOURCE_UID")) |>
    left_join(ap |> transmute(ADEP = ICAO, dep_lat = LAT, dep_lon = LON), by = "ADEP") |>
    left_join(ap |> transmute(ADES = ICAO, arr_lat = LAT, arr_lon = LON), by = "ADES") |>
    mutate(GCD_NM = gcd(dep_lat, dep_lon, arr_lat, arr_lon),
           CLIMB_MIN = as.numeric(difftime(TIME_TOC, TIME_ATOT, units = "mins")),
           ENROUTE_MIN = as.numeric(difftime(TIME_TOD, TIME_TOC, units = "mins")),
           DESCENT_MIN = as.numeric(difftime(TIME_ALDT, TIME_TOD, units = "mins")),
           AIRBORNE_MIN = as.numeric(difftime(TIME_ALDT, TIME_ATOT, units = "mins")),
           ENROUTE_SHARE = ENROUTE_MIN / AIRBORNE_MIN,
           BAND100 = floor(GCD_NM/100)*100,
           DISTANCE_BAND = cut(GCD_NM, c(0, 500, 700, 1000, Inf), right = FALSE,
                               labels = c("<500", "500-699", "700-999", ">=1000")),
           COMPLETE = !is.na(TIME_ATOT) & !is.na(TIME_TOC) & !is.na(TIME_TOD) & !is.na(TIME_ALDT),
           ORDERED = coalesce(COMPLETE & CLIMB_MIN > 0 & ENROUTE_MIN > 0 & DESCENT_MIN > 0, FALSE),
           ZERO_ENROUTE = coalesce(ENROUTE_MIN == 0, FALSE),
           TIME_PLAUSIBLE = coalesce(ORDERED & AIRBORNE_MIN >= 10 & AIRBORNE_MIN <= 480 &
             GCD_NM / AIRBORNE_MIN * 60 <= 650, FALSE),
           ALT_PLAUSIBLE = coalesce(is.finite(ALT_FT_TOC) & is.finite(ALT_FT_TOD) &
             ALT_FT_TOC >= 2000 & ALT_FT_TOC <= 50000 & ALT_FT_TOD >= 2000 & ALT_FT_TOD <= 50000, FALSE),
           ENDPOINT_OK = if_else(REGION == "CHN", coalesce(
             gcd(LAT_ATOT, LON_ATOT, dep_lat, dep_lon) <= 10 &
             gcd(LAT_ALDT, LON_ALDT, arr_lat, arr_lon) <= 10, FALSE), TRUE))
  # Inspect independent geometric movement between emitted airborne event rows.
  # Cumulative distance is NOT used in the timing/altitude cohort screen.
  events <- m |> inner_join(f |> select(REGION, SOURCE_UID, TIME_ATOT, TIME_ALDT), by = c("REGION", "SOURCE_UID")) |>
    filter(TIME >= TIME_ATOT, TIME <= TIME_ALDT) |>
    distinct(REGION, SOURCE_UID, ROW_ID, TIME, .keep_all = TRUE) |>
    arrange(REGION, SOURCE_UID, TIME, ROW_ID) |> group_by(REGION, SOURCE_UID) |>
    mutate(dt = as.numeric(TIME) - lag(as.numeric(TIME)),
           step_nm = gcd(lag(LAT), lag(LON), LAT, LON),
           bad_pos = REGION == "CHN" & (!is.finite(LAT) | !is.finite(LON) | abs(LAT)>90 | abs(LON)>180 | LAT==0 | LON==0),
           # EUR enriched anchors interpolate different quantities from M3/G2G;
           # adjacent enriched rows are not independent trajectory samples.
           # Source-event screening here applies only to CHN recorder events.
           bad_speed = REGION == "CHN" & is.finite(step_nm) & dt > 0 & step_nm / dt * 3600 > 750,
           bad_vrate = REGION == "CHN" & is.finite(ALT_FT) & is.finite(lag(ALT_FT)) & dt > 0 & abs(ALT_FT-lag(ALT_FT))/dt*60 > 12000) |>
    summarise(EVENT_ISSUE = any(bad_pos | bad_speed | bad_vrate, na.rm = TRUE), .groups = "drop")
  f <- f |> left_join(events, by = c("REGION", "SOURCE_UID")) |>
    mutate(EVENT_ISSUE = coalesce(EVENT_ISSUE, TRUE),
           PROFILE_OK = COMPLETE & ORDERED & TIME_PLAUSIBLE & ALT_PLAUSIBLE & ENDPOINT_OK & !EVENT_ISSUE,
           EXCLUSION = case_when(!COMPLETE ~ "Missing core boundary",
             !ORDERED ~ "Coincident/unordered boundaries", !TIME_PLAUSIBLE ~ "Timing/GCD screen",
             !ALT_PLAUSIBLE ~ "Boundary altitude screen", !ENDPOINT_OK ~ "CHN runway/airport position screen",
             EVENT_ISSUE ~ "Emitted airborne event screen", TRUE ~ "Retained"))
  # A second, stricter flag is required for future distance/fuel analyses.
  f <- f |> mutate(DISTANCE_OK = PROFILE_OK &
    coalesce(DIST_FLOWN_NM_TOC > DIST_FLOWN_NM_ATOT & DIST_FLOWN_NM_TOD > DIST_FLOWN_NM_TOC &
      DIST_FLOWN_NM_ALDT > DIST_FLOWN_NM_TOD &
      (DIST_FLOWN_NM_TOC-DIST_FLOWN_NM_ATOT)/CLIMB_MIN*60 <= 750 &
      (DIST_FLOWN_NM_TOD-DIST_FLOWN_NM_TOC)/ENROUTE_MIN*60 <= 750 &
      (DIST_FLOWN_NM_ALDT-DIST_FLOWN_NM_TOD)/DESCENT_MIN*60 <= 750 &
      DIST_FLOWN_NM_ALDT-DIST_FLOWN_NM_ATOT >= .95*GCD_NM, FALSE))
  # Require >=30 independent flights in EACH region per exact type and 100 NM band.
  p <- f |> filter(PROFILE_OK)
  support <- p |> count(TYPE, BAND100, REGION) |> pivot_wider(names_from = REGION, values_from = n, values_fill = 0) |>
    mutate(COMMON = CHN >= 30 & EUR >= 30)
  p <- p |> left_join(select(support, TYPE, BAND100, COMMON), by = c("TYPE", "BAND100"))
  f <- f |> left_join(select(p, REGION, SOURCE_UID, COMMON), by = c("REGION", "SOURCE_UID")) |>
    mutate(COMMON = coalesce(COMMON, FALSE))
  q <- function(x, prob) if (any(is.finite(x))) unname(quantile(x[is.finite(x)], prob, type = 7)) else NA_real_
  metrics <- c("GCD_NM", "AIRBORNE_MIN", "CLIMB_MIN", "ENROUTE_MIN", "DESCENT_MIN", "ENROUTE_SHARE", "ALT_FT_TOC", "ALT_FT_TOD")
  summaries <- p |> select(REGION, all_of(metrics)) |> pivot_longer(-REGION, names_to = "METRIC", values_to = "VALUE") |>
    group_by(REGION, METRIC) |> summarise(N = sum(is.finite(VALUE)), P20 = q(VALUE,.2), P50 = q(VALUE,.5), P80 = q(VALUE,.8), .groups="drop")
  common <- p |> filter(COMMON) |> select(REGION, TYPE, BAND100, all_of(metrics)) |>
    pivot_longer(all_of(metrics), names_to="METRIC", values_to="VALUE") |>
    group_by(REGION, TYPE, BAND100, METRIC) |>
    summarise(N=n(), P20=q(VALUE,.2), P50=q(VALUE,.5), P80=q(VALUE,.8), .groups="drop")
  # Paired cell medians are descriptive, not an equivalence test or causal estimate.
  differences <- common |> select(REGION, TYPE, BAND100, METRIC, N, P50) |>
    pivot_wider(names_from=REGION, values_from=c(N,P50)) |> mutate(CHN_MINUS_EUR = P50_CHN-P50_EUR)
  inventory <- f |> group_by(REGION) |> summarise(INPUT=n(), RETAINED=sum(PROFILE_OK),
    DISTANCE_SCREEN=sum(DISTANCE_OK), COMMON_SUPPORT=sum(COMMON), AIRPORTS=n_distinct(c(ADEP,ADES)),
    ROUTES=n_distinct(paste(ADEP,ADES)), TYPES=n_distinct(TYPE),
    GCD_MIN=min(GCD_NM), GCD_P50=median(GCD_NM), GCD_MAX=max(GCD_NM),
    FIRST_DATE=as.character(min(as.Date(TIME_ATOT), na.rm=TRUE)), LAST_DATE=as.character(max(as.Date(TIME_ATOT),na.rm=TRUE)), .groups="drop")
  type_counts <- f |> group_by(TYPE, REGION) |> summarise(INPUT=n(), RETAINED=sum(PROFILE_OK), .groups="drop") |>
    pivot_wider(names_from=REGION, values_from=c(INPUT,RETAINED), values_fill=0) |> arrange(desc(INPUT_CHN))
  # Validate partition and independent-flight support before emitting results.
  stopifnot(all(abs(p$AIRBORNE_MIN-p$CLIMB_MIN-p$ENROUTE_MIN-p$DESCENT_MIN)<1e-6),
    nrow(p)==nrow(distinct(p, REGION,SOURCE_UID)), all(p$ENROUTE_SHARE>0 & p$ENROUTE_SHARE<1),
    all(!is.na(f$GCD_NM)), sum(inventory$INPUT)==nrow(f))
  inputs <- c(eur_file, chn_files, airport_files)
  provenance <- tibble::tibble(PATH=inputs, SHA256=vapply(inputs, digest::digest, character(1), algo="sha256", file=TRUE))
  manifest <- read.csv(file.path(eur_dir,"EUR-parallel-release-manifest.csv"))
  declared <- manifest$sha256[endsWith(manifest$artifact,
    "EUR-2026-10-13-002/EUR-canonical-milestones-parallel.parquet")]
  stopifnot(length(declared)==1L, identical(declared,provenance$SHA256[[1]]))
  list(flights=f, profiles=p, inventory=inventory, exclusions=count(f, REGION, EXCLUSION),
       types=type_counts, summary=summaries, support=support, common=common,
       differences=differences, provenance=provenance)
}

plot_paper_profiles <- function(x) {
  colors <- c(CHN="#A33A32", EUR="#245C89")
  base <- theme_bw(base_size=9) + theme(legend.position="bottom", panel.grid.minor=element_blank())
  p <- x$profiles
  stage <- ggplot(p, aes(GCD_NM, color=REGION)) + stat_ecdf(linewidth=.65) +
    scale_color_manual(values=colors) + labs(x="Aerodrome great-circle distance (NM)", y="Cumulative flight share", color=NULL) + base
  timing <- p |> select(REGION, CLIMB_MIN, ENROUTE_MIN, DESCENT_MIN) |>
    pivot_longer(-REGION, names_to="PHASE", values_to="MIN") |>
    mutate(PHASE=factor(PHASE, levels=c("CLIMB_MIN","ENROUTE_MIN","DESCENT_MIN"), labels=c("Climb","Enroute","Descent")))
  time <- ggplot(timing, aes(MIN, color=REGION)) + stat_ecdf(linewidth=.6) +
    facet_wrap(~PHASE, scales="free_x", nrow=1) + scale_color_manual(values=colors) +
    labs(x="Milestone-defined duration (min)",y="Cumulative flight share",color=NULL) + base
  alt <- x$common |> filter(METRIC %in% c("ALT_FT_TOC","ALT_FT_TOD")) |>
    mutate(CELL=paste(TYPE,paste0(BAND100,"-",BAND100+99),"NM"),
           EVENT=if_else(METRIC=="ALT_FT_TOC","Top of climb","Top of descent"))
  altitude <- ggplot(alt, aes(P50/100, CELL, color=REGION)) +
    geom_linerange(aes(xmin=P20/100,xmax=P80/100),position=position_dodge(width=.5),orientation="y") +
    geom_point(position=position_dodge(width=.5),size=1.6) + facet_wrap(~EVENT,ncol=2) +
    scale_color_manual(values=colors) + labs(x="Pressure altitude / 100 ft (P20/P50/P80)",y=NULL,color=NULL) + base
  list(stage=stage, timing=time, altitude=altitude)
}
