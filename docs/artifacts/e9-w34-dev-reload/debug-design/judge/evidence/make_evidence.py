from pathlib import Path
import hashlib,json
root=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-74528bbe')
base=Path('/private/tmp/dart3d-e9-debug-design-20261027')
out=base/'judge/evidence'
sdk=Path('/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.1.sdk/System/Library/Frameworks/SceneKit.framework/Headers')
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def parse_manifest(p): return {s.split(None,1)[1].strip():s.split(None,1)[0] for s in p.read_text().splitlines() if s.strip()}
expected=parse_manifest(out/'accepted58-sha256.txt')
for c,name in [('a','import-sha256.txt'),('b','accepted58-sha256.txt'),('c','accepted58-sha256.txt')]:
    assert parse_manifest(base/f'candidate-{c}'/name)==expected
locks=json.loads((out/'locks-before.json').read_text())
assert parse_manifest(base/'candidate-a/locks-sha256.txt')==locks
assert json.loads((base/'candidate-b/preserved-locks.json').read_text())==locks
assert json.loads((base/'candidate-c/preservation-receipt.json').read_text())['lock_and_registrant_sha256']==locks
inputs=[base/'rubric.md',base/'grounding.md',Path('/private/tmp/dart3d-e9-debug-source-20261027/ios/source-map.md'),Path('/private/tmp/dart3d-e9-debug-source-20261027/android/source-map.md'),Path('/private/tmp/dart3d-e9-debug-native-review-20261027/r1/report.md')]
inputs += [Path('/Users/jasonholt/.gradle/caches/8.14/transforms/9bb4994d005a4c5de333b93df3141828/transformed/filament-android-1.77.3-api.jar'),Path('/Users/jasonholt/.gradle/caches/8.14/transforms/b8bb90b8ae8c1309c730b47ce826f73b/transformed/filamat-android-1.77.3-api.jar')]
inputs += [sdk/n for n in ['SCNSkinner.h','SCNParticleSystem.h','SCNShadable.h','SCNTechnique.h']]
inputs += [root/p for p in ['docs/program-v2.md','docs/full-engine-program.md','dart3d/README.md','.devin/skills/dart-native/SKILL.md','dart3d/lib/src/scene_view.dart','dart3d/lib/src/scene_controller.dart','dart3d/ios/Classes/FsceneRealizer.swift','dart3d/ios/Classes/SceneViewHost.swift','dart3d/ios/Classes/RenderTargets.swift','dart3d/ios/Classes/BakedShadowCatchers.swift','dart3d/ios/Classes/ToneMapping.swift','dart3d/android/build.gradle','dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt','dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/FsceneRealizer.kt','dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/MaterialRecipe.kt','dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/RenderTargets.kt','dart3d/tool/bake_materials.sh']]
(out/'input-receipt.json').write_text(json.dumps({'files':{str(p):digest(p) for p in inputs},'candidate_adjacent_manifests_match_accepted58':True,'candidate_adjacent_lock_receipts_match_six_locks':True,'scope':'source/API inspection and preservation, no behavior tests'},indent=2)+'\n')
vendor_paths=['filament/src/details/Renderer.cpp','filament/src/details/Engine.cpp','filament/src/details/MaterialInstance.cpp','filament/src/components/RenderableManager.cpp','filament/src/RenderPass.cpp','android/filament-android/src/main/java/com/google/android/filament/Renderer.java','android/filament-android/src/main/java/com/google/android/filament/RenderableManager.java','shaders/src/surface_main.fs','filament/src/RenderPrimitive.cpp']
(out/'vendor-provenance.json').write_text(json.dumps({Path(p).name:{'url':'https://raw.githubusercontent.com/google/filament/v1.77.3/'+p,'sha256':digest(out/'filament'/Path(p).name)} for p in vendor_paths},indent=2)+'\n')
sections=[]
def excerpt(p,ranges):
    lines=p.read_text().splitlines()
    for start,end in ranges:
        sections.append('\n## '+str(p)+f':{start}-{end}\n\n```text\n'+'\n'.join(f'{i}: {lines[i-1]}' for i in range(start,min(end,len(lines))+1))+'\n```\n')
excerpt(sdk/'SCNSkinner.h',[(23,81)])
excerpt(sdk/'SCNParticleSystem.h',[(17,36),(61,82),(197,203),(310,377),(406,423)])
excerpt(sdk/'SCNShadable.h',[(65,89)])
excerpt(sdk/'SCNTechnique.h',[(26,47),(108,109),(174,180)])
excerpt(root/'dart3d/ios/Classes/FsceneRealizer.swift',[(6116,6120),(6267,6305),(6367,6377),(6785,6821)])
excerpt(root/'dart3d/ios/Classes/RenderTargets.swift',[(558,628)])
excerpt(root/'dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt',[(1254,1262),(3506,3555),(5835,5884)])
excerpt(out/'filament/Renderer.cpp',[(510,528),(671,757),(1067,1118)])
excerpt(out/'filament/Engine.cpp',[(759,799)])
excerpt(out/'filament/MaterialInstance.cpp',[(215,273)])
excerpt(out/'filament/RenderableManager.cpp',[(866,900),(971,994)])
excerpt(out/'filament/RenderPass.cpp',[(674,709),(1118,1127)])
excerpt(out/'filament/RenderPrimitive.cpp',[(61,83)])
(out/'source-excerpts.md').write_text('# Independently inspected source excerpts\n\nLine numbers are one-based in the exact hashed local inputs. Vendor source is pinned v1.77.3; cached web line numbers may differ.\n'+''.join(sections))
print(json.dumps({'input_files_hashed':len(inputs),'vendor_files_hashed':len(vendor_paths),'candidate_manifests_checked':3,'candidate_lock_receipts_checked':3,'excerpt_sections':len(sections)}))
