from pathlib import Path
import hashlib, json, tarfile, io, subprocess, tempfile, shutil
root=Path('/private/tmp/dart3d-e9-native-particle-review-20261027/r1')
p=Path('/private/tmp/dart3d-e9-particle-technique-probe-20261027/r1')
b=Path('/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1')
w=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-70a094be')
durable=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e9-w34-dev-reload/particle-technique-ios')
def sha(data): return hashlib.sha256(data).hexdigest()
def manifest(path):
    result={}
    for line in path.read_text().splitlines():
        h,n=line.split(None,1); n=n.lstrip('*')
        assert n not in result
        result[n]=h
    return result
def verify_manifest(base,path):
    entries=manifest(path)
    for n,h in entries.items(): assert sha((base/n).read_bytes())==h,(path,n)
    return {'count':len(entries),'manifest_sha256':sha(path.read_bytes())}
def archive(path,expected):
    assert sha(path.read_bytes())==expected
    result={}
    with tarfile.open(path) as t:
        for m in t.getmembers():
            assert m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts
            assert m.name not in result
            result[m.name]=t.extractfile(m).read()
    return result
def inventory(base):
    return {str(f.relative_to(base)):sha(f.read_bytes()) for f in base.rglob('*') if f.is_file()}
receipt={'base_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=w,text=True).strip()}
assert receipt['base_head']=='2f38e4e33f0b1cb678bc408a42d069c796cefc12'
assert subprocess.check_output(['git','status','--porcelain'],cwd=w)==b''
receipt['private_packet']=verify_manifest(p,p/'packet-sha256.txt')
receipt['durable_packet']=verify_manifest(durable,durable/'evidence-sha256.txt')
for n,h in manifest(durable/'evidence-sha256.txt').items(): assert sha((p/n).read_bytes())==h,('correspondence',n)
receipt['durable_correspondence']='all 52 files byte-identical to frozen private packet'
receipt['video_hashes']=verify_manifest(p,p/'video-sha256.txt')
accepted=archive(b/'parent-source.tgz','6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706')
r1=archive(p/'parent-source.tgz','560cbe5d93d83b8bd96c659002e6d71d98ab1a304468dd0f7b5a811c79af9294')
r2=archive(p/'parent-r2-source.tgz','ad36f3cb97f394bc56324e9bd0f211d3ea6e7225132c594436f54049764d6ecb')
for name,data,man in [('accepted58',accepted,b/'parent-source-sha256.txt'),('r1',r1,p/'parent-source-sha256.txt'),('r2',r2,p/'parent-r2-source-sha256.txt')]:
    assert {n:sha(v) for n,v in data.items()}==manifest(man)
    receipt[name]={'paths':len(data),'all_manifest_entries_match':True}
scoped={'dart3d/ios/Classes/ParticleDebugProbe.swift','dart3d/ios/Classes/SceneViewHost.swift','dart3d/example/lib/w34_particle_probe_scene.dart','dart3d/example/lib/w34_particle_probe_main.dart'}
for name,data in [('r1',r1),('r2',r2)]:
    assert {n for n in set(accepted)|set(data) if accepted.get(n)!=data.get(n)}==scoped
    receipt[name]['unchanged_accepted_sources']=sum(data.get(n)==v for n,v in accepted.items())
receipt['r1_to_r2_changed_paths']=[n for n in r1 if r1[n]!=r2[n]]
import difflib
(root/'r1-to-r2.diff').write_text(''.join(difflib.unified_diff(r1['dart3d/ios/Classes/ParticleDebugProbe.swift'].decode().splitlines(True),r2['dart3d/ios/Classes/ParticleDebugProbe.swift'].decode().splitlines(True),fromfile='r1',tofile='r2')))
base_tar=subprocess.check_output(['git','archive','HEAD'],cwd=w)
with tarfile.open(fileobj=io.BytesIO(base_tar)) as t:
    base={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
base.update(accepted)
receipt['baseline_regular_paths']=len(base)
replay=Path(tempfile.mkdtemp(prefix='replay-',dir=root))
try:
    for n,v in base.items():
        f=replay/n; f.parent.mkdir(parents=True,exist_ok=True); f.write_bytes(v)
    baseline=inventory(replay)
    receipt['replays']={}
    for name,data,patch,expected_hash in [('r1',r1,p/'parent-probe.patch','4b67a86525f3bcb961bb9307d51f541e4b9e6b72b54653776fe996d35ce22620'),('r2',r2,p/'parent-r2-probe.patch','2709b22236ef3f9867e554105b81deb78c147ffe0f088e84269dae58564e1d46')]:
        assert sha(patch.read_bytes())==expected_hash
        commands=[]
        for args in [['--check'],[]]:
            cmd=['git','apply',*args,str(patch)]; result=subprocess.run(cmd,cwd=replay,capture_output=True,text=True); assert result.returncode==0,result.stderr; commands.append({'argv':cmd,'exit':result.returncode,'stderr':result.stderr})
        after=inventory(replay)
        assert all(after[n]==sha(v) for n,v in data.items())
        assert all(after[n]==h for n,h in baseline.items() if n not in scoped)
        expected=dict(baseline); expected.update({n:sha(v) for n,v in data.items()}); assert after==expected
        for args in [['--reverse','--check'],['--reverse']]:
            cmd=['git','apply',*args,str(patch)]; result=subprocess.run(cmd,cwd=replay,capture_output=True,text=True); assert result.returncode==0,result.stderr; commands.append({'argv':cmd,'exit':result.returncode,'stderr':result.stderr})
        assert inventory(replay)==baseline
        receipt['replays'][name]={'commands':commands,'source61_exact':True,'unowned_preserved':sum(n not in scoped for n in baseline),'reverse_exact_baseline':True,'archive_sha256':sha((p/('parent-source.tgz' if name=='r1' else 'parent-r2-source.tgz')).read_bytes()),'patch_sha256':expected_hash}
finally:
    shutil.rmtree(replay)
receipt['replay_scratch_removed']=True
# The only import is the observed coherent r2 archive; no parent writes.
before={n:sha((w/n).read_bytes()) for n in subprocess.check_output(['git','ls-files','-co','--exclude-standard','-z'],cwd=w).decode().split('\0') if n and (w/n).is_file()}
for n,v in r2.items():
    f=w/n; f.parent.mkdir(parents=True,exist_ok=True); f.write_bytes(v)
after={n:sha((w/n).read_bytes()) for n in subprocess.check_output(['git','ls-files','-co','--exclude-standard','-z'],cwd=w).decode().split('\0') if n and (w/n).is_file()}
assert all(after[n]==h for n,h in before.items() if n not in r2)
assert all(after[n]==sha(v) for n,v in r2.items())
receipt['import']={'source61_exact':True,'unowned_paths_preserved':sum(n not in r2 for n in before),'before_count':len(before),'after_count':len(after)}
locks=[n for n in before if n.endswith(('pubspec.lock','Podfile.lock','Package.resolved','GeneratedPluginRegistrant.swift','GeneratedPluginRegistrant.m','GeneratedPluginRegistrant.h','dartnative_plugin_registrant.dart'))]
receipt['import']['locks_registrants_preserved']={n:after[n] for n in locks}; assert all(before[n]==after[n] for n in locks)
(root/'preimport-source-sha256.json').write_text(json.dumps(before,indent=2)+'\n')
(root/'postimport-source-sha256.json').write_text(json.dumps(after,indent=2)+'\n')
(root/'source-replay-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
