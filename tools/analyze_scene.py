#!/usr/bin/env python3
"""Stage 1 of the scene pipeline: look at raw art, write the scene meta.

Takes a backdrop jpeg and its sprite sheets, and produces the two files the
rest of the pipeline runs on:

    tools/scenes/<id>.meta.json    what is in the room (see docs/scene-meta.md)
    tools/scenes/<id>.build.json   the build spec, with no objects placed yet

Both are meant to be read before stage 2 runs. The meta file is the scene's
memory: every placement decision after this point is argued against it.

    tools/scene.sh analyze <id> --bg <jpeg> --sheets <jpeg> [<jpeg> ...]
"""
import argparse
import json
import sys

from PIL import Image

from claude_json import ROOT, VisionError, ask_json

SCENES = ROOT / "tools" / "scenes"
# The pirate cabin is the reference scene: hand-checked, and the shape every
# later meta file is copied from.
EXAMPLE = "tools/scenes/pirate_cabin.meta.json"
BACKDROP_MAX_WIDTH = 2400
BACKDROP_QUALITY = 86

SHEET_PROMPT = """Read the sprite sheet image at {path}.

It is a grid of hidden-object props drawn on a plain background, one prop per
cell, meant for a {theme} hidden-object scene.

Reply with only this JSON object:

{{
  "cols": <number of columns>,
  "rows": <number of rows>,
  "props": [
    {{"id": "snake_case_id", "label": "Title Case Player-Facing Name",
      "shape": "one short phrase: silhouette, main colours, how it is normally
                oriented and what it would rest on"}}
  ]
}}

List the props in reading order, left to right then top to bottom, exactly
cols * rows of them. Ids must be unique, lowercase, and describe the object
rather than its position."""

# The meta file is where audience lives: the validator and the placement step
# both read their limits from it, so tuning happens once, here.
AUDIENCE = {
    "kids": """This level is for children aged five to seven. Author the meta for them:

- "placementRules" must set minSeparation to about 0.08, edgeMargin to about 0.04
  and maxPerRegion to 3, so finds are spread out without starving the room.
- Every "sizeRange" floor must be generous, because a prop here is roughly twice
  the width it would be in an adult scene: start regions around 0.045 to 0.06 and
  cap them near 0.13. Do not go wider than that even in the nearest regions. A
  prop wide enough to fill a whole shelf leaves the placer nowhere to put the
  next one, and the level ships missing objects.
- Prefer regions a child can reach on a phone. Anything in the top eighth or the
  extreme corners of the frame is decor, not a hiding place, so leave it out or
  mark it noGo.
- "occludedBy" must be filled in properly, even here. These backdrops are drawn
  with a shallow near foreground along the bottom of the frame - cushions,
  crates, bushes, the back of a chair - and it exists so a prop can be tucked
  partly behind it. Walk that foreground and anything else standing in front of
  something else, give each its own region, and list it in the "occludedBy" of
  every region it stands in front of. A prop is only ever hidden behind a thing
  whose top edge is below the prop's top and whose bottom edge is at or below
  the prop's, so what matters is upright things in the near foreground, not flat
  things on the floor. Do not put a rug, a floor or a ground plane in anything's
  "occludedBy": a prop stands on those, not behind them.
- A region only works as a hiding place if it reaches behind what covers it.
  The runtime hides a prop's feet, so the covering thing's rect has to start
  above the covered prop's bottom edge and run below it. A floor region that
  stops where the crate in front of it begins can never tuck anything behind
  that crate, however carefully "occludedBy" is filled in. So give the ground
  behind each foreground object a region that runs down past that object's top
  edge, and say what it is behind.
- "contrast" must be honest and must vary, because it is read at runtime to
  decide where a prop of a given tone hides best, and a room where every region
  says "medium" switches that off. Say "dark" for deep timber, shaded foliage
  and strong-coloured rugs, "light" for pale walls and sunlit floor.
- "clutter" must be honest: this artwork is lived in rather than sparse, so
  shelves and decor pockets are often medium, while the open surfaces a prop
  rests on - rug, table top, floor - stay low.""",
    "dense": """This level is the dense variant of a scene, played by children aged
eight to twelve. The authored scene is drawn sparse for the younger bands; this
backdrop is the busy one, and the meta has to describe what makes it busy.

- "placementRules" must set minSeparation to about 0.06, edgeMargin to about 0.04
  and maxPerRegion to 3.
- "sizeRange" floors must be lower than a young scene's, because the older bands
  are drawn smaller: start regions around 0.03 to 0.045 and cap them near 0.11.
  The floor is what actually binds - a region that starts at 0.06 hands the
  oldest band the same sprite the middle band gets, however small it asks for,
  and one that starts at 0.075 is a region no prop in this variant is wide
  enough to use at all. That holds for the near foreground too: give the rug,
  the crate and the couch arm the same low floor as the shelves, or the whole
  front of the room drops out of the game.
- "occludedBy" is the point of this backdrop and must be filled in properly. Walk
  the near foreground - the tall grass, bushes, crates, railings, cushions and
  consoles drawn along the bottom of the frame, and anything else standing in
  front of something else - give each its own region, and list it in the
  "occludedBy" of every region it stands in front of. A prop is only ever hidden
  behind a thing whose top edge is below the prop's top and whose bottom edge is
  at or below the prop's, so what matters is upright things in the near
  foreground, not flat things on the floor. Do not put a rug, a floor or a
  ground plane in anything's "occludedBy": a prop stands on those, not behind
  them.
- A region only works as a hiding place if it reaches behind what covers it:
  the covering thing's rect has to start above the covered prop's bottom edge
  and run below it. A rug that stops where the crate in front of it begins can
  never tuck anything behind that crate, however carefully "occludedBy" is
  filled in. Give the ground behind each foreground object its own region,
  running down past that object's top edge, and say what it is behind.
- "contrast" must be honest and must vary. It is read at runtime to decide where
  a prop of a given tone hides best, and a room where every region says "medium"
  switches that off. Say "dark" for shaded foliage, dark timber and navy
  panelling, "light" for pale walls, bright lawn and sunlit floor.
- "clutter" must be honest too. This artwork is deliberately busy, so plenty of
  regions really are medium or high.""",
    "adult": "",
}

META_PROMPT = """Read these three files, in this order:

1. docs/scene-meta.md - the schema you are writing.
2. {example} - a complete, hand-checked meta file for another scene.
3. {image} - the backdrop you are describing. Look at it closely.

Write the meta file for {image}, as one JSON object with exactly the fields
the schema doc lists, following the example's style and level of detail.

Rules:

- "sceneId" must be exactly "{scene_id}", "image" exactly "{output_image}".
- Normalized [0,1] coordinates, (0,0) top-left, rects are [x0,y0,x1,y1].
- Walk the picture back to front and add a region wherever a prop could
  plausibly rest, hang, lean, tuck, or sit inside something. Cover the whole
  room, not just the obvious surfaces: {region_target} regions is a good scene.
- "scale" must grow steadily from far to near regions, because the same prop
  is drawn larger when it is closer to the camera.
- A region with no "restLine" and a "kind" other than surface is a region
  nothing can be put in: resting, lying and leaning need ground, and tucking
  needs ground or a polygon, so a hedge, a flower bed or a fringe of grass
  written as "kind": "structure" with no rest line drops out of the game
  entirely. Give every bed, tuft, hedge and shelf a rest line, and keep
  "structure" for things a prop genuinely cannot sit in.
- Every region whose "supports" includes rests_on, lies_flat or leans_against
  needs a "restLine": the y where a prop's bottom edge actually lands, which is
  the visible top edge of that surface and not the middle of its rect. Use a
  single number for a flat lid or shelf, or a polyline of [x, y] points for a
  surface that curves or runs uphill in perspective, like a hammock sag or a
  desk seen at an angle. Add "restTolerance" (default 0.02) when the surface has
  real depth, so a deep table accepts props near its back and front edges alike.
- Add a "polygon" of [x, y] points to any region whose rect swallows a lot that
  is not the region: a crate stack seen at an angle, a hammock, a shelf that
  ends halfway across its box. The rect stays, the polygon is the real outline,
  and a prop dropped in the leftover corner of a rect is exactly how a level
  ends up with something hovering in mid-air.
- Ground planes are the exception: a floor or a rug gets no "restLine", because
  there a prop's y is its distance from the camera rather than a height.
- Mark "noGo" for bright openings, focal artwork and the frame edge, each with
  a reason.
- Every rect must hug the thing it names. Read the coordinates off the picture
  rather than estimating from the description: a rect a tenth of the frame off
  its furniture puts props in mid-air, and the same drift in a "restLine" hangs
  them above the surface they are meant to be standing on.
- Notes are for what the numbers cannot say: what already hides there, what
  would look pasted on, which sprite colours vanish against it.

{audience}

Reply with only the JSON object."""


def sheet_grid(path, theme):
    print(f"reading {path}", file=sys.stderr)
    spec = ask_json(SHEET_PROMPT.format(path=path, theme=theme))
    cols, rows = int(spec["cols"]), int(spec["rows"])
    props = spec["props"]
    if len(props) != cols * rows:
        raise VisionError(
            f"{path}: {cols}x{rows} grid but {len(props)} props named"
        )
    return cols, rows, props


def meta_problems(meta, scene_id):
    """Structural checks, so a malformed meta never reaches stage 2."""
    problems = []
    if meta.get("sceneId") != scene_id:
        problems.append(f'"sceneId" must be "{scene_id}"')
    for key in ("summary", "lighting", "regions", "noGo", "placementRules"):
        if key not in meta:
            problems.append(f'missing "{key}"')
    regions = meta.get("regions", [])
    if len(regions) < 8:
        problems.append(f"only {len(regions)} regions; the room needs more")
    seen = set()
    for region in regions:
        rid = region.get("id", "?")
        for key in ("id", "name", "kind", "rect", "depth", "orientation",
                    "scale", "sizeRange", "clutter", "contrast", "supports"):
            if key not in region:
                problems.append(f'region "{rid}" missing "{key}"')
        if rid in seen:
            problems.append(f'duplicate region id "{rid}"')
        seen.add(rid)
        rect = region.get("rect")
        if isinstance(rect, list) and len(rect) == 4:
            x0, y0, x1, y1 = rect
            if not (0 <= x0 < x1 <= 1 and 0 <= y0 < y1 <= 1):
                problems.append(f'region "{rid}" rect {rect} is not a valid box')
        else:
            problems.append(f'region "{rid}" rect must be [x0,y0,x1,y1]')
    for zone in meta.get("noGo", []):
        if "rect" not in zone or "reason" not in zone:
            problems.append(f'noGo "{zone.get("id", "?")}" needs rect + reason')
    return problems


def level_name(scene_id, variant):
    """The name a variant has to carry: the base spec's, where there is one."""
    if not variant:
        return None
    base = SCENES / f"{scene_id}.build.json"
    if not base.exists():
        return None
    return json.loads(base.read_text()).get("name")


def analyze(scene_id, bg, sheets, name, theme, force, audience, variant=None):
    # A variant is a second backdrop for the same level, described separately
    # and built beside the original: tools/scenes/<id>.dense.meta.json.
    dotted = f".{variant}" if variant else ""
    suffix = f"_{variant}" if variant else ""
    meta_path = SCENES / f"{scene_id}{dotted}.meta.json"
    build_path = SCENES / f"{scene_id}{dotted}.build.json"
    for path in (meta_path, build_path):
        if path.exists() and not force:
            sys.exit(f"{path.relative_to(ROOT)} exists; pass --force to redo it")

    with Image.open(ROOT / bg) as image:
        width, height = image.size
    level_dir = f"assets/levels/{scene_id}"
    output_image = f"{level_dir}/background{suffix}.jpg"

    described = []
    for sheet in sheets:
        cols, rows, props = sheet_grid(sheet, theme)
        described.append({"source": sheet, "cols": cols, "rows": rows,
                          "props": props})

    print(f"reading {bg}", file=sys.stderr)
    prompt = META_PROMPT.format(
        example=EXAMPLE,
        image=bg,
        scene_id=scene_id,
        output_image=output_image,
        region_target="20 to 30",
        audience=AUDIENCE[audience],
    )
    meta = ask_json(prompt)
    problems = meta_problems(meta, scene_id)
    if problems:
        print(f"  meta had {len(problems)} problems, asking again",
              file=sys.stderr)
        listed = "\n".join(f"- {p}" for p in problems)
        meta = ask_json(
            f"{prompt}\n\nYour previous meta file had these problems, fix all "
            f"of them and keep everything else:\n{listed}\n\nHere it "
            f"was:\n{json.dumps(meta)[:12000]}"
        )
        problems = meta_problems(meta, scene_id)

    meta["image"] = output_image
    meta_path.write_text(json.dumps(meta, indent=2) + "\n")

    spec = {
        "sceneId": scene_id,
        **({"variant": variant} if variant else {}),
        # A variant is the same level under a different backdrop, so it
        # answers to the level's name. Falling back to the scene id here is
        # how a card reading "Captain's Cabin" opened a level titled "Pirate
        # Cabin" for the two oldest bands.
        "name": (name or level_name(scene_id, variant) or meta.get("name")
                 or scene_id.replace("_", " ").title()),
        "sceneSize": {"w": width, "h": height},
        "levelDir": level_dir,
        "background": {
            "source": bg,
            "maxWidth": min(width, BACKDROP_MAX_WIDTH),
            "quality": BACKDROP_QUALITY,
        },
        "meta": f"tools/scenes/{scene_id}{dotted}.meta.json",
        "sheets": [
            {
                "source": sheet["source"],
                "cols": sheet["cols"],
                "rows": sheet["rows"],
                "names": [p["id"] for p in sheet["props"]],
            }
            for sheet in described
        ],
        # Stage 2 sets the rules for these; the shape notes are what it
        # argues from. The game places them itself, per playthrough.
        "props": [
            prop
            for sheet in described
            for prop in sheet["props"]
        ],
    }
    build_path.write_text(json.dumps(spec, indent=2) + "\n")

    print(f"{meta_path.relative_to(ROOT)}: "
          f"{len(meta.get('regions', []))} regions, "
          f"{len(meta.get('noGo', []))} no-go zones")
    for problem in problems:
        print(f"  warning: {problem}")
    print(f"{build_path.relative_to(ROOT)}: "
          f"{len(spec['props'])} props, none placed yet")
    tail = f" --variant {variant}" if variant else ""
    print(f"review both files, then: tools/scene.sh place {scene_id}{tail}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--bg", required=True, help="backdrop jpeg")
    parser.add_argument("--sheets", required=True, nargs="+",
                        help="sprite sheet jpegs")
    parser.add_argument("--name", help="player-facing scene name")
    parser.add_argument("--theme", default="",
                        help="theme hint for naming props, e.g. pirate")
    parser.add_argument("--audience", default="kids", choices=sorted(AUDIENCE),
                        help="who the level is for; kids means ages 5-7, "
                             "dense means the 8-12 variant of one")
    parser.add_argument("--variant",
                        help="name a second backdrop for this level, e.g. "
                             "dense; writes <id>.<variant>.meta.json")
    parser.add_argument("--force", action="store_true",
                        help="overwrite existing meta and build files")
    args = parser.parse_args()
    analyze(args.scene_id, args.bg, args.sheets, args.name, args.theme,
            args.force, args.audience, args.variant)


if __name__ == "__main__":
    main()
