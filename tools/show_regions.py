#!/usr/bin/env python3
"""Draw a meta file's regions over the backdrop it describes.

    tools/scene.sh regions <id> [--variant dense] [--sheet] [--only <id> ...]
    tools/scene.sh regions <id> --grid 20 [--crop 0.5 0 1 0.5]

A meta file is a description of a picture written by eye, and the only way to
know it is right is to see the two together: a rect that reaches past the shelf
it names, a rest line an inch above the table top, an outline that still has
wall inside it. Every one of those puts a prop in mid-air at runtime, and none
of them shows up in the build's warnings, because the numbers are all
self-consistent - they just do not match the art.

Two views, because they answer different questions:

- the overlay (default) shows every region at once, which is how you find the
  parts of the room nothing describes.
- `--sheet` gives one panel per region, cropped to it with some room around,
  which is how you check a single rect against what it claims to be.

Regions are drawn by kind, rest lines in a colour of their own, and no-go
zones hatched. `--grid` rules the picture in normalized coordinates, which is
how the numbers get read off the art in the first place. See docs/scene-meta.md.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# One colour per region kind, so a mislabelled region shows up as the wrong
# colour over the art before anyone reads its numbers.
KIND_COLOURS = {
    "surface": (80, 220, 120),
    "container": (255, 190, 60),
    "wall": (120, 170, 255),
    "prop": (230, 120, 255),
    "opening": (120, 230, 230),
    "structure": (190, 190, 190),
}
OTHER_KIND = (255, 255, 255)
REST_COLOUR = (255, 80, 80)
POLYGON_COLOUR = (255, 255, 255)
NOGO_COLOUR = (255, 60, 60)
GRID_COLOUR = (255, 255, 255)


def meta_path(scene_id, variant):
    name = f"{scene_id}.{variant}.meta.json" if variant else f"{scene_id}.meta.json"
    path = ROOT / "tools" / "scenes" / name
    if not path.exists():
        sys.exit(f"{path.relative_to(ROOT)} not found")
    return path


def backdrop(meta):
    """The image the meta describes, as the level ships it."""
    path = ROOT / meta["image"]
    if not path.exists():
        sys.exit(f"{meta['image']} not found; run the build first")
    return Image.open(path).convert("RGB")


def rest_points(region, x0, x1):
    """The region's rest line as [(x, y)] in normalized coordinates."""
    rest = region.get("restLine")
    if rest is None:
        return []
    if isinstance(rest, (int, float)):
        return [(x0, float(rest)), (x1, float(rest))]
    points = sorted((float(x), float(y)) for x, y in rest)
    if not points:
        return []
    # Carry the ends out to the region's edges, the way restY clamps them.
    return (
        [(x0, points[0][1])] * (points[0][0] > x0)
        + points
        + [(x1, points[-1][1])] * (points[-1][0] < x1)
    )


def draw_region(draw, region, size, width=3, label=True):
    w, h = size
    x0, y0, x1, y1 = region["rect"]
    colour = KIND_COLOURS.get(region.get("kind"), OTHER_KIND)
    draw.rectangle(
        (x0 * w, y0 * h, x1 * w, y1 * h), outline=colour + (255,), width=width
    )
    polygon = region.get("polygon") or []
    if polygon:
        draw.polygon(
            [(x * w, y * h) for x, y in polygon],
            outline=POLYGON_COLOUR + (255,),
            width=max(1, width - 1),
        )
    line = rest_points(region, x0, x1)
    if line:
        draw.line(
            [(x * w, y * h) for x, y in line],
            fill=REST_COLOUR + (255,),
            width=max(2, width - 1),
        )
    if label:
        draw.text(
            (x0 * w + 4, y0 * h + 2),
            region["id"],
            fill=colour + (255,),
            stroke_width=2,
            stroke_fill=(0, 0, 0, 255),
        )


def draw_nogo(draw, zones, size, width=3):
    w, h = size
    for zone in zones:
        x0, y0, x1, y1 = zone["rect"]
        draw.rectangle(
            (x0 * w, y0 * h, x1 * w, y1 * h),
            outline=NOGO_COLOUR + (255,),
            width=width,
        )
        step = max(12, int((x1 - x0) * w / 8))
        span = (x1 - x0) * w + (y1 - y0) * h
        for offset in range(0, int(span), step):
            draw.line(
                (
                    max(x0 * w, x0 * w + offset - (y1 - y0) * h),
                    min(y1 * h, y0 * h + offset),
                    min(x1 * w, x0 * w + offset),
                    max(y0 * h, y0 * h + offset - (x1 - x0) * w),
                ),
                fill=NOGO_COLOUR + (90,),
                width=1,
            )


def draw_grid(draw, size, steps, crop):
    """Rule the picture in the whole room's coordinates and label the lines.

    The numbers stay the room's under a crop, because those are the numbers a
    meta file is written in: a crop is a magnifying glass, not a new frame.
    """
    w, h = size
    cx0, cy0, cx1, cy1 = crop
    for i in range(steps + 1):
        t = i / steps
        # Read the weight off the value, not the step count, so a line means
        # the same thing whatever the grid is set to: every twentieth of the
        # room is named, every quarter of it stands out.
        named = abs(t * 20 - round(t * 20)) < 1e-6
        heavy = abs(t * 4 - round(t * 4)) < 1e-6
        alpha = 200 if heavy else (140 if named else 70)
        if cx0 <= t <= cx1:
            x = (t - cx0) / (cx1 - cx0) * w
            draw.line((x, 0, x, h), fill=GRID_COLOUR + (alpha,),
                      width=2 if heavy else 1)
            if named:
                draw.text((x, 4), f"{t:.2f}", fill=GRID_COLOUR + (255,),
                          stroke_width=2, stroke_fill=(0, 0, 0, 255),
                          anchor="ma")
        if cy0 <= t <= cy1:
            y = (t - cy0) / (cy1 - cy0) * h
            draw.line((0, y, w, y), fill=GRID_COLOUR + (alpha,),
                      width=2 if heavy else 1)
            if named:
                draw.text((4, y), f"{t:.2f}", fill=GRID_COLOUR + (255,),
                          stroke_width=2, stroke_fill=(0, 0, 0, 255),
                          anchor="la")


def rebase(box, crop):
    """[box] in normalized room coordinates, re-read inside [crop]."""
    cx0, cy0, cx1, cy1 = crop
    return [
        (box[0] - cx0) / (cx1 - cx0),
        (box[1] - cy0) / (cy1 - cy0),
        (box[2] - cx0) / (cx1 - cx0),
        (box[3] - cy0) / (cy1 - cy0),
    ]


def rebase_points(points, crop):
    cx0, cy0, cx1, cy1 = crop
    return [
        [(x - cx0) / (cx1 - cx0), (y - cy0) / (cy1 - cy0)] for x, y in points
    ]


def in_crop(region, crop):
    """Regions with nothing inside the crop are left out of the drawing."""
    x0, y0, x1, y1 = region["rect"]
    return x0 < crop[2] and crop[0] < x1 and y0 < crop[3] and crop[1] < y1


def overlay(meta, regions, width, grid=0, crop=(0.0, 0.0, 1.0, 1.0)):
    source = backdrop(meta)
    canvas = source.crop((
        round(crop[0] * source.width),
        round(crop[1] * source.height),
        round(crop[2] * source.width),
        round(crop[3] * source.height),
    ))
    canvas = canvas.resize(
        (width, round(width * canvas.height / canvas.width)), Image.LANCZOS
    ).convert("RGBA")
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for region in regions:
        if not in_crop(region, crop):
            continue
        shifted = dict(region, rect=rebase(region["rect"], crop))
        if region.get("polygon"):
            shifted["polygon"] = rebase_points(region["polygon"], crop)
        rest = region.get("restLine")
        if isinstance(rest, list) and rest:
            shifted["restLine"] = rebase_points(rest, crop)
        elif isinstance(rest, (int, float)):
            shifted["restLine"] = (rest - crop[1]) / (crop[3] - crop[1])
        draw_region(draw, shifted, canvas.size)
    draw_nogo(
        draw,
        [dict(z, rect=rebase(z["rect"], crop)) for z in meta.get("noGo", [])],
        canvas.size,
    )
    if grid:
        draw_grid(draw, canvas.size, grid, crop)
    canvas.alpha_composite(layer)
    return canvas.convert("RGB")


def sheet(meta, regions, width, columns=3):
    """One panel per region: the region, plus half its size again around it."""
    source = backdrop(meta)
    panel = width // columns
    rows = (len(regions) + columns - 1) // columns
    out = Image.new("RGB", (columns * panel, rows * panel), (18, 18, 22))
    for index, region in enumerate(regions):
        x0, y0, x1, y1 = region["rect"]
        # A square window around the region, never smaller than a tenth of the
        # room: a thin wall strip on its own says nothing about where it is.
        side = max(x1 - x0, (y1 - y0) * source.height / source.width, 0.1) * 1.6
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        half = side / 2
        box = (
            round(max(0, cx - half) * source.width),
            round(max(0, cy - half * source.width / source.height) * source.height),
            round(min(1, cx + half) * source.width),
            round(min(1, cy + half * source.width / source.height) * source.height),
        )
        crop = source.crop(box).convert("RGBA")
        layer = Image.new("RGBA", crop.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        # Re-express the region in the crop's own coordinates.
        sx = source.width / max(1, box[2] - box[0])
        sy = source.height / max(1, box[3] - box[1])
        shifted = dict(region)
        shifted["rect"] = [
            (x0 - box[0] / source.width) * sx,
            (y0 - box[1] / source.height) * sy,
            (x1 - box[0] / source.width) * sx,
            (y1 - box[1] / source.height) * sy,
        ]
        if region.get("polygon"):
            shifted["polygon"] = [
                [
                    (x - box[0] / source.width) * sx,
                    (y - box[1] / source.height) * sy,
                ]
                for x, y in region["polygon"]
            ]
        rest = region.get("restLine")
        if isinstance(rest, list) and rest:
            shifted["restLine"] = [
                [
                    (x - box[0] / source.width) * sx,
                    (y - box[1] / source.height) * sy,
                ]
                for x, y in rest
            ]
        elif isinstance(rest, (int, float)):
            shifted["restLine"] = (rest - box[1] / source.height) * sy
        draw_region(draw, shifted, crop.size, width=4, label=False)
        crop.alpha_composite(layer)
        crop = crop.convert("RGB").resize((panel, panel), Image.LANCZOS)
        label = ImageDraw.Draw(crop)
        label.text(
            (6, panel - 16),
            f"{region['id']} [{region.get('kind', '?')}]",
            fill=(255, 255, 255),
            stroke_width=2,
            stroke_fill=(0, 0, 0),
        )
        out.paste(crop, ((index % columns) * panel, (index // columns) * panel))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--variant", help="meta variant, e.g. dense")
    parser.add_argument("--sheet", action="store_true",
                        help="one panel per region instead of one overlay")
    parser.add_argument("--only", nargs="+", metavar="REGION",
                        help="draw only these region ids")
    parser.add_argument("--grid", type=int, default=0, metavar="N",
                        help="rule the overlay into N normalized steps")
    parser.add_argument("--crop", nargs=4, type=float, metavar=("X0", "Y0",
                                                                "X1", "Y1"),
                        help="draw only this part of the room, in normalized "
                             "coordinates; the grid still reads in the whole "
                             "room's")
    parser.add_argument("--width", type=int, default=1600)
    args = parser.parse_args()

    meta = json.loads(meta_path(args.scene_id, args.variant).read_text())
    regions = meta["regions"]
    if args.only:
        wanted = set(args.only)
        missing = wanted - {r["id"] for r in regions}
        if missing:
            sys.exit(f"no such region(s): {', '.join(sorted(missing))}")
        regions = [r for r in regions if r["id"] in wanted]

    image = (
        sheet(meta, regions, args.width)
        if args.sheet
        else overlay(meta, regions, args.width, args.grid,
                     tuple(args.crop) if args.crop else (0.0, 0.0, 1.0, 1.0))
    )
    parts = [args.scene_id]
    if args.variant:
        parts.append(args.variant)
    parts.append("regions.sheet" if args.sheet else "regions")
    out = ROOT / "tools" / "scenes" / f"{'.'.join(parts)}.png"
    image.save(out, optimize=True)
    print(f"{out.relative_to(ROOT)}: {len(regions)} region(s)")


if __name__ == "__main__":
    main()
