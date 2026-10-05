# Shared setup for paper and technical notes.

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(gt)
})

ggplot2::theme_set(ggplot2::theme_minimal())

source(here::here("R", "paths.R"))
source(here::here("R", "canonical-fuel-milestones.R"))
source(here::here("R", "phase-summary.R"))
