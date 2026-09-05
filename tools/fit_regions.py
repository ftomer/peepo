#!/usr/bin/env python3
"""Check a meta file's regions against the pixels of the backdrop it describes.

    tools/scene.sh fit <id> [--variant dense] [--only <id> ...]
    tools/scene.sh fit <id> --snap            # apply the small corrections
    tools/scene.sh fit <id> --check           # exit 1 if anything is off

A meta file is written by eye - by a vision model in `analyze`, by hand after
that - and eyes are wrong by a few percent. A few percent is the difference
between a prop standing on the shelf and a prop hanging in the air above it,
which is the single loudest way a hidden object stops looking like part of the
picture. The numbers cannot be checked against each other, because they are
all self-consistent; they can only be checked against the art.

The art is cartoon line work: flat fills bounded by near-black outlines. That
makes a supporting surface findable without understanding the picture at all -
it is a long horizontal run of outline ink, and the top of that run is where a
prop's feet go. So:

- every rest line is expected to sit on such a run. One that does not is
  reported with the ink the region does have near it, which is what a hand
  correction needs to know.
- a region that is not a floor is expected to have something in it. A box of
  unbroken wall colour describes nothing, and props sent there hang in space.
- `--snap` moves a rest line onto the ink under it when the ink is already
  within [SNAP_WINDOW] - drift too small to see and too big to stand on. It
  deliberately will not jump further: a rest line a whole shelf tier out is a
  reading of the picture that is wrong rather than imprecise, and guessing
  which tier was meant is how a fitter puts the crate inside the shelf.

Exit status is 1 under `--check` when any region fails, so a build can gate on
it. See docs/scene-meta.md.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# Anything darker than this is outline ink. The palettes are pale and the line
# work is near-black, so the gap is wide and the exact number does not matter.
INK_LEVEL = 120

# How long a horizontal run of ink has to be, as a fraction of scene width,
# before it counts as an edge something can stand on. Shorter runs are the
# sides of things, lettering, rivets and shading ticks.
MIN_RUN = 0.02

# How far above and below a rest line to look for the ink it should be sitting
# on, and how far a `--snap` is willing to move it.
#
# The move is capped well inside the search: past [SNAP_LIMIT] the surface
# under the line is a different piece of furniture - the rug under the chair,
# the shelf tier below the one that was meant - and a fitter that jumps there
# is confidently wrong. Those are reported for eyes instead.
SEARCH = 0.09
SNAP_WINDOW = 0.02
SNAP_LIMIT = 0.04

# How far off a rest line may be and still count as sitting on its surface. A
# prop's foot lands inside its own outline at this distance, so nothing reads
# as floating.
TOLERANCE = 0.008

# Where along the region to take readings, as fractions of its width. The ends
# are read too, near enough to the edge to matter: a prop only has to have its
# middle over the region, so a box that reaches past the console it names is a
# prop standing in the air beside the console.
SAMPLES = (0.03, 0.2, 0.35, 0.5, 0.65, 0.8, 0.97)

# Least of a non-floor region's box that has to be something other than flat
# backdrop before the region counts as describing anything.
MIN_FILL = 0.02

# How the supported span of a rest line is walked, and how much of a region's
# width may hang off the end of its own surface before the region is called
# too wide. A prop only has to have its middle over the region, so a box that
# reaches a few percent past the console it names is a prop standing in the
# air beside the console.
SPAN_STEP = 0.005
SPAN_SLACK = 0.02

# How much of a region's width the surface under it has to account for before
# the rest is called overhang. Below this the readings have found a sliver -
# a ladder rung, a shelf tier packed end to end - and what the box should be
# is a question for eyes, not for a trim.
SPAN_TRUST = 0.6

# Least width of a gap in the backdrop's own clutter that is worth offering
# the placer, and how far inside the gap a prop's middle has to stay so it
# does not straddle what stands beside it.
MIN_FREE = 0.02
FREE_MARGIN = 0.006

# The sliver of picture just over a surface that decides whether the backdrop
# is already standing something there. It is deliberately thin: anything the
# room draws *on* this surface has its outline touching the line, while what
# is drawn behind the surface - the shelf across the room, the crates behind
# the table - sits at its own height and never touches this one. A taller
# band cannot tell the two apart, because the art has no depth to read.
ROOM_HEIGHT = 0.013
ROOM_INK = 0.12

# How wide a hole in a surface is read as art standing on it rather than the
# end of the surface. The backdrop stands its own things on its own shelves,
# and each of them hides the board it stands on, so the walk carries on across
# a stretch this wide before it calls the surface finished.
SPAN_GAP = 0.055

# How much room above a line is looked at to decide whether it is a surface
# something can stand on, and how much of that room may be ink before it is
# not. A shelf board has clear air over it; the top edge of a monitor screen,
# a drawer front or a crate's own face has the rest of that object over it,
# and a prop stood there is a prop drawn on top of the scenery.
HEADROOM = 0.028
HEADROOM_INK = 0.2

# The other way a surface shows itself: the paint changes between the prop's
# feet and the air above them. A table top, a mattress, a rug and a crate lid
# are all one flat colour with the room's colour over them, and a prop stands
# anywhere on that colour rather than only on the outline at its far edge.
# Below this much difference the two are the same paint, which means the feet
# are somewhere in the middle of a wall, a screen or a drawer front.
PAINT_STEP = 22


def meta_path(scene_id, variant):
    name = f"{scene_id}.{variant}.meta.json" if variant else f"{scene_id}.meta.json"
    path = ROOT / "tools" / "scenes" / name
    if not path.exists():
        sys.exit(f"{path.relative_to(ROOT)} not found")
    return path


def load_art(meta):
    """The backdrop as (rgb, grey, ink): its paint, its luminance, its outlines."""
    path = ROOT / meta["image"]
    if not path.exists():
        sys.exit(f"{meta['image']} not found; run the build first")
    image = Image.open(path).convert("RGB")
    rgb = np.asarray(image, dtype=np.int16)
    grey = np.asarray(image.convert("L"), dtype=np.uint8)
    return rgb, grey, grey < INK_LEVEL


def rest_of(region, x):
    """The rest line's height at [x], or None where the region has none."""
    rest = region.get("restLine")
    if rest is None or rest == []:
        return None
    if isinstance(rest, (int, float)):
        return float(rest)
    points = sorted((float(px), float(py)) for px, py in rest)
    if len(points) == 1:
        return points[0][1]
    if x <= points[0][0]:
        return points[0][1]
    if x >= points[-1][0]:
        return points[-1][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x0 <= x <= x1:
            span = x1 - x0
            return y0 if span == 0 else y0 + (x - x0) / span * (y1 - y0)
    return points[-1][1]


def run_length(ink, row, col):
    """Width of the unbroken ink run through (col, row), in pixels."""
    height, width = ink.shape
    if not ink[row, col]:
        return 0
    left = col
    while left > 0 and ink[row, left - 1]:
        left -= 1
    right = col
    while right + 1 < width and ink[row, right + 1]:
        right += 1
    return right - left + 1


def paint_at(rgb, x, y0, y1):
    """Mean colour of the column at [x] between [y0] and [y1]."""
    height, width, _ = rgb.shape
    col = min(width - 1, max(0, int(x * width)))
    first = max(0, min(height - 1, int(y0 * height)))
    last = max(first + 1, min(height, int(y1 * height)))
    return rgb[first:last, col].mean(axis=0)


def paint_changes(rgb, x, y):
    """True when the feet are on a body with the room's air over them.

    Three readings of the same column: the paint under the feet, the paint
    just over them, and the paint well over them. A surface has the same paint
    just over the feet as well over them - that is the air the prop stands in -
    and different paint under them. A screen, a drawer front or the inside of
    a bunk recess reads the same in all three, which is how the fitter tells a
    thing's top from a thing's face.
    """
    below = paint_at(rgb, x, y + 0.004, y + 0.016)
    lip = paint_at(rgb, x, y - 0.02, y - 0.008)
    air = paint_at(rgb, x, y - 0.05, y - 0.032)
    if float(np.abs(lip - air).max()) >= PAINT_STEP:
        return False
    return float(np.abs(below - air).max()) >= PAINT_STEP


def stands_on(grey, ink, x, y):
    """True when a prop put at [y] in the column at [x] would look supported.

    Two things make a line a surface rather than just a line: clear room over
    it, and something solid under it. Ink over the line is the rest of the
    object the line belongs to - the screen above a monitor's bezel, the face
    of the crate above its own top edge - and a prop stood there sits in front
    of that object instead of on top of anything.
    """
    height, width = grey.shape
    col = min(width - 1, max(0, int(x * width)))
    top = max(0, int((y - HEADROOM) * height))
    lip = max(0, int((y - 0.004) * height))
    below = min(height, int((y + HEADROOM) * height))
    over = ink[top:lip, col]
    under = ink[int(y * height) : below, col]
    if over.size == 0 or under.size == 0:
        return False
    if float(over.mean()) > HEADROOM_INK:
        return False
    # The paint over a surface is the room's, the paint under it is the thing
    # the prop stands on: a line with darker paint above it than below is the
    # top of something's face, not the top of something.
    return float(grey[top:lip, col].mean()) + 8 >= float(
        grey[int(y * height) : below, col].mean()
    )


def clear_above(grey, ink, x, y):
    """True when nothing of the backdrop's own is standing at [y] in this column.

    Taller and stricter than the headroom [stands_on] wants: that one asks
    whether a line is a surface at all and has to tolerate the crate standing
    on it, this one asks whether there is room, and a crate is exactly what
    takes the room. Cartoon art draws every object in outline, so a column
    with any ink over it for the height of a small prop is a column already
    holding one.
    """
    height, width = ink.shape
    col = min(width - 1, max(0, int(x * width)))
    top = max(0, int((y - ROOM_HEIGHT) * height))
    lip = max(0, int((y - 0.003) * height))
    over = ink[top:lip, col]
    return over.size > 0 and float(over.mean()) <= ROOM_INK


def supported(rgb, grey, ink, x, y):
    """True when a prop with its feet at [y] would look held up by the art.

    Two ways for that to be true, because the art draws surfaces two ways: as
    a line to stand on - a shelf board, a rail, a bench - and as a body to
    stand in the middle of, like a table top or a mattress.
    """
    return stands_on(grey, ink, x, y) or paint_changes(rgb, x, y)


def edges_at(grey, ink, x, low, high):
    """Tops of the surfaces crossing the column at [x], between [low] and [high].

    A surface is drawn as one stroke a few pixels thick, so the rows it covers
    are collapsed to the first of them: the top of the line is where a prop
    sits, the rest of it is the thickness of the pen.
    """
    height, width = ink.shape
    col = min(width - 1, max(0, int(x * width)))
    first = max(0, int(low * height))
    last = min(height - 1, int(high * height))
    needed = MIN_RUN * width
    found = []
    row = first
    while row <= last:
        if ink[row, col] and run_length(ink, row, col) >= needed:
            y = row / height
            if stands_on(grey, ink, x, y):
                found.append(y)
            # Skip the thickness of this stroke rather than report every row.
            while row <= last and ink[row, col]:
                row += 1
        row += 1
    return found


def fill_of(ink, rect):
    """How much of [rect] is ink, as a fraction of its pixels."""
    height, width = ink.shape
    x0, y0, x1, y1 = rect
    c0, c1 = int(x0 * width), max(int(x1 * width), int(x0 * width) + 1)
    r0, r1 = int(y0 * height), max(int(y1 * height), int(y0 * height) + 1)
    patch = ink[r0:r1, c0:c1]
    return float(patch.mean()) if patch.size else 0.0


def free_spans(region, rgb, grey, ink):
    """Where along a region's rest line the backdrop has left room.

    A surface in a lived-in room is mostly taken: the shelf board holds its own
    crates, the table its own cup. A prop dropped on the taken part is drawn
    over the top of that art and reads as a sticker however well it is
    grounded, so the placer is given the gaps instead - the stretches where the
    line has clear air over it, which is where the picture would have put
    something itself.

    Returns [[x0, x1], ...] in normalized coordinates, or [] for a region with
    no rest line, one that is free end to end, or one with no room left.
    """
    rest = rest_of(region, region["rect"][0])
    if rest is None:
        return []
    x0, _, x1, _ = region["rect"]
    spans = []
    run = None
    x = x0
    while x <= x1 + 1e-9:
        # Clear ink over the line, not merely a surface: what is being looked
        # for here is room, and the outline of whatever the backdrop already
        # stands there is exactly what takes the room away.
        if clear_above(grey, ink, x, rest_of(region, x)):
            run = [x, x] if run is None else [run[0], x]
        elif run is not None:
            spans.append(run)
            run = None
        x += SPAN_STEP
    if run is not None:
        spans.append(run)
    spans = [
        [round(a + FREE_MARGIN, 4), round(b - FREE_MARGIN, 4)]
        for a, b in spans
        if b - a >= MIN_FREE + 2 * FREE_MARGIN
    ]
    return spans


def supported_span(region, rgb, grey, ink):
    """The stretch of a region's rest line that actually has surface under it.

    Returns (x0, x1) of the longest run of supported readings across the
    region's width, or None where the region has no rest line at all.
    """
    rest = rest_of(region, region["rect"][0])
    if rest is None:
        return None
    x0, _, x1, _ = region["rect"]
    best = None
    run = None
    gap = 0.0
    x = x0
    while x <= x1 + 1e-9:
        at = rest_of(region, x)
        held = supported(rgb, grey, ink, x, at)
        if held:
            gap = 0.0
            run = (x, x) if run is None else (run[0], x)
            if best is None or run[1] - run[0] > best[1] - best[0]:
                best = run
        else:
            gap += SPAN_STEP
            if gap > SPAN_GAP:
                run = None
        x += SPAN_STEP
    return best


class Reading:
    """What the pixels say about one region.

    A rest line is read at [SAMPLES] points across the region and each reading
    comes back one of three ways:

    - **on a surface**: a long horizontal line with clear room over it, which
      is what a shelf board, a table top or a bunk looks like where nothing is
      standing on it.
    - **against something**: ink at the line, but with the body of an object
      over it. That is the normal look of a surface at a point where the
      backdrop already stands a crate or a stack of towels on it, so it is not
      a fault - it just cannot confirm the height either.
    - **in the air**: no ink at all where the prop's feet would be. One of
      these is enough to call the region wrong, because a prop that lands at
      that x has nothing under it.
    """

    def __init__(self, region, rgb, grey, ink):
        self.region = region
        self.id = region["id"]
        self.rect = region["rect"]
        self.fill = fill_of(ink, self.rect)
        self.span = supported_span(region, rgb, grey, ink)
        self.samples = []
        x0, _, x1, _ = self.rect
        for at in SAMPLES:
            x = x0 + (x1 - x0) * at
            rest = rest_of(region, x)
            if rest is None:
                continue
            surfaces = edges_at(grey, ink, x, rest - SEARCH, rest + SEARCH)
            near = nearest_ink(ink, x, rest, TOLERANCE)
            held = supported(rgb, grey, ink, x, rest)
            self.samples.append(
                _Sample(x, rest, surfaces, near, held, art=(rgb, grey, ink))
            )
        # A table top and a monitor screen look the same from one column: paint
        # under the feet, more of the same paint over them. What tells them
        # apart is the rest of the region - a table top is the paint the line
        # already proved it stands on somewhere else along its length, and a
        # screen is not - so a reading in the middle of the surface's own
        # colour is taken as standing on it.
        paints = [
            paint_at(rgb, s.x, s.rest + 0.004, s.rest + 0.016)
            for s in self.samples
            if s.held
        ]
        if paints:
            surface_paint = np.median(np.stack(paints), axis=0)
            for sample in self.samples:
                if sample.held:
                    continue
                under = paint_at(rgb, sample.x, sample.rest + 0.004, sample.rest + 0.016)
                if float(np.abs(under - surface_paint).max()) < PAINT_STEP:
                    sample.held = True

    @property
    def grounded(self):
        return bool(self.samples)

    @property
    def airborne(self):
        """Readings with nothing at all under the prop's feet."""
        return [s for s in self.samples if not s.on_surface and not s.against]

    @property
    def landed(self):
        return [s for s in self.samples if s.on_surface]

    def coverage(self, move):
        """How many readings would have something under them, moved by [move]."""
        return sum(1 for sample in self.samples if sample.would_land(move))

    @property
    def snap(self):
        """The move that would put the whole rest line on its surface, or None.

        One number for the whole line: the drift being corrected is the region
        being read a little high or a little low, and bending the line sample
        by sample would fit the ink of whatever happens to be standing on the
        surface instead.

        Every surface the readings found is tried as a destination, nearest
        first, and the first one that leaves nothing in the air wins. A move
        past [SNAP_WINDOW] is a re-reading rather than a nudge, so it is only
        taken when it lands every reading - a rest line one shelf tier out is
        exactly the mistake a fitter must not make twice.
        """
        here = self.coverage(0.0)
        if here == len(self.samples):
            return None
        moves = sorted(
            {
                round(y - sample.rest, 4)
                for sample in self.samples
                for y in sample.surfaces
            },
            key=abs,
        )
        for move in moves:
            if not move or abs(move) > SNAP_LIMIT:
                continue
            landed = self.coverage(move)
            if landed < len(self.samples):
                continue
            return move
        return None

    @property
    def overhang(self):
        """How much of the region's width has no surface under it."""
        if not self.grounded or self.span is None:
            return 0.0
        x0, _, x1, _ = self.rect
        return (x1 - x0) - (self.span[1] - self.span[0])

    @property
    def trimmable(self):
        """True when the surface found is most of the region: enough to trim to."""
        if self.span is None:
            return False
        x0, _, x1, _ = self.rect
        width = x1 - x0
        return width > 0 and (self.span[1] - self.span[0]) >= SPAN_TRUST * width

    @property
    def verdict(self):
        if self.grounded:
            if self.airborne:
                return "drifts" if self.snap is not None else "floats"
            if not self.landed:
                # Every reading came back with the backdrop's own things
                # standing where the prop's feet would go. The height cannot
                # be confirmed, but nothing about it is wrong either, and a
                # shelf packed end to end is a real thing to draw.
                return "busy"
            if self.overhang > SPAN_SLACK and self.trimmable:
                return "wide"
            return "ok"
        if self.region.get("kind") != "surface" and self.fill < MIN_FILL:
            return "empty"
        return "ok"

    def report(self):
        if not self.grounded:
            return f"{self.id:<26} {self.verdict:<7} fill {self.fill:.3f}"
        marks = " ".join(sample.mark for sample in self.samples)
        note = f"{marks}"
        if self.verdict == "wide" and self.span is not None:
            note += (
                f"; box x {self.rect[0]:.3f}-{self.rect[2]:.3f}, "
                f"surface {self.span[0]:.3f}-{self.span[1]:.3f}"
            )
        if self.verdict == "drifts":
            note += f"; snap {self.snap:+.3f}"
        elif self.verdict == "floats":
            surfaces = sorted(
                {round(y, 3) for s in self.samples for y in s.surfaces}
            )
            rest = self.samples[0].rest
            note += f"; rest {rest:.3f}"
            if surfaces:
                note += "; surfaces at " + ", ".join(f"{y:.3f}" for y in surfaces[:8])
            else:
                note += f"; no surface within {SEARCH:.2f}"
        return f"{self.id:<26} {self.verdict:<7} {note}"


class _Sample:
    """One reading of a rest line against the art under it."""

    def __init__(self, x, rest, surfaces, near, held, art=None):
        self.x = x
        self.rest = rest
        self.surfaces = surfaces
        self.near = near
        self.held = held
        self.art = art

    @property
    def nearest(self):
        return min(self.surfaces, key=lambda y: abs(y - self.rest), default=None)

    @property
    def offset(self):
        nearest = self.nearest
        return None if nearest is None else nearest - self.rest

    @property
    def on_surface(self):
        offset = self.offset
        return self.held or (offset is not None and abs(offset) <= TOLERANCE)

    @property
    def against(self):
        """Ink at the feet, but something standing over them: a busy surface."""
        return self.near is not None

    def would_land(self, move):
        y = self.rest + move
        if any(abs(surface - y) <= TOLERANCE for surface in self.surfaces):
            return True
        if not move:
            return self.held or self.near is not None
        if self.art is not None and supported(*self.art, self.x, y):
            return True
        return nearest_ink(self.art[2], self.x, y, TOLERANCE) is not None \
            if self.art is not None else False

    @property
    def mark(self):
        return "=" if self.on_surface else ("~" if self.against else "!")


def nearest_ink(ink, x, y, window):
    """The ink row nearest [y] in the column at [x], within [window], or None."""
    height, width = ink.shape
    col = min(width - 1, max(0, int(x * width)))
    first = max(0, int((y - window) * height))
    last = min(height - 1, int((y + window) * height))
    rows = [row for row in range(first, last + 1) if ink[row, col]]
    if not rows:
        return None
    return min((row / height for row in rows), key=lambda r: abs(r - y))


def with_spans(region, spans):
    """A copy of [region] carrying the gaps its surface has left.

    Only where gaps were actually found. A line that comes back with none is
    a line the reading could not split - a shelf packed end to end, or a
    surface whose own drawn texture reads as clutter - and there the region's
    box is still the best thing anyone has.
    """
    out = dict(region)
    if spans:
        out["freeSpans"] = spans
    else:
        out.pop("freeSpans", None)
    return out


def corrected(region, move=0.0, span=None):
    """A copy of [region] with its rest line moved, and its box trimmed.

    [move] shifts the line and the box down the picture; [span] replaces the
    box's left and right edges with the stretch of the line that has surface
    under it, so a region stops offering the air beside the console it names.
    """
    out = dict(region)
    rest = region.get("restLine")
    if isinstance(rest, (int, float)):
        out["restLine"] = round(float(rest) + move, 4)
    elif rest:
        out["restLine"] = [[round(x, 4), round(y + move, 4)] for x, y in rest]
    x0, y0, x1, y1 = region["rect"]
    if span is not None:
        x0, x1 = span
    # The box follows the line: a region read a little low was read low all
    # over, and a rect left behind puts the prop outside the region it stands
    # in.
    out["rect"] = [round(x0, 4), round(y0 + move, 4), round(x1, 4), round(y1 + move, 4)]
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--variant")
    parser.add_argument("--only", nargs="*", default=None, help="region ids")
    parser.add_argument(
        "--snap",
        action="store_true",
        help="write the small corrections back into the meta",
    )
    parser.add_argument(
        "--spans",
        action="store_true",
        help="write each surface's free gaps into the meta",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 when a region does not match the art",
    )
    args = parser.parse_args(argv)

    path = meta_path(args.scene_id, args.variant)
    meta = json.loads(path.read_text())
    rgb, grey, ink = load_art(meta)

    regions = meta["regions"]
    wanted = set(args.only) if args.only else None
    readings = [
        Reading(region, rgb, grey, ink)
        for region in regions
        if wanted is None or region["id"] in wanted
    ]

    for reading in readings:
        print(reading.report())

    if args.spans:
        spans = {
            region["id"]: free_spans(region, rgb, grey, ink)
            for region in regions
            if wanted is None or region["id"] in wanted
        }
        meta["regions"] = [
            with_spans(region, spans[region["id"]])
            if region["id"] in spans
            else region
            for region in regions
        ]
        path.write_text(json.dumps(meta, indent=2) + "\n")
        filled = {i: found for i, found in spans.items() if found}
        print(f"gaps written for {len(filled)} region(s) in {path.relative_to(ROOT)}:")
        for region_id, found in filled.items():
            print(
                f"  {region_id:<26} "
                + ", ".join(f"{a:.3f}-{b:.3f}" for a, b in found)
            )
        regions = meta["regions"]

    if args.snap:
        fixes = {}
        for reading in readings:
            move = reading.snap or 0.0
            span = reading.span if reading.verdict == "wide" else None
            if move or span is not None:
                fixes[reading.id] = (move, span)
        if fixes:
            meta["regions"] = [
                corrected(region, *fixes[region["id"]])
                if region["id"] in fixes
                else region
                for region in regions
            ]
            path.write_text(json.dumps(meta, indent=2) + "\n")
            print(f"fitted {len(fixes)} region(s) in {path.relative_to(ROOT)}:")
            for region_id, (move, span) in fixes.items():
                note = f"{move:+.3f}" if move else "-"
                if span is not None:
                    note += f", x {span[0]:.3f}-{span[1]:.3f}"
                print(f"  {region_id:<26} {note}")
        else:
            print("nothing to fit within the window a fitter may move")

    bad = [r for r in readings if r.verdict not in ("ok", "busy")]
    print(f"{len(readings) - len(bad)}/{len(readings)} region(s) match the art")
    if args.check and bad:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
