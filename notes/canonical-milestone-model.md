# Canonical Milestone Model

This note captures the current working model for enriched fuel-burn milestones.

## Purpose

The milestone table is the backbone for comparing CHN QAR-derived outputs and EUROCONTROL/PRU-derived fuel-burn outputs. Source preparation may differ, but the harmonised outputs should support the same analytical questions:

- where important operational events occur;
- where analytical distance and flight-level thresholds are crossed;
- how climb, enroute, and descent profiles differ;
- how level-off segments contribute to profile characterisation and fuel burn.

## Milestone Families

Operational or source-derived events:

- `AOBT`, `ERWY`, `ATOT`, `TOC`, `TOD`, `ALDT`, `XRWY`, `AIBT`, and related source milestones.

Along-track distance anchors:

- departure side: `D040`, `D100`, `D200`;
- arrival side: `A200`, `A100`, `A040`.

These are based on flown distance, not geometric ASMA/TMA rings. Departure-side milestones use cumulative flown distance. Arrival-side milestones use remaining flown distance, derived as total flown distance minus cumulative flown distance.

Flight-level anchors:

- departure side: `D_FL075`, `D_FL100`, `D_FL180`;
- arrival side: `A_FL180`, `A_FL100`, `A_FL075`.

These are pressure-altitude analytical thresholds. PRU surveillance-derived data and CHN QAR-derived data are treated as using standard-pressure altitude, effectively referenced to 1013.25 hPa. Local QNH and field-elevation differences are not corrected at this stage.

Level-segment boundaries:

- `LVL_START`;
- `LVL_END`.

These are derived events and should carry a segment identifier and the detection settings used to produce them.

## Deterministic Rules

- `D_FLxxx`: first upward crossing of the threshold after take-off.
- `A_FLxxx`: last downward crossing of the threshold before landing.
- `Dnnn`: first point where cumulative flown distance reaches the threshold after departure.
- `Annn`: first point where remaining flown distance falls below the threshold before arrival.
- Existing non-padded labels such as `D40` and `A40` should be normalised to `D040` and `A040` in canonical outputs.
- Existing generic labels such as `FL100` should be mapped to direction-aware labels only where phase context supports the mapping.

Short flights may have overlapping departure- and arrival-side distance windows. The lookup logic must therefore not assume that `D200` and `A200` describe disjoint portions of every flight.

## Analytical Tables

The enriched model should produce four harmonised tables:

1. `flights`: one row per flight, with source, route, aircraft, total duration, total distance, and quality flags.
2. `milestones`: one row per operational or analytical event, including source and method metadata.
3. `phase_intervals`: one row per interval between selected milestones, with duration, distance, fuel, altitude change, and macro phase.
4. `level_segments`: one row per reconstructed level segment, linked to paired level milestones.

## Lookup Implication

The paper lookup table should remain compact. The preferred first grouping is:

```text
aircraft_group x distance_band x macro_phase x profile_class
```

The enriched milestones should support profile descriptors and diagnostics, for example level-off time, number of level segments, fuel below or above `FL100`, or fuel inside the final 100 NM. They should not force the lookup table into sparse combinations too early.

