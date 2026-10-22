#!/usr/bin/env Rscript
# Convert FIXED canonical data to OLD schema for pipeline compatibility

library(arrow)
library(dplyr)

cat("Converting FIXED data to OLD pipeline schema...\n\n")

# Read FIXED
fixed <- read_parquet("data-store/raw/eur/EUR-canonical-milestones-summer2025-FIXED.parquet")
cat(sprintf("✓ Read FIXED: %s records\n", format(nrow(fixed), big.mark = ",")))

# Transform to OLD column names that pipeline expects
old_schema <- fixed %>%
  transmute(
    UID = SOURCE_UID,
    TIME,
    LAT,
    LON,
    ALT = ALT_FT,
    MST,
    TOT_FUEL = TOT_FUEL_KG,
    PHASE = FLIGHT_PHASE_RAW,
    TYPE,
    OPERATOR = NA_character_,  # Not in FIXED data
    ADEP,
    ADES,
    SOURCE = "PRU_G2G_FIXED",
    FIR_ID = NA_character_,    # Not in FIXED data
    AUA_ID = NA_character_     # Not in FIXED data
  )

cat(sprintf("✓ Transformed to OLD schema: %s records\n", format(nrow(old_schema), big.mark = ",")))

# Save
write_parquet(old_schema, "data-derived/canonical-milestones-eur-2025-summer.parquet")
cat("✓ Saved: data-derived/canonical-milestones-eur-2025-summer.parquet\n")

cat("\n✅ FIXED data now in OLD schema format\n")
cat("The existing pipeline scripts should now work!\n")
