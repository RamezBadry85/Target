"""CI-only provenance audit of the original pinned hosted archive (no extraction)."""
import hashlib
import io
import json
import tarfile
import urllib.request

url = 'https://pub.dev/api/archives/file_saver-0.3.0.tar.gz'
expected = '448b1e30142cffe52f37ee085ea9ca50670d5425bb09b649d193549b2dcf6e26'
with urllib.request.urlopen(url, timeout=60) as response:
    archive = response.read()
actual = hashlib.sha256(archive).hexdigest()
assert actual == expected, f'Upstream archive checksum mismatch: {actual}'
with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as package:
    def source(suffix):
        member = next(m for m in package.getmembers() if m.name.endswith(suffix))
        return package.extractfile(member).read().decode()

    android = source('/Dialog.kt')
    macos = source('macos/Classes/Dialog.swift')
    windows = source('windows/file_saver_plugin.cpp')
    report = {
        'version': '0.3.0', 'archive_sha256': actual,
        'android_logs_write_error': 'Error while writing file' in android,
        'android_nullable_stream_write': 'opStream?.write(bytes)' in android,
        'macos_error_string': 'result("Failed to save file")' in macos,
        'windows_invalid_member': 'bæegin' in windows,
    }
print('::notice title=Original pinned file_saver archive::' + json.dumps(report))
