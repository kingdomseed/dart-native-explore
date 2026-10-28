import base64
import collections
import hashlib
import json
import pathlib
import re
import struct
import subprocess

ROOT = pathlib.Path('/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-9d86c4eb/docs/artifacts/e5b-u3-outline-probe/ios-first-target-control')
OUT = pathlib.Path(__file__).parent

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read_json(path):
    return json.loads(path.read_text())

def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')

manifest = read_json(ROOT / 'evidence-sha256.json')
assert len(manifest) == 227
for name, expected in manifest.items():
    assert digest((ROOT / name).read_bytes()) == expected, name
originals = read_json(ROOT / 'local-originals.json')
for item in originals:
    data = pathlib.Path(item['path']).read_bytes()
    assert len(data) == item['bytes'] and digest(data) == item['sha256'], item['path']
full_log = pathlib.Path(originals[0]['path']).read_text()
save('evidence-verification.json', {'manifest_entries_verified': len(manifest), 'manifest_sha256': digest((ROOT / 'evidence-sha256.json').read_bytes()), 'originals_verified': originals})

def stamp(record):
    return float(re.search(r'time=([\d.]+)', record['label'])[1])

def pixels(data):
    return list(struct.iter_unpack('4B', data))

def byte_color(value):
    encoded = 12.92 * value if value <= .0031308 else 1.055 * value ** (1 / 2.4) - .055
    return min(255, max(0, int(encoded * 255 + .5)))

result = {}
log_results = {}
for stage, pid in [('baseline', '71924'), ('control', '75848')]:
    folder = ROOT / stage
    records = []
    for file in (folder / 'raw').glob('*.json'):
        record = read_json(file)
        data = file.with_suffix('.rgba').read_bytes()
        assert record['width'] == 96 and record['height'] == 72
        assert record['bytesPerRow'] == 96 * record['bytesPerPixel']
        assert len(data) == 96 * 72 * record['bytesPerPixel']
        assert record['origin'] == 'metal-texture' and record['encoding'] == 'raw-unpadded-native-format'
        assert (record['pixelFormat'], record['bytesPerPixel']) == ((115, 8) if record['label'].startswith('mask ') else (81, 4))
        record.update(data=data, file=file.name)
        records.append(record)
    records.sort(key=stamp)
    assert len(records) == 21
    for item in read_json(folder / 'raw-files.json'):
        file = folder / 'raw' / pathlib.Path(item['copiedPath']).name
        data = file.read_bytes()
        assert digest(data) == item['sha256'] and len(data) == item['bytes']
    logs = (folder / 'native-events.log').read_text().splitlines()
    pid_lines = [line for line in full_log.splitlines() if f'Runner[{pid}:' in line]
    lines = [line for line in pid_lines if 'U3OV RAW row ' not in line]
    base = next(r for r in records if r['label'].startswith('target ') and 'mode=0' in r['label'])
    base_pixels = pixels(base['data'])
    masks = [r for r in records if r['label'].startswith('mask ')]
    supplied = read_json(folder / 'analysis.json')
    passes = []
    for mask_record in masks:
        time = stamp(mask_record)
        mask = list(struct.iter_unpack('<4e', mask_record['data']))
        colors = collections.Counter(mask)
        contour = {}
        for y in range(72):
            for x in range(96):
                index = y * 96 + x
                if mask[index][3] >= .001:
                    continue
                coverage = 0
                chosen = None
                for dy in range(-4, 5):
                    for dx in range(-4, 5):
                        if dx * dx + dy * dy > 9:
                            continue
                        j = min(71, max(0, y + dy)) * 96 + min(95, max(0, x + dx))
                        if mask[j][3] > coverage:
                            coverage, chosen = mask[j][3], j
                if coverage > .001:
                    c = mask[chosen]
                    contour[index] = (byte_color(c[2]), byte_color(c[1]), byte_color(c[0]), 255)
        def get(prefix):
            matches = [r for r in records if r['label'].startswith(prefix) and stamp(r) == time]
            assert len(matches) == 1
            return matches[0]
        target, alpha_in, alpha_out = get('target '), get('alpha-input '), get('alpha-output ')
        tp, aip, aop = pixels(target['data']), pixels(alpha_in['data']), pixels(alpha_out['data'])
        outside = lambda a, b: sum(a[i] != b[i] for i in range(6912) if i not in contour)
        bad = lambda a: sum(a[i] != c for i, c in contour.items())
        callbacks = [line for line in logs if 'private-update-publication binding=target=' in line and f'time={time} ' in line]
        assert len(callbacks) == 1
        draws = int(re.search(r'draws=(\d+)', callbacks[0])[1])
        kinds = ['target-mask-encode target=', 'private-update-publication binding=target=', 'mask-encoded binding=target=', 'target-normal-encode target=']
        indices = [next(i for i,l in enumerate(logs) if kind in l and f'time={time}' in l) for kind in kinds]
        assert indices == sorted(indices)
        row = {'time': time, 'support': sum(c[3] > 0 for c in mask), 'contour': len(contour), 'targetOutsideChanged': outside(base_pixels, tp), 'targetContourMismatches': bad(tp), 'alphaOutsideChanged': outside(aip, aop), 'alphaContourMismatches': bad(aop), 'first_target_equals_off': target['data'] == base['data'], 'target_sha256': digest(target['data']), 'alpha_black_opaque_pixels': sum(c == (0,0,0,255) for c in aop), 'callback_draws': draws, 'event_indices': indices, 'mask_colors': [[list(c),n] for c,n in colors.most_common()]}
        source_row = next(r for r in supplied['maskPasses'] if r['time'] == time)
        for key in ['support', 'contour', 'targetOutsideChanged', 'targetContourMismatches', 'alphaOutsideChanged', 'alphaContourMismatches']:
            assert row[key] == source_row[key], (stage,key)
        passes.append(row)
    held = []
    for record in records:
        if record['label'].startswith('stored-'):
            previous = [r for r in records if r['label'].startswith('target ') and stamp(r) < stamp(record)][-1]
            differences = sum(a != b for a,b in zip(record['data'], previous['data']))
            assert differences == 0 and 'dirty=false' in record['label']
            held.append({'label': record['label'], 'byte_differences': differences})
    first_use = []
    for r in records:
        if r['label'].startswith(('target ', 'alpha-output ')):
            p = pixels(r['data'])
            row = {'label': r['label'], 'changedFromActualOffPixels': sum(a != b for a,b in zip(p,base_pixels)), 'topColorsBGRA': [[','.join(map(str,c)),n] for c,n in collections.Counter(p).most_common()]}
            s = next(item for item in read_json(folder / 'first-use.json') if item['label'] == r['label'])
            assert row['changedFromActualOffPixels'] == s['changedFromActualOffPixels']
            assert dict((c,n) for c,n in row['topColorsBGRA']) == dict((c,n) for c,n in s['topColorsBGRA'])
            first_use.append(row)
    due = [l for l in lines if 'U3OV due ' in l]
    highlights = [l for l in lines if 'U3OV public-highlights' in l]
    installs = [l for l in lines if 'U3OV target-technique-install ' in l]
    assert len(due) == 5 and len(highlights) == 4 and len(installs) == 1
    assert f'bindBeforeInstall={str(stage == "control").lower()} mode=2' in installs[0]
    error_query = r'fatal|shader.*error|Cannot modify|cross.scene mutation|SCNTransaction|unrecognized selector|UI API called|U3OV GPU-ERROR|U3OV BLOCKED'
    errors = [l for l in pid_lines if re.search(error_query,l,re.I)]
    assert len(errors) == read_json(folder / 'native-receipt.json')['errorMatches'] == 0
    assert len(pid_lines) == read_json(folder / 'native-receipt.json')['rows']
    reconstructed = 0
    truncated = 0
    for r in records:
        rows = [l for l in pid_lines if f'U3OV RAW row {r["label"]} y=' in l]
        assert len(rows) == 72
        unpacked = {}
        for line in rows:
            y = int(re.search(r' y=(\d+) ',line)[1])
            payload = line.split(' base64=')[1]
            try:
                b = base64.b64decode(payload, validate=True)
            except ValueError:
                b = b''
            if len(b) != r['bytesPerRow']:
                truncated += 1
            else:
                unpacked[y] = b
        if len(unpacked) == 72:
            assert b''.join(unpacked[y] for y in range(72)) == r['data']
            reconstructed += 1
    result[stage] = {'raw_textures_verified':len(records), 'off_sha256':digest(base['data']), 'off_colors': [[list(c),n] for c,n in collections.Counter(base_pixels).most_common()], 'passes':passes, 'held_reads':held, 'first_use':first_use}
    log_results[stage] = {'pid':pid,'full_log_pid_rows':len(pid_lines),'due':due,'highlights':highlights,'installation':installs,'error_query_matches':errors,'query':error_query,'case_insensitive':True,'complete_4byte_textures_reconstructed':reconstructed,'truncated_half_float_rows':truncated}
save('independent-raw-results.json',result)
save('independent-log-results.json',log_results)

crops = []
for item in read_json(ROOT / 'pixel-comparisons.json'):
    data = []
    for stage in ['baseline', 'control']:
        command = ['ffmpeg','-v','error','-threads','1','-i',str(ROOT / stage / (item['pair'] + '.png')),'-vf','crop=402:600:0:70,format=rgb24','-threads','1','-f','rawvideo','-']
        run = subprocess.run(command, capture_output=True)
        assert run.returncode == 0,run.stderr.decode()
        assert len(run.stdout) == 402*600*3
        data.append(run.stdout)
    changed = sum(data[0][i:i+3] != data[1][i:i+3] for i in range(0,len(data[0]),3))
    maximum = max(abs(a-b) for a,b in zip(*data))
    assert changed == item['changedRGBPixels'] and maximum == item['maxRGBDifference']
    crops.append({'pair':item['pair'],'changedRGBPixels':changed,'maxRGBDifference':maximum,'decoded_rgb_sha256':digest(data[0])})
save('independent-screen-crops.json',crops)

videos = read_json(ROOT / 'video-receipts.json')
for stage, receipt in zip(['baseline','control'],videos):
    assert receipt['sha256'] == next(r['sha256'] for r in originals if r['path'] == receipt['path'])
    assert all(c['exitCode'] == 0 for c in receipt['commands'])
    log = (ROOT / stage / 'decode.log').read_text()
    assert len(log.splitlines()) == receipt['warningLines']
    assert all('non monotonically increasing dts' in l for l in log.splitlines())
save('video-review.json', {'fresh_decode':'NOT_RUN, hash-verified full existing decode receipts suffice for this raw-output diagnosis','receipts':videos,'total_frames':sum(int(r['probe']['streams'][0]['nb_read_frames']) for r in videos)})

sdk = pathlib.Path('/private/tmp/dart3d-u3-outline-first-target-diagnosis-20261028/r1/worker')
headers = read_json(sdk / 'sdk-sha256.json')
for path, expected in headers.items():
    assert digest(pathlib.Path(path).read_bytes()) == expected
    assert digest((sdk / 'sdk' / pathlib.Path(path).name).read_bytes()) == expected
save('installed-sdk-verification.json',headers)
print(json.dumps({'evidence_entries':227,'raw_textures':42,'first_target_identical_off':[result[s]['passes'][0]['first_target_equals_off'] for s in result], 'contour_mismatches':{s:[r['targetContourMismatches'] for r in result[s]['passes']] for s in result},'screen_crops':len(crops),'frames_existing_decode':9428,'log_error_matches':{s:len(log_results[s]['error_query_matches']) for s in log_results}},indent=2))
