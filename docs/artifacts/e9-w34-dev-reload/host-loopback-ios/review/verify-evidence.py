from pathlib import Path
import hashlib,json,subprocess,re
p=Path('/private/tmp/dart3d-e9-host-reload-probe-20261027/r1'); o=Path('/private/tmp/dart3d-e9-host-reload-review-20261027/r1')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
checks=[]
for line in (p/'parent-evidence-sha256.txt').read_text().splitlines():
    expected,name=line.split(None,1); f=p/name
    got=sha(f); checks.append({'file':name,'expected':expected,'actual':got,'match':got==expected})
(o/'parent-evidence-hashes.json').write_text(json.dumps(checks,indent=2)+'\n')
assert all(c['match'] for c in checks)
video=p/'parent-reload-controls.mp4'; vsha=sha(video)
assert vsha=='0bece5e937b718a05d9473ab95e4d00e26dea7a7680e8989311efe792c3fda7a'
probe=subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(video)],capture_output=True,text=True,check=True)
(o/'video-probe.json').write_text(probe.stdout)
v=json.loads(probe.stdout); stream=v['streams'][0]; assert stream['time_base']=='1/600'; assert v['format']['duration']=='33.795000'
cmd=['ffmpeg','-nostdin','-v','info','-xerror','-err_detect','explode','-i',str(video),'-map','0:v:0','-fps_mode','passthrough','-f','null','-']
r=subprocess.run(cmd,capture_output=True,text=True)
(o/'video-strict-decode.log').write_text('Command '+repr(cmd)+'\n'+r.stderr+'\nExit '+str(r.returncode)+'\n')
assert r.returncode==0
frames=re.findall(r'frame=\s*(\d+)',r.stderr); assert frames[-1]=='2109'
names=['00-red','01-blue','02-dark-blue','03-malformed-retained','04-recovered-red']
images=[]; dims=[]
for name in names:
    f=p/('parent-'+name+'.png')
    meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=width,height','-of','json',str(f)]))['streams'][0]
    w,h=meta['width'],meta['height']; dims.append([w,h]); assert (w,h)==(402,874)
    images.append(subprocess.check_output(['ffmpeg','-nostdin','-v','error','-i',str(f),'-f','rawvideo','-pix_fmt','rgb24','-']))
def changed(a,b):
    return sum(a[i:i+3]!=b[i:i+3] for y in range(100,700) for i in range(y*402*3,(y+1)*402*3,3))
samples=[]
for n,data in zip(names,images):
    avg=[sum(data[(y*402+x)*3+c] for y in range(340,349) for x in range(180,189))/81 for c in range(3)]
    samples.append({'file':'parent-'+n+'.png','meanRgb9x9':avg,'changedScenePixelsAgainstInitial':changed(images[0],data)})
comparison={'crop':[0,100,402,700],'sample':[180,340,9,9],'samples':samples,'malformedAgainstLastValidChangedPixels':changed(images[2],images[3]),'recoveryAgainstInitialChangedPixels':changed(images[0],images[4]),'scope':'Encoded screenshot observations only, not photometry, alpha or latency.'}
assert comparison==json.loads((p/'parent-image-comparison.json').read_text())
(o/'independent-image-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
initial=(p/'parent-authored-initial.fscene').read_bytes(); material=(p/'parent-authored-material.fscene').read_bytes(); env=(p/'parent-authored-environment.fscene').read_bytes(); baseline=(p/'parent-authored-baseline.fscene').read_bytes(); malformed=(p/'parent-authored-malformed.fscene').read_bytes()
a,b,c=map(json.loads,[initial,material,env]); expected=json.loads(initial); expected['resources']['mat:01VK6D0000000']['properties']['baseColor']['c']=[.03,.08,.7,1.]; assert b==expected
expected['resources']['env:01VK6D000000A']['exposure']=.2; assert c==expected
assert initial==baseline and malformed==b'{'
assert (Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-71903ff4')/'dart3d/example/tool/fixtures/w34_reload.fscene').read_bytes()==initial
run=(p/'parent-run.log').read_text(); host=(p/'parent-host.log').read_text(); native=(p/'parent-native.log').read_text()
counts={'host_connections':len(re.findall(r'^connected ',host,re.M)),'host_sends':len(re.findall(r'^send ',host,re.M)),'receiver_connections':run.count('w34 connected '),'loads':run.count('w34 loadDocument '),'diffs':run.count('w34 applyDiff '),'decode_errors':run.count('w34 decode error '),'native_protocol_hellos':native.count('protocol hello:'),'native_runner_pids':sorted(set(re.findall(r'Runner\[(\d+):',native))),'run_ends_application_finished':run.strip().endswith('Application finished.')}
assert counts=={'host_connections':1,'host_sends':5,'receiver_connections':1,'loads':1,'diffs':3,'decode_errors':1,'native_protocol_hellos':1,'native_runner_pids':['41344'],'run_ends_application_finished':True}
(o/'log-counts.json').write_text(json.dumps(counts,indent=2)+'\n')
receipt={'parent_evidence_manifest_files':len(checks),'all_hashes_match':True,'video_sha256':vsha,'strict_decoded_frames':2109,'duration_seconds':33.795,'source_time_base':'1/600','image_comparison_matches_parent_json':True,'image_sizes':dims,'authored_snapshots':{'material_only_baseColor':True,'environment_only_exposure':True,'malformed_literal_open_brace':True,'baseline_exact_initial':True,'fixture_exact_initial':True},'scope':'Independent offline recomputation only. No app/test/build/device execution.'}
(o/'evidence-recomputation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2)); print(json.dumps(counts,indent=2)); print(json.dumps(comparison,indent=2))
