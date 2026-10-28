# Read the explicitly built exploratory result layer; never rebuild on render.
load_paper_climb_patterns <- function() {
  cfg<-paper_ref_config()
  path<-file.path(cfg$store,'derived/paper/climb-patterns/PAPER-CLIMB-PATTERNS-2026-10-27-001/analysis.rds')
  if(!file.exists(path))stop('Run Rscript scripts/19-explore-climb-fuel-patterns.R')
  result<-readRDS(path)
  paths<-result$source_fingerprint$PATH
  stopifnot(all(result$source_fingerprint$SHA256==vapply(paths,digest::digest,character(1),algo='sha256',file=TRUE)),
    identical(result$input_manifest,select(cfg$manifest,PATH,SHA256)))
  result
}
