"""Independent parsing/rendering of actual test-generated files, not app mocks.
Requires openpyxl and PyMuPDF in CI. Fixtures are deliberately non-operational.
"""
import base64
import hashlib
import json
from pathlib import Path
import sys
import io
import zipfile
import fitz
import openpyxl

root = Path(sys.argv[1])
manifest = []
for path in sorted(root.glob('*')):
    if path.suffix == '.xlsx':
        book = openpyxl.load_workbook(path)
        sheet = book['Records']
        assert sheet.freeze_panes == 'A2', path
        assert sheet.auto_filter.ref, path
        assert bool(sheet.sheet_view.rightToLeft) == ('_ar' in path.stem), path
        assert book['Report']['B3'].value == sheet.max_row - 1, path
        for row in sheet:
            assert all(cell.data_type != 'f' for cell in row), path
        book.close()
    elif path.suffix == '.pdf':
        document = fitz.open(path)
        assert len(document) > 0
        for page in document:
            assert abs(page.rect.width - 595.28) < 1, path
            assert abs(page.rect.height - 841.89) < 1, path
            assert page.get_text().strip(), path
            pixels = page.get_pixmap(matrix=fitz.Matrix(1, 1))
            assert len(set(pixels.samples)) > 1, path
        if path.name in ['directory_ar.pdf', 'activities_en.pdf']:
            preview = root / (path.stem + '_preview.png')
            preview.write_bytes(document[0].get_pixmap(matrix=fitz.Matrix(1.3, 1.3)).tobytes('png'))
        pages = len(document)
        document.close()
    else:
        continue
    manifest.append({'file': path.name, 'bytes': path.stat().st_size,
                     'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     **({'pages': pages} if path.suffix == '.pdf' else {})})
assert len([r for r in manifest if r['file'].endswith('.xlsx')]) == 12
assert len([r for r in manifest if r['file'].endswith('.pdf')]) == 13
(root / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print(f'::notice title=Independent output inspection::{len(manifest)} actual files independently parsed; all PDF pages rasterized')

# Optional transport for network-restricted reviewers. Public synthetic fixtures
# only; never enable this flag for operational customer exports.
if '--inline-fixtures' in sys.argv:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name in ['directory_ar.xlsx', 'directory_ar.pdf', 'activities_en.xlsx',
                     'activities_en.pdf', 'complete_backup.json', 'manifest.json']:
            archive.write(root / name, name)
    encoded = base64.b64encode(buffer.getvalue()).decode()
    if len(encoded) > 160000:
        raise ValueError('Public sample transport exceeds its bounded capacity')
    (root.parent / 'sample-transport.b64').write_text(encoded)
