# Orientation Notes

## 2025 Starting Point

- The 2025 ICNS workspace is at `../paper-2025-ICNS-CHN-EUR-fuelburn`.
- The project mixes exploratory analysis, technical data preparation, and paper drafting in Quarto files.
- `study-00-data-prep-chn2.qmd` is the clearest CHN data-preparation reference.
- `study-00-data-prep.qmd` contains the broader CHN/EUR setup and EUR comparator work.
- `study-09-results.qmd` contains the first cross-region fuel-burn summaries and additional-burn metrics.

## CHN Data Shared Last Year

- Two main updated source archives:
  - `0210data-linglingadd milestones and flightphase.zip`
  - `0210data2-linglingadd milestones and flightphase.zip`
- Main analytic CHN output:
  - `CHN-fuel-msts-study-0210data1+2.parquet`
- Supporting metadata:
  - `meta-chn-fuel.csv`
  - `CHN-meta-flts-adps.csv`
  - `ourairports-20241227.csv`

## Reusable Ideas

- Treat each flight as a trajectory with milestones.
- Preserve provided CHN milestones where available.
- Summarise phase fuel burn with AOBT, ATOT, D100, A100, ALDT, and AIBT.
- Keep technical data preparation separate from the paper narrative.

## Watch Items

- Confirm CHN fuel-flow units before finalising fuel-burn calculations.
- Decide how to treat taxi-out and taxi-in for cross-region comparability.
- Avoid copying large or sensitive data into Git unless explicitly agreed.
- The 2025 project currently has uncommitted local changes and should be treated as a reference source, not a clean dependency.
