import difflib
import hashlib
import json
import pathlib
import shutil
import subprocess
import tarfile
import tempfile

OUT = pathlib.Path(__file__).parent
ROOT = pathlib.Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-ba3b7060')
PROBE = pathlib.Path('/private/tmp/dart3d-e9-debug-probe-20261027/ios-r1')
BASE = pathlib.Path('/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1')
EXPECTED = {
    PROBE/'parent-r2-source.tgz': '2c70e6f6dd5c19f42bda18f6fe69a1835ace47a7a7d33807486bf8b175abcfb9',
    BASE/'parent-source.tgz': '6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706',
    PROBE/'parent-r2-probe.patch': '520fe187e53ec2f21059be9e3029860b2f15fa1dccad2d9ff3baef262ed8e3db',
}
sha = lambda b: hashlib.sha256(b).hexdigest()
for f, expected in EXPECTED.items():
    assert sha(f.read_bytes()) == expected

def archive(f):
    with tarfile.open(f) as t:
        members = t.getmembers()
        assert len(members) == len({m.name for m in members})
        assert all(m.isfile() and not pathlib.PurePosixPath(m.name).is_absolute()
                   and '..' not in pathlib.PurePosixPath(m.name).parts for m in members)
        return {m.name: t.extractfile(m).read() for m in members}

observed = archive(PROBE/'parent-r2-source.tgz')
baseline = archive(BASE/'parent-source.tgz')
assert len(observed) == 61 and len(baseline) == 58
for f, data in [(PROBE/'parent-r2-source-sha256.txt',observed),
                (BASE/'parent-source-sha256.txt',baseline)]:
    manifest = {name: digest for digest,name in (s.split(None,1) for s in f.read_text().splitlines())}
    assert manifest == {n:sha(v) for n,v in data.items()}
assert set((PROBE/'parent-r2-source-paths.txt').read_text().splitlines()) == set(observed)
owned = (PROBE/'parent-r2-owned-paths.txt').read_text().splitlines()
delta = sorted(n for n in observed.keys() | baseline.keys() if observed.get(n) != baseline.get(n))
assert delta == sorted(owned) and len(delta) == 5
unowned = {n:v for n,v in baseline.items() if n not in owned}
assert len(unowned) == 56 and all(observed[n] == v for n,v in unowned.items())
scratch = pathlib.Path(tempfile.mkdtemp(prefix='review-replay-',dir=OUT))
try:
    for n,v in baseline.items():
        f = scratch/n
        f.parent.mkdir(parents=True,exist_ok=True)
        f.write_bytes(v)
    receipts = []
    for reverse, expected in [(False, observed),(True, baseline)]:
        command = ['git','apply','--unsafe-paths'] + (['--reverse'] if reverse else []) + [str(PROBE/'parent-r2-probe.patch')]
        run = subprocess.run(command,cwd=scratch,text=True,capture_output=True)
        receipts.append({'reverse':reverse,'exit':run.returncode,'stdout':run.stdout,'stderr':run.stderr})
        assert run.returncode == 0
        assert {str(f.relative_to(scratch)):f.read_bytes() for f in scratch.rglob('*') if f.is_file()} == expected
    (OUT/'patch-replay.txt').write_text(json.dumps(receipts,indent=2)+'\n')
finally:
    shutil.rmtree(scratch)
assert all((ROOT/n).read_bytes() == v for n,v in observed.items())
locks = json.loads((BASE/'locks-baseline.json').read_text())
assert all(sha((ROOT/n).read_bytes()) == digest for n,digest in locks.items())
preservation = (PROBE/'parent-r2-preservation.log').read_text().splitlines()
recorded_unowned = {n:d for d,n in (s.split(None,1) for s in preservation if len(s)>66 and s[64:66]=='  ')}
assert recorded_unowned == {n:sha(v) for n,v in unowned.items()}
assert set(s for s in preservation if s.endswith(': OK')) == {n+': OK' for n in locks}
status = subprocess.check_output(['git','status','--porcelain','--untracked-files=all'],cwd=ROOT,text=True)
assert all(s[3:] in observed for s in status.splitlines())
(OUT/'final-git-status.txt').write_text(status)
r0 = archive(PROBE/'parent-source.tgz')
r0delta = [n for n in observed if observed[n] != r0[n]]
(OUT/'r0-r2.diff').write_text(''.join(''.join(difflib.unified_diff(r0[n].decode().splitlines(True),observed[n].decode().splitlines(True),fromfile='r0/'+n,tofile='r2/'+n)) for n in r0delta))
receipt = {'base_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'initial_status':'clean, recorded before import','archive_hashes':{str(f):d for f,d in EXPECTED.items()},
    'safe_unique_regular_paths':61,'baseline_paths':58,'delta':delta,'unowned56_preserved':True,
    'patch_replay_exact':True,'reverse_restores_exact58':True,'import61_exact':True,
    'six_locks_unchanged':locks,'parent_preservation_receipt_matches':True,
    'r0_r2_changed_paths':r0delta,'writes_outside_overlay_in_checkout':False,
    'scratch_removed':True}
assert receipt['base_head'] == '2f38e4e33f0b1cb678bc408a42d069c796cefc12'
(OUT/'source-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Source, exact forward/reverse replay, preservation, current import, and checkout scope verified.')
