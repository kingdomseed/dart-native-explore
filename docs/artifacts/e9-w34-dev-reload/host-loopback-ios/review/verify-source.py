from pathlib import Path
import hashlib, tarfile, subprocess, tempfile, shutil, json, difflib
repo=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4')
parent=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb')
p=Path('/private/tmp/dart3d-e9-host-reload-probe-20261027/r1')
b=Path('/private/tmp/dart3d-e5b-outline-state-current-20261027/r1')
out=Path('/private/tmp/dart3d-e9-host-reload-review-20261027/r1')
def digest(data): return hashlib.sha256(data).hexdigest()
def manifest(path): return {line.split(None,1)[1]:line.split(None,1)[0] for line in path.read_text().splitlines() if line.strip()}
def archive(path):
    with tarfile.open(path) as t:
        all_members=t.getmembers()
        members=[m for m in all_members if not Path(m.name).name.startswith("._")]
        assert all(Path(m.name).name.startswith("._") or m in members for m in all_members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
        result={m.name:t.extractfile(m).read() for m in members}
        assert len(result)==len(members)
        return result
expected={b/'parent-source.tgz':'646f5d269a78020fb588ea420fb2783ea9d5a998e6b8019fd8885ad365726f2d',p/'parent-first-source.tgz':'c6377d4960ad093f593ee63f91fb4f548c5724f1c8920fa9e673e402c9025723',p/'parent-source.tgz':'eb7239a2c3d8366d5d0baee9797ba84cd82d40750798bf9e90d5ece5b49d43e1',p/'candidate-source.tgz':'e7f294f5668e3f51eeb03f1180260405bf60cd0d767d6a8a97022ebeb8ab56cf',p/'candidate-probe.patch':'9817152232e53f26e5da3a06af069a4f6ce1b41889c8dc02fe9b50eb88263c79',p/'post-run-cleanup.patch':'118a2b3d977d24730a44d7d77a6db39f7c8dbf2786b668960fcfbcf79f1409c9'}
receipt={}
for path,want in expected.items():
    got=digest(path.read_bytes()); assert got==want,(path,got)
    receipt[str(path)]=got
(out/'archive-hashes.json').write_text(json.dumps(receipt,indent=2)+'\n')
base=archive(b/'parent-source.tgz'); first=archive(p/'parent-first-source.tgz'); observed=archive(p/'parent-source.tgz'); candidate=archive(p/'candidate-source.tgz')
assert len(base)==52 and len(first)==len(observed)==len(candidate)==57
assert {k:digest(v) for k,v in base.items()}==manifest(b/'parent-source-sha256.txt')
assert set((b/'parent-source-paths.txt').read_text().splitlines())==set(base)
assert {k:digest(v) for k,v in candidate.items()}==manifest(p/'candidate-source-sha256.txt')
owned=set((p/'owned-paths.txt').read_text().splitlines()); assert len(owned)==5
assert set(candidate)-set(base)==owned
assert all(candidate[k]==observed[k]==first[k]==v for k,v in base.items())
assert all(k in candidate for k in base)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()=='2f38e4e33f0b1cb678bc408a42d069c796cefc12'
assert subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True)==''
tracked=subprocess.check_output(['git','ls-files','-z'],cwd=repo).decode().split('\0')
before={k:digest((repo/k).read_bytes()) for k in tracked if k and (repo/k).is_file()}
locks=manifest(p/'locks-registrants-sha256.txt'); assert len(locks)==6
for k,v in locks.items(): assert digest((repo/k).read_bytes())==v
for k in owned: assert not (repo/k).exists()
for overlay in [base,candidate]:
    for k,v in overlay.items():
        target=repo/k; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(v)
assert all(digest((repo/k).read_bytes())==v for k,v in manifest(p/'candidate-source-sha256.txt').items())
assert all(digest((repo/k).read_bytes())==v for k,v in locks.items())
assert all(digest((repo/k).read_bytes())==v for k,v in before.items() if k not in base)
receipt={'base_count':52,'candidate_count':57,'exact_additions':sorted(owned),'unowned_tracked_preserved':len(set(before)-set(base)),'locks_preserved':6,'parent_read_only_source52_matches':all(digest((parent/k).read_bytes())==digest(v) for k,v in base.items()),'parent_five_additions_absent':all(not (parent/k).exists() for k in owned),'parent_locks_match':all(digest((parent/k).read_bytes())==v for k,v in locks.items())}
assert receipt['parent_read_only_source52_matches'] and receipt['parent_five_additions_absent'] and receipt['parent_locks_match']
(out/'import-preservation.json').write_text(json.dumps(receipt,indent=2)+'\n')
changes={}
for label,a,z in [('initial-to-observed',first,observed),('observed-to-candidate',observed,candidate)]:
    delta=[k for k in a if a[k]!=z[k]]; changes[label]=delta
    (out/(label+'.diff')).write_text(''.join(''.join(difflib.unified_diff(a[k].decode().splitlines(True),z[k].decode().splitlines(True),fromfile='a/'+k,tofile='b/'+k)) for k in delta))
assert changes['initial-to-observed']==['dart3d/example/lib/w34_reload_main.dart']
assert set(changes['observed-to-candidate'])=={'dart3d/example/tool/w34_reload_host.dart','dart3d/example/test/w34_reload_transport_test.dart'}
scratch=Path(tempfile.mkdtemp(prefix='e9-review-replay-',dir='/private/tmp'))
lines=[]
def put(data):
    for k,v in data.items():
        f=scratch/k; f.parent.mkdir(parents=True,exist_ok=True); f.write_bytes(v)
def check(data):
    assert {str(x.relative_to(scratch)):x.read_bytes() for x in scratch.rglob('*') if x.is_file()}==data

def apply(name,reverse=False,check_only=False):
    args=['git','apply']+(['--reverse'] if reverse else [])+(['--check'] if check_only else [])+[str(p/name)]
    r=subprocess.run(args,cwd=scratch,text=True,capture_output=True); assert r.returncode==0,(args,r.stdout,r.stderr)
    lines.append('PASS '+' '.join(args))
try:
    put(base); check(base)
    apply('candidate-probe.patch',check_only=True); apply('candidate-probe.patch'); check(candidate); lines.append('PASS exact candidate57 after forward replay')
    apply('candidate-probe.patch',reverse=True,check_only=True); apply('candidate-probe.patch',reverse=True); check(base); lines.append('PASS exact baseline52 and five additions absent after reverse replay')
    put(observed); apply('post-run-cleanup.patch',check_only=True); apply('post-run-cleanup.patch'); check(candidate); lines.append('PASS observed57 plus cleanup equals exact candidate57')
    apply('post-run-cleanup.patch',reverse=True,check_only=True); apply('post-run-cleanup.patch',reverse=True); check(observed); lines.append('PASS cleanup reverse equals exact observed57')
finally:
    shutil.rmtree(scratch); lines.append('REMOVED own replay scratch '+str(scratch))
(out/'replay.log').write_text('\n'.join(lines)+'\n')
(out/'source-boundary.json').write_text(json.dumps(changes,indent=2)+'\n')
print(json.dumps(receipt,indent=2)); print('\n'.join(lines)); print(json.dumps(changes,indent=2))
