# Worker handoff: W0 — Coordinator and release steward / W0-2026-10-09-001

## Result and status

- **Work package:** W0 — Coordinator and release steward
- **Run ID:** W0-2026-10-09-001
- **Worker:** Claude Sonnet 4.5
- **Completion time:** 2026-10-09T13:00:00Z (UTC)
- **Main finding:** All seven manifest artifacts present and hash-verified. Critical EUR interval reconstruction and CHN distance validation issues identified. Analysis release NOT READY pending W1/W2 validation.
- **Proposed paper claim:** "We establish an international data contract for profile-aware fuel references using CHN QAR and EUR AEM sources. Source validation identified critical preprocessing requirements: EUR segment reconstruction affects 87.7% of flights with overlapping intervals (~57% exposure bias), and CHN distance calculations show systematic contradictions requiring coordinate-level verification. These findings establish mandatory validation gates before international benchmarking coefficients can support operational decisions."
- **Limitations:** Release identity frozen but analytical validity contingent on W1/W2 repairs. Distance-dependent metrics (kg/NM, stage-length context) currently unreliable for both regions. CHN 18.5% missing ALDT creates selection risk. No causal ATM attribution without additional counterfactual design.
- **Analysis status:** ✅ Analysed and checked (read-only audit complete)
- **Data delivery status:** Not required (W0 is documentation package)
- **Review status:** Awaiting review by release steward and PRU/CAUC leads
- **Remaining work:** W1 EUR interval reconstruction (proposed, awaiting owner confirmation), W2 CHN distance/boundary validation (proposed, awaiting owner confirmation)
- **Blocker:** None for W0 completion. W1/W2 source access is prerequisite for their work packages.
- **Responsible person:** Release steward (rkoelle) for W0 acceptance; PRU/CAUC leads for W1/W2 assignments

## Producing code and reproduction

- **Git repository:** https://github.com/rainer-rq-koelle/FuelBurnEstimation
- **Branch:** w0-release-contract
- **Exact producing commit SHA:** 46f0a9d680b9c32ed3d33aa0d89ac7675b9218ec
- **Instruction commit SHA:** 1438f500003ffed0e53bd0d6037411120ef4ead5
- **Relevant files:**
  - `scripts/12-audit-study-readiness.R` (readiness audit)
  - `notes/study-release-contract.md` (main deliverable)
  - `notes/results/W0/W0-2026-10-09-001/input-manifest-snapshot.csv` (frozen manifest)
  - `notes/results/W0/W0-2026-10-09-001/*.csv` (7 aggregate diagnostic files)
- **Commands and execution order:**
  ```bash
  # 1. Run readiness audit (read-only, no modifications)
  Rscript scripts/12-audit-study-readiness.R
  
  # 2. Review audit outputs
  ls -lh notes/results/W0/W0-2026-10-09-001/
  
  # 3. Verify manifest integrity
  cat notes/results/W0/W0-2026-10-09-001/release-integrity.csv
  ```
- **Runtime/package versions:**
  - R version: 4.5.x
  - arrow: (from audit script)
  - dplyr: (built under R 4.5.3)
  - tidyr: (built under R 4.5.2)
  - readr: (built under R 4.5.3)
  - here: (built under R 4.5.2)
  - digest: (for SHA-256 hashing)
- **Configuration file/key and SHA-256:** N/A (uses default FUELBURN_DATA_STORE environment variable)
- **Random seeds:** N/A (no random sampling in W0)
- **Development/evaluation split:** Not applicable to W0 (to be established in W3)

## Inputs

| Input role | R2 object key or authorised local reference | Version | SHA-256 |
|---|---|---|---|
| CHN canonical milestones | `processed/chn/CHN-canonical-milestones-summer2025.parquet` | summer2025 | 5907faeaf4094d79e736dd281ac0bac9c2d3d15b332e94868aaa490a4a042b91 |
| CHN level segments | `processed/chn/CHN-level-segments-summer2025.parquet` | summer2025 | 5fdde9e482a60efa09357808051e6eff48bbd9020a96eede19c95cadab2ebcb2 |
| CHN phase summaries | `processed/chn/CHN-phase-summaries-summer2025.parquet` | summer2025 | 5f7b0fdcb9e577699306d3223d9880b14f88fdba1c3f7d3a34d0795ff3606e60 |
| EUR canonical milestones | `processed/eur/EUR-canonical-milestones-summer2025.parquet` | FIXED-summer2025 | 2bed2d8638ba9c81928ed0c89c6e4387f565c2e42238f0045817ddf906229df6 |
| EUR level segments | `processed/eur/EUR-level-segments-summer2025.parquet` | FIXED-summer2025 | a2c1b923a0826e4173ea8402619dc3aa780661631482e1ad4e8147fd8111a86d |
| EUR raw metadata | `raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet` | FIXED | e9d61aa942e0b986ebb82073b489cba550991d7ca8860cc8d4b106893c7e3e35 |
| EUR raw segments | `raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` | FIXED | f341b8894335ebfb62dd97f27dd90517da088f31b4e50fd46e1f420b755744fc |
| Authoritative manifest | `data-store/manifest/current-artifacts.csv` | 2026-10-09 | (snapshot SHA-256: computed from frozen copy) |

**Note:** All seven R2 artifacts were verified present in local data store with matching hashes. The audit script loaded these files read-only and generated aggregate diagnostics without modification.

## Outputs and artifact manifest

W0 is a documentation and governance package. No new analytical datasets were created. All outputs are shareable GitHub artifacts.

| Output role | Durable destination and exact key/path | SHA-256 | Rows/flights | Stored hash verified? |
|---|---|---|---|---|
| Release contract | `notes/study-release-contract.md` | See W0-deliverables-checksums.txt | N/A | N/A (GitHub tracked) |
| Frozen manifest snapshot | `notes/results/W0/W0-2026-10-09-001/input-manifest-snapshot.csv` | See W0-deliverables-checksums.txt | 7 artifacts | N/A (GitHub tracked) |
| Worker handoff | `notes/results/W0/W0-2026-10-09-001/worker-handoff-W0.md` | See W0-deliverables-checksums.txt | N/A | N/A (GitHub tracked) |
| Corrections checklist | `notes/results/W0/W0-2026-10-09-001/CORRECTIONS-CHECKLIST.md` | See W0-deliverables-checksums.txt | N/A | N/A (GitHub tracked) |
| W0 package README | `notes/results/W0/W0-2026-10-09-001/README.md` | See W0-deliverables-checksums.txt | N/A | N/A (GitHub tracked) |
| Release integrity check | `notes/results/W0/W0-2026-10-09-001/release-integrity.csv` | See W0-deliverables-checksums.txt | 7 rows | N/A (audit evidence) |
| Study readiness summary | `notes/results/W0/W0-2026-10-09-001/study-readiness.csv` | See W0-deliverables-checksums.txt | 2 rows (EUR/CHN) | N/A (audit evidence) |
| Actual schema | `notes/results/W0/W0-2026-10-09-001/actual-schema.csv` | See W0-deliverables-checksums.txt | varies | N/A (audit evidence) |
| Milestone coverage | `notes/results/W0/W0-2026-10-09-001/milestone-coverage.csv` | See W0-deliverables-checksums.txt | varies | N/A (audit evidence) |
| Phase label provenance | `notes/results/W0/W0-2026-10-09-001/phase-label-provenance.csv` | See W0-deliverables-checksums.txt | varies | N/A (audit evidence) |
| Aircraft common support | `notes/results/W0/W0-2026-10-09-001/aircraft-common-support.csv` | See W0-deliverables-checksums.txt | 75 types | N/A (audit evidence) |
| Route coverage | `notes/results/W0/W0-2026-10-09-001/route-coverage.csv` | See W0-deliverables-checksums.txt | varies | N/A (audit evidence) |

**Canonical copy:** All outputs in GitHub; no R2 upload required for W0.

## Validation and sample flow

### Checks performed and aggregate results

**Manifest Integrity Check:**
- ✅ All 7 required and optional artifacts present in local data store
- ✅ All 7 SHA-256 hashes match authoritative manifest
- ✅ No missing or corrupted files

**EUR Validation Findings:**
- ❌ CRITICAL: 29,631 repeated segment keys out of 47,849 distinct keys (62% repetition rate)
- ❌ CRITICAL: 18,860 flights (87.7%) with overlapping intervals
- ❌ CRITICAL: Summed exposure ~57% higher than union (20,132 h vs. 12,802 h)
- ⚠️ WARNING: 51,611 intervals (60%) with >1,000 ft altitude change
- ✅ PASS: All 21,503 flights have unique ATOT, ALDT, TOC, TOD
- ✅ PASS: 21,321 flights (99.2%) strictly ordered airborne
- ❌ BLOCKER: EUR segments missing distance field (0 of 86,142 have distance)

**CHN Validation Findings:**
- ❌ CRITICAL: 17,955 segments (27.6%) imply >700 kt speed
- ❌ CRITICAL: 2,958 flights (46%) with enroute (TOC-TOD) speed >700 kt
- ❌ CRITICAL: Median enroute implied speed 830 kt (vs. expected ~450-500 kt)
- ❌ CRITICAL: 1,190 flights (18.5%) missing ALDT milestone
- ⚠️ WARNING: 22 flights missing unique TOC/TOD pair
- ✅ PASS: 5,220 flights (81.3%) strictly ordered airborne (where ALDT present)
- ✅ PASS: All 64,981 segments have distance field

**Schema Validation:**
- ❌ CHN milestones: 27 columns (not 21 as claimed)
- ❌ CHN level segments: 22 columns (not 31 as claimed)
- ⚠️ EUR-CHN schema equivalence claim is FALSE

**Phase Label Validation:**
- ⚠️ EUR phase labeling inconsistency: uppercase context vs. lowercase delivery
- ⚠️ Potential altitude heuristic dominance over milestone-window assignment

### Sample flow

**EUR:**
- Delivered flights: 21,503
- Flights with complete milestones: 21,503 (100%)
- Flights with overlapping segments: 18,860 (87.7%)
- Distinct segment keys: 47,849
- Segment rows delivered: 86,142 (1.80× inflation from repetition)

**CHN:**
- Delivered flights: 6,421
- Flights with complete ATOT: 6,420 (99.98%, 1 missing)
- Flights with complete TOC/TOD: 6,399 (99.7%, 22 missing unique pair)
- Flights with ALDT: 5,231 (81.5%)
- Segment rows: 64,981 (unique keys, all with distance field present; distance validity unresolved pending W2)

**Common Support (primary types):**
- B738: 885 CHN, 1,336 EUR ✅
- A320: 362 CHN, 4,934 EUR ✅
- A321: 507 CHN, 3,095 EUR ✅
- A20N: 203 CHN, 5,771 EUR ✅
- A21N: 350 CHN, 1,003 EUR ✅

### Exclusion reasons

**W0 performs no exclusions** (read-only audit). However, W1/W2 workers must address:

**EUR exclusions pending W1:**
- Repeated segment keys (mechanism to be determined)
- Overlapping intervals (29,631 keys, 38,293 extra rows)
- Intervals with invalid boundaries or out-of-bounds
- Segments where distance cannot be recovered

**CHN exclusions pending W2:**
- Flights/segments with unreliable distance (coordinate issues)
- 1,190 flights without ALDT (descent/airborne analysis risk)
- 22 flights without unique TOC/TOD
- Segments with unvalidated fuel accounting

**Overlap status:** Exclusion reasons are NOT mutually exclusive; W1/W2 must report intersection counts.

### Data/schema/units reconciliation

**Time zones:**
- EUR: `Europe/Paris` attribute
- CHN: `UTC` attribute
- ⚠️ Clock semantics (true instants vs. local wall times) UNVERIFIED

**Units documented in code/notes:**
- Fuel: kilograms (cumulative consumed)
- Distance: nautical miles
- Time: seconds (duration), epoch timestamps (events)
- Altitude: feet (pressure altitude assumed, unverified)
- Speed: knots (derived from distance/time)

**Units requiring W2 verification:**
- CHN coordinate scaling/encoding
- CHN fuel flow (engine summation, raw vs. cleaned)
- CHN altitude reference (pressure vs. GPS)

**Units requiring W1 verification:**
- EUR AEM fuel model configuration
- EUR distance source (missing from segments)

### Parameter sensitivity, stability, and null findings

**Not applicable to W0.** Parameter trials begin in W4 after W3 profile descriptors are established.

**W0 finding:** Current delivered data cannot support parameter trials due to validity issues.

### Holdout/leakage checks

**Not applicable to W0.** Development/evaluation split will be established in W3.

### Remaining uncertainty and limits of interpretation

**EUR uncertainties:**
1. Root cause of repeated segment keys unknown
2. Alternating LVL pairing logic unverified
3. AEM version/configuration undocumented
4. Source distance field absent in processed data
5. Phase label mismatch mechanism unclear
6. Export stage lineage ambiguous (enriched vs. harmonized)

**CHN uncertainties:**
1. Coordinate scaling/units undocumented
2. Missing ALDT root cause unknown (affects 18.5% of flights)
3. Distance calculation method unverified
4. Fuel flow integration conventions unverified
5. Batch processing provenance: `scripts/process-chn-summer2025-update.R` consolidates incoming batch outputs; batch producer/version unknown
6. Helper bundle provided to Lingling contains `R/canonical-fuel-milestones.R`; whether batch-level outputs used this or another helper version is unverified
7. TOC/TOD detector settings undocumented

**General uncertainties:**
1. Clock semantics (instants vs. wall times) for both regions
2. Schema differences larger than claimed (CHN 27/22 vs. EUR 21/31)
3. Historical plausibility checks do NOT confirm units for new batches
4. No source-specific quality flags beyond existence checks

**Interpretation limits:**
- Delivered data availability ≠ analytical validity
- Zero orphan rate ≠ correct interval reconstruction
- Manifest hash match ≠ semantic contract satisfied
- 100% segment completion ≠ trustworthy segment identity
- One source passing checks ≠ other source comparable

## Decisions and downstream use

### Decisions adopted

**By W0 worker:**
1. ✅ Release identity frozen at manifest 2026-10-09T11:35:10Z
2. ✅ Seven input artifacts verified and snapshot preserved
3. ✅ Minimum study scope: B738, A320 primary; A321/A20N/A21N extension
4. ✅ Analysis readiness: NOT READY pending W1/W2 validation
5. ✅ Critical path: W0→W1/W2→W3→W4→W5→W7
6. ✅ Gate A requirement: Corrected or restricted analysis release by 16 October
7. ✅ Audit evidence: 7 aggregate CSV files generated and preserved

**Awaiting release steward decision:**
- W1 owner assignment (requires PRU source access)
- W2 owner assignment (requires CAUC source access)
- R2 upload authority expansion for W1/W2 workers
- Joint author questions on scope and disclosure

**Awaiting joint author decision:**
- Primary operational hypotheses
- Practical improvement threshold definition
- Development/evaluation split policy
- Sparse cell minimum count (30/50/100)
- Disclosure level for routes/airports
- Technical Note hosting/citation approach

### Candidate decisions still awaiting review

**None.** W0 establishes frozen baseline and identifies issues. No analytical decisions made.

### Files/keys the next worker should consume

**W1 worker (EUR) should consume:**
- `processed/eur/EUR-canonical-milestones-summer2025.parquet` (SHA: 2bed2d86...)
- `processed/eur/EUR-level-segments-summer2025.parquet` (SHA: a2c1b923...)
- `raw/eur/g2g-flight-metadata-2025-summer-FIXED.parquet` (SHA: e9d61aa9...)
- `raw/eur/g2g-segment-details-2025-summer-FIXED.parquet` (SHA: f341b889...)
- EUR raw segment data in PRU environment (not in R2)
- W0 release contract and audit findings

**W2 worker (CHN) should consume:**
- `processed/chn/CHN-canonical-milestones-summer2025.parquet` (SHA: 5907faea...)
- `processed/chn/CHN-level-segments-summer2025.parquet` (SHA: 5fdde9e4...)
- `processed/chn/CHN-phase-summaries-summer2025.parquet` (SHA: 5f7b0fdc...)
- CHN raw QAR data in CAUC environment (not in R2)
- W0 release contract and audit findings

**W3 worker should consume:**
- W1 candidate EUR artifacts (keys TBD after W1 completion)
- W2 candidate CHN artifacts (keys TBD after W2 completion)
- W0 frozen manifest snapshot
- W0 aircraft common support table
- Methodological note: `technical-note-methodology.qmd`

### Unsupported uses, incomplete fields, and prerequisites

**DO NOT use current delivered data for:**
- ❌ EUR segment rate calculations (repeated keys overweight intervals)
- ❌ EUR segment count statistics (repeated keys inflate counts)
- ❌ EUR exposure summation (overlaps create ~57% bias)
- ❌ CHN distance-dependent metrics (systematic speed contradictions)
- ❌ CHN stage-length context (unreliable distance)
- ❌ CHN descent/airborne population claims (18.5% missing ALDT creates selection)
- ❌ EUR-CHN schema-equivalent processing (actual schemas differ)
- ❌ International lookup coefficients (neither region validated)

**Incomplete fields requiring W1:**
- EUR segment distance (absent in processed data)
- EUR source segment IDs (needed for tracing)
- EUR AEM configuration (version/settings undocumented)
- EUR phase assignment provenance (label mismatch)

**Incomplete fields requiring W2:**
- CHN distance recalculation (coordinate-level)
- CHN missing ALDT recovery (1,190 flights)
- CHN fuel flow verification (units/integration)
- CHN TOC/TOD boundary validation

**Prerequisites for scientific use:**
1. W1 EUR interval reconstruction complete and accepted
2. W2 CHN distance/boundary validation complete and accepted
3. W3 harmonized analytical tables created from validated W1/W2 outputs
4. Development/evaluation split established (W3)
5. Parameter configuration frozen (W4)
6. Held-out validation performed (W5)

### Production promotion

**Status:** Not requested

**W0 creates NO new production artifacts.** W0 outputs are documentation and audit evidence for steward review.

**Production promotion path for W1/W2:**
1. W1/W2 workers upload candidate artifacts to R2 `derived/<region>/study-runs/<run-id>/`
2. Workers return handoff with validation evidence
3. Release steward reviews candidate evidence and acceptance criteria
4. If accepted, steward promotes candidate to production release
5. Steward updates authoritative manifest with new production keys/hashes
6. Old production artifacts retained for reproducibility

**W0 does NOT authorize:**
- Production manifest changes
- R2 production object updates
- Manuscript submission
- Coefficient publication
- Operational use of current delivered data

## Pending-upload package

**Not applicable.** W0 is a GitHub documentation package with no R2 uploads required.

All W0 outputs are committed to GitHub on branch `w0-release-contract` for release steward review.

## Additional notes

### Audit execution details

The readiness audit (`scripts/12-audit-study-readiness.R`) is a **read-only** script that:
- Loads seven manifest-listed artifacts from local data store
- Computes aggregate statistics on identity, overlap, ordering, and plausibility
- Writes seven CSV files to `notes/results/W0/W0-2026-10-09-001/`
- **Does NOT modify, repair, or upload any production data**
- **Does NOT create new analytical datasets**

Audit runtime: ~30 seconds on local machine.

### Critical findings for steward attention

**Highest priority for Gate A:**
1. EUR interval overlaps affect 87.7% of flights (~57% exposure bias)
2. CHN distance contradictions affect 46% of flights (enroute speed >700kt)
3. CHN missing ALDT affects 18.5% of flights (selection bias risk)

**Medium priority:**
4. EUR phase label mismatch (altitude heuristic vs. milestone context)
5. CHN/EUR schema not equivalent as claimed
6. EUR segment distance field absent

**Lower priority but required for documentation:**
7. AEM configuration undocumented
8. Batch processing provenance: upstream batch producer/version unknown
9. Clock semantics unverified for both regions

### Recommended immediate actions

**Release steward:**
1. Accept or revise W0 release contract
2. Assign W1 to PRU worker with source access (deadline: 12 Oct)
3. Assign W2 to CAUC worker with source access (deadline: 12 Oct)
4. Expand R2 upload authority for W1/W2
5. Convene author call for scope/disclosure questions

**Project team:**
1. Do NOT use current delivered data for analysis
2. Do NOT publish coefficients from current data
3. Do NOT claim EUR-CHN data are validated or schema-equivalent
4. Review exploratory paper claims against W0 findings

### References

- Study worker plan: `notes/study-worker-plan.md`
- Methodological note: `technical-note-methodology.qmd`
- Data preparation note: `technical-note-data-preparation.qmd`
- Instruction commit: 1438f500003ffed0e53bd0d6037411120ef4ead5

---

**Handoff complete.** W0 ready for release steward acceptance review.
