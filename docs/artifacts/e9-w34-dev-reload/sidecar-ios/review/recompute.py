import hashlib
import json
import pathlib
import re
import struct
import subprocess
import tarfile
import difflib

OUT = pathlib.Path(__file__).parent
PACKET = pathlib.Path('/private/tmp/dart3d-e9-assets-runtime-20261027/r1')
IMPL = pathlib.Path('/private/tmp/dart3d-e9-reload-library-implementation-20261027/r1')
ROOT = pathlib.Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-c507b9f1')
PARENT = pathlib.Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def manifest(path):
    return {line.split(None, 1)[1].strip(): line.split()[0] for line in path.read_text().splitlines() if line.strip()}

def run(args):
    result = subprocess.run(args, capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
    return result.stdout

hashes = manifest(PACKET / 'evidence-sha256.txt')
assert all(digest((PACKET / n).read_bytes()) == h for n, h in hashes.items())
source = manifest(IMPL / 'parent-source-sha256.txt')
assert all(digest((PARENT / n).read_bytes()) == h for n, h in source.items())
locks = json.loads((IMPL / 'locks-baseline.json').read_text())
assert all(digest((PARENT / n).read_bytes()) == h for n, h in locks.items())
assert digest((IMPL / 'correction.patch').read_bytes()) == '31aa933d3962ad2aeaf8f3977a8d4db66b86551473497e9b7513bbe586901058'
assert digest((IMPL / 'owned-source.tgz').read_bytes()) == 'a87b30e795cbdbf69604845407b702877fcdf143c9145a04a81c17b1e53155d4'
worker = manifest(IMPL / 'owned-source-sha256.txt')
delta = []
with tarfile.open(IMPL / 'owned-source.tgz') as archive:
    contents = {m.name.removeprefix('./'): archive.extractfile(m).read() for m in archive.getmembers() if m.isfile() and not pathlib.PurePosixPath(m.name).name.startswith('._')}
    assert set(contents) == set(worker)
    for name, data in contents.items():
        assert digest(data) == worker[name]
        delta.extend(difflib.unified_diff(data.decode().splitlines(True), (ROOT / name).read_text().splitlines(True), fromfile='worker/' + name, tofile='parent/' + name))
(OUT / 'worker-parent.diff').write_text(''.join(delta))
inputs = {}
for state in ['init', 'b', 'malformed', 'a']:
    scene = (PACKET / f'{state}-quad.fscene').read_bytes()
    side = (PACKET / f'{state}-pixels.fsceneb').read_bytes()
    assert digest(scene) == '5261ff0059f72616c8dc0e69bc97d965a2e004ff7e3fda5f45325ed32b5ca611'
    record = {'scene_sha256': digest(scene), 'scene_characters': len(scene.decode()), 'sidecar_sha256': digest(side), 'sidecar_length': len(side), 'scene': json.loads(scene)}
    if state == 'malformed':
        assert list(side) == [0, 1, 2]
        record['literal_bytes'] = list(side)
    else:
        assert side[:4] == b'FSCB'
        version, size, reserved = struct.unpack_from('<III', side, 4)
        assert (version, size, reserved) == (2, len(side), 0)
        offset = 16
        chunks = []
        while offset < size:
            length, kind = struct.unpack_from('<I4s', side, offset)
            data = side[offset + 8:offset + 8 + length]
            assert len(data) == length
            if kind == b'JSON':
                record['sidecar_manifest'] = json.loads(data)
            elif kind == b'BLOB':
                token_length = struct.unpack_from('<I', data)[0]
                record['payload_token'] = data[4:4 + token_length].decode()
                record['payload_bytes'] = list(data[4 + token_length:])
            chunks.append({'type': kind.decode(), 'length': length})
            offset += 8 + length + ((-length) & 7)
        assert offset == size
        record['chunks'] = chunks
        assert record['scene'] == record['sidecar_manifest']
    inputs[state] = record
assert inputs['init']['sidecar_sha256'] == inputs['a']['sidecar_sha256'] == '82facd2365dffe257b04452231a4c6fbea3605182d9511f8df6ed43dfb4c8f81'
assert inputs['b']['sidecar_sha256'] == 'c7bbe700d89ba4fac131fb0031460bed953b2be4a918b7ca093af1ea83f498a4'
assert inputs['init']['payload_token'] == inputs['b']['payload_token'] == inputs['a']['payload_token']
(OUT / 'saved-inputs.json').write_text(json.dumps(inputs, indent=2) + '\n')
names = ['00-a.png', '01-b.png', '02-malformed-retained.png', '03-a-recovered.png']
images = []
for name in names:
    assert struct.unpack_from('>II', (PACKET / name).read_bytes(), 16) == (402, 874)
    rgb = run(['ffmpeg', '-v', 'error', '-i', str(PACKET / name), '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'rgb24', 'pipe:1'])
    assert len(rgb) == 402 * 874 * 3
    images.append(rgb)
def changed(a, b):
    return sum(a[i:i+3] != b[i:i+3] for y in range(100, 740) for x in range(402) for i in [(y * 402 + x) * 3])
def sample(data, left, top):
    return [sum(data[(y * 402 + x) * 3 + c] for y in range(top, top + 9) for x in range(left, left + 9)) / 81 for c in range(3)]
pixels = {'size': [402, 874], 'scene_crop': [0, 100, 402, 740], 'samples': {n: {'left': sample(rgb, 40, 200), 'right': sample(rgb, 350, 200)} for n, rgb in zip(names, images)}, 'changed_pixels': {'b_vs_a': changed(images[1], images[0]), 'malformed_vs_b': changed(images[2], images[1]), 'recovered_vs_a': changed(images[3], images[0])}}
supplied = json.loads((PACKET / 'image-comparison.json').read_text())
assert all(supplied[k] == v for k, v in pixels.items())
(OUT / 'image-recomputation.json').write_text(json.dumps(pixels, indent=2) + '\n')
video = PACKET / 'asset-reload.mp4'
assert digest(video.read_bytes()) == '0693e2aeb703caf8a6eb7d3e3d960ddc6dd8e119be189cea9e6c5550bf0d1512'
probe = json.loads(run(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(video)]))
(OUT / 'video-probe.json').write_text(json.dumps(probe, indent=2) + '\n')
stream = next(s for s in probe['streams'] if s['codec_type'] == 'video')
args = ['ffmpeg', '-hide_banner', '-nostats', '-v', 'info', '-xerror', '-err_detect', 'explode', '-i', str(video), '-map', '0:v:0', '-fps_mode', 'passthrough', '-enc_time_base', stream['time_base'].replace('/', ':'), '-f', 'null', '/dev/null']
result = subprocess.run(args, capture_output=True, text=True)
(OUT / 'video-strict-decode.log').write_text(result.stdout + result.stderr + f'\nexit={result.returncode}\n')
assert result.returncode == 0
counts = re.findall(r'frame=\s*(\d+)', result.stderr)
assert counts and int(counts[-1]) == 1767
assert stream['time_base'] == '1/600' and probe['format']['duration'] == '29.161667'
run(['ffmpeg', '-v', 'error', '-i', str(video), '-frames:v', '1', '-y', str(OUT / 'video-first.png')])
run(['ffmpeg', '-v', 'error', '-sseof', '-0.1', '-i', str(video), '-update', '1', '-y', str(OUT / 'video-final.png')])
run(['ffmpeg', '-v', 'error', '-i', str(video), '-vf', 'fps=1/5,scale=201:437,tile=3x2', '-frames:v', '1', '-y', str(OUT / 'video-contact.png')])
log = (PACKET / 'run.log').read_text()
native = (PACKET / 'native.log').read_text()
host = (PACKET / 'host.log').read_text()
summary = {'evidence_manifest_entries_verified': len(hashes), 'parent_source58_readonly_recheck': True, 'parent_six_locks_readonly_recheck': True, 'worker_archive_and_patch_verified': True, 'video_sha256': digest(video.read_bytes()), 'video_frames_strict_decoded': int(counts[-1]), 'video_duration': probe['format']['duration'], 'video_time_base': stream['time_base'], 'runtime_log': {'connections': log.count('w34 connected '), 'loads': log.count('w34 loadDocument'), 'diffs': log.count('w34 applyDiff'), 'rejections': log.count('w34 input error'), 'finished': log.rstrip().endswith('Application finished.'), 'native_pids': sorted(set(re.findall(r'Runner\[(\d+):', native))), 'native_hellos': native.count('protocol hello'), 'host_connections': host.splitlines().count('connected'), 'host_sends': re.findall(r'send chars=(\d+)', host), 'http_byte_counts': re.findall(r'payload path=pixels.fsceneb bytes=(\d+)', host)}, 'pixel_recomputation_matches': True, 'raw_decode_temp_files_created': False, 'retained_decode_artifacts': ['video-first.png', 'video-final.png', 'video-contact.png']}
(OUT / 'offline-verification.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
