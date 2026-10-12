#!/usr/bin/env Rscript
# Plot descent profiles with orphaned level segments

library(arrow)
library(dplyr)
library(ggplot2)
library(purrr)

cat("Loading data...\n")

# Read harmonized milestones
milestones <- read_parquet("data-store/derived/eur/canonical-milestones-eur-2026-harmonized.parquet")

# Find flights with orphaned descent segments below FL100
orphan_flights <- milestones %>%
  group_by(UID) %>%
  mutate(
    has_lvl_start = any(MST == "LVL_START" & ALT < 10000),
    next_mst = lead(MST),
    is_orphan_start = MST == "LVL_START" & ALT < 10000 &
                      (is.na(next_mst) | !any(MST[row_number() > cur_group_id()] == "LVL_END"))
  ) %>%
  filter(has_lvl_start, any(is_orphan_start)) %>%
  ungroup() %>%
  distinct(UID) %>%
  pull(UID)

cat(sprintf("Found %d flights with orphaned descent level segments\n", length(orphan_flights)))

# Sample 12 flights for plotting
set.seed(42)
sample_flights <- sample(orphan_flights, min(12, length(orphan_flights)))

# Get trajectory data for sample flights
plot_data <- milestones %>%
  filter(UID %in% sample_flights) %>%
  arrange(UID, TIME) %>%
  group_by(UID) %>%
  mutate(
    time_min = as.numeric(difftime(TIME, min(TIME), units = "mins")),
    is_descent = grepl("descent|approach|landing", PHASE, ignore.case = TRUE),
    is_lvl_start = MST == "LVL_START",
    is_lvl_end = MST == "LVL_END",
    is_tod = MST == "TOD",
    is_landing = MST %in% c("ALDT", "AIBT")
  ) %>%
  ungroup()

# Create individual plots
cat("Creating descent profile plots...\n")

plots <- map(sample_flights[1:min(6, length(sample_flights))], function(flt) {
  flt_data <- plot_data %>% filter(UID == flt)

  # Find descent start
  tod_time <- flt_data %>% filter(is_tod) %>% pull(time_min) %>% first()
  if (length(tod_time) == 0) tod_time <- 0

  # Focus on descent
  descent_data <- flt_data %>% filter(time_min >= tod_time)

  # Find orphaned LVL_START
  orphan_starts <- descent_data %>%
    filter(is_lvl_start, ALT < 10000) %>%
    mutate(has_end = any(descent_data$is_lvl_end[descent_data$time_min > time_min]))

  ggplot(descent_data, aes(x = time_min, y = ALT)) +
    geom_line(color = "steelblue", linewidth = 0.8) +
    geom_point(data = filter(descent_data, is_tod),
               aes(x = time_min, y = ALT),
               color = "orange", size = 3, shape = 17) +
    geom_point(data = filter(descent_data, is_lvl_start),
               aes(x = time_min, y = ALT),
               color = "green4", size = 3) +
    geom_point(data = filter(descent_data, is_lvl_end),
               aes(x = time_min, y = ALT),
               color = "red", size = 3) +
    geom_point(data = filter(descent_data, is_landing),
               aes(x = time_min, y = ALT),
               color = "black", size = 3, shape = 15) +
    geom_hline(yintercept = 10000, linetype = "dashed", color = "gray50", alpha = 0.5) +
    labs(
      title = sprintf("Flight: %s", substr(flt, 1, 30)),
      subtitle = sprintf("Orphaned LVL_START: %d at %.0f ft (mean)",
                        nrow(filter(orphan_starts, !has_end)),
                        mean(filter(orphan_starts, !has_end)$ALT, na.rm = TRUE)),
      x = "Time from Flight Start (minutes)",
      y = "Altitude (feet)"
    ) +
    theme_minimal() +
    theme(plot.title = element_text(size = 9))
})

# Combine plots
library(patchwork)
combined_plot <- wrap_plots(plots, ncol = 2) +
  plot_annotation(
    title = "Descent Profiles with Orphaned Level Segments (Below FL100)",
    subtitle = "Green = LVL_START | Red = LVL_END | Orange = TOD | Black = Landing | Dashed = FL100",
    theme = theme(plot.title = element_text(size = 14, face = "bold"))
  )

# Save
output_file <- "notes/figures/orphan-descent-profiles.png"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
ggsave(output_file, combined_plot, width = 14, height = 10, dpi = 150)
cat(sprintf("✓ Saved: %s\n", output_file))

# Create altitude distribution plot
cat("\nCreating orphan altitude distribution...\n")

orphan_altitudes <- milestones %>%
  filter(UID %in% orphan_flights) %>%
  group_by(UID) %>%
  filter(MST == "LVL_START", ALT < 10000) %>%
  mutate(
    next_rows = list(tail(MST[row_number() >= cur_group_id()], -1)),
    has_end = map_lgl(next_rows, ~"LVL_END" %in% .)
  ) %>%
  filter(!has_end) %>%
  ungroup()

altitude_plot <- ggplot(orphan_altitudes, aes(x = ALT)) +
  geom_histogram(binwidth = 500, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = mean(orphan_altitudes$ALT, na.rm = TRUE),
             color = "red", linetype = "dashed", linewidth = 1) +
  annotate("text",
           x = mean(orphan_altitudes$ALT, na.rm = TRUE) + 500,
           y = Inf, vjust = 1.5,
           label = sprintf("Mean: %.0f ft", mean(orphan_altitudes$ALT, na.rm = TRUE)),
           color = "red", fontface = "bold") +
  labs(
    title = "Altitude Distribution of Orphaned LVL_START (Below FL100)",
    subtitle = sprintf("n = %d orphaned descent level segments", nrow(orphan_altitudes)),
    x = "Altitude (feet)",
    y = "Count"
  ) +
  theme_minimal()

altitude_file <- "notes/figures/orphan-altitude-distribution.png"
ggsave(altitude_file, altitude_plot, width = 10, height = 6, dpi = 150)
cat(sprintf("✓ Saved: %s\n", altitude_file))

# Summary statistics
cat("\n=== Orphan Altitude Statistics ===\n")
cat(sprintf("Count: %d\n", nrow(orphan_altitudes)))
cat(sprintf("Mean: %.0f ft\n", mean(orphan_altitudes$ALT, na.rm = TRUE)))
cat(sprintf("Median: %.0f ft\n", median(orphan_altitudes$ALT, na.rm = TRUE)))
cat(sprintf("Min: %.0f ft\n", min(orphan_altitudes$ALT, na.rm = TRUE)))
cat(sprintf("Max: %.0f ft\n", max(orphan_altitudes$ALT, na.rm = TRUE)))
cat(sprintf("25th percentile: %.0f ft\n", quantile(orphan_altitudes$ALT, 0.25, na.rm = TRUE)))
cat(sprintf("75th percentile: %.0f ft\n", quantile(orphan_altitudes$ALT, 0.75, na.rm = TRUE)))

cat("\nPlots created successfully!\n")
