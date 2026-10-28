"""Keep review tables and figure-caption rows together; preserve namespaces/text.

Usage: python3 scripts/format-paper-docx.py _output/paper.docx
The export stays single-column. Figure sizing is controlled in paper.qmd.
"""
from pathlib import Path
from zipfile import ZipFile
from xml.dom import minidom
import sys

p = Path(sys.argv[1])
ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
with ZipFile(p) as source:
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
    prefix = node.prefix or 'w'
    new = doc.createElementNS(ns, prefix + ':' + local)
    style = children(node, 'pStyle') if local == 'keepNext' else []
    node.insertBefore(new, style[0].nextSibling if style else node.firstChild)
    return new

def text_values():
    return [x.toxml() for x in doc.getElementsByTagNameNS(ns, 't')]

before = text_values()
count = 0
figure_count = 0
separators = 0
for table in doc.getElementsByTagNameNS(ns, 'tbl'):
    for row in children(table, 'tr'):
        prop(prop(row, 'trPr'), 'cantSplit')
    if table.getElementsByTagNameNS(ns, 'drawing'):
        figure_count += 1
        continue
    rows = children(table, 'tr')
    for index, row in enumerate(rows):
        # Every cell in the last row must release the following paragraph.
        # Clearing only the final cell can keep a whole subsequent figure
        # attached and move an otherwise fitting table to the next page.
        for paragraph in row.getElementsByTagNameNS(ns, 'p'):
            keep = prop(prop(paragraph, 'pPr'), 'keepNext')
            keep.setAttributeNS(ns, (keep.prefix or 'w') + ':val',
                                '1' if index < len(rows) - 1 else '0')
    count += 1
# Word/LibreOffice can merge adjacent table elements into one table. Pandoc
# represents figures as tables too; separate them so a preceding data header
# cannot repeat above a figure on the following page.
for table in list(doc.getElementsByTagNameNS(ns, 'tbl')):
    previous = table.previousSibling
    while previous is not None and previous.nodeType != previous.ELEMENT_NODE:
        previous = previous.previousSibling
    if previous is None or previous.namespaceURI != ns or previous.localName != 'tbl':
        continue
    prefix = table.prefix or 'w'
    separator = doc.createElementNS(ns, prefix + ':p')
    paragraph_props = prop(separator, 'pPr')
    spacing = prop(paragraph_props, 'spacing')
    for key, value in [('before', '0'), ('after', '0'), ('line', '20'), ('lineRule', 'exact')]:
        spacing.setAttributeNS(ns, prefix + ':' + key, value)
    prop(paragraph_props, 'keepNext').setAttributeNS(ns, prefix + ':val', '0')
    table.parentNode.insertBefore(separator, table)
    separators += 1
assert before == text_values()
updated = doc.toxml(encoding='utf-8')
temp = p.with_suffix('.formatting.tmp')
with ZipFile(temp, 'w') as output:
    for info, data in members:
        output.writestr(info, updated if info.filename == 'word/document.xml' else data)
temp.replace(p)
print(f'Kept {count} editable tables and {figure_count} figure-caption rows together; '
      f'separated {separators} adjacent tables; text and namespaces preserved.')
