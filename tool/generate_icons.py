"""Generate reproducible foundation icons. Requires Pillow (tooling only)."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def icon(size):
    image = Image.new('RGB', (size, size), '#142D4E')
    draw = ImageDraw.Draw(image)
    # Neutral Target monogram; final brand artwork can replace it later.
    draw.rectangle((size * .25, size * .27, size * .75, size * .39), fill='white')
    draw.rectangle((size * .44, size * .38, size * .56, size * .75), fill='white')
    return image


for platform in ('ios', 'macos'):
    assets = ROOT / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
    for entry in json.loads((assets / 'Contents.json').read_text())['images']:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        icon(size).save(assets / entry['filename'])
for name, size in [('favicon.png', 32), ('icons/Icon-192.png', 192),
                   ('icons/Icon-512.png', 512), ('icons/Icon-maskable-192.png', 192),
                   ('icons/Icon-maskable-512.png', 512)]:
    icon(size).save(ROOT / 'web' / name)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                      ('xxhdpi', 144), ('xxxhdpi', 192)]:
    icon(size).save(ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
icon(256).save(ROOT / 'windows/runner/resources/app_icon.ico',
               sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
for path in (ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset').glob('*.png'):
    Image.new('RGBA', (1, 1), (255, 255, 255, 0)).save(path)
