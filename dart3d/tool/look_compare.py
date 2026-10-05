#!/usr/bin/env python3
"""Compares look-reference captures from two platforms, patch by patch.

    tool/look_compare.py <dir-a> <dir-b> [--a NAME] [--b NAME]
                         [--variants v1,v2] [--summary]

Each directory holds one screenshot per variant of the look-reference
board (`<variant>.png`, written by tool/look_capture.sh). For every
variant both directories have, this prints a table of the mean sRGB
colour of each patch on each side and their difference, then a summary
per patch kind against the tolerances below. Exits 1 when a kind is
over its tolerance.

The board carries two magenta squares at its top-left and bottom-right
corners; their bounding box gives the board-to-pixel map, so the two
captures may differ in size. The patch table is
tool/look_reference_patches.json, generated from the Dart layout
(example/test/look_reference_test.dart keeps the two in step).

Needs ffmpeg on PATH; otherwise Python's standard library only.
"""

import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Mean absolute difference per patch, out of 255, averaged over R, G, B.
TOLERANCE = {
    'unlit': 8,
    'emissive': 8,
    'sky': 8,
    'lit': 16,
    'sphere': 16,
    'light': 16,
    'shadow': 16,
}


def load_layout():
    with open(os.path.join(HERE, 'look_reference_patches.json')) as f:
        return json.load(f)


def read_rgb(path):
    probe = subprocess.run(
        ['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
         'stream=width,height', '-of', 'csv=p=0', path],
        check=True, capture_output=True, text=True).stdout.strip()
    width, height = (int(v) for v in probe.split(',')[:2])
    raw = subprocess.run(
        ['ffmpeg', '-v', 'error', '-i', path, '-f', 'rawvideo', '-pix_fmt',
         'rgb24', '-'], check=True, capture_output=True).stdout
    if len(raw) != width * height * 3:
        raise SystemExit(f'{path}: unexpected frame size')
    return width, height, raw


def board_rect(width, height, raw, layout, path):
    """Pixel bounding box of the magenta fiducials."""
    x0, y0, x1, y1 = width, height, -1, -1
    for y in range(height):
        row = raw[y * width * 3:(y + 1) * width * 3]
        r, g, b = row[0::3], row[1::3], row[2::3]
        for x in range(width):
            low = r[x] if r[x] < b[x] else b[x]
            if low > 120 and g[x] * 4 < low * 3:
                if x < x0:
                    x0 = x
                if x > x1:
                    x1 = x
                if y < y0:
                    y0 = y
                if y > y1:
                    y1 = y
    if x1 < 0:
        raise SystemExit(f'{path}: no fiducials found')
    board = layout['board']
    want = (board['right'] - board['left']) / (board['top'] - board['bottom'])
    got = (x1 - x0 + 1) / (y1 - y0 + 1)
    if abs(got / want - 1) > 0.03:
        raise SystemExit(
            f'{path}: fiducial box {x0},{y0}-{x1},{y1} has aspect {got:.3f},'
            f' the board is {want:.3f}')
    return x0, y0, x1 + 1, y1 + 1


def measure(path, layout):
    width, height, raw = read_rgb(path)
    x0, y0, x1, y1 = board_rect(width, height, raw, layout, path)
    board = layout['board']
    sx = (x1 - x0) / (board['right'] - board['left'])
    sy = (y1 - y0) / (board['top'] - board['bottom'])
    out = {}
    for patch in layout['patches']:
        cx = x0 + (patch['x'] - board['left']) * sx
        cy = y0 + (board['top'] - patch['y']) * sy
        hx, hy = patch['half'] * sx, patch['half'] * sy
        px0, px1 = round(cx - hx), round(cx + hx)
        py0, py1 = round(cy - hy), round(cy + hy)
        total = [0, 0, 0]
        for y in range(py0, py1):
            row = raw[(y * width + px0) * 3:(y * width + px1) * 3]
            for c in range(3):
                total[c] += sum(row[c::3])
        n = (px1 - px0) * (py1 - py0)
        out[patch['name']] = [t / n for t in total]
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('dir_a')
    ap.add_argument('dir_b')
    ap.add_argument('--a', default='A')
    ap.add_argument('--b', default='B')
    ap.add_argument('--variants', default='')
    ap.add_argument('--summary', action='store_true',
                    help='print only the per-kind summary of each variant')
    args = ap.parse_args()

    layout = load_layout()
    wanted = [v for v in args.variants.split(',') if v] or layout['variants']
    kinds = {p['name']: p['kind'] for p in layout['patches']}
    failed = False
    for variant in wanted:
        a_path = os.path.join(args.dir_a, variant + '.png')
        b_path = os.path.join(args.dir_b, variant + '.png')
        if not (os.path.exists(a_path) and os.path.exists(b_path)):
            continue
        a, b = measure(a_path, layout), measure(b_path, layout)
        print(f'### {variant}\n')
        per_kind = {}
        if not args.summary:
            print(f'| Patch | {args.a} | {args.b} | Diff |')
            print('|---|---|---|---|')
        for name, kind in kinds.items():
            diff = sum(abs(x - y) for x, y in zip(a[name], b[name])) / 3
            per_kind.setdefault(kind, []).append((diff, name))
            if not args.summary:
                fmt = lambda v: ' '.join(f'{c:3.0f}' for c in v)
                print(f'| {name} | {fmt(a[name])} | {fmt(b[name])} |'
                      f' {diff:.1f} |')
        if not args.summary:
            print()
        print('| Kind | Patches | Mean diff | Worst | Tolerance | |')
        print('|---|---|---|---|---|---|')
        for kind, diffs in per_kind.items():
            worst, worst_name = max(diffs)
            mean = sum(d for d, _ in diffs) / len(diffs)
            ok = worst <= TOLERANCE[kind]
            failed = failed or not ok
            print(f'| {kind} | {len(diffs)} | {mean:.1f} |'
                  f' {worst:.1f} ({worst_name}) | {TOLERANCE[kind]} |'
                  f' {"ok" if ok else "over"} |')
        print()
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
