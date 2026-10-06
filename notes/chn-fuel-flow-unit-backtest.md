# CHN Fuel-Flow Unit Back-Test

## Scope

The new fuel-flow unit QC was back-tested on the locally available 2025 CHN QAR archives from `../paper-2025-ICNS-CHN-EUR-fuelburn/data`:

- `fuel data-LL.zip`
- `fuel data-lingling0201.zip`
- `0210data-linglingadd milestones and flightphase.zip`
- `0210data2-linglingadd milestones and flightphase.zip`

The repeatable audit script is `scripts/02-audit-chn-fuel-flow-units.R`. It writes the detailed row-level result to `data-derived/CHN-fuel-flow-unit-backtest.csv`, which is intentionally ignored by Git.

## Result

The current back-test found:

- 220 CSV files in the four archives.
- 192 files with auditable fuel-flow columns.
- 28 files without `FF*C` fuel-flow columns; these are not fuel-burn auditable with the current helper.
- 192 of 192 auditable flights inferred as `kg/h`.
- 0 auditable flights inferred as `lb/h`.
- 0 auditable flights marked for unit review.

The auditable set covered these aircraft-type labels:

- `B737-800`: 129 flights
- `A320`: 30 flights
- `A330-300`: 17 flights
- `A320-NEO`: 10 flights
- `B787-9`: 6 flights

The median selected total fuel burn was about 5.0 tonnes. Under a hypothetical `lb/h` interpretation, the median would be about 2.3 tonnes. The plausibility score therefore consistently preferred the original kg/h interpretation.

## Additional Finding

This test also exposed a reader-compatibility issue in the old raw files: several archives contain both `Time` and `TIME` columns. The reader now makes uppercase column names unique and prefers `TIME.1` when it exists, which corresponds to the clock-time column in the historical files.

The 28 non-auditable files in `fuel data-lingling0201.zip` appear to be trajectory-only extracts without fuel-flow columns. They should not be used for fuel-burn integration unless a fuel-flow or fuel-quantity field is provided.

## Interpretation

For the historical CHN files available locally, we do not see evidence that a kg/lb mix-up affected the previously auditable fuel-burn calculations. The new check is still valuable because it now makes that assumption explicit, produces a compact QC table for Lingling to send back, and would catch a future batch reported in lb/h.

## ZBAA-ZSPD Download Check

On 2026-10-06, the Downloads folder contained two copies of the same ZIP file:

- `/Users/rainerkoelle/Downloads/ZBAA-ZSPD Fuel data.zip`
- `/Users/rainerkoelle/Downloads/ZBAA-ZSPD Fuel data (1).zip`

The two files have the same SHA-256 hash, so they are duplicate downloads of one package. The package contains 132 CSV files for July 2025:

- `ZBAA-ZSPD`: 117 flights
- `ZSPD-ZBAA`: 15 flights
- date range: 2025-07-01 to 2025-07-31

The unit audit result for this package was:

- 132 files read successfully.
- 132 inferred as `kg/h` with high confidence.
- 0 inferred as `lb/h`.
- 0 marked for manual unit review.
- median selected total fuel burn: about 5.1 tonnes.
- median hypothetical `lb/h` total: about 2.3 tonnes.

This package is not additional relative to the already processed `../international-CHN-EUR-2025/data/fuel-burn-study/chn-zbaa-zspd-vfe/CHN-ZBAA-ZSPD-canonical-milestones.csv` output: all 132 `SOURCE_UID` values overlap. It is, however, the raw July 2025 ZBAA-ZSPD package underlying that processed output and should be treated as useful provenance/reference material.
