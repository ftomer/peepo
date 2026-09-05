# Scene meta files

Every background image gets a meta file next to its build spec: `tools/scenes/<scene>.meta.json`.
It is written by stage 1 of the scene pipeline and reviewed by hand: see [scene-pipeline.md](scene-pipeline.md).

The backdrop is a flat picture, so nothing in the pipeline knows that a desk is a desk, that the window is bright sky, or that the barrels in the corner are twice as close to the camera as the ones behind the desk.
The meta file is that missing knowledge, written once per background and reused by everything that has to decide where a hidden object goes.

It is runtime data.
The build copies it into the level folder as `assets/levels/<scene>/meta.json`, next to the `scene.json` catalog, because the game hides the level itself: props are placed when the level is played, against this description of the room.
`tools/scenes/<scene>.meta.json` stays the editable original - fix things there and re-run the build.

## What it is for

- Choosing placements that read as real: a spyglass lies on the chart, a doubloon goes in the gold pile, a hat sits on the bunk.
- Sizing sprites for depth, so a prop on the foreground barrels is bigger than the same prop on the far wall.
- Keeping props off bright openings and off the vignetted frame edge.
- Steering difficulty, by moving a find between a cluttered region and an empty one instead of shrinking it until it is unfair.
- Placing the props, every time the level is played: `lib/game/placement.dart` reads this file and nothing else about the room.
- Checking the level before it ships: `tools/build_scene.py` warns about a prop no region can hold, which would otherwise be missing from the game with no error anywhere.

## Coordinates

All rectangles and points are normalized to `[0, 1]`, with `(0, 0)` at the top-left of the backdrop, matching `scene.dart`.
Rectangles are `[x0, y0, x1, y1]`.
A region may add an optional `polygon` (list of `[x, y]` points) when its bounding box is far too generous, and placements then have to fall inside that outline rather than merely inside the box.
The `rect` stays required either way, and is still the fast first test.

The outline is not decoration on a region whose box is mostly air - a ship's wheel, a hanging net, a chandelier.
Without one, the placer will not hang or tuck anything there at all, because it has no way to tell the thing from the wall behind it.

## Top-level fields

| Field | Meaning |
| --- | --- |
| `sceneId` | Must match the `sceneId` in the build spec. |
| `image` | The backdrop asset the description refers to. |
| `summary` | One paragraph a person or a model can read to picture the room. |
| `theme` | Prop vocabulary that belongs in this room, for example `pirate`. |
| `camera` | Viewpoint and perspective, which is what makes depth and scale legible. |
| `lighting` | `ambient`, `keySources` (id, position, colour, strength), `shadowDirection` as a normalized `[dx, dy]`, and notes on how sprites must be shaded to sit in the scene. |
| `palette` | `dominant` and `accent` colours plus notes on which sprite colours camouflage and which pop. |
| `focalPoints` | Places the eye lands first, useful for spreading finds away from them. |
| `viewport` | How the scene is fitted on screen, which decides how much of it a player sees at rest. |
| `placementRules` | `minSeparation`, `edgeMargin`, `maxPerRegion` and free-form notes. |
| `regions` | The parts of the room a prop can interact with. |
| `noGo` | Areas nothing may be placed on, each with a reason. |

## Regions

A region is one addressable place in the room.

| Field | Meaning |
| --- | --- |
| `id` | Stable slug, referenced by the `region` field of a build-spec placement. |
| `name` | Human label. |
| `kind` | `surface`, `wall`, `container`, `prop`, `opening` or `structure`. |
| `rect` | Bounding box in normalized coordinates. |
| `depth` | `near`, `mid` or `far`, which is the perspective band the region sits in. |
| `orientation` | `horizontal`, `vertical`, `angled` or `hanging`. |
| `scale` | Normalized width a hand-sized object (roughly 20 cm) should have here. |
| `sizeRange` | Minimum and maximum sprite width that looks right here; `[0, 0]` means the region holds nothing. |
| `clutter` | `low`, `medium` or `high`, which is how much the art already hides. |
| `contrast` | Tone of the backdrop there - `light`, `medium` or `dark` - which decides whether a light or dark sprite disappears. Read at runtime: see [Camouflage](#camouflage). |
| `supports` | Placement kinds the region accepts: `rests_on`, `lies_flat`, `hangs_on`, `pinned_to`, `leans_against`, `tucked_in`, `inside`. |
| `restLine` | Where a prop's bottom edge lands inside the region, as a single `y` or a polyline of `[x, y]` points. |
| `restTolerance` | How far a footprint may miss the rest line, default `0.02`. |
| `freeSpans` | Stretches of the rest line the backdrop left empty, as `[[x0, x1], ...]`. Measured off the art by `tools/scene.sh fit --spans`, never written by hand. Read at runtime: see [Room on a surface](#room-on-a-surface). |
| `occludedBy` | Regions drawn in front of this one, so a prop placed here may be partly covered. Read at runtime: see [Cover](#cover). |
| `notes` | Anything the numbers cannot say. |

A region with no `restLine` whose `kind` is not `surface` holds nothing at all: footed placements need ground, hanging needs something solid, and tucking needs one or the other.
That is easy to author by accident - the rainbow meadow's dense hedge, cattails, fence and foreground fringe all came back as `structure` with no rest line, which took a third of the room out of play and left the Seek band a find short on some seeds.

### Rest lines

A `rect` is a bounding box, and most of a hammock's box is air.
`restLine` is the line inside it that props actually stand on, which is what makes the difference between a lantern sitting on the barrel and a lantern hovering over it.

Use a single number for a flat lid or shelf.
Use a polyline for a surface that curves or recedes, like a hammock sag: `[[0.46, 0.5], [0.63, 0.555], [0.72, 0.52]]`, interpolated in `x` and clamped past the ends.
Raise `restTolerance` for a surface with real depth, because a table seen at an angle accepts props anywhere between its back and front edge.

Ground planes are the exception and carry no `restLine` at all.
On a floor or a rug, a prop's `y` is how far back it stands, not how high it is, so there is no single line to meet.

The validator only checks the footprint for placements that rest, lie flat or lean, and it accounts for `rot`, since a dagger laid at 45 degrees reaches lower than its upright height suggests.

## Room on a surface

A lived-in room draws its own things on its own surfaces: the shelf board already holds three crates, the console top a joystick and a button pad.
A find dropped on the taken part of that surface is drawn over the top of the art, and reads as a sticker however honestly it is grounded.

`freeSpans` is where the surface is still empty, read off the backdrop rather than guessed: `tools/scene.sh fit --spans` walks the rest line and keeps the stretches with clear air over them.
The placer picks one of those stretches, weighted by width, and puts the prop's middle inside it, so a find arrives where the picture had room for it.

The test is deliberately a thin band just over the line, because a cartoon backdrop has no depth to read: what the room stands *on* this surface has its outline touching this line, while the shelf across the room and the crates behind the table sit at their own heights and never touch it.

A region with no `freeSpans` at all is one the reading could not split - a shelf packed end to end, or a surface whose own drawn texture reads as clutter - and there the whole width is used, as it was before any of this was measured.

## Cover

`occludedBy` names the regions drawn in front of this one.
The placer reads it, and where the older age bands play, part of a prop put here is not drawn: the backdrop already holds the thing doing the covering, so covering a prop is a matter of leaving out the part of it that falls behind.

What is not drawn is not tappable either, and the tap tolerance around it goes with it - a target a player cannot see is not a target.

Three things follow for the person authoring the file.

**The cut is always horizontal and always keeps the top.**
In a scene drawn from eye level, going behind something means your feet disappear first: a prop tucked behind a hedge has lost its bottom and kept its head.
So the occluder has to be genuinely in front of the prop - its top edge below the prop's top, its bottom edge at or below the prop's - and anything else is not occlusion, it is the prop standing on the thing.
That test is what a rug fails: a duck on the floorboards beside the toy room's rug is next to it, not behind it, and slicing the duck down the middle to prove otherwise reads as broken art rather than as something half hidden.

**Only one occluder applies**, the one covering most of that spot.
A floor's `occludedBy` lists everything in the room drawn in front of any part of it - nine regions, in the toy room - and taking them in turn whittles the visible part to nothing and has the placer refuse the floor altogether.
What a prop is actually behind is one thing: the chair it is under, not the chair and the shelf and the castle as well.

**Nothing here may cost a find.**
A prop that cannot be tucked in far enough is drawn whole rather than turned away, which is what the game did before it could hide anything behind anything.

**The region behind the foreground has to reach behind it.**
Cover is decided between two rects, so the covered region has to run down past the covering one's top edge: a prop's box has to reach into the occluder before any of it can be hidden.
A rug that stops where the crate in front of it begins can never tuck anything behind that crate, however carefully its `occludedBy` is filled in.
That is what kept the toy room's dense variant at zero cover even after the art was redrawn with a proper near foreground - the rug ended at `0.80` and the crate started at `0.814`.
The fix is a region for the ground *behind* each foreground object, running down past that object's top edge and naming it in `occludedBy`: `floor_front_strip` in `toy_room.dense.meta.json` is that region, and it carries every tucked-away prop the level has.

A backdrop with no overlapping foreground gives this nothing to describe.
Before the blend-in redesign the rule fired on roughly one placement in five hundred across all four levels and every band, because the backdrops were drawn without a near foreground and the rainbow meadow had no `occludedBy` on any of its twenty regions at all.
With the redrawn toy room - near foreground in the art, a floor strip behind it in the meta - it fires on about one placement in twenty at Seek and Hunt, which is the band that asks for it.
No amount of meta authoring puts a bush in front of a lawn that was drawn empty: a backdrop meant to use this needs a near foreground drawn in front of the surfaces behind it - see [art-direction.md](imgenprompts/art-direction.md#dense-variants).

## Camouflage

`contrast` is the tone of the backdrop in this region.
`tools/build_scene.py` measures the matching figure for every sprite off its own opaque pixels and writes it into `scene.json` as `tone`, so the two are comparable and neither can drift from the art.

The placer weights its region draw by whether the two match: the youngest band prefers a region the prop stands out against, the oldest prefers one it sinks into, and the middle band does not care.
It is a weight and never a filter - at most it halves or half-again a region's chance - because a level whose props all share a tone would otherwise run out of places to put them.

A room that is all one `contrast` gives this nothing to choose between.

## Variants

A level may ship a second backdrop for the older bands, denser than the one it was authored with, and it gets a meta file of its own: `tools/scenes/<id>.dense.meta.json`, built into `assets/levels/<id>/meta.dense.json`.

Region ids need not match across variants.
Each variant ships its own `scene.dense.json` carrying its own per-prop region lists, so the two rooms are described independently and a region that exists in one and not the other is not a problem.

## Using it in a build spec

The build spec points at the meta file and tags each placement with the region it is meant to sit in.

```json
"meta": "tools/scenes/pirate_cabin.meta.json",
"objectCount": 14,
"props": [
  { "id": "spyglass", "label": "Spyglass", "places": ["rests_on", "lies_flat", "tucked_in"], "regions": [], "width": [0.05, 0.085], "rotate": [-15, 15], "copies": [1, 1] }
]
```

`regions` is optional, and usually best left empty: the more of the room a prop can use, the less predictable the game is.

`places` is how the prop can meet a region: `rests_on`, `lies_flat`, `hangs_on`, `pinned_to`, `leans_against`, `tucked_in` or `inside`.
A region has to support one of them for real before it can hold the prop, which is a narrower thing than appearing in its `supports` - see the table in [scene-pipeline.md](scene-pipeline.md#what-is-checked-and-where).

Running the build prints any disagreement and still writes the level:

```
assets/levels/pirate_cabin/scene.json: 14 objects
  warning: tricorn_hat: only 2 region(s) can hold it (bunk_bed, rug), so it
           lands in much the same spot every game
```

## Authoring a meta file for a new background

1. Write `summary`, `camera` and `lighting` first, because every later judgement about scale and shading follows from them.
2. Walk the image from back to front and add a region wherever a prop could plausibly rest, hang, lean, tuck or sit inside something.
3. Set `depth` per region, then set `scale` so the same real-world object grows steadily from `far` to `near`.
4. Give every resting surface a `restLine` read off the artwork, and leave ground planes without one. A surface at two heights - a cupboard with three shelves - is two or three regions, not one: a region has one rest line, and a prop put on the average of three shelves stands on none of them.
5. Outline anything whose box is mostly air, and drop `supports` a region cannot honour. A region that says nothing can go there (`sizeRange: [0, 0]`, `supports: []`) is a perfectly good answer for beams, glass and polished spheres.
6. Mark `noGo` for bright openings, focal art, the vignetted frame edge, and anything drawn in front of a region - a desk's front panel stands over the floor behind it.
7. Fill in `viewport`, because `SceneView` fits the backdrop cover-style and pans the overflow, so a scene whose finds all sit on one side is unplayable on a phone before the first drag.
8. Rule on the props in the build spec, run the build, then look at three or four seeds with `tools/scene.sh preview <id> --seed N` and fix what the pictures show.
