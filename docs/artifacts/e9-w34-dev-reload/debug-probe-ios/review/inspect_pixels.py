import collections
import hashlib
import json
import pathlib
import subprocess

ROOT = pathlib.Path('/private/tmp/dart3d-e9-debug-probe-20261027/ios-r1/parent-runtime')
OUT = pathlib.Path(__file__).parent
NAMES = ['00-off-r2.png', '01-mapped-r2.png', '01-mapped-steady-r2.png',
         '02-geometry-r2.png', '03-transfer-r2.png', '04-mapped-return-r2.png',
         '05-off-restored-r2.png', '06-wire-on-r2.png', '07-wire-off-restored-r2.png']
W, H = 402, 874
pixels = {}
for name in NAMES:
    pixels[name] = subprocess.check_output(['ffmpeg', '-v', 'error', '-nostdin',
        '-i', str(ROOT / name), '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'])
    assert len(pixels[name]) == W * H * 3

def rgb(name, x, y):
    offset = (y * W + x) * 3
    return pixels[name][offset:offset + 3]

def compare(a, b):
    differences = [max(abs(x-y) for x,y in zip(rgb(a,i,j), rgb(b,i,j)))
                   for j in range(100, 750) for i in range(W)]
    return {'changedPixels': sum(v != 0 for v in differences), 'maxChannelDelta': max(differences)}

points = [(120,320), (260,330), (140,470), (290,475)]
report = {
    'meaning': 'Independent offline recomputation of encoded screenshot RGB; no calibrated normal claim.',
    'sceneCropXYWH': [0,100,402,650],
    'pngSHA256': {n: hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in NAMES},
    'comparisonsVsOff': {n: compare(NAMES[0],n) for n in NAMES[1:]},
    'mappedReturn': compare(NAMES[1],NAMES[5]),
    'mappedSteady': compare(NAMES[1],NAMES[2]),
    'samples': {n: {f'{x},{y}':list(rgb(n,x,y)) for x,y in points} for n in NAMES},
    'interiorRegion11x11': {},
}
for n in [NAMES[1],NAMES[3],NAMES[4]]:
    report['interiorRegion11x11'][n] = {
        f'{x},{y}': {','.join(map(str,k)):v for k,v in collections.Counter(
            tuple(rgb(n,i,j)) for j in range(y-5,y+6) for i in range(x-5,x+6)).items()}
        for x,y in points}

changed = [(x,y) for y in range(100,750) for x in range(W)
           if rgb(NAMES[0],x,y)!=rgb(NAMES[7],x,y)]
inner = [(x,y) for x,y in changed if 105<=x<=302 and 285<=y<=485]
# Projected diagonal joins screenshot vertices approximately (91,499) and (316,270).
distances = [abs((x-91)*229+(y-499)*225)/(229**2+225**2)**0.5 for x,y in inner]
report['wire'] = {'changedBoundingBox': [min(x for x,y in changed),min(y for x,y in changed),
    max(x for x,y in changed),max(y for x,y in changed)],
    'changedInsideFaceAwayFromPerimeter':len(inner),
    'maxInnerDistanceToExpectedTriangleDiagonalPixels':max(distances),
    'filledQuadUnchangedPixels':sum(rgb(NAMES[0],x,y)==rgb(NAMES[7],x,y)
        for y in range(100,750) for x in range(W) if any(rgb(NAMES[0],x,y)))}
parent = json.loads((ROOT/'pixel-analysis.json').read_text())
assert all(report['comparisonsVsOff'][n]['changedPixels']==p['changedPixelsVsInitialOff']
           and report['comparisonsVsOff'][n]['maxChannelDelta']==p['maximumChannelDifference']
           for n,p in parent['comparisons'].items())
assert report['samples']==parent['rgbSamples']
assert report['mappedReturn']['changedPixels']==parent['initialMappedVsReturnSceneChangedPixels']==0
report['parentNumbersReproduced'] = True
(OUT/'independent-pixels.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['samples','pngSHA256','interiorRegion11x11']},indent=2))
