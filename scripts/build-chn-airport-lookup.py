"""Build the public, offline CHN airport lookup from a pinned public snapshot.
Usage: python3 scripts/build-chn-airport-lookup.py <source.csv> <codes.csv> <provenance.json>
The code inventory contains ICAO codes only. No flight identities enter the lookup.
"""
from pathlib import Path
import csv
import hashlib
import json
import sys

source, codes, provenance = map(Path, sys.argv[1:])
meta = json.loads(provenance.read_text())
assert hashlib.sha256(source.read_bytes()).hexdigest() == meta['source_sha256']
wanted = sorted({x['ICAO'] for x in csv.DictReader(codes.open())})
raw = list(csv.DictReader(source.open()))
rows = []
for code in wanted:
    candidates = [x for x in raw if x.get('icao_code') == code or x['ident'] == code]
    if len(candidates) != 1:
        raise ValueError(f'Ambiguous or absent airport: {code}')
    x = candidates[0]
    assert x['type'] != 'closed_airport'
    lat, lon = float(x['latitude_deg']), float(x['longitude_deg'])
    assert -90 <= lat <= 90 and -180 <= lon <= 180 and (lat, lon) != (0, 0)
    rows.append(dict(ICAO=code, LAT=x['latitude_deg'], LON=x['longitude_deg'],
                     AIRPORT_NAME=x['name'], COORDINATE_SOURCE='OurAirports 2025-08-31',
                     SOURCE_COMMIT=meta['commit'], COORDINATE_STATUS='airport_coordinate_proxy_for_ARP'))
root = Path(__file__).resolve().parents[1] / 'helpers/chn-qar-v2'
(root / 'data').mkdir(exist_ok=True)
with (root / 'data/airports.csv').open('w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
(root / 'data/airports-provenance.json').write_text(json.dumps(meta, indent=2) + '\n')
q = lambda x: json.dumps(x, ensure_ascii=False)
lines = ['# BEGIN BUNDLED AIRPORT LOOKUP', '.chn_bundled_airports <- function() {',
         '  tibble::tribble(~ICAO,~LAT,~LON,~AIRPORT_NAME,']
lines += ['    '+','.join([q(x['ICAO']), x['LAT'], x['LON'], q(x['AIRPORT_NAME'])])+(',' if i < len(rows)-1 else '') for i,x in enumerate(rows)]
lines += ['  ) |> dplyr::mutate(COORDINATE_SOURCE="OurAirports 2025-08-31",',
          '    SOURCE_COMMIT='+q(meta['commit'])+', COORDINATE_STATUS="airport_coordinate_proxy_for_ARP")',
          '}', '# END BUNDLED AIRPORT LOOKUP']
p = root / 'R/chn-qar.R'; text = p.read_text()
start, end = text.index('# BEGIN BUNDLED AIRPORT LOOKUP'), text.index('# END BUNDLED AIRPORT LOOKUP') + len('# END BUNDLED AIRPORT LOOKUP')
p.write_text(text[:start] + '\n'.join(lines) + text[end:])
print('Bundled airports:',len(rows),'SHA256',hashlib.sha256((root/'data/airports.csv').read_bytes()).hexdigest())
