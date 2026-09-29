#!/usr/bin/env python3
"""Emit a JSON command stream for Android's `hid` tool: a 2-contact uhid
touchscreen plus a gesture. Usage: hidmt.py <mode> > out.json
modes: pinch_out | pinch_in | drag_then_pinch_out | drag
Screen coords are device pixels (1084x2412)."""
import json, sys

W, H = 1084, 2412
D = [
    0x05, 0x0D, 0x09, 0x04, 0xA1, 0x01, 0x85, 0x01,
]
finger = [
    0x09, 0x22, 0xA1, 0x02,
    0x09, 0x42, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x01, 0x81, 0x02,
    0x75, 0x07, 0x81, 0x03,
    0x09, 0x51, 0x75, 0x08, 0x95, 0x01, 0x26, 0xFF, 0x00, 0x81, 0x02,
    0x05, 0x01, 0x26, 0xFF, 0x0F, 0x75, 0x10,
    0x09, 0x30, 0x81, 0x02, 0x09, 0x31, 0x81, 0x02,
    0x05, 0x0D, 0xC0,
]
D += finger + finger
D += [0x09, 0x54, 0x25, 0x7F, 0x75, 0x08, 0x95, 0x01, 0x81, 0x02,
      0x85, 0x02, 0x09, 0x55, 0x25, 0x02, 0xB1, 0x02, 0xC0]


def sx(x):
    return int(round(x * 4095 / (W - 1)))


def sy(y):
    return int(round(y * 4095 / (H - 1)))


def contact(c, cid):
    if c is None:
        return [0, cid, 0, 0, 0, 0]
    x, y = sx(c[0]), sy(c[1])
    return [1, cid, x & 0xFF, x >> 8, y & 0xFF, y >> 8]


out = [{"id": 1, "command": "register", "name": "s0g test touchscreen",
        "vid": 0x1234, "pid": 0x5678, "bus": "usb", "descriptor": D,
        "feature_reports": [{"id": 2, "data": [2, 2]}]},
       {"id": 1, "command": "delay", "duration": 5000}]
last = {}


def rep(a, b):
    """a,b: (x,y) or None. Lifted contacts are reported once with tip 0."""
    cs = []
    for cid, p in ((0, a), (1, b)):
        if p is not None or cid in last:
            cs.append(contact(p, cid))
        if p is None:
            last.pop(cid, None)
        else:
            last[cid] = p
    cnt = len(cs)
    while len(cs) < 2:
        cs.append([0, 0, 0, 0, 0, 0])
    out.append({"id": 1, "command": "report",
                "report": [1] + cs[0] + cs[1] + [cnt]})
    out.append({"id": 1, "command": "delay", "duration": 16})


def lerp(a, b, t):
    return a + (b - a) * t


mode = sys.argv[1]
cx, cy = 542, 1150
n = 30
if mode in ('pinch_out', 'pinch_in'):
    r0, r1 = (75, 150) if mode == "pinch_out" else (150, 75)
    for i in range(n + 1):
        r = lerp(r0, r1, i / n)
        rep((cx, cy - r), (cx, cy + r))
    rep(None, None)
elif mode == 'drag':
    for i in range(n + 1):
        rep((lerp(cx - 150, cx + 150, i / n), cy), None)
    rep(None, None)
elif mode == 'drag_then_pinch_out':
    x0 = cx - 150
    for i in range(n + 1):
        rep((lerp(x0, x0 + 300, i / n), cy), None)
    fx = x0 + 300
    # finger 0 holds, finger 1 lands 120px below and moves away
    for i in range(n + 1):
        rep((fx, cy), (fx, cy + 150 + lerp(0, 150, i / n)))
    rep(None, None)
out.append({"id": 1, "command": "delay", "duration": 300})
print("\n".join(json.dumps(o) for o in out))
