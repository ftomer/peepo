#!/usr/bin/env python3
"""Composite a scene into one PNG, so placements can be reviewed by eye.

Numbers do not tell you that the hat is floating an inch above the barrel. This
draws the scene exactly the way `scene_view.dart` does - box of w x h centred on
(x, y), rotated clockwise by `rotation` - and optionally outlines the tap
polygons, which is how you catch a bad alpha cut.

A level places its props when it is played, so there is nothing on disk to
draw. `tools/layout.dart` runs the game's own placer for a seed and prints the
layout, and that is what gets composited here - the same code the player gets,
not a second implementation of it.

    tools/scene.sh preview <id> [--seed N] [--outlines] [--labels]
    tools/scene.sh preview <id> --band hunt --variant dense

A level plays differently at every age, so a preview is a preview of one band:
--band picks which, and Look - the band the art is drawn for - is the default.
"""
import argparse
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent

# Placements that stand on a surface, mirroring SceneObject.grounded in
# lib/models/scene.dart: these get the renderer's soft contact shadow, and a
# preview without it would be judging a blend the player never sees.
GROUNDED = {"rests_on", "lies_flat", "leans_against", "tucked_in", "inside"}


def foot_of(obj, box, scene_height):
    """How far the art reaches below the placement's centre, in pixels.

    Mirrors SceneObject.foot in lib/models/scene.dart: read off the polygon,
    which is the silhouette already turned and placed, and never past the
    bottom of the sprite box.
    """
    half = box[1] / 2
    polygon = obj.get("polygon") or []
    if not polygon:
        return half * 0.92
    drop = (max(p[1] for p in polygon) - obj["pos"][1]) * scene_height
    return half * 0.92 if drop <= 0 else min(drop, half)


def contact_shadow(box, foot):
    """The renderer's grounded-prop shadow for a sprite of size `box`.

    Same geometry as _SpritePosition in lib/game/scene_view.dart: an ellipse
    from 6% in on either side, a fifth of the sprite's height tall, centred on
    the prop's foot, one soft blurred tone.

    Returns the layer and the padding around the sprite box it carries. The
    blur spills well past the ellipse and the app's Stack lets it - a layer cut
    to the box would draw a shadow with a flat edge the player never sees - so
    the caller pastes the layer that much up and to the left of the box.
    """
    bw, bh = box
    sw, sh = round(bw * 0.88), max(2, round(bh * 0.20))
    blur = sh * 0.28
    pad = max(1, math.ceil(blur * 3))
    layer = Image.new("RGBA", (bw + 2 * pad, bh + 2 * pad), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    left = pad + round(bw * 0.06)
    top = pad + round(bh / 2 + foot - sh / 2)
    draw.ellipse((left, top, left + sw, top + sh), fill=(34, 34, 34, 85))
    return layer.filter(ImageFilter.GaussianBlur(blur)), pad


def run_placer(scene_id, seed, band=None, variant=None):
    """Ask the game's placer for one layout of this level."""
    dart = shutil.which("dart") or shutil.which(
        "dart", path=str(Path(os.environ.get("FLUTTER_ROOT", "")) / "bin")
    )
    if not dart:
        sys.exit(
            "dart not found on PATH; add the Flutter SDK's bin folder or set "
            "FLUTTER_ROOT, so the preview can run the same placer the app does"
        )
    command = [dart, "run", "tools/layout.dart", scene_id]
    if seed is not None:
        command += ["--seed", str(seed)]
    if band:
        command += ["--band", band]
    if variant:
        command += ["--variant", variant]
    done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if done.returncode != 0:
        sys.exit(done.stderr.strip() or f"{' '.join(command)} failed")
    if done.stderr.strip():
        print(done.stderr.strip(), file=sys.stderr)
    return json.loads(done.stdout)


def preview(scene_id, outlines, labels, width, seed, band=None, variant=None):
    level_dir = ROOT / "assets" / "levels" / scene_id
    # What this level ships for the room being asked for, best first: the
    # variant's own file, then the first picture of its pool, then the level's
    # own. A baked scene is drawn as it is; a catalog is handed to the placer.
    names = []
    if variant:
        names += [f"scene.{variant}.json", f"scene.{variant}.1.json"]
    names += ["scene.json", "scene.1.json"]
    scene_path = next(
        (level_dir / name for name in names if (level_dir / name).exists()),
        None,
    )
    if scene_path is None:
        sys.exit(f"{scene_id}: no scene to draw; run build or bake first")
    scene = json.loads(scene_path.read_text())
    if "props" in scene:
        scene = run_placer(scene_id, seed, band, variant)

    # Scene paths are relative to the level folder, the way the app reads them.
    canvas = Image.open(level_dir / scene["background"]).convert("RGBA")
    if canvas.width != width:
        canvas = canvas.resize(
            (width, round(width * canvas.height / canvas.width)), Image.LANCZOS
        )
    w, h = canvas.size

    for obj in scene["objects"]:
        # A baked find is already in the backdrop; drawing its chip icon over
        # it would double the art and hide exactly what wants checking.
        if obj.get("drawn") is False:
            continue
        sprite = Image.open(level_dir / obj["sprite"]).convert("RGBA")
        box = (
            max(1, round(obj["size"][0] * w)),
            max(1, round(obj["size"][1] * h)),
        )
        sprite = sprite.resize(box, Image.LANCZOS)
        if obj.get("place") in GROUNDED:
            # Grounded props get the renderer's contact shadow, clipped the
            # way the sprite is: a prop tucked behind a crate tucks its
            # shadow behind it too.
            shadow, pad = contact_shadow(box, foot_of(obj, box, h))
            s_left = round(obj["pos"][0] * w - box[0] / 2) - pad
            s_top = round(obj["pos"][1] * h - box[1] / 2) - pad
            clip = obj.get("clip")
            if clip:
                keep = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
                window = (
                    max(0, round(clip[0] * w) - s_left),
                    max(0, round(clip[1] * h) - s_top),
                    min(shadow.width, round(clip[2] * w) - s_left),
                    min(shadow.height, round(clip[3] * h) - s_top),
                )
                if window[2] > window[0] and window[3] > window[1]:
                    keep.paste(shadow.crop(window), window[:2])
                shadow = keep
            canvas.alpha_composite(shadow, (s_left, s_top))
        # `rotation` is clockwise on screen; PIL rotates counterclockwise.
        if obj["rotation"]:
            sprite = sprite.rotate(
                -obj["rotation"], resample=Image.BICUBIC, expand=True
            )
        centre = (obj["pos"][0] * w, obj["pos"][1] * h)
        left = round(centre[0] - sprite.width / 2)
        top = round(centre[1] - sprite.height / 2)
        clip = obj.get("clip")
        if clip:
            # Part of this prop sits behind scenery the backdrop already
            # holds, so the game draws only what is left showing. Drawing the
            # whole of it here would make the preview kinder than the game.
            keep = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
            window = (
                max(0, round(clip[0] * w) - left),
                max(0, round(clip[1] * h) - top),
                min(sprite.width, round(clip[2] * w) - left),
                min(sprite.height, round(clip[3] * h) - top),
            )
            if window[2] > window[0] and window[3] > window[1]:
                keep.paste(sprite.crop(window), window[:2])
            sprite = keep
        canvas.alpha_composite(sprite, (left, top))

    if outlines or labels:
        draw = ImageDraw.Draw(canvas)
        for obj in scene["objects"]:
            if outlines:
                points = [(x * w, y * h) for x, y in obj["polygon"]]
                # Decoys are outlined in red: they are in the picture and on
                # no list, and a preview that cannot tell them apart is a
                # preview you cannot check the find list against.
                colour = ((80, 255, 120, 255) if obj.get("findable", True)
                          else (255, 90, 90, 255))
                draw.polygon(points, outline=colour, width=2)
            if labels:
                # Sit the name just above this object, not above whatever the
                # last composited sprite happened to be.
                above = obj["size"][1] * h / 2 + 4
                draw.text(
                    (obj["pos"][0] * w, obj["pos"][1] * h - above),
                    obj["label"],
                    fill=(255, 240, 160, 255),
                    anchor="ms",
                )

    parts = [scene_id]
    if scene.get("band") and scene["band"] != "look":
        parts.append(scene["band"])
    if scene.get("variant"):
        parts.append(scene["variant"])
    if "seed" in scene:
        parts.append(str(scene["seed"]))
    out = ROOT / "tools" / "scenes" / f"{'.'.join(parts)}.preview.png"
    canvas.convert("RGB").save(out, optimize=True)
    seeded = f" (seed {scene['seed']})" if "seed" in scene else ""
    print(
        f"{out.relative_to(ROOT)}: {len(scene['objects'])} objects at "
        f"{w}x{h}{seeded}"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--outlines", action="store_true",
                        help="draw the tap polygons")
    parser.add_argument("--labels", action="store_true",
                        help="draw each object's name")
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--seed", type=int,
                        help="layout to draw; omitted, a random one")
    parser.add_argument("--band", choices=["peek", "look", "seek", "hunt"],
                        help="age band to draw it for; default look")
    parser.add_argument("--variant",
                        help="backdrop variant, e.g. dense; default is "
                             "whichever the band asks for")
    args = parser.parse_args()
    preview(args.scene_id, args.outlines, args.labels, args.width, args.seed,
            args.band, args.variant)


if __name__ == "__main__":
    main()
