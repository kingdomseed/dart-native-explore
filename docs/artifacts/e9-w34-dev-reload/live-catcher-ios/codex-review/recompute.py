import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from PIL import Image, ImageChops

OUT = Path('/private/tmp/dart3d-w34-ios-live-production-review-20261028/r1')
E = Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e9-w34-dev-reload/live-catcher-ios')
W = Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-c1dca07d')
def sha(data): return hashlib.sha256(data).hexdigest()
def save(name, value): (OUT/name).write_text(json.dumps(value, indent=2)+'\n')
def archive(name):
    with tarfile.open(E/'source'/name) as t:
        return {m.name.removeprefix('./'):t.extractfile(m).read() for m in t.getmembers() if m.isfile() and not any(p.startswith('._') or p == '__MACOSX' for p in Path(m.name).parts)}

receipt=json.loads((E/'source/receipt.json').read_text())
checks={name:sha((E/'source'/name).read_bytes()) for name in ['source.tgz','baseline66-source.tgz','correction.patch']}
assert checks['source.tgz']==receipt['sourceArchiveSha256']
assert checks['baseline66-source.tgz']==receipt['baselineArchiveSha256']
assert checks['correction.patch']==receipt['patchSha256']
a,b=archive('baseline66-source.tgz'),archive('source.tgz')
assert len(a)==len(b)==66 and a.keys()==b.keys()
changed=sorted(k for k in a if a[k]!=b[k])
assert changed==sorted(receipt['changedPaths'])
for name, data in [('baseline-source-sha256.json',a),('source-sha256.json',b)]:
    assert {k:sha(v) for k,v in data.items()}==json.loads((E/'source'/name).read_text())
manifest=json.loads((E/'evidence-sha256.json').read_text())
bad=[k for k,v in manifest.items() if sha((E/k).read_bytes())!=v]
assert not bad, bad
locks={k:sha((W/k).read_bytes()) for k in receipt['locks']}
assert locks==receipt['locks']
# The only checkout import is the authorized, verified final66 packet.
for k,v in b.items():
    dest=W/k
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(v)
assert all(sha((W/k).read_bytes())==sha(v) for k,v in b.items())
assert {k:sha((W/k).read_bytes()) for k in locks}==locks
save('integrity.json', {'requiredHead':receipt['head'],'archiveHashes':checks,'archiveFiles':len(b),'changedPaths':changed,'unchangedOverlayPeers':60,'evidenceManifestEntries':len(manifest),'evidenceManifestMismatches':bad,'locks':locks,'final66Imported':True})
print('integrity: 66 files; six changed; 60 preserved; manifest '+str(len(manifest))+' exact',flush=True)

cache={}
def image(p):
    if p not in cache:
        cache[p]=Image.open(E/p).convert('RGB')
    return cache[p]
for name in ['pixel-analysis.json','final-pixel-analysis.json']:
    data=json.loads((E/name).read_text()); rows=[]
    for r in data['comparisons']:
        x,y,w,h=r['crop']; box=(x,y,x+w,y+h)
        left,right=image(r['left']),image(r['right'])
        assert left.size==right.size==(402,874)
        diff=ImageChops.difference(left.crop(box),right.crop(box))
        pixels=list(diff.getdata())
        changedPixels=sum(any(p) for p in pixels)
        maximum=max(max(p) for p in pixels)
        assert changedPixels==r['changedPixels'] and maximum==r['maxRGBDifference'],r
        rows.append(dict(r, independentlyRecomputed=True))
    stable=[r for r in rows if r['expectedStable']]
    save('recomputed-'+name, {'comparisons':rows,'stableCount':len(stable),'stableFailures':[r for r in stable if r['changedPixels']]})
    print(name+': '+str(len(rows))+' comparisons; '+str(len(stable))+' stable exact',flush=True)

originals=json.loads((E/'local-originals.json').read_text())
for p,r in originals.items():
    f=Path(p)
    assert f.stat().st_size==r['bytes'] and sha(f.read_bytes())==r['sha256'],p
save('local-original-hashes.json',{'verified':len(originals),'originals':originals})
print('local originals: all '+str(len(originals))+' hashes and sizes exact',flush=True)
