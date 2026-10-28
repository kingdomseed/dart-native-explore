import hashlib
import json
from pathlib import Path
import subprocess
from datetime import datetime, timezone

OUT=Path('/private/tmp/dart3d-w34-ios-live-production-review-20261028/r1')
E=Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e9-w34-dev-reload/live-catcher-ios')
expected=json.loads((E/'video-receipts.json').read_text())+json.loads((E/'final-video-receipts.json').read_text())
rows=[]
for n,r in enumerate(expected):
    path=r['path']; start=datetime.now(timezone.utc).isoformat()
    probe_cmd=['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height,duration','-of','json',path]
    probe=subprocess.run(probe_cmd,capture_output=True,text=True)
    decode_cmd=['ffmpeg','-v','warning','-threads','2','-i',path,'-map','0:v:0','-an','-progress','pipe:1','-nostats','-f','null','-']
    decode=subprocess.run(decode_cmd,capture_output=True,text=True)
    (OUT/f'video-{n:02d}-stderr.log').write_text(decode.stderr)
    (OUT/f'video-{n:02d}-progress.log').write_text(decode.stdout)
    frames=int([line.split('=',1)[1] for line in decode.stdout.splitlines() if line.startswith('frame=')][-1])
    p=json.loads(probe.stdout)['streams'][0]
    original=r['probe']['streams'][0]
    assert probe.returncode==decode.returncode==0
    assert frames==int(original['nb_read_frames'])
    assert (p['width'],p['height'])==(original['width'],original['height'])
    rows.append({'path':path,'sha256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),'commands':[probe_cmd,decode_cmd],'startUTC':start,'endUTC':datetime.now(timezone.utc).isoformat(),'probe':p,'decodedFrames':frames,'probeExit':probe.returncode,'decodeExit':decode.returncode,'stderr':f'video-{n:02d}-stderr.log'})
    (OUT/'independent-video-receipts.json').write_text(json.dumps({'videos':rows,'totalFrames':sum(x['decodedFrames'] for x in rows)},indent=2)+'\n')
    print(f'{n+1}/{len(expected)}: {path}: {frames} frames',flush=True)
