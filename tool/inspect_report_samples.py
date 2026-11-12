"""Independent parsing/rendering of actual test-generated files, not app mocks.
Requires openpyxl and PyMuPDF in CI. Fixtures are deliberately non-operational.
"""
import base64
import hashlib
import json
import unicodedata
from pathlib import Path
import sys
import io
import zipfile
import fitz
import openpyxl

root = Path(sys.argv[1])
manifest = []
for path in sorted(root.glob('*')):
    if path.name == 'complete_backup.json':
        envelope = json.loads(path.read_text(encoding='utf-8'))
        body = envelope['body']
        checksum = envelope['checksum']
        canonical = json.dumps(
            body,
            ensure_ascii=False,
            sort_keys=True,
            separators=(',', ':'),
            allow_nan=False,
        ).encode('utf-8')
        assert checksum == {
            'algorithm': 'SHA-256',
            'value': hashlib.sha256(canonical).hexdigest(),
        }, path
        assert body['format'] == 'target-complete-backup', path
        assert body['schemaVersion'] == 2, path
        payload = body['payload']
        assert body['counts']['customers'] == len(payload['customers']), path
        assert body['counts']['customer_activities'] == len(
            payload['customer_activities']
        ), path
        assert body['counts']['contacts'] == sum(
            len(row['value']['data']['contacts']) for row in payload['customers']
        ), path
        manifest.append({
            'file': path.name,
            'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'counts': body['counts'],
        })
    elif path.suffix == '.xlsx':
        book = openpyxl.load_workbook(path)
        sheet = book['Records']
        assert sheet.freeze_panes == 'A2', path
        assert sheet.auto_filter.ref, path
        assert bool(sheet.sheet_view.rightToLeft) == ('_ar' in path.stem), path
        assert book['Report']['B3'].value == sheet.max_row - 1, path
        if path.name == 'directory_ar.xlsx':
            assert sheet['B2'].value == 'مؤسسة الاختبار', path
            assert sheet['T2'].is_date, path
            assert sheet['T2'].number_format == 'yyyy-mm-dd hh:mm', path
            assert isinstance(sheet['P2'].value, float), path
            assert sheet['P2'].number_format == '#,##0.00', path
        for column in sheet.column_dimensions.values():
            if column.width is not None:
                assert 12 <= column.width <= 50, path
        for row in sheet:
            assert all(cell.data_type != 'f' for cell in row), path
        book.close()
    elif path.suffix == '.pdf':
        document = fitz.open(path)
        assert len(document) > 0
        extracted_text = '\n'.join(page.get_text() for page in document)
        normalized_text = ' '.join(
            unicodedata.normalize('NFKC', extracted_text).split()
        )
        assert normalized_text.strip(), path
        if path.name == 'directory_ar.pdf':
            assert 'دليل العملاء' in normalized_text, path
            assert 'مؤسسة الاختبار' in normalized_text, path
        if path.name == 'activities_en.pdf':
            assert 'Customer activities' in extracted_text, path
            assert 'Visit' in extracted_text, path
        for page in document:
            assert abs(page.rect.width - 595.28) < 1, path
            assert abs(page.rect.height - 841.89) < 1, path
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
expected_xlsx, expected_pdf = (2, 2) if '--subset' in sys.argv else (12, 13)
assert len([r for r in manifest if r['file'].endswith('.xlsx')]) == expected_xlsx
assert len([r for r in manifest if r['file'].endswith('.pdf')]) == expected_pdf
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
