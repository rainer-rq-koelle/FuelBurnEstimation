#!/usr/bin/env Rscript
source("R/paper-profile-characterisation.R")
source("R/enroute-level-exposure.R")
profiles <- build_paper_profiles()
result <- build_enroute_exposure(profiles)
out <- "outputs/paper-enroute-levels"
dir.create(out,recursive=TRUE,showWarnings=FALSE)
saveRDS(result,file.path(out,"analysis.rds"))
for(name in setdiff(names(result),c("exposure","flight_metrics","boundaries")))
  readr::write_csv(result[[name]],file.path(out,paste0(name,".csv")))
writeLines(capture.output(sessionInfo()),file.path(out,"session-info.txt"))
print(result$summary,n=30)
print(result$boundary_summary,n=20)
