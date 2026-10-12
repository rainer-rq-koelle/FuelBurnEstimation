#!/bin/bash
# Run verification pipeline using existing scripts with FIXED data

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  EUR FIXED Verification Using Existing Scripts               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Set paths for FIXED data
export FUELBURN_EUR_CANONICAL_MILESTONES="data-store/raw/eur/EUR-canonical-milestones-summer2025-FIXED.parquet"
export FUELBURN_EUR_HARMONIZED_MILESTONES="data-derived/eur/EUR-harmonized-milestones-summer2025-FIXED.parquet"

echo ""
echo "=== STEP 1: Harmonize FIXED milestones ==="
Rscript scripts/04-harmonize-eur-milestones.R

echo ""
echo "=== STEP 2: Derive FIXED level segments ==="
Rscript scripts/05-derive-eur-level-segments.R

echo ""
echo "=== STEP 3: Compare orphan rates ==="
Rscript -e "
library(readr)
library(dplyr)

old_qc <- read_csv('data-derived/eur/EUR-level-qc-detail.csv', show_col_types = FALSE)
fixed_qc <- read_csv('data-derived/eur/EUR-level-qc-detail-FIXED.csv', show_col_types = FALSE)

orphan_old <- old_qc %>% filter(orphaned_no_end) %>% distinct(SOURCE_UID)
orphan_fixed <- fixed_qc %>% filter(orphaned_no_end) %>% distinct(SOURCE_UID)

total_old <- n_distinct(old_qc\$SOURCE_UID)
total_fixed <- n_distinct(fixed_qc\$SOURCE_UID)

rate_old <- 100 * nrow(orphan_old) / total_old
rate_fixed <- 100 * nrow(orphan_fixed) / total_fixed

improvement <- rate_old - rate_fixed
pct_reduction <- 100 * improvement / rate_old

cat(sprintf('\n📊 RESULTS:\n'))
cat(sprintf('OLD:   %.1f%% orphan rate (%s / %s flights)\n', rate_old, format(nrow(orphan_old), big.mark=','), format(total_old, big.mark=',')))
cat(sprintf('FIXED: %.1f%% orphan rate (%s / %s flights)\n', rate_fixed, format(nrow(orphan_fixed), big.mark=','), format(total_fixed, big.mark=',')))
cat(sprintf('\n🎯 IMPROVEMENT: %.1f pp (%.1f%% reduction)\n', improvement, pct_reduction))

if (rate_fixed < 20) {
  cat('\n✅ SUCCESS - LOBT filter bug FIXED!\n')
} else {
  cat('\n⚠️  Review needed - orphan rate still high\n')
}
"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  VERIFICATION COMPLETE                                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
