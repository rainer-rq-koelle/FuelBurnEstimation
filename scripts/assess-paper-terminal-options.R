# Compare existing source-3000-ft and FL075 terminal options without new crossings.
# Usage: Rscript scripts/assess-paper-terminal-options.R <new restricted directory>
suppressPackageStartupMessages({library(arrow);library(dplyr);library(tidyr);library(readr)})
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
store<-normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
out<-normalizePath(args[1],mustWork=TRUE)
stopifnot(startsWith(out,paste0(store,'/')),length(list.files(out,all.files=TRUE,no..=TRUE))==0L)
ledger<-file.path(store,'derived/paper/eligibility-comparability/PAPER-2026-10-27-004-lower-ground/restricted-window-eligibility.parquet')
cells_file<-'notes/results/paper-lower-ground-support-2026-10-27/aggregate-type-stage-window-support.csv'
inputs<-c(ledger,cells_file)
hashes<-vapply(inputs,digest::digest,character(1),algo='sha256',file=TRUE)
x<-read_parquet(ledger)
cells<-read_csv(cells_file,show_col_types=FALSE) |>filter(METRIC=='FUEL_OK',PAIRED_SUPPORT) |>
 select(WINDOW,TYPE,BAND100) |>mutate(PAIRED_CELL=TRUE)
windows<-c('Climb-out source LTO','Takeoff-FL075','Approach-landing source LTO','FL075-landing','Climb source LTO-FL075','Descent FL075-source LTO')
y<-x |>filter(WINDOW%in%windows) |>
 mutate(SIDE=if_else(WINDOW%in%c('Climb-out source LTO','Takeoff-FL075','Climb source LTO-FL075'),'Departure','Arrival'),
 AIRPORT=if_else(SIDE=='Departure',ADEP,ADES)) |>
 left_join(cells,by=c('WINDOW','TYPE','BAND100')) |>mutate(PAIRED_CELL=coalesce(PAIRED_CELL,FALSE))
write_csv(y |>group_by(REGION,WINDOW,SIDE,AIRPORT) |>
 summarise(INPUT=n(),TIME_N=sum(TIME_OK),FUEL_N=sum(FUEL_OK),PAIRED_FUEL_N=sum(FUEL_OK&PAIRED_CELL),.groups='drop'),file.path(out,'aggregate-airport-support.csv'))
scenarios<-bind_rows(y |>mutate(SCENARIO='All supplied airports'),y |>filter(REGION!='CHN'|AIRPORT!='ZPPP') |>mutate(SCENARIO='Omit CHN ZPPP at relevant window endpoint'))
write_csv(scenarios |>group_by(SCENARIO,REGION,WINDOW) |>
 summarise(INPUT=n(),FUEL_N=sum(FUEL_OK),PAIRED_FUEL_N=sum(FUEL_OK&PAIRED_CELL),.groups='drop'),file.path(out,'aggregate-airport-scenarios.csv'))
z<-y |>filter(!WINDOW%in%c('Climb source LTO-FL075','Descent FL075-source LTO')) |>
 mutate(OPTION=if_else(grepl('source LTO',WINDOW),'SOURCE_3000','FL075'))
z<-bind_rows(z |>mutate(SCOPE='All eligible source flights'),z |>filter(PAIRED_CELL) |>mutate(SCOPE='Paired aircraft-GCD cells')) |>
 select(REGION,SOURCE_UID,SIDE,SCOPE,OPTION,FUEL_OK) |>pivot_wider(names_from=OPTION,values_from=FUEL_OK)
stopifnot(!anyNA(z$SOURCE_3000),!anyNA(z$FL075))
overlap<-z |>group_by(REGION,SIDE,SCOPE) |>summarise(SOURCE_3000_N=sum(SOURCE_3000),FL075_N=sum(FL075),
 BOTH_N=sum(SOURCE_3000&FL075),SOURCE_ONLY_N=sum(SOURCE_3000&!FL075),FL075_ONLY_N=sum(!SOURCE_3000&FL075),.groups='drop')
stopifnot(all(overlap$SOURCE_3000_N==overlap$BOTH_N+overlap$SOURCE_ONLY_N),all(overlap$FL075_N==overlap$BOTH_N+overlap$FL075_ONLY_N))
write_csv(overlap,file.path(out,'aggregate-terminal-option-overlap.csv'))
stopifnot(identical(hashes,vapply(inputs,digest::digest,character(1),algo='sha256',file=TRUE)))
write_csv(tibble(PATH=c(paste0('data-store/',substring(ledger,nchar(store)+2L)),cells_file),SHA256=hashes),file.path(out,'input-manifest.csv'))
write_csv(tibble(PATH='scripts/assess-paper-terminal-options.R',SHA256=digest::digest('scripts/assess-paper-terminal-options.R',algo='sha256',file=TRUE)),file.path(out,'source-manifest.csv'))
writeLines(capture.output(sessionInfo()),file.path(out,'runtime.txt'))
print(overlap,n=10,width=Inf)
