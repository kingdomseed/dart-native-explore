from pathlib import Path
import subprocess, json, hashlib, struct, zlib
r=Path('/private/tmp/dart3d-e9-native-particle-review-20261027/r1')
v=Path('/private/tmp/dart3d-e9-particle-technique-probe-20261027/r1/parent-runtime-r2/interception.mp4')
meta=subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(v)],capture_output=True,text=True,check=True)
(r/'video-ffprobe.json').write_text(meta.stdout)
frames=r/'video-frames'; frames.mkdir(exist_ok=True)
receipt={'sha256':hashlib.sha256(v.read_bytes()).hexdigest(),'full_decode_exit':0,'full_decode_exit_evidence':'exec_command session 60182 completed exit 0','frame_extractions':[]}
for sec in [0,5,12,30,60,75,82,88]:
    dest=frames/f'{sec:02d}s.png'
    cmd=['ffmpeg','-hide_banner','-loglevel','error','-nostdin','-ss',str(sec),'-i',str(v),'-frames:v','1','-vf','scale=402:874','-y',str(dest)]
    result=subprocess.run(cmd,capture_output=True,text=True); assert result.returncode==0,result.stderr
    receipt['frame_extractions'].append({'seconds':sec,'argv':cmd,'exit':result.returncode,'stderr':result.stderr,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
progress=(r/'video-decode-progress.txt').read_text().splitlines(); stderr=(r/'video-decode-stderr.txt').read_text()
receipt['full_decode_final_progress']=dict(line.split('=',1) for line in progress[-12:] if '=' in line)
receipt['timestamp_warning_explicit_lines']=sum('non monotonically increasing dts' in line for line in stderr.splitlines())
receipt['timestamp_warning_repeat_summary_lines']=sum('Last message repeated' in line for line in stderr.splitlines())
receipt['timestamp_warning_and_repeat_lines']=receipt['timestamp_warning_explicit_lines']+receipt['timestamp_warning_repeat_summary_lines']
receipt['parent_stderr_total_lines']=len(Path('/private/tmp/dart3d-e9-particle-technique-probe-20261027/r1/parent-runtime-r2/video-decode-stderr.txt').read_text().splitlines())
receipt['ffprobe']=json.loads(meta.stdout)
cmd=['ffmpeg','-hide_banner','-loglevel','error','-nostdin',*[arg for t in [0,5,12,30,60,75,82,88] for arg in ['-i',str(frames/f'{t:02d}s.png')]],'-filter_complex',''.join(f'[{i}:v]scale=201:437[s{i}];' for i in range(8))+''.join(f'[s{i}]' for i in range(8))+'xstack=inputs=8:layout=0_0|201_0|402_0|603_0|0_437|201_437|402_437|603_437[out]','-map','[out]','-frames:v','1','-y',str(r/'independent-video-contact-sheet.png')]
result=subprocess.run(cmd,capture_output=True,text=True); assert result.returncode==0,result.stderr
receipt['contact_sheet']={'argv':cmd,'exit':result.returncode,'order':'row-major 0,5,12,30,60,75,82,88 seconds'}
(r/'video-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k not in ['frame_extractions','ffprobe','contact_sheet']},indent=2))
