# Common interruption thresholds and support

27 October 2026. Companion aggregate snapshot for the unlimited-length study
technical note. See [definitions and reproduction](../../paper-profile-classes.md).

## Working primary rule

Use a sustained low-rate episode (absolute vertical rate <=300 ft/min) lasting
at least 120 seconds inside the selected window, supported by at least two native
intervals. Require complete native altitude bracketing, every overlapping native
gap <=60 seconds, and retain explicit negative source altitude-support gates.
Unknown includes incomplete coverage, too-short windows and material reversals.

- Continuous **at this scale**: no qualifying episode.
- Light: 1--2 episodes, combined share <=20%, longest <=180 seconds; all required.
- Heavy: count >=3 OR share >20% OR longest >180 seconds.

These are fuel-independent working study thresholds, not formal CCO/CDO rules.
The snapshot includes short-feature and resolution sensitivities plus one-at-a-time
class-boundary sensitivities. No regional quantiles define the classes.

## Principal result

The primary rule produces **no paired aircraft/GCD/window/class fuel-reference
cell** meeting n>=30 in each region, across the ten assessed windows. This does
not invalidate the existing marginal pressure/terminal fuel references.

CHN's supplied point product contains event-bracket/coverage-edge observations,
not the dense QAR trace. In particular, neither FL100--180 direction has eligible
CHN primary common classes. Known local altitude support and fine-window fuel
support must not be misread as delivery of dense interior knots.

| Pressure window | CHN classifiable C/L/H | EUR classifiable C/L/H |
|---|---:|---:|
| Climb FL075--100 | 41/0/0 | 134/0/2 |
| Climb FL100--180 | 0/0/0 | 17,966/0/3 |
| Descent FL180--100 | 0/0/0 | 9,548/2/300 |
| Descent FL100--075 | 104/0/0 | 5,094/0/86 |

These are profile counts, independently of fuel support. They are selected
reconstruction cohorts, not estimates of the regions' class proportions. At fixed
primary coverage, changing only the light share cap from 20% to 30% increases the
EUR FL180--100 light count from 2 to 79; this is class-boundary sensitivity, not
validation of either choice. The CHN coverage limitation persists.

Positive source-level evidence remains substantial: 851 CHN flights have a
qualifying native source episode in climb FL100--180 and 2,925 in descent
FL180--100 (851 / 2,924 also have window fuel support). The corresponding EUR
source-evidence counts are 60 / 2,577. Different native detectors prevent treating
these as comparable regional prevalence. The point representation can retain
the endpoints of long levels while omitting their interior; the short-gap
classification cohort can therefore select against interrupted CHN profiles.
Do not interpret the surviving class distribution as regional smoothness.

## Tables and denominators

- `support.csv`: five feature/gap specifications x ten windows x two regions;
  input/time/bracketing/coverage/classification/fuel counts and C/L/H/unknown counts.
- `status.csv`: complete reason-specific unknown accounting, separate from classes.
- `class_counts.csv`: regional counts with explicit zero class slots.
- `cell_support.csv`: exact type x 100-NM GCD band x window x class x specification;
  independent profile/fuel n, paired support and explicit unknown status.
- `paired_support.csv`: number of paired class cells; unknown is never a paired
  operational profile class.
- `native_level_evidence.csv` and `native_level_cell_evidence.csv`: positive
  source-level evidence only; absence does not establish continuity.
- `native_point_summary.csv`: whole supplied-record knot-spacing context, not
  the cadence of the underlying QAR recorder or an airborne-only summary.
- `threshold_sensitivity.csv`, `thresholds.csv`, `feature_specs.csv` and
  `class_definitions.csv`: working rules and their separate sensitivities.
- `class_references.csv`: independently supported fuel, duration and rate
  percentiles by primary class, suppressed below n=30. Unknown references are
  diagnostic; sparse/unpaired populated regional references are not paired claims.
- `input-manifest.csv`: 138 adopted input hashes, verified after the build.
- `source-manifest.csv` and `session-info.txt`: analysis code/settings and runtime.
  The companion marginal-reference snapshot additionally records the QMD,
  bibliography, styles and complete technical-note rendering dependencies.

Every count is window-specific; windows overlap and must not be added as
independent flights. Class counts use profile eligibility independently of fuel;
fuel-reference counts require both. Regional frequency comparisons need supported,
comparable observation mechanisms as well as identical physical class cut points.

Flight identifiers, detailed native knots and classification ledgers remain in
the restricted data store. Source releases, canonical inputs, detector code,
existing eligibility views and fuel quantities are unchanged. No decoder,
coverage-improvement, repair, upload or ground-distance proxy work is performed.
