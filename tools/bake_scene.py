#!/usr/bin/env python3
"""Turn a picture that already holds its finds into a playable scene.

    tools/scene.sh bake <id> [--variant dense] --plate <room jpeg>
                            [--art <jpeg>] [--take N] [--relocate]

The rest of the pipeline hides a level by compositing cut-out sprites over a
backdrop, freshly per playthrough. That is what makes a level different every
time it is played, and it is also the one thing a player's eye can always
undo: a sprite is drawn by a different pass than the room, and no amount of
grounding, shadowing and clipping quite makes it the same picture.

A baked scene is the other trade. The illustrator draws the finds into the
room - same pen, same palette, same shadows, half of them behind something -
and this reads them back out.

The art is made by handing the model the room and asking it to add the finds
to it (see `--from` in `generate_art.py`), which is what makes the reading
exact. The room without the finds is a clean plate, pixel for pixel, so:

1. the difference between plate and picture is the finds, and nothing else.
   Each blob of difference is one object, cut out to the pixel - no flood
   fills, no guessing where a drawing ends and its shelf begins.
2. a vision call names the blobs by boxing each find the level asks for; the
   box only has to overlap the right blob, so it is allowed to be rough.
3. the mask gives the tap polygon, the centre and the size, and is checked
   for the two ways a reading goes wrong to look at: a drawing cut off in
   mid-air, and one so far behind the scenery there is nothing left to find.
4. what is cut out is a *stamp*: the find's own pixels on transparency, with
   the soft edge of its shadow feathered in, plus the exact place it goes.
   The level ships the plate and the stamps rather than the finished picture,
   and the renderer puts them back - which is the same picture to look at, at
   a fraction of the size, and lets a find leave it again by simply not being
   drawn.
5. the object list's icons are cut from the sprite sheets instead, one per
   kind: the bar says what is being asked for, and that is the prop whole
   rather than this picture's half-hidden copy of it.
6. the level file is written in the fixed-`objects` shape: the backdrop is the
   plate every picture of that band shares, and each object is its stamp at
   its own place.

What the model cannot be trusted with is completeness, so anything missing,
doubled or too small to tap is reported rather than shipped quietly. A find
drawn twice is not a fault - the game already knows how to ask for two of a
thing - so both copies are kept and the level asks for both.
"""
import argparse
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

import build_scene
import claude_json

ROOT = Path(__file__).resolve().parent.parent
SCENES = ROOT / "tools" / "scenes"
LEVELS = ROOT / "assets" / "levels"

# Anything darker than this is outline ink. Only the pen: a saturated orange
# rug is dark too, and reading it as ink glues every object standing on it to
# the floor it stands on.
INK_LEVEL = 110

# What separates one patch of flat colour from the next: the pen, or any step
# in brightness this big between neighbouring pixels. The step is what closes
# the gaps - a stroke thins to nothing at a corner, and an outline one pixel
# short of meeting itself would otherwise let a patch of star bleed into the
# rug it sits on.
EDGE_STEP = 32

# How far past the located box to look when refining it. The box is a vision
# model's aim and is a percent or two out either way; the flood does the rest.
PAD = 0.3

# Least of the picture a find may be across before it is too small to tap on a
# phone, and the most it may be before the reading has clearly run away into
# the furniture around it.
MIN_SIZE = 0.02
MAX_SIZE = 0.30

# How much room to leave around the sighting when the blob is trimmed to it,
# tried in order. The first is enough for a box aimed well; the rest are what a
# drawing gets when the trim would otherwise cut straight through it.
#
# A find may be cut off by the shelf in front of it - that is the whole point
# of hiding one - but it may never be cut off by a rectangle. The two are told
# apart exactly: paint that stops at the barrel stops because the picture stops
# it, while paint that carries on past the trim was severed by the trim.
TRIM_SLACK = (0.3, 0.6, 1.0, 1.8, 3.0)

# Longest run of a find's own pixels that may sit against the edge of the
# picture, as a fraction of the picture's width. Past this the drawing runs off
# the frame, and no shelf is doing the covering: it is simply half a coin.
EDGE_RUN = 0.004

# Least of the picture a find has to actually colour in, and the least of its
# own box it has to fill.
#
# The box tests above measure how far a drawing reaches; this measures how much
# of it there is to see. A wand drawn behind the cart is a legal box and two
# slivers of paint, and asking a child to find it is asking them to find
# nothing.
#
# Area carries the test and the fill barely comes into it: a wand, a balloon on
# its string and a butterfly are all mostly empty box by nature, and a floor
# high enough to mean anything there would throw out half the cast. What is
# left of the fill is a guard against the degenerate reading - an outline's
# worth of paint spread over a box the size of a shelf.
MIN_VISIBLE = 0.0004
MIN_FILL = 0.10

# How much of the located box the cut-out has to fill to be believed. Under
# the floor the flood leaked in through a gap in the outline and cut out a
# crater or an eye; over the ceiling it leaked out and took the shelf with it.
# Either way the box the vision call drew is the better answer, and saying so
# is better than dropping a find the picture really does hold.
MASK_FLOOR = 0.2
MASK_CEILING = 2.0

# How far past the located box a patch of paint may reach and still be read as
# part of the object, as a fraction of the box, and how much of the patch has
# to fall inside it. Both are loose because the box is aimed by eye: a star
# drawn a little taller than the box around it is still the star, while the rug
# it sits on has almost all of itself somewhere else.
BOX_SLACK = 0.12
BOX_SHARE = 0.7

# The pen the art is drawn with, as a fraction of picture width: how much ink
# around a patch of paint is the outline of that patch.
OUTLINE = 0.004

# Least of the biggest patch of a drawing that another patch has to be before
# it is part of the same drawing rather than a speck of whatever else the crop
# caught.
SPECK = 0.02

# How far a pixel has to move, on its strongest channel, before it counts as
# changed between the plate and the picture drawn over it. Below this is jpeg
# noise and the odd re-rendered outline.
DIFF_STEP = 60

# How far apart two blobs of difference may be and still be the same object:
# an aerial, a wheel and a shadow arrive as separate pieces of one drawing.
DIFF_JOIN = 0.003

# Widest line, in pixels, that is a redrawn outline rather than a drawing. A
# crowded plate comes back with every figure's pen a pixel to one side, and
# those hairlines, joined across DIFF_JOIN, would rope the finds into one
# tangle that no box can point at. Lines this wide or narrower are dropped
# before anything is joined; a find is solid and survives.
HAIRLINE = 1

# How much smaller the picture is made before its blobs are counted.
LABEL_SCALE = 4

# Least of the picture a blob has to cover to be an object rather than a line
# the model redrew a pixel to the left.
MIN_BLOB = 0.00025

# Where the feathered edge of a stamp starts: a pixel that moved less than
# this is the plate showing through, one that moved [DIFF_STEP] or more is the
# drawing, and in between is the shadow it casts.
FEATHER_LOW = 12

# How far around a find a stamp reaches for the rest of what the picture added
# there: the shadow it casts, the ring it carries, the aerial that came back
# from the diff as a piece of its own.
ERASE_REACH = 0.02

# Longest side of a chip icon, in pixels. The object bar draws them at about
# half of this on a phone.
CHIP_SIZE = 140

# Palette sizes: what a stamp and a chip are quantised to before they ship.
STAMP_COLOURS = 256
CHIP_COLOURS = 128

# Corners of the tap polygon. Enough for a hull to follow a boot or a saucer,
# few enough to stay readable in the level file.
HULL_POINTS = 20

# The backdrop as it ships: the same width and quality the composited scenes
# are built at, so a baked level is no heavier than the one it replaces.
MAX_WIDTH = 2400
QUALITY = 86


def spec_path(scene_id, variant):
    name = f"{scene_id}.{variant}.build.json" if variant else f"{scene_id}.build.json"
    path = SCENES / name
    if not path.exists():
        sys.exit(f"{path.relative_to(ROOT)} not found")
    return path


def find_list(spec):
    """The props the level asks for, decoys left out: a decoy that is painted
    into the room is just part of the room."""
    return [prop for prop in spec["props"] if not prop.get("decoy")]


def locate(art, props, cache, relocate=False):
    """Ask where each find is, as boxes. Cached, because it costs real money."""
    if cache.exists() and not relocate:
        return json.loads(cache.read_text())
    listing = "\n".join(
        f"- {prop['id']}: {prop.get('shape') or prop['label']}"
        for prop in props
    )
    where = art if not art.is_absolute() else art.relative_to(ROOT)
    prompt = f"""Read the image at {where}.

It is a hidden object picture with the objects drawn into it. Find every one of
these {len(props)} things:
{listing}

Reply with only a JSON object mapping each id to a list of sightings, one entry per
copy actually drawn in the picture (usually one, sometimes two, sometimes none):

{{"rocket": [{{"box": [x0, y0, x1, y1], "note": "on the ledge by the porthole"}}]}}

`box` is the tight bounding box of the drawn object in normalized coordinates, where
[0,0] is the top left corner of the picture and [1,1] the bottom right, given to three
decimals. Be precise: the box should touch the outermost dark outline of the object on
every side and contain nothing else.
An id with nothing drawn for it gets an empty list. Look twice before you say a thing
is not there, and look for a second copy of every one you do find."""
    found = claude_json.ask_json(prompt, model="sonnet")
    cache.write_text(json.dumps(found, indent=2) + "\n")
    return found


# Contact sheet of the changed patches: how big each crop is drawn, and how
# many go across. The number above each crop is what the model answers with.
SHEET_CELL = 200
SHEET_COLUMNS = 6
SHEET_LABEL = 26


def label_blobs(image, props, drawn_in, cache, relocate=False):
    """Ask what each changed patch is, rather than where each find is.

    With a plate the finds are already cut out - they are the patches that
    changed - so the only question left is which find each patch is. That is a
    far easier question than finding a duck in a crowd: the crop is handed over
    on its own, at its own size, and the answer is one id or "none". It is also
    the question a crowded picture forces, because a box aimed at a fairground
    from memory of the whole picture lands a stall to the left.

    The answer is written in the same shape `locate` writes - a box per
    sighting - so the rest of the bake and a hand correction read either.
    """
    if cache.exists() and not relocate:
        return json.loads(cache.read_text())
    width, height = image.size
    boxes = []
    for blob in drawn_in:
        rows, cols = np.nonzero(blob)
        boxes.append((int(cols.min()), int(rows.min()),
                      int(cols.max()) + 1, int(rows.max()) + 1))

    from PIL import ImageDraw, ImageFont
    font = ImageFont.load_default(size=SHEET_LABEL)
    rows_needed = (len(boxes) + SHEET_COLUMNS - 1) // SHEET_COLUMNS
    cell = SHEET_CELL + SHEET_LABEL + 8
    sheet = Image.new(
        "RGB", (SHEET_COLUMNS * SHEET_CELL, rows_needed * cell), "white"
    )
    draw = ImageDraw.Draw(sheet)
    for index, (c0, r0, c1, r1) in enumerate(boxes):
        # Room around the patch, so a duck is a duck on a saucer rather than
        # a yellow shape, and never less than a hand's width.
        side = max(c1 - c0, r1 - r0)
        pad = max(24, side // 3)
        crop = image.crop((
            max(0, c0 - pad), max(0, r0 - pad),
            min(width, c1 + pad), min(height, r1 + pad),
        ))
        crop.thumbnail((SHEET_CELL, SHEET_CELL), Image.LANCZOS)
        x = (index % SHEET_COLUMNS) * SHEET_CELL
        y = (index // SHEET_COLUMNS) * cell
        draw.text((x + 6, y + 2), str(index + 1), fill="red", font=font)
        sheet.paste(crop, (x + (SHEET_CELL - crop.width) // 2,
                           y + SHEET_LABEL + 6))
    sheet_path = cache.with_suffix("").with_suffix(".sheet.png")
    sheet.save(sheet_path)

    listing = "\n".join(
        f"- {prop['id']}: {prop.get('shape') or prop['label']}"
        for prop in props
    )
    where = sheet_path.relative_to(ROOT)
    prompt = f"""Read the image at {where}.

It is a contact sheet of {len(boxes)} numbered crops cut from a cartoon hidden
object picture. Each crop is centred on one patch the illustrator added to the
picture. Most of the patches are one of these {len(props)} things, drawn small
in the picture's own style:
{listing}

The rest are bits of scenery the illustrator touched up while drawing - part
of a person, a fence, a bench, a stall, a ride - and are "none".

For every number, say which thing its crop is centred on, or "none". Reply with
only a JSON object mapping each number, as a string, to one id or "none":

{{"1": "teddy_bear", "2": "none", "3": "rubber_duck"}}

The same thing may be drawn more than once, so an id may appear for several
numbers. Judge by the patch in the middle of the crop, not by what is around
it. Be strict: a crop with no such thing in the middle is "none"."""
    answer = claude_json.ask_json(prompt, model="sonnet")
    found = {prop["id"]: [] for prop in props}
    for index, (c0, r0, c1, r1) in enumerate(boxes):
        label = answer.get(str(index + 1)) or answer.get(index + 1)
        if label in found:
            found[label].append({
                "box": [round(c0 / width, 4), round(r0 / height, 4),
                        round(c1 / width, 4), round(r1 / height, 4)],
                "note": f"patch {index + 1} of {where.name}",
            })
    cache.write_text(json.dumps(found, indent=2) + "\n")
    return found


def _area(box, shape):
    """Pixel area of a normalized box."""
    height, width = shape
    return max(1.0, (box[2] - box[0]) * width * (box[3] - box[1]) * height)


def _box_mask(shape, box):
    """The located box itself, for a find the flood could not cut out."""
    height, width = shape
    mask = np.zeros(shape, dtype=bool)
    c0, c1 = int(box[0] * width), int(box[2] * width) + 1
    r0, r1 = int(box[1] * height), int(box[3] * height) + 1
    mask[max(0, r0):min(height, r1), max(0, c0):min(width, c1)] = True
    return mask


def mask_of(grey, box):
    """The drawn object inside [box], as a boolean mask over the whole picture.

    Cartoon art is flat colour bounded by thick dark outlines, so a drawing is
    a handful of enclosed patches of paint: the alien's body, its eyes, its
    mouth. The room behind it is patches too, but bigger ones - the desk, the
    wall, the rug - which run past the edges of any crop taken around the
    object.

    So the object is every patch that is wholly inside the located box, and the
    room is every patch that reaches out of it. Adding back the ink that
    touches the kept patches puts the outline around the cut-out, which is what
    makes it read as the drawing rather than as a sticker of its fill colours.
    """
    height, width = grey.shape
    x0, y0, x1, y1 = box
    pad_x = (x1 - x0) * PAD
    pad_y = (y1 - y0) * PAD
    c0 = max(0, int((x0 - pad_x) * width))
    c1 = min(width, int((x1 + pad_x) * width) + 1)
    r0 = max(0, int((y0 - pad_y) * height))
    r1 = min(height, int((y1 + pad_y) * height) + 1)
    if c1 - c0 < 4 or r1 - r0 < 4:
        return None

    crop = grey[r0:r1, c0:c1]
    dark = crop < INK_LEVEL
    # Only the pen is a wall. A dark visor, a night porthole and a black screen
    # are dark too, and walling them off cuts the middle out of the drawing
    # they belong to; a stroke is thin, so what survives an erosion is a fill
    # and what does not is the pen.
    pen = max(2, int(OUTLINE * width))
    stroke = dark & ~_grown(_eroded(dark, pen), pen)
    paint = ~(stroke | _edges(crop))
    rows, cols = paint.shape
    # The object's own share of the crop, in crop pixels: a patch may reach
    # this far out of the located box and still be part of the thing, because
    # the box is a vision model's aim rather than a measurement.
    slack_x = (x1 - x0) * width * BOX_SLACK
    slack_y = (y1 - y0) * height * BOX_SLACK
    left = int((x0 * width - c0) - slack_x)
    right = int((x1 * width - c0) + slack_x)
    top = int((y0 * height - r0) - slack_y)
    bottom = int((y1 * height - r0) + slack_y)

    kept = np.zeros_like(paint)
    seen = np.zeros_like(paint)
    for row in range(rows):
        for col in range(cols):
            if not paint[row, col] or seen[row, col]:
                continue
            patch = np.zeros_like(paint)
            patch[row, col] = True
            _spread(paint, patch, deque([(row, col)]))
            seen |= patch
            pr, pc = np.nonzero(patch)
            if pr.min() <= 0 or pc.min() <= 0 or pr.max() >= rows - 1 \
                    or pc.max() >= cols - 1:
                continue  # runs out of the crop: this is the room, not the find
            inside = (
                (pr >= top) & (pr <= bottom) & (pc >= left) & (pc <= right)
            ).mean()
            if inside < BOX_SHARE:
                continue  # mostly out of the box the sighting drew: the room
            kept |= patch
    if not kept.any():
        return None

    kept = _body(kept)
    # The outline belongs to the object it draws, so every stroke within a
    # pen's width of a kept patch comes with it.
    outline = _grown(kept, pen) & dark
    # Closed before it is filled: a dark visor or a dark window is read as ink
    # rather than as paint, and without closing the gap where it meets the
    # object's own edge the fill leaks in and cuts the middle out of the
    # drawing.
    piece = _filled(_closed(kept | outline, pen))
    mask = np.zeros(grey.shape, dtype=bool)
    mask[r0:r1, c0:c1] = piece
    return mask


def _body(kept):
    """[kept] without the specks: patches too small to be part of the drawing.

    A crop always catches a few pixels of something else - the corner of a
    label, a rivet, the end of a cable - and each one arrives as its own tiny
    patch. Anything under [SPECK] of the biggest patch is one of those.
    """
    rows, cols = kept.shape
    seen = np.zeros_like(kept)
    patches = []
    for row in range(rows):
        for col in range(cols):
            if not kept[row, col] or seen[row, col]:
                continue
            patch = np.zeros_like(kept)
            patch[row, col] = True
            _spread(kept, patch, deque([(row, col)]))
            seen |= patch
            patches.append(patch)
    if not patches:
        return kept
    biggest = max(patch.sum() for patch in patches)
    body = np.zeros_like(kept)
    for patch in patches:
        if patch.sum() >= SPECK * biggest:
            body |= patch
    return body


def _edges(crop):
    """Where the picture steps from one flat colour to another."""
    value = crop.astype(np.int16)
    edge = np.zeros(crop.shape, dtype=bool)
    step = np.abs(np.diff(value, axis=1)) > EDGE_STEP
    edge[:, :-1] |= step
    edge[:, 1:] |= step
    step = np.abs(np.diff(value, axis=0)) > EDGE_STEP
    edge[:-1, :] |= step
    edge[1:, :] |= step
    return edge


def _grown(mask, radius):
    """[mask] dilated by [radius] pixels, square-wise."""
    grown = mask.copy()
    for _ in range(radius):
        stepped = grown.copy()
        stepped[1:, :] |= grown[:-1, :]
        stepped[:-1, :] |= grown[1:, :]
        stepped[:, 1:] |= grown[:, :-1]
        stepped[:, :-1] |= grown[:, 1:]
        grown = stepped
    return grown


def _eroded(mask, radius):
    """[mask] shrunk by [radius] pixels, square-wise."""
    return ~_grown(~mask, radius)


def _closed(mask, radius):
    """[mask] grown by [radius] and shrunk back, which seals hairline gaps."""
    return ~_grown(~_grown(mask, radius), radius)


def _opened(mask, radius):
    """[mask] shrunk by [radius] and grown back, which drops hairlines."""
    return _grown(~_grown(~mask, radius), radius)


def _filled(mask):
    """[mask] with its enclosed holes filled in."""
    outside = _flood_border(~mask)
    return ~outside


def refined(grey, box, passes=2):
    """[mask_of] again against its own reading, so a box aimed a little wide
    or a little short converges on the drawing inside it.

    The sighting is a vision model's aim. One pass keeps whatever patches of
    paint sit mostly inside it, which is enough to find the object but also
    picks up the netting behind a planet or the pillow under a boot when the
    aim was loose. Reading the box back off the first cut-out and asking again
    drops those, because they are no longer mostly inside anything.
    """
    height, width = grey.shape
    mask = None
    for _ in range(passes):
        found = mask_of(grey, box)
        if found is None or not found.any():
            return mask
        mask = found
        rows, cols = np.nonzero(found)
        box = [
            float(cols.min()) / width,
            float(rows.min()) / height,
            float(cols.max() + 1) / width,
            float(rows.max() + 1) / height,
        ]
    return mask


def _flood_border(passable):
    """Everything reachable from the crop's edge through [passable] pixels."""
    height, width = passable.shape
    seen = np.zeros_like(passable)
    queue = deque()
    for col in range(width):
        for row in (0, height - 1):
            if passable[row, col] and not seen[row, col]:
                seen[row, col] = True
                queue.append((row, col))
    for row in range(height):
        for col in (0, width - 1):
            if passable[row, col] and not seen[row, col]:
                seen[row, col] = True
                queue.append((row, col))
    _spread(passable, seen, queue)
    return seen


def _component(mask, seed):
    """The connected piece of [mask] holding [seed], nearest one if it misses."""
    row, col = seed
    height, width = mask.shape
    if not mask[row, col]:
        # The middle of the box can land in a gap - the hole in a wrench, the
        # window of a rocket. Take the nearest solid pixel to start from.
        rows, cols = np.nonzero(mask)
        if rows.size == 0:
            return None
        distance = (rows - row) ** 2 + (cols - col) ** 2
        nearest = int(np.argmin(distance))
        row, col = int(rows[nearest]), int(cols[nearest])
    seen = np.zeros_like(mask)
    seen[row, col] = True
    _spread(mask, seen, deque([(row, col)]))
    return seen


def _spread(passable, seen, queue):
    """Four-way flood over [passable], marking [seen]."""
    height, width = passable.shape
    while queue:
        row, col = queue.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            r, c = row + dr, col + dc
            if 0 <= r < height and 0 <= c < width and passable[r, c] \
                    and not seen[r, c]:
                seen[r, c] = True
                queue.append((r, c))


def hull(points):
    """Convex hull of [points] as (x, y) pairs, counter-clockwise."""
    points = sorted(set(map(tuple, points)))
    if len(points) <= 2:
        return points

    def half(order):
        built = []
        for point in order:
            while len(built) >= 2 and _cross(built[-2], built[-1], point) <= 0:
                built.pop()
            built.append(point)
        return built[:-1]

    return half(points) + half(reversed(points))


def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def thinned(polygon, limit=HULL_POINTS):
    """Drop hull corners until [limit] are left, least important first."""
    points = [list(p) for p in polygon]
    while len(points) > limit:
        losses = [
            abs(_cross(points[i - 1], points[i], points[(i + 1) % len(points)]))
            for i in range(len(points))
        ]
        points.pop(int(np.argmin(losses)))
    return points


def icon_of(image, found, others, width):
    """The find cut out of the picture as a stamp: its own pixels, on
    transparency, with its shadow feathered out to nothing.

    A hard-edged cut at the diff threshold leaves the shadow behind, which is
    what a rubbed-out find used to show as a halo. Here the alpha follows how
    much each pixel changed - fully opaque where the drawing is, fading out
    through the shadow it casts - so stamping it back over the plate rebuilds
    the picture the illustrator drew.
    """
    r0, r1, c0, c1 = found["box"]
    change = found.get("change")
    mask = found["mask"]
    reach = max(2, int(ERASE_REACH * width))
    allowed = _grown(mask, reach)
    for other in others:
        if other is not mask:
            allowed &= ~other
    crop = np.asarray(image.crop((c0, r0, c1, r1)).convert("RGB"))
    if change is None:
        alpha = (mask[r0:r1, c0:c1] * 255).astype(np.uint8)
    else:
        ramp = np.clip(
            (change[r0:r1, c0:c1].astype(np.float32) - FEATHER_LOW)
            / max(1, DIFF_STEP - FEATHER_LOW),
            0.0, 1.0,
        )
        ramp *= (allowed[r0:r1, c0:c1] | mask[r0:r1, c0:c1])
        # Inside the find itself nothing is faded: the ramp is only there for
        # the shadow around it.
        ramp = np.maximum(ramp, mask[r0:r1, c0:c1])
        alpha = (ramp * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([crop, alpha]), mode="RGBA")


def blobs(plate, art):
    """Every patch of picture the finds were drawn into, as boolean masks.

    The plate is the room before the finds were added and the art is the room
    after, so the difference between them is the finds and nothing else. Which
    is a far better reading than any cut-out from a single picture: it knows
    exactly where a drawing ends and the shelf behind it begins, because the
    shelf did not change.
    """
    before = np.asarray(plate, dtype=np.int16)
    after = np.asarray(art, dtype=np.int16)
    amount = np.abs(after - before).max(axis=2)
    changed = amount > DIFF_STEP
    # Kept for the stamps: how far each pixel moved, not just whether it did,
    # which is what lets a find's shadow fade out instead of ending on a line.
    blobs.amount = amount
    blobs.changed = changed
    height, width = changed.shape
    # Hairlines out first, then joined before they are counted: one drawing
    # arrives as several patches - a body, an aerial, the shadow under it -
    # and each of them alone is a speck.
    join = max(2, int(DIFF_JOIN * width))
    joined = _closed(_opened(changed, HAIRLINE), join)

    # Counted small and cut out full size. A find is hundreds of pixels across,
    # so which pixels belong together is a question a quarter-size copy answers
    # just as well and in a fraction of the time.
    small = _shrink(joined, LABEL_SCALE)
    labels = _label(small)
    least = MIN_BLOB * small.size

    found = []
    for label in np.unique(labels):
        if label < 0:
            continue
        piece = labels == label
        if piece.sum() < least:
            continue
        full = _stretch(piece, LABEL_SCALE, changed.shape) & changed
        if not full.any():
            continue
        found.append(_filled_in_place(full))
    return found


def _padded(box, slack=0.3):
    """[box] with room around it, in normalized coordinates."""
    pad_x = (box[2] - box[0]) * slack
    pad_y = (box[3] - box[1]) * slack
    return [
        box[0] - pad_x, box[1] - pad_y, box[2] + pad_x, box[3] + pad_y,
    ]


def _trimmed(blob, shape, box):
    """The find inside [blob], trimmed to its sighting but never cut through.

    The blob is every pixel the picture gained around here, and now and then
    that is more than the find: the model touches up a fitting while it draws,
    and a blob that has run into one would hand the find a tap target the size
    of the bench beside it. So the blob is trimmed to the box the sighting drew.

    The trim is a rectangle, and a rectangle laid over a drawing cuts it in a
    straight line - which is exactly what a hidden object may not look like.
    A find is allowed to disappear behind the scenery, because the picture drew
    it that way; it is not allowed to end on a razor edge in mid-air.

    So the window is widened until it stops cutting. It is cutting whenever the
    blob carries on immediately past it, and it is not when the paint ends of
    its own accord - which is the barrel in front, and stays. Growing stops at
    [MAX_SIZE], where the reading has plainly run off into the furniture and
    the caller throws it out.
    """
    kept = None
    for slack in TRIM_SLACK:
        window = _box_mask(shape, _padded(box, slack))
        piece = _largest_piece(blob & window)
        if piece is None:
            return kept
        if kept is not None and _spans(piece, shape) > MAX_SIZE:
            return kept  # the widening has left the object; keep what fit
        kept = piece
        if not (_grown(piece, 1) & blob & ~window).any():
            return kept  # the paint ends where the picture ends it
    return kept


def _spans(mask, shape):
    """The longer side of [mask]'s box, as a fraction of the picture."""
    rows, cols = np.nonzero(mask)
    if rows.size == 0:
        return 0.0
    height, width = shape
    return max((cols.max() - cols.min() + 1) / width,
               (rows.max() - rows.min() + 1) / height)


def _runs_off_frame(mask, width):
    """Whether [mask] is a drawing the picture itself cut in half.

    An object that reaches the edge of the canvas was drawn running off it, and
    what ships is whatever fell inside the frame. Nothing in the room is doing
    the covering, so it reads as a mistake rather than as a hiding place.
    """
    limit = max(4, int(EDGE_RUN * width))
    return any(
        int(edge.sum()) > limit
        for edge in (mask[0, :], mask[-1, :], mask[:, 0], mask[:, -1])
    )


def _largest_piece(mask):
    """The biggest connected piece of [mask], or None if it is empty."""
    if not mask.any():
        return None
    labels = _label(_shrink(mask, LABEL_SCALE))
    best, most = None, 0
    for label in np.unique(labels):
        if label < 0:
            continue
        piece = labels == label
        size = int(piece.sum())
        if size > most:
            best, most = piece, size
    if best is None:
        return None
    return _stretch(best, LABEL_SCALE, mask.shape) & mask


def _shrink(mask, scale):
    """[mask] at 1/[scale], true wherever any pixel under it is true."""
    height, width = mask.shape
    rows, cols = height // scale, width // scale
    clipped = mask[: rows * scale, : cols * scale]
    return clipped.reshape(rows, scale, cols, scale).any(axis=(1, 3))


def _stretch(mask, scale, shape):
    """[mask] back to full size, each pixel becoming a [scale] square."""
    grown = np.repeat(np.repeat(mask, scale, axis=0), scale, axis=1)
    full = np.zeros(shape, dtype=bool)
    height = min(shape[0], grown.shape[0])
    width = min(shape[1], grown.shape[1])
    full[:height, :width] = grown[:height, :width]
    return full


def _label(mask):
    """Connected pieces of [mask], each pixel carrying its piece's number.

    Every pixel starts as its own number and keeps taking the biggest number
    it can see, which settles once each piece is all one number. Written this
    way because it is all whole-array work: a pixel-by-pixel flood over a
    picture this size is minutes, and this is a moment.
    """
    numbered = np.where(mask, np.arange(mask.size).reshape(mask.shape), -1)
    while True:
        spread = numbered.copy()
        spread[1:, :] = np.maximum(spread[1:, :], numbered[:-1, :])
        spread[:-1, :] = np.maximum(spread[:-1, :], numbered[1:, :])
        spread[:, 1:] = np.maximum(spread[:, 1:], numbered[:, :-1])
        spread[:, :-1] = np.maximum(spread[:, :-1], numbered[:, 1:])
        spread = np.where(mask, spread, -1)
        if np.array_equal(spread, numbered):
            return numbered
        numbered = spread


def _filled_in_place(mask):
    """[mask] with its holes filled, worked on its own corner of the picture."""
    rows, cols = np.nonzero(mask)
    if rows.size == 0:
        return mask
    r0, r1 = int(rows.min()), int(rows.max()) + 1
    c0, c1 = int(cols.min()), int(cols.max()) + 1
    # One pixel of margin so the fill has a border to start from.
    patch = np.zeros((r1 - r0 + 2, c1 - c0 + 2), dtype=bool)
    patch[1:-1, 1:-1] = mask[r0:r1, c0:c1]
    out = mask.copy()
    out[r0:r1, c0:c1] = _filled(patch)[1:-1, 1:-1]
    return out


def read(scene_id, variant, art, relocate, plate=None, take=None):
    spec = json.loads(spec_path(scene_id, variant).read_text())
    props = find_list(spec)
    image = Image.open(art).convert("RGB")
    if image.width > MAX_WIDTH:
        image = image.resize(
            (MAX_WIDTH, round(image.height * MAX_WIDTH / image.width)),
            Image.LANCZOS,
        )
    clean = None
    if plate is not None:
        clean = Image.open(plate).convert("RGB")
        if clean.size != image.size:
            clean = clean.resize(image.size, Image.LANCZOS)
    grey = np.asarray(image.convert("L"), dtype=np.uint8)
    height, width = grey.shape

    cache = SCENES / (
        f"{scene_id}{'.' + variant if variant else ''}"
        f"{'.' + str(take) if take else ''}.baked.json"
    )
    drawn_in = blobs(clean, image) if clean is not None else []
    if drawn_in:
        sightings = label_blobs(image, props, drawn_in, cache, relocate=relocate)
    else:
        sightings = locate(art, props, cache, relocate=relocate)
    taken = set()

    objects = []
    faults = []
    notes = []
    for prop in props:
        seen = sightings.get(prop["id"]) or []
        if not seen:
            faults.append(f"{prop['id']}: not drawn in the picture")
            continue
        for copy, sighting in enumerate(seen):
            box = [float(v) for v in sighting["box"]]
            mask = None
            if drawn_in:
                # The box only has to point at the right blob; the blob is the
                # measurement.
                window = _box_mask(grey.shape, box)
                best, overlap = None, 0
                for index, blob in enumerate(drawn_in):
                    if index in taken:
                        continue
                    shared = int((blob & window).sum())
                    if shared > overlap:
                        best, overlap = index, shared
                if best is None or overlap < 0.05 * drawn_in[best].sum():
                    faults.append(
                        f"{prop['id']}: nothing was added to the picture at "
                        f"{[round(v, 3) for v in box]}"
                    )
                    continue
                taken.add(best)
                mask = _trimmed(drawn_in[best], grey.shape, box)
                if mask is None:
                    faults.append(f"{prop['id']}: nothing inside {box}")
                    continue
            else:
                mask = refined(grey, box)
                share = (
                    0.0 if mask is None
                    else mask.sum() / max(1.0, _area(box, grey.shape))
                )
                if mask is None or not MASK_FLOOR <= share <= MASK_CEILING:
                    notes.append(
                        f"{prop['id']}: outline would not hold the flood "
                        f"({share:.2f} of the box), using the box"
                    )
                    mask = _box_mask(grey.shape, box)
            rows, cols = np.nonzero(mask)
            r0, r1 = int(rows.min()), int(rows.max()) + 1
            c0, c1 = int(cols.min()), int(cols.max()) + 1
            size = ((c1 - c0) / width, (r1 - r0) / height)
            if min(size) < MIN_SIZE:
                faults.append(
                    f"{prop['id']}: drawn {size[0]:.3f} x {size[1]:.3f}, "
                    "too small to tap"
                )
                continue
            if max(size) > MAX_SIZE:
                faults.append(
                    f"{prop['id']}: read {size[0]:.3f} x {size[1]:.3f}, which "
                    "is the furniture around it rather than the object"
                )
                continue
            if _runs_off_frame(mask, width):
                faults.append(
                    f"{prop['id']}: drawn off the edge of the picture, so what "
                    "is in frame is half of it"
                )
                continue
            visible = int(mask.sum())
            fill = visible / max(1, (r1 - r0) * (c1 - c0))
            if visible < MIN_VISIBLE * mask.size or fill < MIN_FILL:
                faults.append(
                    f"{prop['id']}: {100 * visible / mask.size:.3f}% of the "
                    f"picture and {fill:.2f} of its own box left showing - too "
                    "far behind the scenery to find"
                )
                continue
            objects.append({
                "prop": prop,
                "changed": getattr(blobs, "changed", None),
                "change": getattr(blobs, "amount", None),
                "copy": copy,
                "mask": mask,
                "box": (r0, r1, c0, c1),
                "pos": ((c0 + c1) / 2 / width, (r0 + r1) / 2 / height),
                "size": size,
                "centroid": (float(cols.mean()) / width,
                             float(rows.mean()) / height),
            })
    if drawn_in and len(taken) < len(drawn_in):
        notes.append(
            f"{len(drawn_in) - len(taken)} thing(s) were added to the picture "
            "that no find claimed"
        )
    return image, clean, objects, faults, notes





def _packed(image, colours):
    """[image] on a palette, which is most of what a stamp costs.

    The art is flat cel colour, so a couple of hundred of them hold the whole
    drawing; what makes a stamp big as a truecolour PNG is the jpeg noise it
    was cut from, and a palette throws exactly that away. Measured on the
    cabin's octopus: 351 KB down to 47 KB, six parts in a thousand different
    where the drawing is opaque.
    """
    return image.quantize(colors=colours, method=Image.FASTOCTREE)


def scene_name(variant, take):
    """`scene.json`, `scene.dense.json`, `scene.dense.2.json`."""
    parts = ["scene"]
    if variant:
        parts.append(variant)
    if take:
        parts.append(str(take))
    return ".".join(parts) + ".json"


def chips(kinds, spec, level_dir):
    """One icon per kind for the object list, cut from the sprite sheets.

    The bar is the level's promise: this is the thing you are looking for. So
    it shows the prop as the illustrator drew it on the sheet - whole, upright
    and on nothing - and not the copy that happens to be in this picture, which
    is half behind a barrel and carries the barrel's corner with it.

    It is one icon per kind rather than one per stamp for the same reason: the
    same thing asked for twice in one room is the same thing, and a bar that
    showed one of them lit from the left and the other half hidden would be
    asking for two.
    """
    paths = {kind: f"baked/chip_{kind}.png" for kind in kinds}
    missing = [k for k, p in paths.items() if not (level_dir / p).exists()]
    if missing:
        sheets = build_scene.slice_sheets(spec)
        for kind in missing:
            if kind not in sheets:
                sys.exit(f"{kind} is on no sprite sheet, so it has no icon")
            icon = sheets[kind].copy()
            icon.thumbnail((CHIP_SIZE, CHIP_SIZE), Image.LANCZOS)
            _packed(_deflecked(icon), CHIP_COLOURS).save(level_dir / paths[kind])
    return paths


def _deflecked(icon):
    """[icon] with the flecks taken off: a rivet of the next cell, a crumb of
    sheet paper the cut kept, the dot of ink beside the star.

    Kept by size against the biggest piece rather than by position, so a kite's
    tail and a wand's sparkles - drawn detached and meant to be there - stay.
    """
    pixels = np.asarray(icon.convert("RGBA")).copy()
    solid = pixels[:, :, 3] > 40
    if not solid.any():
        return icon
    labels = _label(solid)
    numbers, counts = np.unique(labels[solid], return_counts=True)
    keep = numbers[counts >= SPECK * counts.max()]
    pixels[:, :, 3] *= np.isin(labels, keep)
    return Image.fromarray(pixels, mode="RGBA")


def write(scene_id, variant, spec, image, plate, objects, take=None):
    """The level folder: the plate, a stamp per find, the icons and the scene.

    The finished picture is not shipped. The plate is - once per band, however
    many pictures are baked from it - and each find is a stamp put back where
    the illustrator drew it. Same picture to look at, a fraction of the size,
    and a find that is tapped simply stops being drawn.
    """
    level_dir = LEVELS / scene_id
    icons = level_dir / "baked"
    icons.mkdir(parents=True, exist_ok=True)
    suffix = f"_{variant}" if variant else ""
    stem = f"{suffix.strip('_')}{'_' if suffix else ''}{take or 1}"
    # This picture's last reading, cleared before its new one is written: a
    # re-bake that drops a find - off the edge of the frame, or too far behind
    # the scenery - would otherwise leave the stamp in the bundle, referenced
    # by nothing and shipped to every phone. Only this take's own files go;
    # the other pictures of the pool are not being re-read.
    for stale in icons.glob(f"{stem}_*.png"):
        stale.unlink()
    # Cut from the picture, one per stamp, before the bar took its icons off
    # the sheets.
    for stale in icons.glob("*_chip.png"):
        stale.unlink()
    background = f"background{suffix}.jpg"
    # The plate, not the picture: every take of a band shares it.
    (plate or image).save(
        level_dir / background, quality=QUALITY, optimize=True
    )

    width, height = image.size
    written = []
    others = [found["mask"] for found in objects]
    icon_of_kind = chips(
        {found["prop"]["id"] for found in objects}, spec, level_dir
    )
    for found in objects:
        prop = found["prop"]
        copy = found["copy"]
        object_id = prop["id"] if copy == 0 else f"{prop['id']}#{copy + 1}"
        name = f"{stem}_{object_id.replace('#', '_')}"
        stamp = icon_of(image, found, others, width)
        _packed(stamp, STAMP_COLOURS).save(level_dir / f"baked/{name}.png")

        rows, cols = np.nonzero(found["mask"])
        points = thinned(hull(list(zip(cols / width, rows / height))))
        r0, r1, c0, c1 = found["box"]
        written.append({
            "id": object_id,
            "kind": prop["id"],
            "label": prop["label"],
            "sprite": f"baked/{name}.png",
            "chip": icon_of_kind[prop["id"]],
            # The stamp's own box, which is where it goes back.
            "pos": [round((c0 + c1) / 2 / width, 5),
                    round((r0 + r1) / 2 / height, 5)],
            "size": [round((c1 - c0) / width, 5),
                     round((r1 - r0) / height, 5)],
            "rotation": 0,
            "polygon": [[round(x, 5), round(y, 5)] for x, y in points],
            "hintCenter": [round(found["centroid"][0], 5),
                           round(found["centroid"][1], 5)],
        })

    scene = {
        "sceneId": scene_id,
        "name": spec["name"],
        "background": background,
        "size": {"w": width, "h": height},
        "objectCount": len(written),
        "objects": written,
    }
    name = scene_name(variant, take)
    (level_dir / name).write_text(json.dumps(scene, indent=2) + "\n")
    register_assets(level_dir)
    return level_dir / name, len(written), background


def register_assets(level_dir):
    """Make sure pubspec lists the folder the chip icons went into.

    Flutter bundles asset directories one by one and never recursively, so a
    baked level that is not listed builds cleanly and then fails to load its
    own object list at runtime.
    """
    pubspec = ROOT / "pubspec.yaml"
    lines = pubspec.read_text().splitlines()
    entry = f"    - {level_dir.relative_to(ROOT)}/baked/"
    if entry in lines:
        return
    for index, line in enumerate(lines):
        if line.strip() != "assets:":
            continue
        end = index + 1
        while end < len(lines) and lines[end].startswith("    - "):
            end += 1
        lines[end:end] = [entry]
        pubspec.write_text("\n".join(lines) + "\n")
        print(f"pubspec.yaml: added {entry.strip()}")
        return
    sys.exit(f"pubspec.yaml has no assets: block; add {entry.strip()} by hand")


def pool(scene_id, variant):
    """Every picture this variant ships, and how many finds each holds.

    Read off the folder rather than counted as they are baked, so a pool is
    whatever is actually there - re-baking one picture of four does not make
    the level list forget the other three.
    """
    level_dir = LEVELS / scene_id
    found = {}
    for take in range(1, 100):
        path = level_dir / scene_name(variant, take)
        if not path.exists():
            break
        found[take] = len(json.loads(path.read_text())["objects"])
    return found


def update_manifest(scene_id, variant, asked, thumbnail):
    """Tell the level list what the baked scenes hold.

    The card is read before any scene is opened, so what is written here is
    what a player is promised: how many things the band is asked for, how many
    are drawn in the picture at all, how many pictures there are to choose
    between, and which one the card shows.
    """
    path = LEVELS / "levels.json"
    manifest = json.loads(path.read_text())
    pictures = pool(scene_id, variant)
    # The least any one picture holds, because the level list promises a count
    # before it knows which picture the player will be given. A pool where one
    # picture came back a find short asks everybody for one find fewer.
    drawn = min(pictures.values()) if pictures else asked
    entry = {
        "objectCount": min(asked, drawn),
        "maxObjects": drawn,
        "scenes": len(pictures) or 1,
    }
    # Only the first picture of a pool is the one the level card shows; the
    # others leave the card alone.
    if thumbnail:
        entry["thumbnail"] = thumbnail
    for level in manifest["levels"]:
        if level["id"] != scene_id:
            continue
        # Merged, not replaced: baking the third picture of a pool must not
        # forget which one the card shows.
        if variant:
            variants = level.setdefault("variants", {})
            variants[variant] = {**variants.get(variant, {}), **entry}
        else:
            level.update(entry)
    path.write_text(json.dumps(manifest, indent=2) + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--variant")
    parser.add_argument("--art", help="the picture with the finds drawn in")
    parser.add_argument(
        "--plate",
        help="the same room without them, which is what the picture was drawn "
             "from; gives exact cut-outs and lets a find be rubbed out again",
    )
    parser.add_argument(
        "--take", type=int,
        help="which of a variant's several pictures this is; a level that "
             "ships a pool hides its finds somewhere else in each of them",
    )
    parser.add_argument(
        "--asked", type=int,
        help="how many of the drawn finds the band is asked for, when that is "
             "fewer than the picture holds; the rest are decoys",
    )
    parser.add_argument(
        "--relocate",
        action="store_true",
        help="ask the vision model again instead of reusing the cached boxes",
    )
    args = parser.parse_args(argv)

    art = Path(args.art) if args.art else (
        ROOT / "rawimages" / args.scene_id / "baked_scene.jpeg"
    )
    if not art.exists():
        sys.exit(f"{art} not found; generate the baked scene art first")

    plate = Path(args.plate) if args.plate else None
    if plate is not None and not plate.exists():
        sys.exit(f"{plate} not found")

    image, clean, objects, faults, notes = read(
        args.scene_id, args.variant, art, args.relocate, plate=plate,
        take=args.take,
    )
    spec = json.loads(spec_path(args.scene_id, args.variant).read_text())
    scene, count, background = write(
        args.scene_id, args.variant, spec, image, clean, objects,
        take=args.take,
    )
    update_manifest(
        args.scene_id, args.variant, args.asked or count,
        background if (args.take or 1) == 1 else None,
    )

    for found in objects:
        object_id = found["prop"]["id"]
        if found["copy"]:
            object_id += f"#{found['copy'] + 1}"
        print(
            f"  {object_id:<20} at {found['pos'][0]:.3f},{found['pos'][1]:.3f}"
            f"  {found['size'][0]:.3f} x {found['size'][1]:.3f}"
        )
    print(f"{scene.relative_to(ROOT)}: {count} object(s) baked in")
    for note in notes:
        print(f"  ~ {note}")
    for fault in faults:
        print(f"  ! {fault}")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
