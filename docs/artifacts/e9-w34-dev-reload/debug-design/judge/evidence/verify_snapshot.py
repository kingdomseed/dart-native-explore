from pathlib import Path, PurePosixPath
import hashlib, json, subprocess, tarfile
root = Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe')
base = Path('/private/tmp/dart3d-e9-debug-design-20261027')
out = base / 'judge/evidence'
arc = Path('/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/parent-source.tgz')
man = arc.with_name('parent-source-sha256.txt')
def sha(data): return hashlib.sha256(data).hexdigest()
def digest(path): return sha(path.read_bytes())
def git(*args): return subprocess.check_output(['git', '-C', str(root), *args]).decode()
def dump(name, data): (out / name).write_text(json.dumps(data, indent=2)+'\n')
expected = dict((line.split(None,1)[1].strip(), line.split(None,1)[0]) for line in man.read_text().splitlines() if line.strip())
locks = ['dart3d/pubspec.lock', 'dart3d/example/pubspec.lock', 'dart3d/example/dn_plugins.lock', 'dart3d/example/lib/dartnative_plugin_registrant.dart', 'dart3d/example/ios/Podfile.lock', 'probe/pubspec.lock']
if not (out / 'import-receipt.json').exists():
    assert git('rev-parse','HEAD').strip() == '2f38e4e33f0b1cb678bc408a42d069c796cefc12'
    assert not git('status','--porcelain=v1','--untracked-files=all').strip()
    assert digest(arc) == '6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706'
    before = {p:digest(root/p) for p in git('ls-files','-z').split('\0') if p and (root/p).is_file()}
    dump('checkout-before.json', before)
    candidates = {str(p.relative_to(base)):digest(p) for d in ('candidate-a','candidate-b','candidate-c') for p in (base/d).iterdir() if p.is_file()}
    dump('candidate-inputs-before.json', candidates)
    dump('locks-before.json', {p:digest(root/p) for p in locks})
    with tarfile.open(arc) as t:
        members = t.getmembers()
        assert len(members) == len(expected) == 58
        assert len(set(m.name for m in members)) == 58
        for m in members:
            p = PurePosixPath(m.name)
            assert m.isfile() and not p.is_absolute() and '..' not in p.parts and m.name in expected
            assert sha(t.extractfile(m).read()) == expected[m.name]
        for m in members:
            target = root/m.name
            assert not target.is_symlink()
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(t.extractfile(m).read())
    dump('import-receipt.json', {'head':git('rev-parse','HEAD').strip(),'pre_import_status':'clean','archive_sha256':digest(arc),'manifest_sha256':digest(man),'imported_files':58,'purpose':'authorized read-only accepted58 source overlay'})
assert all(digest(root/p)==h for p,h in expected.items())
before = json.loads((out/'checkout-before.json').read_text())
assert all(digest(root/p)==h for p,h in before.items() if p not in expected)
assert all(digest(root/p)==h for p,h in json.loads((out/'locks-before.json').read_text()).items())
candidates = json.loads((out/'candidate-inputs-before.json').read_text())
assert all(digest(base/p)==h for p,h in candidates.items())
for c in ('b','c'):
    receipt=json.loads((base/f'candidate-{c}/preservation-receipt.json').read_text())
    assert receipt['design_sha256']==digest(base/f'candidate-{c}/design.md')
assert (base/'candidate-a/design-sha256.txt').read_text().split()[0]==digest(base/'candidate-a/design.md')
status=git('status','--porcelain=v1','--untracked-files=all')
assert all(line[3:] in expected for line in status.splitlines())
(out/'final-git-status.txt').write_text(status)
(out/'accepted58-sha256.txt').write_text(man.read_text())
dump('preservation-receipt.json',{'head_unchanged':git('rev-parse','HEAD').strip()=='2f38e4e33f0b1cb678bc408a42d069c796cefc12','accepted58_all_unchanged':True,'other_tracked_files_unchanged':True,'six_locks_unchanged':True,'candidate_artifacts_unchanged':True,'candidate_design_receipt_hashes_match':True,'candidate_design_sha256':{c:digest(base/f'candidate-{c}/design.md') for c in 'abc'},'all_git_deltas_within_import':True,'status_lines':len(status.splitlines()),'runtime':'NOT_RUN','builds':'NOT_RUN','tests':'NOT_RUN','devices':'NOT_RUN','performance':'NOT_RUN'})
print(json.dumps({'accepted58_verified':58,'preserved_locks':6,'candidate_design_hashes_verified':3,'checkout_deltas':len(status.splitlines())}))
