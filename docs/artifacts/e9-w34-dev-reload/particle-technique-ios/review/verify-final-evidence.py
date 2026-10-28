from pathlib import Path
import hashlib,json,re,subprocess
r=Path('/private/tmp/dart3d-e9-native-particle-review-20261027/r1'); p=Path('/private/tmp/dart3d-e9-particle-technique-probe-20261027/r1'); w=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-70a094be'); parent=w.parent/'t3-9d86c4eb'
sha=lambda x:hashlib.sha256(x).hexdigest()
def manifest(path): return dict((n.lstrip('*'),h) for h,n in (line.split(None,1) for line in path.read_text().splitlines()))
accepted=manifest(Path('/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/parent-source-sha256.txt'))
assert all(sha((parent/n).read_bytes())==h for n,h in accepted.items())
absent=['dart3d/ios/Classes/ParticleDebugProbe.swift','dart3d/example/lib/w34_particle_probe_main.dart','dart3d/example/lib/w34_particle_probe_scene.dart']
assert all(not (parent/n).exists() for n in absent)
pre=json.loads((r/'preimport-source-sha256.json').read_text()); post=json.loads((r/'postimport-source-sha256.json').read_text())
locks=['dart3d/example/dn_plugins.lock','dart3d/example/ios/Podfile.lock','dart3d/example/lib/dartnative_plugin_registrant.dart','dart3d/example/pubspec.lock','dart3d/pubspec.lock','probe/pubspec.lock']
assert all(pre[n]==post[n]==sha((w/n).read_bytes()) for n in locks)
assert all(sha((w/n).read_bytes())==h for n,h in post.items())
headers=Path('/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers')
source_receipt={}
excerpts=[]
for n,ranges in {'SCNTechnique.h':[(14,48),(96,128),(176,207),(296,326)],'scn_metal':[(8,23),(59,71)],'SCNParticleSystem.h':[(190,203),(215,225),(275,292),(310,360),(374,423)],'SCNSceneRenderer.h':[(314,320)]}.items():
    path=headers/n; data=path.read_bytes(); lines=data.decode().splitlines(); source_receipt[str(path)]=sha(data)
    excerpts.append(str(path)+' SHA256 '+sha(data))
    for start,end in ranges: excerpts.extend(f'{i}: {lines[i-1]}' for i in range(start,min(end,len(lines))+1))
(r/'installed-api-excerpts.txt').write_text('\n'.join(excerpts)+'\n')
# Inspect logs as records, without executing any native command from them.
logs={}
for f in ['parent-runtime/native.log','parent-runtime-r2/native.log']:
    lines=(p/f).read_text().splitlines()
    candidates=[l for l in lines if any(s in l.lower() for s in ['libraryerror','functionerror','techniqueerror','stateerror','requesterror','failed to compile','pipeline error','shader compilation','failed to create render'])]
    logs[f]={'reviewed_lines':len(lines),'matching_probe_or_pipeline_error_lines':candidates}
status=subprocess.check_output(['git','status','--short'],cwd=w,text=True); (r/'final-git-status.txt').write_text(status)
receipt={'parent_source_read_only_hash_check':{'accepted58_match':True,'three_probe_additions_absent':True,'device_or_process_state_queried':False},'review_checkout_all_postimport_bytes_preserved':True,'six_locks_registrants_unchanged':{n:post[n] for n in locks},'installed_headers':source_receipt,'logs':logs,'post_run_source_check_counts':{run:len((p/run/'source61-after.txt').read_text().splitlines()) for run in ['parent-runtime','parent-runtime-r2']}}
(r/'final-evidence-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n'); print(json.dumps(receipt,indent=2))
