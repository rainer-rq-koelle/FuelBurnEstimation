"""Apply shared review formatting and give conference tables deliberate widths.

Usage: python3 scripts/format-conference-docx.py _output/conference-paper.docx
The shared Technical Note formatter and all document text remain unchanged.
"""
from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom
import runpy
import sys

runpy.run_path(str(Path(__file__).with_name('format-paper-docx.py')), run_name='__main__')
path = Path(sys.argv[1])
ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
with ZipFile(path) as source:
    members = [(info, source.read(info.filename)) for info in source.infolist()]
xml = dict((info.filename, data) for info, data in members)['word/document.xml']
doc = minidom.parseString(xml)

def children(node, local):
    return [x for x in node.childNodes if x.nodeType == x.ELEMENT_NODE
            and x.namespaceURI == ns and x.localName == local]

def prop(node, local):
    found = children(node, local)
    if found:
        return found[0]
    new = doc.createElementNS(ns, 'w:' + local)
    node.appendChild(new)
    return new

def texts():
    return [n.toxml() for n in doc.getElementsByTagNameNS(ns, 't')]

before = texts()
matched = 0
width_presets = {
    ('Phase', 'Selected finding', 'Lookup qualifier'): [1400, 4100, 3600],
    ('Segment', 'Fuel kg', 'Minutes', 'kg/min', 'n time', 'n fuel/rate'):
        [1700, 1350, 1400, 1600, 1500, 1550],
    ('Interval', 'China', 'Europe', 'Minutes', 'n CHN/EUR'):
        [2000, 2000, 2000, 1500, 1600],
}
for table in doc.getElementsByTagNameNS(ns, 'tbl'):
    rows = children(table, 'tr')
    if not rows:
        continue
    headers = [''.join(t.firstChild.data for t in c.getElementsByTagNameNS(ns, 't')
                       if t.firstChild) for c in children(rows[0], 'tc')]
    if tuple(headers) not in width_presets:
        continue
    matched += 1
    widths = width_presets[tuple(headers)]
    props = prop(table, 'tblPr')
    layout = prop(props, 'tblLayout')
    layout.setAttributeNS(ns, 'w:type', 'fixed')
    total = prop(props, 'tblW')
    total.setAttributeNS(ns, 'w:type', 'dxa')
    total.setAttributeNS(ns, 'w:w', str(sum(widths)))
    grid = children(table, 'tblGrid')[0]
    cols = children(grid, 'gridCol')
    assert len(cols) == len(widths)
    for col, width in zip(cols, widths):
        col.setAttributeNS(ns, 'w:w', str(width))
    for row in rows:
        cells = children(row, 'tc')
        assert len(cells) == len(widths)
        for cell, width in zip(cells, widths):
            cell_width = prop(prop(cell, 'tcPr'), 'tcW')
            cell_width.setAttributeNS(ns, 'w:type', 'dxa')
            cell_width.setAttributeNS(ns, 'w:w', str(width))
assert matched == len(width_presets) and before == texts()
updated = doc.toxml(encoding='utf-8')
temp = path.with_suffix('.conference-formatting.tmp')
with ZipFile(temp, 'w') as output:
    for info, data in members:
        output.writestr(info, updated if info.filename == 'word/document.xml' else data)
temp.replace(path)
print('Set ground, terminal and synthesis column widths; all text and namespaces preserved.')
