# Fuel-Flow Unit QC

## Purpose

The CHN QAR helper now checks whether the `FF*C` fuel-flow columns are more plausible as `kg/h` or `lb/h` before calculating canonical fuel-burn outputs.

This check is part of source-specific CHN preparation. The harmonised outputs remain kilogram-based:

- `FF_TOTAL_RAW` preserves the row-level fuel-flow sum in source units.
- `FF_UNIT_INFERRED` records the selected unit.
- `FF_KG_PER_RAW_UNIT` records the conversion factor.
- `FF_TOTAL_RAW_KGPH`, `FF_TOTAL_KGPH`, `FUEL_BURNT_KG`, and `TOT_FUEL_KG` are canonical kilogram-based fields.

## How It Works

For each flight, the helper computes candidate totals under both assumptions:

- `kg/h`: raw fuel-flow values are already kilograms per hour.
- `lb/h`: raw fuel-flow values are pounds per hour and are multiplied by `0.45359237`.

The candidates are scored against broad aircraft-type plausibility ranges for:

- total fuel burn per nautical mile,
- average fuel burn rate in kg/h,
- median total fuel flow in kg/h.

The scoring is deliberately broad. It is intended to catch the kg/lb factor-of-2.205 ambiguity, not to validate detailed aircraft performance.

## Output

The scripts write `CHN-fuel-flow-unit-qc.csv` with one row per flight. Important columns are:

- `burn_if_kg`, `burn_if_lb`
- `burn_per_nm_if_kg`, `burn_per_nm_if_lb`
- `burn_rate_kgph_if_kg`, `burn_rate_kgph_if_lb`
- `inferred_unit`
- `unit_confidence`
- `unit_flag`
- `review_required`

Flights with `review_required == TRUE` should be checked before the output is used in the paper analysis.

## Override

The default mode is automatic inference:

```sh
Rscript scripts/prepare-chn-qar-canonical.R <qar_input> <output_dir> <airport_meta> auto
```

The unit can be forced when the source system is known:

```sh
Rscript scripts/prepare-chn-qar-canonical.R <qar_input> <output_dir> <airport_meta> kg/h
Rscript scripts/prepare-chn-qar-canonical.R <qar_input> <output_dir> <airport_meta> lb/h
```

For the standalone helper:

```sh
Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R <qar_input> <output_dir> auto
Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R <qar_input> <output_dir> kg/h
Rscript HELPER-FOR-LINGLING-fuel-burn-processing.R <qar_input> <output_dir> lb/h
```

The environment variable `CHN_QAR_FUEL_FLOW_UNIT` can also be set to `auto`, `kg/h`, or `lb/h`.

## Interpretation

- `unit_confidence == "high"`: the preferred assumption is clearly more plausible.
- `unit_confidence == "medium"`: likely enough to inspect, but not automatically trusted.
- `unit_confidence == "low"` or `"unknown"`: treat as ambiguous and review manually.
- `unit_confidence == "forced"`: the unit was supplied by the user rather than inferred.

The check is not a substitute for confirmation from the data owner. It gives us a compact integrity check to send back and discuss without exchanging raw QAR data.
