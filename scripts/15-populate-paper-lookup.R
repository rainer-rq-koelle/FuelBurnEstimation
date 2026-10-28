#!/usr/bin/env Rscript
source("R/paper-profile-characterisation.R")
source("R/paper-lookup-table.R")
profiles<-build_paper_profiles()
enroute<-readRDS("outputs/paper-enroute-levels/analysis.rds")
# The enroute class input must match both the pinned inputs and current cohort.
stopifnot(all(enroute$provenance$SHA256==vapply(enroute$provenance$PATH,digest::digest,character(1),algo="sha256",file=TRUE)),
  isTRUE(all.equal(enroute$boundaries[,names(profiles$profiles)],profiles$profiles |>dplyr::filter(COMMON),check.attributes=FALSE)))
result<-build_paper_lookup(profiles,enroute)
out<-"outputs/paper-lookup"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
saveRDS(result,file.path(out,"analysis.rds"))
for(name in setdiff(names(result),"flight_rows"))readr::write_csv(result[[name]],file.path(out,paste0(name,".csv")))
writeLines(capture.output(sessionInfo()),file.path(out,"session-info.txt"))
print(result$quality_summary)
print(result$profile_support,n=30)
print(result$variant_audit)
