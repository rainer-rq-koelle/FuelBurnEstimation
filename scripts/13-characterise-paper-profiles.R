#!/usr/bin/env Rscript
source("R/paper-profile-characterisation.R")
result <- build_paper_profiles()
out <- "outputs/paper-profile-characterisation"
dir.create(out, recursive=TRUE, showWarnings=FALSE)
saveRDS(result, file.path(out,"analysis.rds"))
for (name in setdiff(names(result), c("flights","profiles")))
  readr::write_csv(result[[name]], file.path(out,paste0(name,".csv")))
readr::write_csv(result$flights, file.path(out,"restricted-flight-screen.csv"))
writeLines(capture.output(sessionInfo()), file.path(out,"session-info.txt"))
print(result$inventory)
print(result$exclusions)
print(filter(result$support, COMMON))
print(result$summary, n=30)
