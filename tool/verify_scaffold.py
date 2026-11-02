"""SDK-independent structural checks. These do NOT replace Flutter builds/tests."""
from pathlib import Path
import json
import plistlib
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
checks = 0


def check(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1


for platform in ('android', 'ios', 'macos', 'windows', 'web'):
    folder = ROOT / platform
    check(folder.is_dir(), f'Missing platform: {platform}')
    for path in folder.rglob('*'):
        if not path.is_file():
            continue
        check(path.stat().st_size > 0, f'Empty scaffold: {path}')
        if path.suffix in {'.xml', '.plist', '.xcworkspacedata', '.xcscheme', '.xib', '.storyboard', '.manifest'}:
            ET.parse(path)
        if path.suffix == '.json':
            json.loads(path.read_text())
        if path.suffix in {'.tmpl', '.dart', '.kts', '.pbxproj', '.html'}:
            check('{{' not in path.read_text(), f'Unresolved template: {path}')
        if path.suffix == '.png':
            check(path.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n', f'Invalid PNG: {path}')

for platform in ('ios', 'macos'):
    with (ROOT / platform / 'Runner/Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    check(info['CFBundleLocalizations'] == ['ar', 'en'], f'{platform}: locales')
    assets = ROOT / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
    for entry in json.loads((assets / 'Contents.json').read_text())['images']:
        path = assets / entry['filename']
        width, height = struct.unpack('>II', path.read_bytes()[16:24])
        expected = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        check(width == height == expected, f'Wrong icon dimensions: {path}')

for feature in (ROOT / 'lib/features').iterdir():
    for layer in ('data', 'domain', 'presentation'):
        check((feature / layer).is_dir(), f'Missing {feature.name}/{layer}')
check(len(list((ROOT / 'lib/features').iterdir())) == 10, 'Expected ten features')
for path in (ROOT / 'lib').rglob('*.dart'):
    for line in path.read_text().splitlines():
        if line.startswith("import '"):
            target = line.split("'")[1]
            if not target.startswith(('dart:', 'package:')):
                check((path.parent / target).is_file(), f'Broken import in {path}: {target}')
print(f'PASS: {checks} structural checks; XML/JSON/plist parsed. No Flutter compilation performed.')
