#!/usr/bin/env Rscript
# Plot descent profiles with orphaned level segments - ONLY flights with actual orphans

library(arrow)
library(dplyr)
library(ggplot2)
library(purrr)

cat("Loading data...\n")

# Read harmonized milestones
milestones <- read_parquet("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet")

# Find flights with orphaned descent segments below FL100
orphan_flights <- milestones %>%
  filter(MST == "LVL_START", ALT < 10000) %>%
  arrange(UID, TIME) %>%
  group_by(UID) %>%
  mutate(lvl_start_id = row_number()) %>%
  ungroup() %>%
  # For each LVL_START, check if there's a matching LVL_END after it
  rowwise() %>%
  mutate(
    has_end = any(milestones$MST[milestones$UID == UID & milestones$TIME > TIME] == "LVL_END")
  ) %>%
  ungroup() %>%
  filter(!has_end) %>%
  pull(UID) %>%
  unique()

cat(sprintf("Found %d flights with orphaned descent level segments\n", length(orphan_flights)))

# Sample 12 flights
set.seed(42)
sample_flights <- sample(orphan_flights, min(12, length(orphan_flights)))

# Get full trajectory for sample flights
plot_data <- milestones %>%
  filter(UID %in% sample_flights) %>%
  arrange(UID, TIME) %>%
  group_by(UID) %>%
  mutate(
    time_min = as.numeric(difftime(TIME, min(TIME), units = "mins")),
    is_lvl_start = MST == "LVL_START" & ALT < 10000,
    is_lvl_end = MST == "LVL_END",
    is_tod = MST == "TOD",
    is_landing = MST %in% c("ALDT", "AIBT")
  ) %>%
  # Mark orphaned starts
  group_by(UID) %>%
  mutate(
    is_orphan = is_lvl_start & !any(is_lvl_end[row_number() < cur_group_id()])
  ) %>%
  ungroup()

# Create plots
cat("Creating plots...\n")

library(patchwork)

plots <- map(sample_flights[1:min(6, length(sample_flights))], function(flt) {
  flt_data <- plot_data %>% filter(UID == flt)

  # Focus on descent (from TOD)
  tod_idx <- which(flt_data$is_tod)[1]
  if (is.na(tod_idx)) tod_idx <- 1
  descent_data <- flt_data %>% slice(tod_idx:n())

  ggplot(descent_data, aes(x = time_min, y = ALT)) +
    geom_line(color = "steelblue", linewidth = 0.8) +
    geom_point(data = filter(descent_data, is_tod),
               color = "orange", size = 3, shape = 17) +
    geom_point(data = filter(descent_data, is_lvl_start, !is_orphan),
               color = "green4", size = 3) +
    geom_point(data = filter(descent_data, is_lvl_start, is_orphan),
               color = "darkgreen", size = 4, shape = 1, stroke = 2) +
    geom_point(data = filter(descent_data, is_lvl_end),
               color = "red", size = 3) +
    geom_point(data = filter(descent_data, is_landing),
               color = "black", size = 4, shape = 15) +
    geom_hline(yintercept = 10000, linetype = "dashed", color = "gray50", alpha = 0.5) +
    labs(
      title = sprintf("%s", substr(flt, 1, 35)),
      subtitle = sprintf("Orphan: %.0f ft | Landing: %.0f ft",
                        mean(filter(descent_data, is_orphan)$ALT, na.rm = TRUE),
                        last(filter(descent_data, is_landing)$ALT)),
      x = "Time (min)",
      y = "Altitude (ft)"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(size = 8))
})

combined <- wrap_plots(plots, ncol = 2) +
  plot_annotation(
    title = "Orphaned Level Segments in Final Approach",
    subtitle = "Green circle = ORPHANED LVL_START | Green = LVL_START | Red = LVL_END | Orange = TOD | Black = Landing",
    theme = theme(plot.title = element_text(size = 13, face = "bold"))
  )

ggsave("notes/figures/orphan-descent-profiles-v2.png", combined, width = 14, height = 10, dpi = 150)
cat("✓ Saved: notes/figures/orphan-descent-profiles-v2.png\n")
