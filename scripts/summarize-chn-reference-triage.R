# Aggregate comparison of candidate.1 and candidate.2, with restricted case ledger.
# Usage: Rscript scripts/summarize-chn-reference-triage.R <baseline-run> <new-run>
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==2)
store<-normalizePath(Sys.getenv("FUELBURN_DATA_STORE",".fuelburn-data-store"),mustWork=TRUE)
runs<-vapply(args,normalizePath,"",mustWork=TRUE)
stopifnot(all(startsWith(runs,paste0(store,"/"))))
suppressPackageStartupMessages({library(dplyr);library(readr);library(tidyr)})
read<-function(p)read_csv(p,show_col_types=FALSE)
old<-read(file.path(runs[1],"evaluation/flight-quality.csv"))
new<-read(file.path(runs[2],"evaluation/flight-quality.csv"))
out<-file.path(runs[2],"triage")
metrics<-read(file.path(out,"reference-metrics.csv"))
baseline<-old |> filter(ROLE=="historical_reference") |>
  select(INPUT_ID,OLD_EXCLUDE=STUDY_EXCLUDE,OLD_REASONS=UNRESOLVED_REASONS)
x<-new |> filter(ROLE=="historical_reference") |> left_join(baseline,by="INPUT_ID") |>
  left_join(select(metrics,-SOURCE_UID),by="INPUT_ID",suffix=c("","_BASELINE")) |>
  mutate(REVIEW_CLASS=case_when(
    !STUDY_EXCLUDE ~ "included",
    SOURCE_FLOW_COLUMNS<2 ~ "source_required_fuel_channels_absent",
    !TIME_VALID ~ "clock_or_sampling_review",
    position_bad_airborne_rows>0 | altitude_bad_airborne_rows>0 ~ "airborne_motion_or_altitude_review",
    AIRBORNE_WINDOW_SUPPORTED & position_bad_rows>0 & position_bad_airborne_rows==0 ~ "ground_only_position_coverage",
    grepl("repair_budget",UNRESOLVED_REASONS) ~ "repair_share_policy_review",
    grepl("profile_boundaries",UNRESOLVED_REASONS) ~ "milestone_contract_review",
    TRUE ~ "other_review"))
stopifnot(nrow(x)==220,!anyDuplicated(x$INPUT_ID),!any(!x$OLD_EXCLUDE & x$STUDY_EXCLUDE))
write_csv(x,file.path(out,"reference-classification.csv"))
write_csv(count(x,OLD_EXCLUDE,STUDY_EXCLUDE,name="files"),file.path(out,"reference-transitions.csv"))
write_csv(x |> group_by(REVIEW_CLASS) |> summarise(files=n(),flight_identifiers=n_distinct(SOURCE_UID),.groups="drop"),file.path(out,"reference-review-buckets.csv"))
flags<-function(d){d |> filter(ROLE=="historical_reference") |> select(UNRESOLVED_REASONS) |>
  mutate(UNRESOLVED_REASONS=strsplit(coalesce(UNRESOLVED_REASONS,""),";")) |>
  unnest(UNRESOLVED_REASONS) |> filter(nzchar(UNRESOLVED_REASONS)) |> count(UNRESOLVED_REASONS,name="files")}
f<-full_join(rename(flags(old),before=files),rename(flags(new),after=files),by="UNRESOLVED_REASONS") |>
  mutate(across(c(before,after),~replace_na(.x,0L)))
write_csv(f,file.path(out,"rule-flags-before-after.csv"))
fuels<-metrics |> mutate(FUEL_EVIDENCE=case_when(SOURCE_FLOW_COLUMNS<2 ~ "required_channels_absent",
  FUEL_BAD_ROWS_CREATED_BY_SPIKE_RULE>0 ~ "finite_nonnegative_source_flagged_by_spike_rule",
  TRUE ~ "no_unresolved_fuel_rows")) |> count(FUEL_EVIDENCE,name="files")
write_csv(fuels,file.path(out,"fuel-source-vs-rule.csv"))
clock<-read(file.path(out,"clock-replication-evidence.csv")) |>
  inner_join(filter(x,grepl("ambiguous_clock",OLD_REASONS)) |> select(INPUT_ID),by="INPUT_ID")
write_csv(clock |> group_by(COLUMN) |> summarise(files=n(),min_distinct_observations=min(DISTINCT_OBSERVATIONS),
  max_row_expansion=max(RAW_ROWS/DISTINCT_OBSERVATIONS),min_collapsed_score=min(COLLAPSED_SCORE),
  max_collapsed_score=max(COLLAPSED_SCORE),.groups="drop"),file.path(out,"clock-score-summary.csv"))
print(count(x,REVIEW_CLASS,name="files"),n=20)
print(count(x,OLD_EXCLUDE,STUDY_EXCLUDE,name="files"))
