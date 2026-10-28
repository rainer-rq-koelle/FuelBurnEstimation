# Read the reviewed aggregate snapshot without rebuilding or changing inputs.
load_paper_descent_enroute_lookup <- function() {
  cfg<-paper_ref_config()
  root<-'notes/results/descent-enroute-lookup-2026-10-28'
  if(!file.exists(file.path(root,'product-manifest.csv')))
    stop('Run Rscript scripts/21-review-descent-enroute-lookup.R')
  inputs<-readr::read_csv(file.path(root,'input-manifest.csv'),show_col_types=FALSE)
  stopifnot(identical(as.data.frame(inputs),as.data.frame(dplyr::select(cfg$manifest,PATH,SHA256))))
  sources<-readr::read_csv(file.path(root,'source-manifest.csv'),show_col_types=FALSE)
  products<-readr::read_csv(file.path(root,'product-manifest.csv'),show_col_types=FALSE)
  stopifnot(all(sources$SHA256==vapply(sources$PATH,digest::digest,character(1),algo='sha256',file=TRUE)),
    all(products$SHA256==vapply(file.path(root,products$FILE),digest::digest,character(1),algo='sha256',file=TRUE)))
  tables<-c('paired_support','descent_level_groups','fine_window_level_thresholds',
    'fine_window_time_groups_exact','lower_descent_two_three_minutes','enroute_exact_cell_contrasts',
    'lookup_exact_enroute_wide','feature_share_compatibility','modern_older_same_altitude',
    'enroute_altitude_composition','phase_sector_context','fine_window_source_criteria')
  stats::setNames(lapply(tables,function(n)readr::read_csv(file.path(root,paste0(n,'.csv')),show_col_types=FALSE)),tables)
}
