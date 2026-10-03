"""Generate an original provisional football/pitch icon for the internal beta."""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / 'apps/manager-futebol/Resources/Assets.xcassets'
output = root / 'AppIcon.appiconset'
output.mkdir(parents=True, exist_ok=True)
image = Image.new('RGB', (1024, 1024), '#07382e')
draw = ImageDraw.Draw(image)
for row in range(8):
    draw.rectangle((0, row * 128, 1024, (row + 1) * 128), fill='#0a493a' if row % 2 else '#083e32')
draw.rounded_rectangle((100, 100, 924, 924), radius=24, outline='#58ad83', width=12)
draw.line((100, 512, 924, 512), fill='#58ad83', width=12)
draw.ellipse((362, 362, 662, 662), outline='#58ad83', width=12)
draw.rectangle((332, 100, 692, 252), outline='#58ad83', width=12)
draw.rectangle((332, 772, 692, 924), outline='#58ad83', width=12)
draw.ellipse((262, 296, 782, 816), fill='#052b23')
draw.ellipse((252, 252, 772, 772), fill='#f4f4e9')

def pentagon(x, y, radius):
    return [(x + radius * math.cos(-math.pi / 2 + i * 2 * math.pi / 5), y + radius * math.sin(-math.pi / 2 + i * 2 * math.pi / 5)) for i in range(5)]

center = pentagon(512, 512, 95)
draw.polygon(center, fill='#17382f')
for i, point in enumerate(center):
    angle = -math.pi / 2 + i * 2 * math.pi / 5
    x, y = 512 + 213 * math.cos(angle), 512 + 213 * math.sin(angle)
    draw.line((point[0], point[1], x, y), fill='#17382f', width=12)
    draw.polygon(pentagon(x, y, 44), fill='#17382f')

entries = []
for idiom, sizes in [('iphone', [(20, [2, 3]), (29, [2, 3]), (40, [2, 3]), (60, [2, 3])]), ('ipad', [(20, [1, 2]), (29, [1, 2]), (40, [1, 2]), (76, [1, 2]), (83.5, [2])]), ('ios-marketing', [(1024, [1])])]:
    for size, scales in sizes:
        for scale in scales:
            filename = f'{idiom}-{size}-{scale}.png'
            pixels = int(size * scale)
            image.resize((pixels, pixels), Image.Resampling.LANCZOS).save(output / filename)
            entries.append({'idiom': idiom, 'size': f'{size}x{size}', 'scale': f'{scale}x', 'filename': filename})
(output / 'Contents.json').write_text(json.dumps({'images': entries, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
(root / 'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
