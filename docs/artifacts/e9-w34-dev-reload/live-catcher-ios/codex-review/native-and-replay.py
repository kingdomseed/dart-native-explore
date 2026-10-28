import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

O=Path('/private/tmp/dart3d-w34-ios-live-production-review-20261028/r1')
E=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e9-w34-dev-reload/live-catcher-ios')
P=E.parents[3]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,x):(O/n).write_text(json.dumps(x,indent=2)+'\n')
def files(name):
    with tarfile.open(E/'source'/name) as t:
        return {m.name.removeprefix('./'):t.extractfile(m).read() for m in t.getmembers() if m.isfile() and not any(p.startswith('._') or p=='__MACOSX' for p in Path(m.name).parts)}
a,b=files('baseline66-source.tgz'),files('source.tgz')
with tempfile.TemporaryDirectory(prefix='replay-',dir=O) as tmp:
    d=Path(tmp)
    for k,v in a.items():
        p=d/k;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(v)
    results=[]
    for reverse,expected in [(False,b),(True,a)]:
        cmd=['git','apply']+(['--reverse'] if reverse else [])+[str(E/'source/correction.patch')]
        run=subprocess.run(cmd,cwd=d,capture_output=True,text=True)
        assert run.returncode==0,run.stderr
        assert all((d/k).read_bytes()==v for k,v in expected.items())
        results.append({'reverse':reverse,'exit':run.returncode,'all66Exact':True})
save('patch-replay.json',{'runs':results,'scratchRemoved':True})
final=json.loads((E/'source/source-sha256.json').read_text())
packets={}
for stage in ['before','traced','clean','blend-before','blend-after','final-clean']:
    p=json.loads((E/stage/'packet/source-sha256.json').read_text())
    packets[stage]=sorted(k for k in p if p[k]!=final.get(k))
assert packets['final-clean']==['docs/debug-views.md']
assert packets['blend-after']==['docs/debug-views.md']
save('packet-differences.json',packets)
initial=json.loads((E/'initial-all-source.json').read_text())
owned=json.loads((E/'source/receipt.json').read_text())['changedPaths']
other={k:v for k,v in initial.items() if k not in owned}
bad=[k for k,v in other.items() if not (P/k).is_file() or digest(P/k)!=v]
assert not bad,bad
save('parent-preservation.json',{'initialFiles':len(initial),'excludedOwnedChanges':len(owned),'otherFiles':len(other),'mismatches':bad,'readOnlyVerification':True})

error=re.compile(r'fatal|shader.*error|Cannot modify|cross.scene mutation|SCNTransaction|unrecognized selector|UI API called',re.I)
raw=Path('/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent/native-all.log').read_text().splitlines()
group={}
for line in raw:
    m=re.search(r'Runner\[(\d+):',line)
    if m:group.setdefault(m[1],[]).append(line)
expected=json.loads((E/'native-summary.json').read_text());summaries={}
for stage,r in expected.items():
    lines=group[r['pid']]
    counts={name:sum('liveDebugTrace '+event in l for l in lines) for name,event in [('templateCreates','templateCreate'),('displayCreates','displayCreate'),('displayRemovals','displayRemove')]}
    samples=[l for l in lines if 'liveDebugTrace sample frame=' in l]
    epochs=[];latest={}
    for l in lines:
        c=re.search(r'displayCreate node=(ObjectIdentifier\([^)]+\)) template=(ObjectIdentifier\([^)]+\)) displayed=(ObjectIdentifier\([^)]+\))',l)
        if c:
            epoch={'epoch':len(epochs)+1,'node':c[1],'template':c[2],'displayed':c[3],'samples':[]}
            epochs.append(epoch);latest[c[1]]=epoch
        if 'liveDebugTrace sample frame=' not in l:continue
        s=re.search(r'node=(ObjectIdentifier\([^)]+\)) template=(ObjectIdentifier\([^)]+\)) displayed=(ObjectIdentifier\([^)]+\)) inputI=(\S+) actualI=(\S+) inputShadow=(\S+) actualShadow=(\S+) fieldsMatch=(\S+) attached=(\S+) colorInput=(.*?) colorActual=(.*)$',l)
        assert s and s[4]==s[5] and s[6]==s[7] and s[8]==s[9]=='true' and s[10]==s[11]
        epoch=latest[s[1]];assert epoch['template']==s[2] and epoch['displayed']==s[3]
        epoch['samples'].append((float(s[4]),s[6]))
    epoch_summaries=[{k:v for k,v in e.items() if k!='samples'}|{'sampleCount':len(e['samples']),'intensities':sorted(set(s[0] for s in e['samples'])),'shadowValues':sorted(set(s[1] for s in e['samples']))} for e in epochs]
    capture=[int(re.search(r'captureCount templates=(\d+)',l)[1]) for l in lines if 'liveDebugTrace captureCount templates=' in l]
    errors=[l for l in lines if error.search(l)]
    assert len(samples)==r['sampleCount'] and len(errors)==r['errorQueryMatches']
    if r['instrumented']:
        assert all(counts[k]==r[k] for k in counts)
        assert capture==r['captureTemplateCounts']
    summaries[stage]={'pid':r['pid'],'sampleCount':len(samples),'matchingLoggedSampleValues':True if samples else None,'errorMatches':len(errors),'creationRemovalCallSites':counts if samples else None,'captureCounts':capture if samples else None,'epochs':epoch_summaries,'adapterProbe':[l for l in lines if 'liveDebugTrace adapterProbe' in l]}
save('native-recomputed.json',summaries)
raw=Path('/private/tmp/dart3d-w34-ios-live-production-20261028/r1/parent/blend-before/native-all.log').read_text().splitlines()
final_expected=json.loads((E/'final-native-analysis.json').read_text())['stages'];counts={}
for stage,r in final_expected.items():
    lines=[l for l in raw if 'Runner['+r['pid']+':' in l]
    actual={'nativeRowCount':len(lines),'eventRows':sum('com.jasonholtdigital.dart3d:scene' in l for l in lines),'errorMatches':sum(bool(error.search(l)) for l in lines)}
    assert all(actual[k]==r[k] for k in actual)
    counts[stage]={'pid':r['pid'],**actual,'sampledCopyCount':None,'templateCreateCount':None,'displayCreateCount':None}
save('final-native-recomputed.json',counts)
print(json.dumps({'replay':'forward and reverse all66 exact','parentOtherFiles':len(other),'samples':summaries['traced']['sampleCount'],'callSites':summaries['traced']['creationRemovalCallSites'],'finalPIDs':counts}))
