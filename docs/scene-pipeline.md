# Scene pipeline

Raw jpegs in, playable level out.

```bash
tools/scene.sh analyze pirate_cabin --bg rawimages/pirate_bg.jpeg \
    --sheets rawimages/pirate_6_sprite_1.jpeg rawimages/pirate_6_sprite_2.jpeg \
    --theme pirate --name "Captain's Cabin"
tools/scene.sh place   pirate_cabin --difficulty medium
tools/scene.sh build   pirate_cabin
tools/scene.sh preview pirate_cabin --seed 7 --outlines
```

The first run creates `.venv` and installs Pillow; after that the wrapper just dispatches.
`tools/scene.sh all <id> --bg ... --sheets ...` runs every stage back to back, which is useful once a scene's art is known good and you are only re-running it.

## Inputs

Two kinds of raw art in `rawimages/`, at any resolution:

- One backdrop jpeg, the room itself, with no findable props composited into it.
- One or more sprite sheet jpegs, a grid of props on a plain near-white background, one prop per cell.

Nothing else is needed.
Grid size, prop names and player-facing labels are read off the sheets, not configured.

## Stage 1: analyze

Looks at the sheets and the backdrop, and writes two files:

- `tools/scenes/<id>.meta.json`, the description of the room: regions, depth, lighting, rest lines, no-go zones and placement rules ([schema](scene-meta.md)).
- `tools/scenes/<id>.build.json`, the build spec, with the sheets described and `props` listed but not yet ruled on.

The meta file is checked for structural problems before it is written, and a malformed one is sent back once with the list of faults.

**Review it before going on.**
Every later decision is argued against this file, so a region in the wrong place produces a prop in the wrong place, three stages later and much harder to see.
Skim the region list against the picture and fix anything obviously wrong by hand.

## Stage 1b: fit

`tools/scene.sh fit <id> [--variant dense]` checks the meta file against the pixels of the backdrop it describes, which is the one thing stage 1 cannot do for itself.

A meta file is written by eye, and eyes are wrong by a few percent.
A few percent is the difference between a prop standing on the shelf and a prop hanging in the air above it, which is the loudest way a find stops looking like part of the picture.
The numbers in a meta cannot be checked against each other - they are all self-consistent - so they are checked against the art:

- every rest line is expected to have surface under it, at each of seven points across the region.
  `=` is a reading with clear air over the surface, `~` one where the backdrop already stands something there, and `!` one with nothing under the prop's feet at all.
- a region that is not a floor is expected to have something inside its box.
  A box of unbroken wall colour describes nothing.
- a box that reaches past the end of the surface it names is reported, because a prop only has to have its middle over the region to be placed there.

Three flags:

- `--snap` applies what a fitter may safely decide: a rest line moved onto the surface under it, up to four percent of the picture, and a box trimmed to the width that actually has surface.
  Bigger corrections are reported and left alone - a rest line a whole shelf tier out is a misreading rather than a drift, and guessing which tier was meant is how a fitter puts the crate inside the shelf.
- `--spans` writes `freeSpans`, the gaps the backdrop left on each surface ([schema](scene-meta.md#room-on-a-surface)).
- `--check` exits non-zero when any region still does not match, so a build can gate on it.

Run `fit`, then `fit --snap`, then read what is left and correct it by hand against a grid overlay (`tools/scene.sh regions <id> --grid 20`), then `fit --spans`.

## The other shape: a baked scene

Everything above composites: the level ships cut-out sprites and the game puts them somewhere new each playthrough.
A baked scene trades that away for the thing compositing cannot buy.
The illustrator draws the finds into the room - same pen, same palette, same shadows, several of them half behind something - and the level ships that picture with no sprites over it at all.
Nothing in it can be peeled off the backdrop by eye, because it *is* the backdrop.

```bash
tools/scene.sh art  docs/imgenprompts/<level>.md --only "Baked scene" \
                    --from rawimages/<level>/dense_backdrop.jpeg --force
tools/scene.sh bake <id> --variant dense \
                    --plate rawimages/<level>/dense_backdrop.jpeg
```

The `--from` is what makes the rest work.
The model is handed the room and asked to add the finds to it, so the room it was handed is a **clean plate**: the same picture, pixel for pixel, without the finds.
Three things follow.

1. **The cut-outs need no guessing.** The difference between plate and picture is the finds and nothing else, so each one is masked to the pixel - no flood fills, no deciding where a drawing ends and the shelf behind it begins, because the shelf did not change.
2. **A find can leave the picture.** The plate cut at a find's place is a patch of room; painted back over the find when a player taps it, the object is gone and what was behind it is exactly right. Without a plate a drawn find can only be circled, which is the fallback and reads as second best.
3. **A find can be measured rather than guessed at**, which is what lets the two readings below be rejected instead of shipped.

The object list's icons do not come from the picture at all: they are cut from the sprite sheets, one per kind, whole and upright on nothing.
The bar states what is being looked for, and this picture's copy of it is half behind a barrel with the barrel's corner in the crop - that is the puzzle, and putting it in the bar gives it away while looking like a mistake.
So a level ships `baked/chip_<kind>.png` once and every picture of it points at the same file.

`bake` still asks a vision model where each find is, cached in `tools/scenes/<id>[.variant].baked.json`, but only to name the blobs: the box has to overlap the right one, not to measure it.
It prints what it found, flags anything missing or too small to tap, and says how many changed patches no find claimed - the model touches up a fitting here and there while it draws, and a high count means the plate and the picture have drifted apart.
A find drawn twice is kept as two copies rather than treated as a fault; the game already knows how to ask for two of a thing.

### What is not shipped

A find may be cut off by the shelf in front of it - that is the whole point of hiding one - and it may not be cut off by anything else. Three readings are dropped rather than written, each printed with its reason:

- **Cut by the trim.** The blob is trimmed to the sighting so a reading that ran into a fitting does not hand the find a tap target the size of the bench beside it, and a rectangle laid over a drawing cuts it in a straight line. The two are told apart exactly: paint that stops at the barrel stops because the picture stops it, while paint that carries on immediately past the trim was severed by it. The window widens until it stops cutting, and a widening that runs past `MAX_SIZE` has left the object, so the find goes.
- **Cut by the frame.** A find whose own pixels run along the edge of the canvas was drawn running off it, and nothing in the room is doing the covering - it is simply half a coin. Dropping it takes it out of the picture entirely, which the plate makes free.
- **Nothing left to see.** A find behind the woodpile can be a legal box and two slivers of paint. `MIN_VISIBLE` is the floor on how much of the picture it actually colours in; `MIN_FILL` is a loose guard on the degenerate reading, loose because a wand, a balloon on its string and a butterfly are all mostly empty box by nature.

Each drop costs the picture a find, and `maxObjects` is the least any picture in the pool holds, so a heavy-handed floor here shows up as a smaller number on the level card.

### Why the plate ships instead of the picture

Four pictures per band per level is thirty-two full backdrops, and they are
mostly the same room over and over.
Shipping the plate once and stamping the finds back is the same artwork at the
same resolution for a third of the weight: **58MB of level assets became 12MB**
- plates, stamps and one icon per kind - with nothing downscaled. (It was 16MB
while every stamp carried a chip of its own.)

Two thirds of that saving is the palette. The art is flat cel colour, so a
couple of hundred of them hold a whole drawing; what makes a stamp big as a
truecolour PNG is the jpeg noise it was cut from, and quantising throws exactly
that away. The cabin's octopus went from 351KB to 47KB, six parts in a thousand
different where the drawing is opaque.

### Where the randomness comes from

One picture is one layout, so a baked level that shipped a single picture would be the same hunt every time.
Two things put the variety back, and they multiply.

- **A pool.** `--takes N` draws the same prompt N times, `--take i` bakes each, and the level ships `scene.<variant>.<i>.json` with `scenes: N` in the manifest. Which picture a game opens is the playthrough's seed modulo the pool.
- **More drawn than asked for.** A picture holds every find it will ever hold - the station's hunt pictures hold about nineteen - and a game asks for what the band wants: `--asked` writes that into the manifest, the band scales it, and `GameScene.asked` picks that many by seed. Everything drawn and not asked for stays in the room as a decoy, which is exactly what it looks like.

So the ask changes even when the picture repeats, and the picture changes every fourth game or so.
`maxObjects` is the least any one picture in the pool holds, because the level card promises a count before it knows which picture the player will be handed.

What a baked scene still gives up:

- **the placer's difficulty knobs.** Sizes, spacing, cover and camouflage are the illustrator's now. What is left to the band is which picture, how many finds are asked for, how solidly they are drawn ([`blendOpacity`](../lib/models/difficulty.dart)), the hints and the clock.
- **art per band.** Two densities means two plates and two pools: a busy room with hand-sized finds for Peek and Look, a packed one with much smaller finds for Seek and Hunt.

All four levels are baked, both bands: eight pictures each, from two plates.
Nothing in `assets/levels/` is composited any more, so a level folder is two plates, the stamps, one icon per kind and the scene files - no sprite sheets and no metas.
`tools/scene.sh build` refuses to overwrite a baked scene, because doing so would composite every find a second time on top of the picture that already holds it.

## Stage 2: place

Reads the meta file, the backdrop and the sheets, then places every prop.
Each placement names the region it belongs to, how it meets that region (`rests_on`, `hangs_on`, `tucked_in`, `inside`, and so on), a point, a width and a rotation, plus one sentence of reasoning that is printed and then discarded.

The proposal is run through the same validator `build` uses, and anything it flags is sent back for another attempt, twice by default.
`--difficulty easy|medium|hard` steers the choice between open regions and camouflaged ones.

**Review the placements before going on**, most easily as a preview image after stage 3.

## Stage 3: build

`tools/build_scene.py`: slices the sheets, strips the near-white background to alpha, and writes the whole level folder.

```
assets/levels/<id>/
  scene.json        the level, with a convex-hull tap polygon per sprite
  background.jpg    the downscaled backdrop
  sprites/*.png     one per findable object
```

Paths inside `scene.json` are relative to that folder (`background.jpg`, `sprites/hook.png`), so a level can be moved, renamed or handed over whole.
The build then registers the level in `assets/levels/levels.json`, the catalog the app's level list reads, and adds the folder's two lines to `pubspec.yaml` - Flutter never bundles directories recursively, so an unlisted level builds cleanly and then fails to load.
An existing level keeps its place in the catalog; a new one lands at the end, which is play order.
Reorder or rename by editing `levels.json` directly.

It re-validates the placements against the meta and prints anything that disagrees.

## Stage 4: preview

Composites the built scene into `tools/scenes/<id>.preview.png` exactly the way `scene_view.dart` draws it, so placements can be judged by eye rather than by coordinate.
`--outlines` draws the tap polygons, which is how a bad alpha cut shows itself; `--labels` names each prop.

This is where floating props are caught.
The validator can prove that a lantern is inside the barrel region at a legal size; only the picture shows that it is hovering two inches above the lid.

## A worked example

`docs/examples/pipeline-output.meta.json` and `pipeline-output.build.json` are the unedited output of stages 1 and 2 on the pirate cabin backdrop: 32 regions and 12 placed props, written without a human touching either file.
They are there to show what to expect from a clean run, and what a plausible-but-wrong region looks like when you review one.

## What is checked, and where

At build time, per prop, against the meta:

- Every named region exists, and every `place` is a real placement kind.
- Some region can hold the prop: it supports one of the prop's `places` for real (see the table above), and its `sizeRange` overlaps the prop's `width`.
- Enough regions can, that the prop does not land in much the same spot every game.
- `objectCount` is between the copies the props require and the copies they allow.

At placement time, per object, every game:

- The centre falls inside a region, and inside its outline when it has a `polygon`.
- The width is inside both the prop's range and the region's.
- A prop that stands on something has its bottom edge on the region's rest line, accounting for rotation.
- Nothing lands in a `noGo` zone or straddles the edge margin.
- No region is over-filled, no two objects are closer than `minSeparation`, and no two sprites overlap.

Build warnings never block the build.
A deliberate exception costs nothing; an accidental one is visible.
Placement rules are not warnings - the placer simply will not produce a layout that breaks one, and `test/placement_test.dart` holds it to that over forty seeds of the real cabin.

## Cost and time

The vision steps shell out to the `claude` CLI already installed on the machine, so the pipeline needs no API key of its own and bills through the existing subscription.
A full scene is three vision calls: one per sprite sheet and one for the room, plus one for placement.
In practice that is a few dollars and about ten minutes, most of it the room analysis.

Everything the model returns is data, and every file is written by the pipeline itself.
The CLI runs with the Read tool and nothing else, in a fresh session with no MCP servers, plugins or settings loaded.

## When something is wrong

| Symptom | Fix |
| --- | --- |
| Props hover or sink | The region's `restLine` is wrong; correct it in the meta and re-run `build`. |
| A prop sits on empty air inside a legal rect | Give that region a `polygon`, or drop the `supports` it cannot honour. |
| A prop is drawn over furniture that stands in front of the region | Add a `noGo` for what is in front. |
| A prop is comically large or small | The region's `scale` or `sizeRange` does not match its depth. |
| Sprite has a white halo or a chewed edge | The sheet background is not near-white enough; raise `WHITE` in `build_scene.py` or clean the sheet. |
| Everything clusters in one half | Tighten `placementRules`, especially `maxPerRegion`. |
| The level places fewer objects than it hides | Some prop has nowhere legal to go. Usually it is restricted to a few narrow regions, or its `width` is wide enough to fill a whole surface. Widen the prop, not the rules: the toy room's kite could only hang on two curtains and two castle corners, and one seed in twelve shipped eleven objects because of it. `test/level_test.dart` catches this. |
| A prop turns up in the same two places every game | Widen its `width` range or clear its `regions` list, so more of the room can hold it. The build warns about this. |
| The level hides fewer objects than it should | Some prop has nowhere to go; the build says which. |
