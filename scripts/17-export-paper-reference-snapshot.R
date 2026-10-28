#!/usr/bin/env Rscript
# Export only identifier-free paper tables; detailed views remain restricted.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr)})
source('R/enroute-level-exposure.R');source('R/paper-window-references.R')
x<-load_paper_window_references()
out<-'notes/results/paper-window-references-2026-10-27'
dir.create(out,recursive=TRUE,showWarnings=FALSE)
pair<-x$paired_cells |>filter(METRIC=='FUEL_KG',PAIRED_SUPPORT) |>select(TYPE,BAND100,WINDOW)
paired_wide<-x$wide_grid |>semi_join(pair,by=c('TYPE','BAND100','WINDOW'))
write_csv(paired_wide |>filter(WINDOW%in%x$config$core_windows),file.path(out,'core-references.csv'))
write_csv(paired_wide |>filter(WINDOW%in%x$config$terminal_options),file.path(out,'terminal-references.csv'))
write_csv(paired_wide |>filter(FAMILY=='Ground'),file.path(out,'ground-references.csv'))
for(n in c('inventory','types','dates','support','paired_support','paired_cells','overview','enroute_support','fuel_convention','profile_state'))
 write_csv(x[[n]],file.path(out,paste0(n,'.csv')))
for(n in c('summary','paired_summary','band_summary','boundary_summary','support'))
 write_csv(x$enroute[[n]],file.path(out,paste0('enroute-',n,'.csv')))
write_csv(x$grid |>filter(WINDOW%in%x$config$core_windows,PAIRED_SUPPORT,METRIC%in%c('FUEL_KG','DURATION_MIN','KG_MIN')) |>
 select(REGION,TYPE,BAND100,WINDOW,METRIC,N,P50) |>pivot_wider(names_from=REGION,values_from=c(N,P50)) |>
 mutate(P50_CHN_OVER_EUR=P50_CHN/P50_EUR),file.path(out,'median-ratios.csv'))
write_csv(select(x$config$manifest,-LOCAL_PATH),file.path(out,'input-manifest.csv'))
paths<-c(x$source_fingerprint$PATH,'scripts/17-export-paper-reference-snapshot.R',
 'tests/paper-window-references.R','tests/paper-window-adoption.R','paper.qmd','paper-style.tex','paper-references.bib','paper-numeric.csl')
paths<-c(paths,'scripts/format-paper-docx.py')
paths<-c(paths,'config/paper-profile-classes-2026-10-27.json','R/paper-profile-classes.R',
 'scripts/18-characterise-paper-interruptions.R','tests/paper-profile-classes.R',
 'tests/paper-profile-class-adoption.R','notes/paper-profile-classes.md')
paths<-c(paths,'R/paper-climb-patterns.R','scripts/19-explore-climb-fuel-patterns.R',
 'notes/results/paper-climb-patterns-2026-10-27/README.md')
paths<-c(paths,'R/paper-descent-enroute-lookup.R','scripts/21-review-descent-enroute-lookup.R',
 'notes/results/descent-enroute-lookup-2026-10-28/README.md',
 'notes/results/descent-enroute-lookup-2026-10-28/product-manifest.csv')
write_csv(tibble(PATH=paths,SHA256=vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE)),file.path(out,'source-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'session-info.txt'))
for(p in list.files(out,'[.]csv$',full.names=TRUE))
 stopifnot(!any(names(read_csv(p,show_col_types=FALSE))%in%c('SOURCE_UID','FLTID','INPUT_ID')))
cat('Paper snapshot:',out,'\n')
