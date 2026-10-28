"""Inventory returned QAR batches and aggregate eligibility; restricted outputs only."""
from pathlib import Path
import csv, collections, hashlib, json, os, statistics, sys
run = Path(sys.argv[1]).resolve()
store = Path(os.environ.get('FUELBURN_DATA_STORE', '.fuelburn-data-store')).resolve()
assert run.is_relative_to(store)
out = run / 'summary'
out.mkdir(exist_ok=True)
def read(p):
    with p.open(newline='') as f:
        return list(csv.DictReader(f))
def write(name, rows):
    if not rows: return
    with (out / name).open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=rows[0]); w.writeheader(); w.writerows(rows)
def sha(p):
    with p.open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()
def reasons(r): return set(filter(None, r['UNRESOLVED_REASONS'].split(';')))
budget = {'position_repair_budget', 'airborne_position_repair_budget'}
def pure(r): return bool(reasons(r)) and reasons(r).issubset(budget)
def truth(r, col): return r.get(col) == 'TRUE'
def category(r):
    rs = reasons(r)
    if not truth(r, 'STUDY_EXCLUDE'): return 'included_default'
    if pure(r): return 'position_share_only_review'
    if 'position_unresolved' in rs: return 'unresolved_position_including_mixed_holds'
    if rs & budget: return 'position_share_with_other_domain_hold'
    return 'other_time_fuel_profile_holds'
qc, inputs, issues, manifests, batches = [], [], [], [], []
for p in sorted((run / 'returned').rglob('run-manifest.json')):
    batch = p.parent.name; m = json.loads(p.read_text())
    q = read(p.with_name('CHN-flight-quality.csv'))
    im = read(p.with_name('input-manifest.csv'))
    led = read(p.with_name('CHN-issue-ledger.csv'))
    assert len(q) == len(im) and {r['SOURCE_UID'] for r in q} == {r['SOURCE_UID'] for r in im}
    assert len({r['SOURCE_UID'] for r in q}) == len(q)
    for rows in [q, im, led]:
        for r in rows: r['BATCH'] = batch
    assert p.with_name('CHN-problem-flights.csv').read_bytes() == p.with_name('CHN-study-exclusions.csv').read_bytes()
    assert len(read(p.with_name('CHN-study-exclusions.csv'))) == sum(truth(r, 'STUDY_EXCLUDE') for r in q)
    qc += q; inputs += im; issues += led
    manifests.append(m)
    batches.append(dict(BATCH=batch,FILES=len(q),INCLUDED=sum(not truth(r,'STUDY_EXCLUDE') for r in q),HELD=sum(truth(r,'STUDY_EXCLUDE') for r in q),POSITION_SHARE_ONLY=sum(pure(r) for r in q),WHOLE_AIRBORNE_FUEL_TIME=sum(truth(r,'WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE') for r in q),ALL_12_ANCHORS=sum(truth(r,'ALL_12_ARP_FL_ANCHORS_PRESENT') for r in q)))
assert len({r['SOURCE_UID'] for r in qc}) == len(qc)
write('aggregate-batches.csv', sorted(batches,key=lambda r:int(r['BATCH'].removeprefix('output'))))
write('aggregate-hold-categories.csv',[dict(CATEGORY=k,FILES=v) for k,v in collections.Counter(category(r) for r in qc).items()])
write('aggregate-reasons.csv',[dict(REASON=k,FILES=v) for k,v in collections.Counter(x for r in qc if truth(r,'STUDY_EXCLUDE') for x in reasons(r)).most_common()])
write('aggregate-domain-support.csv',[dict(FIELD=col,TRUE=sum(truth(r,col) for r in qc),FALSE=sum(not truth(r,col) for r in qc),HELD_BUT_SUPPORTED=sum(truth(r,'STUDY_EXCLUDE') and truth(r,col) for r in qc)) for col in ['TIME_VALID','FUEL_VALID','DISTANCE_VALID','PROFILE_DATA_VALID','AIRBORNE_WINDOW_SUPPORTED','AIRBORNE_TIME_VALID','AIRBORNE_FUEL_VALID','AIRBORNE_DISTANCE_VALID','AIRBORNE_PROFILE_VALID','WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE','PHASE_BOUNDARIES_VALID','ALL_12_ARP_FL_ANCHORS_PRESENT','ARP_DEP_REFERENCE_SUPPORTED','ARP_ARR_REFERENCE_SUPPORTED']])
types = []
for typ in sorted({r['TYPE'] for r in qc}):
    q = [r for r in qc if r['TYPE']==typ]
    shares = [float(r['AIRBORNE_POSITION_REPAIR_SHARE']) for r in q if r['AIRBORNE_POSITION_REPAIR_SHARE'] not in ['', 'NA']]
    types.append(dict(TYPE=typ,FILES=len(q),HELD=sum(truth(r,'STUDY_EXCLUDE') for r in q),POSITION_SHARE_ONLY=sum(pure(r) for r in q),UNRESOLVED_POSITION=sum('position_unresolved' in reasons(r) for r in q),FROZEN_POSITION=sum('position_frozen_while_moving' in reasons(r) for r in q),WHOLE_AIRBORNE_FUEL_TIME=sum(truth(r,'WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE') for r in q),MEDIAN_AIR_POSITION_REPAIR_SHARE=statistics.median(shares) if shares else None))
write('aggregate-types.csv', types)
shares = []
for r in qc:
    v=r['AIRBORNE_POSITION_REPAIR_SHARE']
    band='unavailable' if v in ['', 'NA'] else ('<=1%' if float(v)<=.01 else '1-2%' if float(v)<=.02 else '2-5%' if float(v)<=.05 else '5-10%' if float(v)<=.1 else '>10%')
    shares.append((band,pure(r)))
write('aggregate-repair-share-bands.csv',[dict(BAND=k,FILES=sum(x==k for x,p in shares),POSITION_SHARE_ONLY=sum(x==k and p for x,p in shares)) for k in ['unavailable','<=1%','1-2%','2-5%','5-10%','>10%']])
write('aggregate-study-issues.csv',[dict(CODE=k[0],STATUS=k[1],FILES=v) for k,v in collections.Counter((r['CODE'],r['STATUS']) for r in issues if r['STUDY_RELEVANT']=='TRUE').most_common()])
by_uid={r['SOURCE_UID']:r for r in qc}; by_input={r['SOURCE_UID']:r for r in inputs}
queue=[]
for r in qc:
    if pure(r): queue.append(dict(BATCH=r['BATCH'],INPUT_ID=r['INPUT_ID'],SOURCE_UID=r['SOURCE_UID'],SHA256=by_input[r['SOURCE_UID']]['SHA256'],TYPE=r['TYPE'],AIRBORNE_POSITION_REPAIR_SHARE=r['AIRBORNE_POSITION_REPAIR_SHARE'],STATUS='review_candidate_not_approved'))
write('restricted-position-review-candidates.csv',queue)
source=[]
for p in sorted((run/'source').rglob('*.csv')):
    r=by_uid[p.stem]; im=by_input[p.stem]; assert sha(p)==im['SHA256']
    source.append(dict(SOURCE_UID=p.stem,BATCH=r['BATCH'],INPUT_ID=r['INPUT_ID'],SHA256=im['SHA256'],PATH=str(p),TYPE=r['TYPE'],STUDY_EXCLUDE=r['STUDY_EXCLUDE'],REASONS=r['UNRESOLVED_REASONS']))
write('restricted-source-manifest.csv',source)
oldids={r['SOURCE_UID'] for r in read(Path('.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-18-006/scan/flight-event-envelopes.csv'))}
reviews=read(Path('.fuelburn-data-store/derived/chn/helper-v2/CHN-v2-2026-10-22-003/review/approved-repair-shares.csv'))
review_hashes={r['SHA256'] for r in reviews}; matches=sum(r['SHA256'] in review_hashes for r in inputs)
known=read(Path('.fuelburn-data-store/derived/chn/verification/CHN-2026-10-22-001/local-input-manifest.csv'))
assert all(r['SHA256']==by_input[r['SOURCE_UID']]['SHA256'] for r in known)
configs={json.dumps(m['configuration'],sort_keys=True) for m in manifests}
helper_hash=sha(Path('helpers/chn-qar-v2/R/chn-qar.R')); airport_hash=sha(Path('helpers/chn-qar-v2/data/airports.csv'))
assert all(m['helper_version']=='2.0.0-candidate.6' and m['source_functions_sha256']==helper_hash and m['airport_reference_sha256']==airport_hash for m in manifests)
assert len(configs)==1 and all(m['repair_review_sha256'] is None for m in manifests)
summary=dict(BATCHES=len(manifests),FILES=len(qc),UNIQUE_FLIGHTS=len(by_uid),HELD=sum(truth(r,'STUDY_EXCLUDE') for r in qc),INCLUDED=sum(not truth(r,'STUDY_EXCLUDE') for r in qc),PURE_POSITION_REVIEW_CANDIDATES=len(queue),WHOLE_AIRBORNE_FUEL_TIME=sum(truth(r,'WHOLE_AIRBORNE_FUEL_TIME_ELIGIBLE') for r in qc),PREVIOUS_CANONICAL_ID_SET_IDENTICAL=set(by_uid)==oldids,KNOWN_VERIFICATION_HASHES_MATCH=len(known),SUPPLIED_RAW_FILES=len(source),RAW_FILES_HELD=sum(r['STUDY_EXCLUDE']=='TRUE' for r in source),EXISTING_EXACT_INPUT_APPROVAL_MATCHES=matches,IDENTICAL_DEFAULT_CONFIGS=True,SOURCE_HASH_AND_AIRPORT_HASH_MATCH=True,PROCESSING_ERROR_RECORDS=sum(r['CODE']=='processing_error' for r in issues),CONSOLE_LOGS_SUPPLIED=False)
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
