import json
from pathlib import Path
import sys


root = Path(sys.argv[1])
side = 256
cases = {}
masks = {}
for path in sorted(root.glob("*.rgba")):
    data = path.read_bytes()
    if len(data) != side * side * 4:
        raise ValueError(f"Unexpected RGBA length: {path}")
    channels = [data[channel::4] for channel in range(4)]
    mask = channels[0]
    occupied = [i for i, value in enumerate(mask) if value >= 128]
    rim = [i for i in range(side * side) if i % side < 8 or i % side >= 248 or i // side < 8 or i // side >= 248]
    interior = [i for i in range(side * side) if 12 <= i % side < 244 and 12 <= i // side < 244]
    cases[path.stem] = {
        "bytes": len(data),
        "channel_ranges": [[min(c), max(c)] for c in channels],
        "max_rgb_difference": max(
            max(abs(r - g), abs(r - b), abs(g - b))
            for r, g, b in zip(*channels[:3])
        ),
        "zero_mask_pixels": mask.count(0),
        "full_mask_pixels": mask.count(255),
        "uncovered_rim_R_range": [min(mask[i] for i in rim), max(mask[i] for i in rim)],
        "uncovered_rim_A_range": [min(channels[3][i] for i in rim), max(channels[3][i] for i in rim)],
        "receiver_interior_A_range": [min(channels[3][i] for i in interior), max(channels[3][i] for i in interior)],
        "threshold128_bbox": [
            min(i % side for i in occupied),
            min(i // side for i in occupied),
            max(i % side for i in occupied),
            max(i // side for i in occupied),
        ],
    }
    masks[path.stem] = mask

comparisons = {}
for light in ("directional", "spot"):
    a = masks[f"raw-mask-{light}-opengl"]
    b = masks[f"raw-mask-{light}-vulkan"]
    comparison = {}
    for name, flip_x, flip_y in (
        ("same", False, False),
        ("flipY", False, True),
        ("flipX", True, False),
        ("flipXY", True, True),
    ):
        delta = intersection = union = 0
        for y in range(side):
            for x in range(side):
                bx = side - 1 - x if flip_x else x
                by = side - 1 - y if flip_y else y
                v, w = a[y * side + x], b[by * side + bx]
                delta += abs(v - w)
                intersection += int(v >= 128 and w >= 128)
                union += int(v >= 128 or w >= 128)
        comparison[name] = {
            "mean_abs_byte_delta": delta / (side * side),
            "threshold128_intersection_over_union": intersection / union,
        }
    comparisons[light] = comparison

print(json.dumps({"cases": cases, "backend_comparison": comparisons}, indent=2))
