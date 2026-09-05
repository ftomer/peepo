#!/usr/bin/env python3
"""Build a playable level from raw art.

Takes a build spec (see tools/scenes/*.build.json), slices the sprite sheets,
strips their solid background to alpha, and writes a whole level folder:

    assets/levels/<id>/
      scene.json        what the level hides and how it may be hidden
      meta.json         what the backdrop is made of, for the placer
      background.jpg    the downscaled backdrop
      sprites/*.png     one per findable object

The level is then registered in assets/levels/levels.json, the catalog the app
reads, and its folders are added to pubspec.yaml.

Where each prop ends up is not decided here. A level ships a catalog - each
prop's silhouette, the sizes it may take, how it can sit, how often it may
appear - and the game places them when the level is played, against the meta
that travels with it. So the room is hidden differently every game, and the
build's job is to make sure it can be: every prop is checked against the meta
for a region that can hold it at a size that region allows. Problems are
printed as warnings; the build still runs, so a deliberate exception costs
nothing.

Silhouettes are the convex hull of each sprite's opaque pixels in sprite-local
units; the placer turns them into tap polygons where it puts the sprite, so
taps match the art.

A spec that lists `objects` instead of `props` is a hand-placed level and is
built exactly as written, layout and all.

    python3 -m venv .venv && .venv/bin/pip install pillow
    .venv/bin/python tools/build_scene.py tools/scenes/pirate_cabin.build.json
"""
import json
import math
import re
import statistics
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent

# Per-channel threshold for "this is sheet background, not artwork".
WHITE = 232
# An enclosed near-white patch this large a share of the tile can be a hole.
HOLE_MIN_AREA = 0.0015
# ...and is one when its tone matches the sheet's paper this closely, in mean
# brightness and in flatness. Paper is paper wherever it shows through; painted
# white is a shade darker and carries the brush gradient with it.
HOLE_TONE_SLACK = 1.0
HOLE_FLAT_SD = 2.0
# A sprite whose gaps are thin reads darker and rougher than the same paper
# does in an open margin: a two-pixel sliver is nearly all jpeg edge ringing
# off the ink either side of it. Those sprites widen the test by hand, through
# a sheet's optional "holes" map - see cut_holes.
HOLE_SLACK_KEYS = ("toneSlack", "flatSd")
# Alpha threshold for a pixel counting as part of the object's silhouette.
OPAQUE = 40
# Median brightness, 0-255, above which a sprite reads as light art and below
# which it reads as dark. The band between them is the middle tone, which
# camouflage placement treats as matching nothing.
#
# Set to the tertiles of the shipped catalog rather than to the middle of the
# range: this art is bright and saturated throughout, so splitting at 85 and
# 170 called forty of forty-eight sprites medium and left camouflage with
# nothing to tell apart.
TONE_LIGHT, TONE_DARK = 150, 120
# Convex hull sampling grid per sprite.
HULL_SAMPLES = 72
# Ship sprites at this multiple of the pixels they can occupy in the scene.
SPRITE_OVERSAMPLE = 4.0
SPRITE_MIN_PX, SPRITE_MAX_PX = 256, 1024


def cut_background(tile, name="", slack=None):
    """Flood-fill near-white in from the tile border and make it transparent."""
    tile = tile.convert("RGB")
    w, h = tile.size
    px = tile.load()
    bg = bytearray(w * h)
    queue = deque()

    def push(x, y):
        i = y * w + x
        if bg[i]:
            return
        r, g, b = px[x, y]
        if r >= WHITE and g >= WHITE and b >= WHITE:
            bg[i] = 1
            queue.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            push(x - 1, y)
        if x < w - 1:
            push(x + 1, y)
        if y > 0:
            push(x, y - 1)
        if y < h - 1:
            push(x, y + 1)

    holes = cut_holes(px, w, h, bg, slack)
    if holes:
        print(f"  {name or 'sprite'}: {holes} hole(s) cut out")

    alpha = Image.frombytes("L", (w, h), bytes(255 - v * 255 for v in bg))
    # Pull the cut one pixel inward, then soften so edges are not stair-stepped.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(
        ImageFilter.GaussianBlur(0.8)
    )
    out = tile.convert("RGBA")
    out.putalpha(alpha)
    return out.crop(out.getbbox())


def paper_tone(px, w, h, bg):
    """Mean brightness and flatness of the sheet background around the prop."""
    tones = [
        sum(px[i % w, i // w]) / 3 for i in range(0, w * h, 53) if bg[i]
    ]
    if len(tones) < 50:
        return None
    return statistics.fmean(tones), statistics.pstdev(tones)


def cut_holes(px, w, h, bg, slack=None):
    """Also make enclosed near-white regions transparent when they are holes.

    Flooding from the border only clears the space around a prop. A ring, a
    buckle or a handle has sheet showing through *inside* its outline too, and
    left opaque that arrives in the game as a white blob glued to the artwork.

    A hole is told from a highlight by tone: the hole is the same paper as the
    margin, so it matches the background's brightness and is just as flat,
    while the shine painted on a polished skull is a shade darker and carries a
    gradient. On this art the gap is wide - a hole lands within a tone of the
    paper, the brightest highlight is three off it.

    [slack] widens both halves of that test for one sprite. A gap only a few
    pixels across is mostly the jpeg's ringing against the ink either side of
    it, so it reads darker and rougher than the same paper does out in an open
    margin, and the lantern's two cage gaps miss the test by a hundredth of a
    tone. Widen it only as far as that sprite's own highlights allow, and only
    for a sprite whose cut has been looked at.
    """
    paper = paper_tone(px, w, h, bg)
    if paper is None:
        return 0
    mean, spread = paper
    slack = slack or {}
    tone_slack = float(slack.get("toneSlack", HOLE_TONE_SLACK))
    flat = max(float(slack.get("flatSd", HOLE_FLAT_SD)), spread * 1.6)

    seen = bytearray(w * h)
    cut = 0
    for start in range(w * h):
        if bg[start] or seen[start]:
            continue
        sx, sy = start % w, start // w
        r, g, b = px[sx, sy]
        if not (r >= WHITE and g >= WHITE and b >= WHITE):
            continue

        seen[start] = 1
        queue = deque([(sx, sy)])
        patch, tones = [], []
        while queue:
            x, y = queue.popleft()
            patch.append(y * w + x)
            tones.append(sum(px[x, y]) / 3)
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                r, g, b = px[nx, ny]
                if r >= WHITE and g >= WHITE and b >= WHITE:
                    index = ny * w + nx
                    if not seen[index]:
                        seen[index] = 1
                        queue.append((nx, ny))

        if (
            len(patch) >= HOLE_MIN_AREA * w * h
            and abs(statistics.fmean(tones) - mean) <= tone_slack
            and statistics.pstdev(tones) <= flat
        ):
            for index in patch:
                bg[index] = 1
            cut += 1
    return cut


def slice_sheets(spec):
    """Return {sprite id: trimmed RGBA image} for every sheet in the spec."""
    sprites = {}
    for sheet in spec["sheets"]:
        img = Image.open(ROOT / sheet["source"])
        cols, rows = sheet["cols"], sheet["rows"]
        tw, th = img.width // cols, img.height // rows
        holes = sheet.get("holes", {})
        for key, slack in holes.items():
            unknown = set(slack) - set(HOLE_SLACK_KEYS)
            if unknown:
                sys.exit(
                    f"{sheet['source']}: holes.{key} has unknown key(s) "
                    f"{', '.join(sorted(unknown))}"
                )
            if key not in sheet["names"]:
                sys.exit(f"{sheet['source']}: holes names no sprite {key!r}")
        for index, name in enumerate(sheet["names"]):
            col, row = index % cols, index // cols
            tile = img.crop(
                (col * tw, row * th, (col + 1) * tw, (row + 1) * th)
            )
            sprites[name] = cut_background(tile, name, holes.get(name))
    return sprites


def convex_hull(points):
    """Andrew's monotone chain convex hull."""
    points = sorted(set(points))
    if len(points) < 3:
        return points

    def half(pts):
        out = []
        for p in pts:
            while len(out) >= 2:
                (ax, ay), (bx, by) = out[-2], out[-1]
                if (bx - ax) * (p[1] - ay) - (by - ay) * (p[0] - ax) > 0:
                    break
                out.pop()
            out.append(p)
        return out[:-1]

    return half(points) + half(points[::-1])


def sprite_tone(img):
    """How light or dark the art is: "light", "medium" or "dark".

    Measured off the sprite's own opaque pixels rather than authored, so it
    cannot drift from the picture the way a hand-written colour column does.
    The placer matches it against a region's `contrast` to decide whether
    putting the prop there hides it or shows it off - which is the difference
    between the green clover in the hedge and the green clover on the red
    picnic blanket.

    The thick dark outline every sprite carries would drag the mean down on
    its own, so the darkest and lightest tenth of the pixels are dropped and
    the median of what is left is what counts: the fill, not the linework.
    """
    rgb = img.convert("RGBA")
    alpha = rgb.getchannel("A")
    grey = rgb.convert("L")
    values = [
        v for v, a in zip(list(grey.getdata()), list(alpha.getdata()))
        if a >= OPAQUE
    ]
    if not values:
        return "medium"
    values.sort()
    trim = len(values) // 10
    core = values[trim:len(values) - trim] or values
    median = core[len(core) // 2]
    if median >= TONE_LIGHT:
        return "light"
    if median <= TONE_DARK:
        return "dark"
    return "medium"


def silhouette(img):
    """Convex hull of the opaque pixels, in [-0.5, 0.5] sprite-local units."""
    n = HULL_SAMPLES
    alpha = img.getchannel("A").resize((n, n), Image.BILINEAR)
    px = alpha.load()
    points = [
        (x, y) for y in range(n) for x in range(n) if px[x, y] > OPAQUE
    ]
    return [
        ((x + 0.5) / n - 0.5, (y + 0.5) / n - 0.5)
        for x, y in convex_hull(points)
    ]


def compact(text):
    """Put coordinate pairs on one line so the scene JSON stays readable."""
    text = re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", text)

    def reflow(match):
        pairs = re.findall(r"\[[^\[\]]+\]", match.group(0))
        lines = [
            " " * 8 + ", ".join(pairs[i:i + 4])
            for i in range(0, len(pairs), 4)
        ]
        return "[\n" + ",\n".join(lines) + "\n" + " " * 6 + "]"

    return re.sub(r"\[\s+(\[[^\[\]]+\],?\s+)+\]", reflow, text)


def load_meta(spec, spec_path):
    """Meta file for this scene, or None when the scene has no description."""
    path = spec.get("meta")
    path = ROOT / path if path else Path(spec_path).with_suffix("").with_suffix(
        ".meta.json"
    )
    if not Path(path).exists():
        return None
    return json.loads(Path(path).read_text())


def rest_y(region, x):
    """Height of the region's supporting surface at x, or None if it has none.

    A rect is a bounding box, and most of a hammock's box is air. `restLine`
    is the line inside it that props actually stand on: a single y, or a
    polyline of [x, y] points for a surface that runs uphill in perspective.
    """
    line = region.get("restLine")
    if line is None:
        return None
    if isinstance(line, (int, float)):
        return float(line)
    points = sorted((float(px), float(py)) for px, py in line)
    if x <= points[0][0]:
        return points[0][1]
    if x >= points[-1][0]:
        return points[-1][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x0 <= x <= x1:
            span = x1 - x0
            return y0 if span == 0 else y0 + (x - x0) / span * (y1 - y0)
    return points[-1][1]


def _in_polygon(points, x, y):
    """Ray casting, matching SceneObject.contains in the Dart model."""
    inside = False
    j = len(points) - 1
    for i, (ax, ay) in enumerate(points):
        bx, by = points[j]
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            inside = not inside
        j = i
    return inside


def _inside(region_or_rect, x, y):
    """Point test against a region, using its polygon when it has one."""
    if isinstance(region_or_rect, dict):
        rect = region_or_rect["rect"]
        polygon = region_or_rect.get("polygon")
    else:
        rect, polygon = region_or_rect, None
    x0, y0, x1, y1 = rect
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    return polygon is None or _in_polygon(
        [(float(px), float(py)) for px, py in polygon], x, y
    )


# How a prop meets its region. Resting kinds are judged by the sprite's
# footprint, the rest by where its middle lands.
FOOTED = {"rests_on", "lies_flat", "leans_against"}
# ...and these hold it off the ground, so they need something solid instead.
HANGING = {"hangs_on", "pinned_to"}
# A footprint may hang this far past the region edge before it reads as floating.
FOOT_SLACK = 0.02


def validate(spec, meta, aspects=None):
    """Warn about placements the scene meta says do not make sense.

    `aspects` maps sprite id to height/width of the trimmed art. With it, a
    prop that is meant to rest on something is checked by where its bottom edge
    lands, which is the difference between sitting on the barrel and hovering
    over it.
    """
    regions = {r["id"]: r for r in meta["regions"]}
    rules = meta.get("placementRules", {})
    margin = rules.get("edgeMargin", 0.0)
    separation = rules.get("minSeparation", 0.0)
    per_region = rules.get("maxPerRegion")
    aspect = spec["sceneSize"]["w"] / spec["sceneSize"]["h"]
    warnings = []
    used = {}

    for placement in spec["objects"]:
        pid, x, y, w = (
            placement["id"],
            placement["x"],
            placement["y"],
            placement["w"],
        )

        named = placement.get("region")
        if named and named not in regions:
            warnings.append(f"{pid}: unknown region '{named}'")
            named = None

        hits = [r for r in meta["regions"] if _inside(r, x, y)]
        if named:
            region = regions[named]
            if not _inside(region, x, y):
                shape = "outline" if region.get("polygon") else "box"
                warnings.append(
                    f"{pid}: sits at ({x}, {y}), outside the {shape} of "
                    f"region '{named}' {region['rect']}"
                )
        elif hits:
            # Without an explicit region, judge against the tightest match.
            region = min(
                hits,
                key=lambda r: (r["rect"][2] - r["rect"][0])
                * (r["rect"][3] - r["rect"][1]),
            )
        else:
            warnings.append(
                f"{pid}: sits at ({x}, {y}), which no region covers"
            )
            region = None

        if region is not None:
            used[region["id"]] = used.get(region["id"], 0) + 1
            supports = region.get("supports", [])
            place = placement.get("place")
            if place and place not in supports:
                warnings.append(
                    f"{pid}: '{region['id']}' does not support {place} "
                    f"(it supports {', '.join(supports) or 'nothing'})"
                )
            if aspects and (place in FOOTED or not place):
                # Rotated art occupies a taller box, so a dagger laid at 45
                # degrees reaches lower than its upright height suggests.
                theta = math.radians(placement.get("rot", 0))
                spread = abs(math.sin(theta)) + aspects.get(pid, 1) * abs(
                    math.cos(theta)
                )
                bottom = y + w * aspect * spread / 2
                surface = rest_y(region, x)
                if surface is not None:
                    slack = region.get("restTolerance", FOOT_SLACK)
                    if abs(bottom - surface) > slack:
                        verb = "floats above" if bottom < surface \
                            else "sinks into"
                        warnings.append(
                            f"{pid}: bottom edge at {bottom:.3f} {verb} the "
                            f"surface of '{region['id']}' at {surface:.3f}"
                        )
                elif not region["rect"][1] <= bottom <= (
                    region["rect"][3] + FOOT_SLACK
                ):
                    warnings.append(
                        f"{pid}: bottom edge at {bottom:.3f} falls outside "
                        f"'{region['id']}' ({region['rect'][1]} to "
                        f"{region['rect'][3]}), so the prop does not sit on "
                        f"anything"
                    )
            # A meta that is merely warned about still reaches this point, so
            # read its fields defensively: a malformed range must not take the
            # whole build down in the middle of reporting on it.
            size_range = region.get("sizeRange", [0, 1])
            if not (isinstance(size_range, (list, tuple))
                    and len(size_range) == 2):
                warnings.append(
                    f"{region['id']}: sizeRange is not a pair, ignoring it"
                )
                size_range = [0, 1]
            low, high = size_range
            if high <= 0:
                warnings.append(
                    f"{pid}: '{region['id']}' holds nothing "
                    f"({region.get('notes', '')})"
                )
            elif not low <= w <= high:
                warnings.append(
                    f"{pid}: width {w} is off for '{region['id']}' "
                    f"(expected {low}-{high} at {region.get('depth', '?')} "
                    f"depth)"
                )
            if not region.get("supports"):
                warnings.append(
                    f"{pid}: '{region['id']}' supports no placement kind"
                )

        if not margin <= x <= 1 - margin or not margin <= y <= 1 - margin:
            warnings.append(f"{pid}: inside the {margin} edge margin")

        for zone in meta.get("noGo", []):
            if _inside(zone["rect"], x, y):
                warnings.append(
                    f"{pid}: lands on no-go '{zone['id']}' - {zone['reason']}"
                )

    for region_id, count in used.items():
        if per_region and count > per_region:
            warnings.append(
                f"{region_id}: {count} objects, more than maxPerRegion "
                f"({per_region})"
            )

    # Compare in scene units so the spacing rule means the same in x and y.
    placements = spec["objects"]
    for i, a in enumerate(placements):
        for b in placements[i + 1:]:
            dx = a["x"] - b["x"]
            dy = (a["y"] - b["y"]) / aspect
            if math.hypot(dx, dy) < separation:
                warnings.append(
                    f"{a['id']} and {b['id']}: closer than the "
                    f"{separation} minimum separation"
                )

    return warnings


LEVELS_DIR = "assets/levels"
MANIFEST = f"{LEVELS_DIR}/levels.json"


def register_assets(level_dir):
    """Make sure pubspec lists this level's folders.

    Flutter bundles asset directories one by one and never recursively, so a
    new level that is not listed builds cleanly and then fails to load at
    runtime. Cheaper to fix here than to debug in the app.
    """
    pubspec = ROOT / "pubspec.yaml"
    lines = pubspec.read_text().splitlines()
    wanted = [
        f"    - {MANIFEST}",
        f"    - {level_dir}/",
        f"    - {level_dir}/sprites/",
    ]
    missing = [entry for entry in wanted if entry not in lines]
    if not missing:
        return False
    for index, line in enumerate(lines):
        if line.strip() == "assets:":
            end = index + 1
            while end < len(lines) and lines[end].startswith("    - "):
                end += 1
            lines[end:end] = missing
            pubspec.write_text("\n".join(lines) + "\n")
            for entry in missing:
                print(f"pubspec.yaml: added {entry.strip()}")
            return True
    for entry in missing:
        print(f"  warning: pubspec.yaml has no assets list; add {entry.strip()}")
    return False


def capacity_of(props):
    """The most objects a catalog can hide: every prop at its copy ceiling."""
    if not props:
        return 0
    return sum(p.get("copies", [1, 1])[1] for p in props)


def variants_map(variants):
    """A level entry's variants as a name to counts map.

    A manifest written before the counts were lists bare names; such a variant
    is read as hiding what its level does, which is what the level list
    assumed at the time. Rebuilding the variant replaces the guess.
    """
    if isinstance(variants, dict):
        return dict(variants)
    return {name: {} for name in (variants or [])}


def register_level(level_id, name, object_count, theme=None, max_objects=None,
                   variant=None):
    """Add or refresh this level's entry in the catalog the app reads.

    New levels land at the end of the list, which is play order; an existing
    entry keeps its place and only its details are updated.

    ``max_objects`` is every copy the props between them allow, which is the
    most the level can ever hide. The older age bands ask for more than the
    authored count, and the level list needs to know where that stops without
    opening the scene file.

    A variant adds itself to the entry's ``variants`` map under its own name,
    with its own two counts. It hides the same things as the level it varies,
    but its room is busier and its regions hold a different number of copies of
    them, so the level card cannot read the base scene's numbers for a band
    that plays the variant.
    """
    path = ROOT / MANIFEST
    catalog = json.loads(path.read_text()) if path.exists() else {"levels": []}
    entry = {"id": level_id, "name": name, "objectCount": object_count}
    if max_objects:
        entry["maxObjects"] = max_objects
    if theme:
        entry["theme"] = theme
    levels = catalog.setdefault("levels", [])
    for index, existing in enumerate(levels):
        if existing.get("id") == level_id:
            if variant:
                # A variant adds itself and its counts, and changes nothing
                # else: the level's name, theme and authored count are the base
                # scene's word.
                counts = {"objectCount": object_count}
                if max_objects:
                    counts["maxObjects"] = max_objects
                variants = variants_map(existing.get("variants"))
                variants[variant] = counts
                levels[index] = {
                    **existing,
                    "variants": dict(sorted(variants.items())),
                }
            else:
                levels[index] = {**existing, **entry}
            break
    else:
        if variant:
            sys.exit(
                f"{level_id}: build the base level before its {variant} "
                f"variant - the variant adds to a catalog entry, it does not "
                f"create one"
            )
        levels.append(entry)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(catalog, indent=2) + "\n")
    print(f"{MANIFEST}: {len(levels)} levels")


# Every way a prop can meet a region, as the meta files spell them.
PLACE_KINDS = {
    "rests_on", "lies_flat", "hangs_on", "pinned_to", "leans_against",
    "tucked_in", "inside",
}


def widest_draw(spec_path):
    """How wide each prop is ever drawn in this level, in scene pixels.

    A variant shares the level's sprites and draws them smaller. Sizing a
    sprite to the spec in hand would leave the base level's art at the dense
    scene's resolution, and which of the two won would depend on which was
    built last - so every one of the level's specs is asked, and the file is
    written for the largest the prop is drawn anywhere. Order-independent, and
    a spec that shrinks its props still shrinks the file next build.
    """
    level_id = Path(spec_path).name.split(".")[0]
    widest = {}
    for path in sorted(Path(spec_path).resolve().parent.glob(
            f"{level_id}.*build.json")):
        try:
            spec = json.loads(path.read_text())
        except (OSError, ValueError) as error:
            print(f"  warning: {path.name} unreadable, not sizing from it "
                  f"({error})")
            continue
        scene_w = spec.get("sceneSize", {}).get("w")
        if not scene_w:
            continue
        for prop in spec.get("props", []):
            width = max(float(w) for w in prop["width"]) * scene_w
            widest[prop["id"]] = max(widest.get(prop["id"], 0.0), width)
    return widest


def write_sprite(source, level_dir, prop_id, width):
    """Save one sprite at the resolution its largest on-screen size needs."""
    target = min(
        SPRITE_MAX_PX,
        max(SPRITE_MIN_PX, round(width * SPRITE_OVERSAMPLE)),
    )
    sprite = source.copy()
    sprite.thumbnail((target, target), Image.LANCZOS)
    path = f"sprites/{prop_id}.png"
    sprite.save(ROOT / level_dir / path, optimize=True)
    return path


def catalog_props(spec, sprites, level_dir, scene_w, widest=None):
    """Describe every prop for the placer that runs when the level is played.

    A catalog says what a thing is, how big it may be, how it can sit and how
    often it may turn up - never where it goes. The spot is chosen at load time
    against the backdrop's meta, so no two playthroughs hide the same room the
    same way.
    """
    props, decoys = [], []
    widest = widest or {}
    for prop in spec["props"]:
        source = sprites[prop["id"]]
        width = [float(w) for w in prop["width"]]
        # A decoy is described exactly like a find; the level tells them apart
        # by which list it finds them in.
        (decoys if prop.get("decoy") else props).append(
            {
                "id": prop["id"],
                "label": prop["label"],
                # Sized for the level, not for this spec: the base scene and
                # its variants share one file.
                "sprite": write_sprite(
                    source,
                    level_dir,
                    prop["id"],
                    widest.get(prop["id"], max(width) * scene_w),
                ),
                # Height follows from the width the placer picks, so the art is
                # never stretched.
                "aspect": round(source.height / source.width, 5),
                "places": list(prop["places"]),
                "regions": list(prop.get("regions", [])),
                "width": [round(w, 5) for w in width],
                # Clockwise on screen, the same sign the renderer uses.
                "rotate": [
                    round(float(r), 1) for r in prop.get("rotate", [0, 0])
                ],
                "copies": [int(c) for c in prop.get("copies", [1, 1])],
                # Read off the art, for camouflage placement.
                "tone": sprite_tone(source),
                "silhouette": [
                    [round(ux, 5), round(uy, 5)] for ux, uy in silhouette(source)
                ],
            }
        )
    return props, decoys


# Words that decide which of the three tones a region's contrast really is,
# tried in the order they appear in the text so "light metal against a dark
# gap" is light - the region's own tone is what it leads with.
TONE_WORDS = (
    ("dark", "dark"), ("shadow", "dark"), ("black", "dark"), ("navy", "dark"),
    ("light", "light"), ("bright", "light"), ("pale", "light"),
    ("white", "light"), ("medium", "medium"),
)


def normalize_contrast(meta):
    """Reduce every region's contrast to light, medium or dark.

    The schema asks for one of three words and the analyzer sometimes writes a
    sentence instead - "very dark, near-black glass", "bright glowing screen".
    The placer matches a region's contrast against a sprite's measured tone by
    equality, so prose reads as no tone at all and camouflage quietly stops
    working for the whole level. Normalising here means the shipped meta is
    always the enum, whatever came back.
    """
    changed = []
    for region in meta.get("regions", []):
        raw = str(region.get("contrast", "medium"))
        if raw in ("light", "medium", "dark"):
            continue
        lowered = raw.lower()
        hits = [
            (lowered.index(word), tone)
            for word, tone in TONE_WORDS
            if word in lowered
        ]
        tone = min(hits)[1] if hits else "medium"
        region["contrast"] = tone
        changed.append(f"{region.get('id')}: {raw!r} -> {tone}")
    return changed


def usable_supports(region):
    """The ways a prop can meet this region without hanging in mid-air.

    Mirrors SceneRegion.placements in the Dart placer: resting, lying and
    leaning need a rest line to stand on, or a surface where depth is free;
    hanging and pinning need something solid, which a box drawn around a
    hanging net is not. A region that offers what the placer will not take is
    not offering it, so it is not counted here either.
    """
    kind = region.get("kind", "surface")
    grounded = region.get("restLine") is not None or kind == "surface"
    solid = kind == "wall" or bool(region.get("polygon"))
    usable = set()
    for support in region.get("supports", []):
        if support in FOOTED:
            allowed = grounded
        elif support in HANGING:
            allowed = solid
        else:
            allowed = grounded or solid
        if allowed:
            usable.add(support)
    return usable


def validate_catalog(props, meta, object_count):
    """Warn about props the room cannot actually hide.

    The runtime placer can only work with what the meta offers it. A prop that
    no region supports, or that is sized for no region at all, would simply not
    appear in the game - a silent hole in the level, which is exactly the kind
    of thing to catch at build time.
    """
    regions = {r["id"]: r for r in meta["regions"]}
    warnings = []
    for prop in props:
        pid = prop["id"]
        named_regions = prop.get("regions") or []
        for kind in prop["places"]:
            if kind not in PLACE_KINDS:
                warnings.append(f"{pid}: '{kind}' is not a placement kind")
        for named in named_regions:
            if named not in regions:
                warnings.append(f"{pid}: unknown region '{named}'")

        low, high = prop["width"]
        if low > high:
            warnings.append(f"{pid}: width range {prop['width']} is backwards")
        candidates = [
            region
            for region in meta["regions"]
            if (not named_regions or region["id"] in named_regions)
            and usable_supports(region) & set(prop["places"])
            and max(low, region.get("sizeRange", [0, 0])[0])
            <= min(high, region.get("sizeRange", [0, 0])[1])
        ]
        if not candidates:
            warnings.append(
                f"{pid}: no region can hold it - nothing supports "
                f"{'/'.join(prop['places'])} at width {low}-{high}"
            )
        elif len(candidates) < 3:
            warnings.append(
                f"{pid}: only {len(candidates)} region(s) can hold it "
                f"({', '.join(r['id'] for r in candidates)}), so it lands in "
                f"much the same spot every game"
            )

        first, last = prop.get("copies", [1, 1])
        if first < 0 or last < first:
            warnings.append(f"{pid}: copies {prop['copies']} is backwards")

    least = sum(p.get("copies", [1, 1])[0] for p in props)
    most = sum(p.get("copies", [1, 1])[1] for p in props)
    if object_count < least:
        warnings.append(
            f"objectCount {object_count} is below the {least} copies the "
            f"props ask for, so some props never appear"
        )
    if object_count > most:
        warnings.append(
            f"objectCount {object_count} is above the {most} copies the props "
            f"allow, so the level hides fewer objects than it claims"
        )
    return warnings


def build(spec_path):
    spec = json.loads(Path(spec_path).read_text())
    scene_w = spec["sceneSize"]["w"]
    scene_h = spec["sceneSize"]["h"]
    # Everything the level owns lives in one folder, and the scene file names
    # its neighbours relative to it, so the folder can be moved or renamed
    # whole without touching what is inside.
    # Named in the spec, or the spec's own name: tools/scenes/<id>.build.json
    # builds assets/levels/<id>/.
    level_id = Path(spec_path).name.split(".")[0]
    level_dir = spec.get("levelDir") or f"{LEVELS_DIR}/{level_id}"
    sprite_dir = ROOT / level_dir / "sprites"
    sprite_dir.mkdir(parents=True, exist_ok=True)

    # A variant is a second backdrop for the same level, with its own room
    # description over the same sprites: tools/scenes/<id>.dense.build.json
    # writes background_dense.jpg, meta.dense.json and scene.dense.json beside
    # the originals and leaves every one of them alone. The older age bands
    # ask for it; the level itself, its name, its music and its find list are
    # unchanged.
    variant = spec.get("variant")
    suffix = f"_{variant}" if variant else ""
    dotted = f".{variant}" if variant else ""

    # A baked scene is a picture with its finds drawn into it, written by
    # `tools/scene.sh bake` rather than from a spec. Rebuilding over one would
    # swap the level back to composited sprites over a backdrop that already
    # holds the objects - every find drawn twice - and would start by
    # overwriting the picture itself, so the refusal comes before any write.
    shipped = ROOT / level_dir / f"scene{dotted}.json"
    if shipped.exists() and spec.get("props"):
        already = json.loads(shipped.read_text())
        if any(not obj.get("drawn", True) for obj in already.get("objects", [])):
            sys.exit(
                f"{shipped.relative_to(ROOT)} is a baked scene; rebuild it "
                f"with tools/scene.sh bake, or delete it first to go back to "
                f"composited sprites"
            )

    background = spec["background"]
    bg = Image.open(ROOT / background["source"]).convert("RGB")
    max_width = background["maxWidth"]
    if bg.width > max_width:
        bg = bg.resize(
            (max_width, round(max_width * bg.height / bg.width)), Image.LANCZOS
        )
    bg.save(
        ROOT / level_dir / f"background{suffix}.jpg",
        quality=background.get("quality", 86),
        optimize=True,
    )

    register_assets(level_dir)
    meta = load_meta(spec, spec_path)
    sprites = slice_sheets(spec)

    if spec.get("props"):
        scene, object_count = build_catalog(
            spec, sprites, meta, level_dir, scene_w, scene_h, variant,
            widest_draw(spec_path),
        )
    else:
        scene, object_count = build_placements(
            spec, sprites, level_dir, scene_w, scene_h
        )

    out = ROOT / level_dir / f"scene{dotted}.json"
    out.write_text(compact(json.dumps(scene, indent=2)) + "\n")
    print(f"{out.relative_to(ROOT)}: {object_count} objects")

    register_level(
        Path(level_dir).name,
        spec["name"],
        object_count,
        (meta or {}).get("theme"),
        max_objects=capacity_of(scene.get("props")) or object_count,
        variant=variant,
    )

    if meta is None:
        print("no scene meta: nothing was checked")
        return
    aspects = {
        name: image.height / image.width for name, image in sprites.items()
    }
    if spec.get("props"):
        # Decoys are checked too: one that cannot be placed is one the room
        # never gets, and silently dropping it is how a level ends up easier
        # than it was authored to be.
        warnings = validate_catalog(scene["props"], meta, object_count)
        decoys = scene.get("decoys", [])
        warnings += [
            f"decoy {w}"
            for w in validate_catalog(decoys, meta, capacity_of(decoys))
        ]
        agrees = "props fit the room described by"
    else:
        warnings = validate(spec, meta, aspects)
        agrees = "placements agree with"
    for warning in warnings:
        print(f"  warning: {warning}")
    if not warnings:
        print(f"{agrees} {meta['sceneId']} meta")


def build_catalog(spec, sprites, meta, level_dir, scene_w, scene_h,
                  variant=None, widest=None):
    """A level whose props are placed at load time, against the backdrop meta.

    The meta travels with the level, because the game needs it: it is what the
    placer reads to decide where a prop can go.
    """
    if meta is None:
        sys.exit(
            f"{spec['sceneId']}: a catalog level needs a meta file - the "
            f"placer has nothing to place against without one"
        )
    unruled = [p["id"] for p in spec["props"] if "places" not in p]
    if unruled:
        sys.exit(
            f"{spec['sceneId']}: {', '.join(unruled)} have no placement rules "
            f"yet; run tools/scene.sh place first"
        )
    suffix = f"_{variant}" if variant else ""
    dotted = f".{variant}" if variant else ""
    for note in normalize_contrast(meta):
        print(f"  contrast {note}")
    (ROOT / level_dir / f"meta{dotted}.json").write_text(
        json.dumps(meta, indent=2) + "\n"
    )
    props, decoys = catalog_props(spec, sprites, level_dir, scene_w, widest)
    object_count = int(spec.get("objectCount") or len(props))
    scene = {
        "sceneId": spec["sceneId"],
        "name": spec["name"],
        "background": f"background{suffix}.jpg",
        "meta": f"meta{dotted}.json",
        "size": {"w": scene_w, "h": scene_h},
        "objectCount": object_count,
        "props": props,
        **({"decoys": decoys} if decoys else {}),
    }
    return scene, object_count


def build_placements(spec, sprites, level_dir, scene_w, scene_h):
    """A level whose props are placed by hand, in the spec, once and for all."""
    objects = []
    for placement in spec["objects"]:
        source = sprites[placement["id"]]
        sprite_path = write_sprite(
            source, level_dir, placement["id"], placement["w"] * scene_w
        )

        # The renderer draws a w x h box centred on (x, y), then rotates it
        # clockwise on screen. `rot` is authored in Pillow's sign convention
        # (counterclockwise on screen), so flip it for the renderer.
        width = placement["w"]
        height = width * (source.height / source.width) * (scene_w / scene_h)
        rotation = -placement.get("rot", 0)
        theta = math.radians(rotation)
        cos, sin = math.cos(theta), math.sin(theta)

        polygon = []
        for ux, uy in silhouette(source):
            dx, dy = ux * width * scene_w, uy * height * scene_h
            polygon.append(
                [
                    round(placement["x"] + (dx * cos - dy * sin) / scene_w, 5),
                    round(placement["y"] + (dx * sin + dy * cos) / scene_h, 5),
                ]
            )

        objects.append(
            {
                "id": placement["id"],
                "label": placement["label"],
                "sprite": sprite_path,
                "pos": [placement["x"], placement["y"]],
                "size": [round(width, 5), round(height, 5)],
                "rotation": rotation,
                "polygon": polygon,
                "hintCenter": [placement["x"], placement["y"]],
            }
        )

    scene = {
        "sceneId": spec["sceneId"],
        "name": spec["name"],
        "background": "background.jpg",
        "size": {"w": scene_w, "h": scene_h},
        "objects": objects,
    }
    return scene, len(objects)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(sys.argv[1])
