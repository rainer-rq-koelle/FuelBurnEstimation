#!/usr/bin/env Rscript
# Independent conference presentation over the same adopted scientific results.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr)})
source('R/paper-window-references.R')
source('R/paper-climb-patterns.R')
source('R/paper-descent-enroute-lookup.R')
source('R/conference-phase-evidence.R')
study<-load_paper_window_references()
climb<-load_paper_climb_patterns()
review<-load_paper_descent_enroute_lookup()
phase<-load_conference_phase_evidence(study,climb,review)
cfg<-study$config
out<-'notes/results/conference-paper-2026-10-28'
dir.create(out,recursive=TRUE,showWarnings=FALSE)
headings<-grep('^# ',readLines('conference-paper.qmd'),value=TRUE)
stopifnot(identical(headings,c('# Introduction','# Background','# Model, concept, methods, and data',
  '# Results and discussion','# Conclusion','# References {.unnumbered}')))
descent<-phase$descent_comparable_time
entry<-review$lookup_exact_enroute_wide |>
 filter(TYPE=='A21N',BAND100==500,PROFILE_CLASS=='FL340+')
products<-list(source_inventory=study$inventory,
 profile_context=study$enroute$summary |>filter(WINDOW=='Source',TYPE%in%c('A20N','A21N','B738')),
 climb_comparable_time=climb$closer_distance_comparison,
 descent_comparable_time=descent,
 descent_level_time=review$descent_level_groups |>filter(TYPE%in%c('A20N','A21N'),GCD_GROUP=='500-<700',WINDOW=='Descent FL180-FL100'),
 descent_two_minute_split=review$fine_window_level_thresholds |>filter(TYPE%in%c('A20N','A21N'),GCD_GROUP=='500-<700',WINDOW=='Descent FL180-FL100',CUT_MIN==2),
 enroute_reference_cells=review$enroute_exact_cell_contrasts,
 complete_lookup_example=entry,
 fleet_generation=review$modern_older_same_altitude,
 threshold_window_compatibility=review$feature_share_compatibility,
 ground_phase_references=phase$ground,
 ground_fuel_cohort_time_check=phase$ground_fuel_cohort_time_check,
 terminal_lower_references=phase$terminal_references,
 boeing_climb_comparable_time=phase$boeing_climb,
 european_direction=phase$european_direction,
 fleet_climb=phase$fleet_climb,
 descent_fleet_exposure=phase$descent_fleet_exposure,
 boeing_enroute=phase$boeing_enroute,
 boeing_boundary_sensitivity=phase$boeing_boundary_sensitivity,
 fleet_enroute=phase$fleet_enroute)
stopifnot(nrow(products$enroute_reference_cells)==5L,nrow(entry)==2L,
 all(entry$N_KG_NM>=30),all(products$enroute_reference_cells$CENTRAL_OVERLAP_WIDTH>0))
for(n in names(products)){
 stopifnot(!any(c('SOURCE_UID','FLTID','CANDIDATE_ID')%in%names(products[[n]])))
 write_csv(products[[n]],file.path(out,paste0(n,'.csv')))
}
write_csv(select(cfg$manifest,PATH,SHA256),file.path(out,'input-manifest.csv'))
review_sources<-read_csv('notes/results/descent-enroute-lookup-2026-10-28/source-manifest.csv',show_col_types=FALSE)
publication_path<-file.path(out,'icns2025-publication-metadata.json')
publication<-jsonlite::read_json(publication_path)
stopifnot(tolower(publication$publisher_deposited_fields$DOI)=='10.1109/icns65417.2025.10976852',
 publication$publisher_deposited_fields$page=='1-8')
paths<-unique(c('conference-paper.qmd','scripts/22-export-conference-paper-snapshot.R',
 'R/paper-climb-patterns.R','R/paper-descent-enroute-lookup.R','R/conference-phase-evidence.R',
 'scripts/format-paper-docx.py','scripts/format-conference-docx.py',
 'paper-style.tex','paper-references.bib','paper-numeric.csl',study$source_fingerprint$PATH,
 climb$source_fingerprint$PATH,review_sources$PATH,
 'notes/results/descent-enroute-lookup-2026-10-28/product-manifest.csv',publication_path))
write_csv(tibble(PATH=paths,SHA256=vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE)),
 file.path(out,'source-manifest.csv'))
files<-c(paste0(names(products),'.csv'),'input-manifest.csv','source-manifest.csv',basename(publication_path))
write_csv(tibble(FILE=files,SHA256=vapply(file.path(out,files),digest::digest,
 character(1),algo='sha256',file=TRUE)),file.path(out,'product-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
invisible(paper_ref_config())
cat('Conference snapshot:',out,'\n')
