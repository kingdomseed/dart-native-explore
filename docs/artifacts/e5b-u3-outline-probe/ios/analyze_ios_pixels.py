from pathlib import Path
import json
from PIL import Image

root = Path('/private/tmp/dart3d-e5b-outline-probe-20261027/parent-ios-r5')
roi = (0, 330, 1206, 2100)
results = {'region': list(roi), 'preservation': {}, 'mask_components': {}, 'stroke': {}}
for off in sorted(root.glob('*-off.png')):
    name = off.name.removesuffix('-off.png')
    control = root / f'{name}-control.png'
    if not control.exists():
        continue
    a = Image.open(off).convert('RGB').crop(roi)
    b = Image.open(control).convert('RGB').crop(roi)
    results['preservation'][name] = sum(x != y for x, y in zip(a.get_flattened_data(), b.get_flattened_data()))
for name in ['skin-near-p05', 'payload-near-p05', 'instances-near-p05', 'skin-near-p10', 'skin-far-p05', 'skin-far-p10']:
    path = root / f'{name}-mask.png'
    if not path.exists():
        continue
    mask = Image.open(path).convert('RGB')
    white = {(x, y) for y in range(roi[1], roi[3]) for x in range(roi[0], roi[2]) if min(mask.getpixel((x, y))) >= 250}
    component_sizes = []
    original = set(white)
    while white:
        pending = [white.pop()]
        size = 0
        while pending:
            x, y = pending.pop()
            size += 1
            for adjacent in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)]:
                if adjacent in white:
                    white.remove(adjacent)
                    pending.append(adjacent)
        component_sizes.append(size)
    results['mask_components'][name] = {'count': len(component_sizes), 'sizes': sorted(component_sizes)}
    if name.startswith('skin') and original:
        ys = [y for x,y in original]
        y = (min(ys) + max(ys)) // 2
        xs = [x for x,sy in original if sy == y]
        outline = Image.open(root / f'{name}-outline.png').convert('RGB')
        def gold(x):
            r,g,b = outline.getpixel((x,y))
            return r >= 250 and 180 <= g <= 230 and b <= 20
        left, right = min(xs), max(xs)
        results['stroke'][name] = {'scanY': y, 'maskLeft': left, 'maskRight': right, 'leftPixels': [x for x in range(left-8,left) if gold(x)], 'rightPixels': [x for x in range(right+1,right+9) if gold(x)]}
(root / 'pixel-analysis.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps(results))
