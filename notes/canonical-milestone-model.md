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

TOC/TOD selection uses complete sustained level segments in altitude versus time.
The initial departure/final arrival 200 NM windows supply altitude context for
selecting the initial/final cruise level when enroute step changes exist. Use the
first/last complete qualifying level boundary, never the circle-crossing timestamp
or a clipped level segment. A relevant level can precede, follow or span the
circle crossing. Short flights or unsupported geometry use the documented
near-ceiling profile fallback; record the selection context and retain partial
supported events independently.

Airport-reference distance anchors:

- departure side: `D040`, `D100`, `D200`;
- arrival side: `A200`, `A100`, `A040`.

Clarified on 18 October 2026: these are great-circle distances from/to the aerodrome reference point (ARP), defining airport-centred radii. They are not cumulative distance flown. Use sourced airport coordinates (with an explicit proxy designation when using OurAirports), calculate distance at each usable trajectory point, and retain every outward departure / inward arrival crossing before an explicit representative-selection rule. No per-flight ARP-to-take-off or landing-to-ARP track-length offset is needed.

Distance flown is a separate cumulative sum of successive short great-circle legs along the cleaned/repaired coordinates. Its full-record or ATOT-zero airborne reference must be explicit. Earlier wording describing the ARP anchors as along-track distance is superseded by this clarification; existing releases are not modified by this model note.

Flight-level anchors:

- departure side: `D_FL075`, `D_FL100`, `D_FL180`;
- arrival side: `A_FL180`, `A_FL100`, `A_FL075`.

These are pressure-altitude analytical thresholds. PRU surveillance-derived data and CHN QAR-derived data are treated as using standard-pressure altitude, effectively referenced to 1013.25 hPa. Local QNH and field-elevation differences are not corrected at this stage. Trajectories can cross a threshold multiple times; preserve all candidate crossings until the selection rule is agreed.

Level-segment boundaries:

- `LVL_START`;
- `LVL_END`.

These are derived events and should carry a segment identifier and the detection settings used to produce them.

Ground interval labels used in the current EUR candidate are derived phase-table labels, not source events: `RUNWAY_EXIT` is the interval from `ALDT` to `XRWY`, and `TAXI_IN` is the interval from `XRWY` to `AIBT`. Their mapping must preserve the APDF/G2G ICAO take-off/landing-roll conventions and the row-level fuel-increment allocation. In the EUR parallel candidate, eligibility is stored per phase and by metric: fuel-per-time requires positive duration and valid fuel, while fuel-per-distance requires positive distance and valid fuel. Passing the structural distance flag does not itself establish physical plausibility; distance-based analyses still need a speed/trajectory plausibility screen. An unresolved ground interval does not remove otherwise usable airborne data. Do not infer a missing ground boundary from M3 or move a G2G row increment between phases without source evidence.

## Candidate generation and event selection

- Generate and retain all observed or interpolated crossings of each distance and pressure-altitude threshold. The production choice of `first`, `last`, or another representative crossing is a separate methodological decision and must be explicit and consistent across sources.
- `Dnnn` candidates use great-circle distance from the departure ARP; `Annn` candidates use great-circle distance to the arrival ARP. Keep cumulative distance from take-off or remaining flown distance to landing under separate labels.
- `D_FLxxx` candidates are upward crossings and `A_FLxxx` candidates are downward crossings, identified from the trajectory sequence rather than from a single first sample that happens to be beyond the threshold.
- If repeated altitude-threshold crossings are associated with an accepted level segment, do not emit those crossings as additional climb/descent sub-phase events. The accepted level interval already provides its entry (`LVL_START`) and exit (`LVL_END`) boundaries. Preserve the level interval and its provenance; apply this suppression only where the association is clear.
- For sampled trajectories, record the crossing method, bracketing samples, time gap, and threshold residual. A tolerance screen may determine whether a crossing is sufficiently resolved; otherwise retain it as unresolved rather than silently assigning a distant sample.
- Existing non-padded labels such as `D40` and `A40` should be normalised to `D040` and `A040` in canonical outputs.
- Existing generic labels such as `FL100` should be mapped to direction-aware labels only where phase context supports the mapping.

Short flights may have overlapping departure- and arrival-side distance windows. The lookup logic must therefore not assume that `D200` and `A200` describe disjoint portions of every flight. A flight may also have several crossings of the same ARP-distance threshold; retain those candidates until the selection rule is applied.

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

