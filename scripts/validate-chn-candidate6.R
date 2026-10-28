# Paired candidate.5/candidate.6 checks. All input mappings and results stay restricted.
# Usage: Rscript scripts/validate-chn-candidate6.R <new restricted run directory>
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
run<-normalizePath(args[1],mustWork=TRUE);store<-normalizePath(Sys.getenv('FUELBURN_DATA_STORE','.fuelburn-data-store'),mustWork=TRUE)
stopifnot(startsWith(run,paste0(store,'/')))
suppressPackageStartupMessages({library(dplyr);library(readr)})
root5<-file.path(run,'baseline-package/CHN-fuel-burn-helper-2.0.0-candidate.5')
load_helper<-function(root){e<-new.env();sys.source(file.path(root,'R/legacy-core.R'),e);sys.source(file.path(root,'R/chn-qar.R'),e);e}
a<-load_helper(root5);b<-load_helper('helpers/chn-qar-v2');stopifnot(a$chn_version=='2.0.0-candidate.5',b$chn_version=='2.0.0-candidate.6')
inputs<-read_csv(file.path(run,'input-manifest.csv'),col_types=cols(.default='c'))
warn<-list();comparisons<-list();qc<-list();accounting<-list();results<-list()
process<-function(e,inp,cfg)withCallingHandlers(e$chn_process_flight(inp$PATH,cfg,keep_trajectory=TRUE),warning=function(w){warn[[length(warn)+1L]]<<-tibble(INPUT_ID=inp$INPUT_ID,VERSION=e$chn_version,WARNING=conditionMessage(w));invokeRestart('muffleWarning')})
compare<-function(x,y,id,mode){
 stopifnot(setequal(names(x),names(y)))
 for(n in names(x))if(is.data.frame(x[[n]])) {
  p<-x[[n]];q<-y[[n]];extra<-setdiff(names(q),names(p));missing<-setdiff(names(p),names(q))
  stopifnot(!length(missing),all(extra%in%c('BRACKET_FROM_ROW','BRACKET_TO_ROW')),nrow(p)==nrow(q))
  for(col in extra){stopifnot(all(is.na(q[[col]])));p[[col]]<-rep(NA_integer_,nrow(p))}
  cols<-setdiff(names(p),'HELPER_VERSION')
  ok<-isTRUE(all.equal(as.data.frame(p[,cols,drop=FALSE]),as.data.frame(q[,cols,drop=FALSE]),check.attributes=FALSE,tolerance=0))
  comparisons[[length(comparisons)+1L]]<<-tibble(INPUT_ID=id,MODE=mode,TABLE=n,ROWS=nrow(p),IDENTICAL_ANALYTICAL_VALUES=ok,SCHEMA_ADDITIONS=paste(extra,collapse=';'))
  if(!ok)stop('Analytical difference: ',id,' / ',mode,' / ',n)
 }
}
check_accounting<-function(z,id){
 tr<-z$trajectory;q<-attr(tr,'quality');air<-z$airborne_summary;fine<-z$phase_intervals;ap<-z$airborne_phases
 fuelerr<-if(q$window_ok&&q$air_time&&q$air_fuel)abs(air$FUEL_KG-sum(tr$FF_TOTAL_KGPH[q$atot:(q$aldt-1L)]*tr$DT_SEC[q$atot:(q$aldt-1L)]/3600))else NA_real_
 partitionerr<-if(nrow(ap)==3&&all(is.finite(ap$FUEL_KG)))abs(sum(ap$FUEL_KG)-air$FUEL_KG)else NA_real_
 fineerr<-if(q$window_ok&&q$air_time&&q$air_fuel)abs(sum(fine$FUEL_KG)-air$FUEL_KG)else NA_real_
 stopifnot(all(is.na(c(fuelerr,partitionerr,fineerr))|c(fuelerr,partitionerr,fineerr)<1e-6),z$qc$STUDY_EXCLUDE||(z$qc$ELIGIBLE_FUEL_TIME&&z$qc$ELIGIBLE_DISTANCE))
 accounting[[length(accounting)+1L]]<<-tibble(INPUT_ID=id,AIRBORNE_FUEL_ERROR_KG=fuelerr,PARTITION_FUEL_ERROR_KG=partitionerr,FINE_FUEL_ERROR_KG=fineerr)
}
checkpoint<-file.path(run,'paired-input-checkpoints');dir.create(checkpoint,showWarnings=FALSE)
worker<-function(i) {
 inp<-inputs[i,];stopifnot(digest::digest(file=inp$PATH,algo='sha256')==inp$SHA256)
 cp<-file.path(checkpoint,paste0(inp$INPUT_ID,'.rds'))
 if(file.exists(cp))return(readRDS(cp))
 # Forked workers have isolated copies of the diagnostic accumulators.
 warn<<-list();comparisons<<-list();accounting<<-list()
 x<-process(a,inp,a$chn_config());y<-process(b,inp,b$chn_config())
 compare(x,y,inp$INPUT_ID,'default');check_accounting(y,inp$INPUT_ID)
 z<-y$qc;z$INPUT_ID<-inp$INPUT_ID;z$ROLE<-inp$ROLE
 kept<-if(inp$ROLE%in%c('verification','additional_verification'))y else NULL
 ans<-list(comparisons=bind_rows(comparisons),warnings=bind_rows(warn),accounting=bind_rows(accounting),qc=z,result=kept)
 saveRDS(ans,cp);cat('Paired default check complete:',i,'of',nrow(inputs),'\n');ans
}
# Two local R workers; no external services or delegated agents are involved.
jobs<-parallel::mclapply(seq_len(nrow(inputs)),worker,mc.cores=2L,mc.preschedule=FALSE)
stopifnot(!any(vapply(jobs,inherits,TRUE,'try-error')))
comparisons<-list(bind_rows(lapply(jobs,`[[`,'comparisons')))
warn<-list(bind_rows(lapply(jobs,`[[`,'warnings')))
accounting<-list(bind_rows(lapply(jobs,`[[`,'accounting')))
qc<-lapply(jobs,`[[`,'qc')
for(i in seq_along(jobs))if(!is.null(jobs[[i]]$result))results[[inputs$INPUT_ID[i]]]<-jobs[[i]]$result
# Carry only verified exact-input reviews into a new version-specific private file.
review5<-read_csv(file.path(run,'candidate5-approved-repair-shares.csv'),show_col_types=FALSE)
review6<-review5;review6$HELPER_VERSION<-b$chn_version
for(i in seq_len(nrow(review6)))stopifnot(review6$SHA256[i]%in%inputs$SHA256)
dir.create(file.path(run,'review'),showWarnings=FALSE)
write_csv(review6,file.path(run,'review/approved-repair-shares.csv'))
ca<-a$chn_config(list(repair_review_path=normalizePath(file.path(run,'candidate5-approved-repair-shares.csv'))))
cb<-b$chn_config(list(repair_review_path=normalizePath(file.path(run,'review/approved-repair-shares.csv'))))
reviewedqc<-list()
for(i in seq_len(nrow(review6))) {
 inp<-inputs[match(review6$SHA256[i],inputs$SHA256),];x<-process(a,inp,ca);y<-process(b,inp,cb)
 compare(x,y,inp$INPUT_ID,'private_review');stopifnot(!y$qc$STUDY_EXCLUDE,y$qc$POSITION_SHARE_REVIEW_APPROVED)
 z<-y$qc;z$INPUT_ID<-inp$INPUT_ID;reviewedqc[[i]]<-z
 stopifnot(!b$chn_review_approved(inp$PATH,b$chn_config(list(repair_review_path=ca$repair_review_path)),'position',y$qc$AIRBORNE_POSITION_REPAIR_SHARE))
}
write_csv(bind_rows(comparisons),file.path(run,'paired-table-comparisons.csv'))
write_csv(bind_rows(qc),file.path(run,'default-flight-quality.csv'))
write_csv(bind_rows(reviewedqc),file.path(run,'reviewed-flight-quality.csv'))
write_csv(bind_rows(accounting),file.path(run,'accounting-validation.csv'))
write_csv(bind_rows(warn),file.path(run,'warnings.csv'))
saveRDS(results,file.path(run,'candidate6-verification-results.rds'))
counts<-bind_rows(qc) |> group_by(ROLE) |> summarise(FILES=n(),INCLUDED=sum(!STUDY_EXCLUDE),HELD=sum(STUDY_EXCLUDE),WHOLE_AIRBORNE_FUEL_TIME=sum(WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE),.groups='drop')
write_csv(counts,file.path(run,'aggregate-default-cohort.csv'));print(counts)
stopifnot(!any(bind_rows(warn)$VERSION==b$chn_version))
jsonlite::write_json(list(default_inputs=nrow(inputs),private_review_inputs=nrow(review6),paired_tables=nrow(bind_rows(comparisons)),all_analytical_values_identical=TRUE,candidate6_warnings=0,candidate5_warnings=nrow(bind_rows(warn)),private_approvals_not_bundled=TRUE),file.path(run,'validation-summary.json'),pretty=TRUE,auto_unbox=TRUE)
writeLines(capture.output(sessionInfo()),file.path(run,'runtime.txt'))
