# Blend-in art redesign - handoff

Status note for the session continuing this work.
Written 2026-08-25 by the session that started the redesign.

## The task

User request: objects are too easy to find at every age band, and sprites look pasted on top of the backdrop.
Redesign the level art so finds look like part of the picture, the way a printed hidden object page reads (reference: a stock "find 10 hidden objects" cartoon where every object sits inside the scene).
Not a style change - an integration change.

## Diagnosis (verified against the shipped art)

1. Sprites came back glossy sticker-style (airbrush shading, specular highlights) while backdrops are flat cel with thin-to-thick uniform outlines. The mismatch is the single biggest tell.
2. Base backdrops were authored deliberately sparse ("half adult density", art-direction.md). A sprite on a bare surface is the only loose object in sight.
3. The renderer draws sprites with zero integration: no contact shadow, nothing. `meta.json` lighting notes even ask for a soft ground shadow; the renderer ignored them.
4. Backdrops have almost no near-foreground, so the occlusion axis ~never fires (~1 placement in 500).
5. The "nothing that looks like a find" prop ban led only the dense prompts, so base backdrops are empty of look-alike clutter.

## Done so far

All uncommitted; nothing pushed.

- `docs/imgenprompts/art-direction.md` - rewritten backdrop rules (lived-in ~2/3 adult density with decor "pockets", near-foreground strip in base backdrops, mild tonal variety, leading prop ban in every backdrop prompt), new sprite-sheet rules (explicit negative list: no airbrush, no gloss, no gradients, no 3D render look, no white sticker rim, same line weight; room-range colours, never neon), new "Belonging" section.
- `docs/imgenprompts/toy-room.md` - backdrop + dense + both sheets + decoy sheet prompts rewritten per the new rules.
- `lib/models/scene.dart` - `SceneObject.place` (String?, from layout placement or scene JSON `place` key) and `SceneObject.grounded` (true for rests_on / lies_flat / leans_against / tucked_in / inside).
- `lib/game/scene_view.dart` - `_SpritePosition` draws a soft contact-shadow ellipse (`_ContactShadowPainter`, blurred oval, `0x30222222`) under grounded sprites: in scene space outside the rotation, inside the occlusion clip, fades with the found animation. Geometry: 8% inset each side, top at 88% of sprite height, height 18%.
- `tools/preview_scene.py` - previews now composite the same contact shadow (`GROUNDED` set + `contact_shadow()`), clipped like the sprite, so previews judge what the player sees.
- `flutter analyze` clean; full `flutter test` passed with these changes (before the asset rebuild below).
- New raw art generated for toy_room via `tools/scene.sh art docs/imgenprompts/toy-room.md --force` into `rawimages/toy_room/` (background, sheet_1, sheet_2, dense_backdrop, decoy_sheet). Visually reviewed: backdrop and dense are exactly the intended lived-in flat style; sheets are flat cel, matched line weight, no sticker gloss (spinning_top and decoy ball keep a mild highlight - acceptable). Decoy sheet has no grid lines.
- NOTE: the new background.jpeg is 2528x1696 (3:2), not 4:3. That is fine ONLY once analyze is rerun, because analyze writes `sceneSize` from the actual image.

## The pipeline, in order

Rerunning a level end to end, checking each stage's output. `analyze` needs `--force` to overwrite an existing meta; `place` and `build` always redo their work, and `build` is what copies the meta into `assets/levels/<id>/`, so a meta edit does nothing until the level is rebuilt.

```bash
tools/scene.sh art     docs/imgenprompts/<level>.md --force      # needs GEMINI_API_KEY
tools/scene.sh analyze <id> --force --bg rawimages/<dir>/background.jpeg \
  --sheets rawimages/<dir>/sheet_1.jpeg rawimages/<dir>/sheet_2.jpeg \
  --theme "<theme>" --name "<Name>"
tools/scene.sh regions <id>                       # audit the rects before placing
tools/scene.sh place   <id>
tools/scene.sh build   <id>
tools/scene.sh analyze <id> --force --variant dense --audience dense \
  --bg rawimages/<dir>/dense_backdrop.jpeg \
  --sheets rawimages/<dir>/sheet_1.jpeg rawimages/<dir>/sheet_2.jpeg rawimages/<dir>/decoy_sheet.jpeg
tools/scene.sh rebase  <id> --variant dense --decoys <id> ...
tools/scene.sh place   <id> --variant dense --difficulty hard
tools/scene.sh build   <id> --variant dense
```

The analyze and place stages shell out to the local `claude` CLI (`tools/claude_json.py`), need no API key, and take about six minutes for a backdrop read and two to four for a placement ruling. Running two of them at once is what produced the `claude_json.VisionError: claude exited 1` in both sessions; it retries cleanly on its own.

## Session 2 progress (2026-08-25, continuing)

Toy room, both variants, is rebuilt and verified. What was wrong and what fixed it:

- Handoff's "background.jpeg is 2528x1696 (3:2)" was wrong: it is 2400x1792, the same 4:3 as the shipped scene. Only the sprite sheets are 2528x1696, which does not matter - the builder cuts them per cell. There was no aspect mismatch, only stale meta.
- `tools/place_objects.py` has no skip guard: it always re-rules and overwrites the build spec. Only `analyze` needs `--force`. `build` is what copies the meta into `assets/levels/<id>/`, so a meta edit does nothing until the level is rebuilt.
- The contact shadow was too faint to read against flat cel art: `0x30222222` at 18% height with a 35% blur was invisible at play size. Now `0x55222222`, 20% height, 6% inset, 28% blur, in both `lib/game/scene_view.dart` and `tools/preview_scene.py`.
- `occludedBy` guidance lived only in the `dense` block of `tools/analyze_scene.py`, so the base meta came back with occluders on one region. Added to the `kids` block, along with an honest-`contrast` rule and a lived-in (not sparse) `clutter` rule.
- The base meta's rects drifted badly for everything centre and right of frame - table, both chairs, rug, tent doorway, chest, sills, shelves - so props stood in mid-air. 18 regions were measured off a percentage grid over the backdrop and corrected, plus: corkboard `supports` cut to `pinned_to` (a standing dinosaur was being tucked into a pinboard), chest rest line moved down into the opening, chair `sizeRange` cut to 0.05-0.075 (a chair seat is 0.08 wide), `floor_right` put behind the crate.
- The dense meta came back much better - real `occludedBy` lists - but 11 regions had rest lines floating above their surfaces, and every near region carried a `sizeRange` floor of 0.075-0.085 while no dense prop is wider than 0.075. The whole near foreground was therefore unusable. Floors lowered, rest lines corrected.
- Even then cover never fired, because cover is decided between two rects: the rug ends at 0.80 and the crate starts at 0.814, so nothing on the rug can ever be behind the crate. Added `floor_front_strip`, a ground region for the floor *behind* the near foreground, naming the crate, the couch arm and the cushion stack in `occludedBy`. Rate went from ~0 to about 1 placement in 20 at Seek and Hunt. The base scene's `floor_left` and `floor_right` were extended down behind the cushions and the crate the same way.
- All three lessons are now in the `analyze` prompts (`tools/analyze_scene.py`) and in [scene-meta.md](scene-meta.md#cover), so the next level's meta should need less hand-correction.
- Dense `objectCount` came back as 13 against the level's 12; `test/level_test.dart` requires a variant to hide the same number. Set to 12 in `tools/scenes/toy_room.dense.build.json`.
- Prop ids: the sheet reader named the xylophone `xylophone`; renamed to `toy_xylophone` in the build spec to match the shipped scene, the docs table and the dense spec.

### Test state

`flutter analyze` is clean. `flutter test` has three failures, none of them from this work:
`game_screen_test`, `age_settings_test` ("changing the age changes what the levels promise") and `level_complete_test` look for copy the parallel difficulty session has removed from `lib/game/level_select_screen.dart` and `lib/game/game_screen.dart` in the working tree ("N objects", "All Levels").
Proven by running those three tests against a HEAD worktree carrying the new `assets/levels/`: all green.
Leave them to the session that owns that UI.

One test was fixed here, because it contradicted the working tree's own placer: `test/placement_test.dart` measured "nothing hangs in mid-air" off the sprite box while the placer now stands props on their silhouette (`_foot`), so a lantern with a hook read as 0.002 above its shelf. The test now measures the drawn shape.

### Sheet art lessons (all three level docs and art-direction.md now carry these)

- Say "do NOT draw the grid" in **every** sheet prompt, not just the decoy ones. The meadow's two find sheets came back ruled into six boxes, which stops `build_scene.py`'s flood cut dead and ships a white block behind every sprite.
- Spell the cast-shadow ban out in full - "NO drop shadow, NO cast shadow, NO shadow ellipse beneath the object". The station's first find sheet drew a grey ellipse under all six props despite "NO cast shadows"; a baked shadow doubles with the renderer's contact shadow.
- Spell the gloss ban out as a paint-bucket instruction. The short negative list still let the meadow's balloon keep a specular highlight and the crystal keep gradients.
- Name the white parts to avoid per sheet: the unicorn came back with a white muzzle and hooves, the ringed planet with a white ring, and the cutter eats near-white.
- The space station's porthole had a ringed planet in it, which is one of the level's own finds; the backdrop ban list has to cover what the scenery is allowed to show through a window.
- The station's first dense backdrop was a different, greyer room. Dense means the same room with more in it, so the dense prompt has to list the base's landmarks explicitly.

### Level status - all four rebuilt

- **toy_room** - base and dense rebuilt and previewed. Cover fires on about 1 placement in 20 at Seek and Hunt.
- **rainbow_meadow** - art regenerated, base and dense rebuilt. Best cover in the game (about 1 in 7 at Look) because its near foreground is grass and ferns rather than solid boxes.
- **space_station** - art regenerated (porthole planet removed, dense reshot as the same room), base and dense rebuilt. Cover only about 1 in 30 at Hunt: crates and a locker hide the deck behind them completely rather than partly, so only the yellow railing gives any. If that matters, the dense backdrop wants more see-through foreground - railings, netting, rope - rather than more meta work.
- **pirate_cabin** - art regenerated (its brief was already flat-styled; it needed the blend rules, not a restyle), base and dense rebuilt. Its decoy bottle is now a message-in-a-bottle, because a plain corked bottle is the wrong read in a 4+ listing.

`pubspec.yaml` bumped to `1.7.0+17` - minor, because this is a visible behaviour change across every level.

### Placement lessons the metas kept getting wrong

1. **Rects drift.** Every analyze pass but the last put some furniture a tenth of the frame off. Measure against a percentage grid over the backdrop (`PIL` overlay, 5% lines) and correct before `place`; a wrong rect puts props in mid-air, a wrong rest line hangs them above the surface.
2. **Size floors shut regions off.** A dense region with a `sizeRange` floor above the widest prop in the variant is a region no prop can use. That silently removed the whole near foreground of the toy room and, later, most of the meadow's leaning spots.
3. **A region with no rest line and a non-surface kind holds nothing.** The meadow's hedge, cattails, fence and foreground fringe were all authored that way; grounding them is what finally let the Seek band place all twelve finds on every seed.
4. **Cover needs the covered region to reach past the occluder's top edge**, which is why each level now has a floor/path strip behind its near foreground.

All four are in the `analyze` prompts now, and 1, 3 and 4 are in [scene-meta.md](scene-meta.md).

### Prompts rolled forward

`docs/imgenprompts/rainbow-meadow.md` and `space-station.md` now carry the new backdrop rules (leading prop ban, lived-in density with decor pockets, near-foreground strip, tonal variety) and the flat-rendering negatives on every sprite sheet including the decoy sheets.
The space station dense prompt also banned spacesuits in its first lines and then asked for "a row of spacesuits in wall alcoves"; that clause is now sealed lockers.

## Then verify

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
tools/scene.sh preview toy_room --seed 7            # Look band
tools/scene.sh preview toy_room --band hunt --seed 7
flutter test && flutter analyze
```

Look at the previews (they now include the contact shadow): objects should sit in decor pockets, grounded by shadow, matching line weight.
Judge like a picky player; iterate prompts/meta if anything floats or pops.

## What is left

1. The three failing tests belong to the parallel difficulty session's uncommitted UI work (see Test state above) - leave them to that session, or fix the copy once it lands.
2. Consider raising camouflage/occlusion weights in `lib/game/placement.dart` now that the art can support them - check with the parallel session first (below).
3. The space station's dense foreground is solid crates and a locker, so cover fires about a tenth as often there as in the meadow. If that band should feel consistent, reshoot that backdrop with see-through foreground - railings, cargo netting, a coil of rope - rather than tuning the meta.
4. Nothing is committed. The working tree holds the new art, the four rebuilt levels, the pipeline prompt changes, the doc updates and the version bump.

## Coordination and safety

- A parallel Claude session `game-difficulty-progression-gates` is active in this repo (difficulty work). It was messaged that this task claims `assets/levels/*`, `docs/imgenprompts/*`, `lib/game/scene_view.dart`, and avoids `lib/models/difficulty.dart`. No reply yet - re-check with ListAgents/SendMessage before touching `lib/game/placement.dart` or difficulty files.
- Pre-redesign copy of `assets/levels/` (with the uncommitted recolor state) saved at `/Users/tomerfayer/dev/findobj-levels-backup-2026-08-25/`.
- The working tree already had many uncommitted asset changes before this task; do not commit or revert without the user.
- Dense backdrop art note: the model painted small ball-like shapes into storage baskets despite the ban. Judged acceptable (the real find is a blue star ball, distinct), but re-check in preview; if it confuses, regenerate dense with a stronger ball ban.

## Session 3 (2026-08-27): fitting the metas to the art

The blend-in art was in and the finds still read as pasted on.
Two causes, both measured rather than guessed:

1. **Props landed on bare picture.** The placer weighted regions by size alone, so the biggest empty floor won more draws than any shelf, and half the finds ended up standing alone on it - the reading a player calls a sticker however well the sprite is drawn.
2. **The metas were out by a few percent.** Rest lines sat on monitor screens, above bunk mattresses and behind the top edge of the near cabinet, so props hung in the air. `analyze` writes those numbers by eye and eyes drift; nothing in the pipeline had ever checked them against the pixels.

### What is in the game now

- `lib/game/placement.dart` weights the region draw by `clutter` (high 1.0, medium 0.5, low 0.15), holds an open-space budget of one find in ten across finds and decoys together, and draws anything in the open at the small end of its range but never below the band's tap size. Half of a prop's tries respect the budget; the rest ignore it, so a level never loses an object to the rule.
- `SceneRegion.freeSpans` and `_pickSpan`: a prop's middle goes in a stretch of surface the backdrop left empty, picked by width.

### What is in the pipeline now

`tools/fit_regions.py`, wired as `tools/scene.sh fit` and into `scene.sh all` between `analyze` and `place`.
It reads the backdrop's own line work: a rest line is expected to have surface under it at seven points across the region, and each reading comes back `=` (clear surface), `~` (surface with the room's own things standing on it) or `!` (nothing there at all).

- `--snap` corrects what a fitter may safely decide - up to 0.04 of the picture, and box widths trimmed to the surface that exists. Bigger corrections are printed instead: the one time the cap was off, it moved a chair seat onto the rug beneath it and a window sill onto its own front face.
- `--spans` writes `freeSpans`.
- `--check` gates a build.

All eight metas (four levels, both variants) now pass, about a third of them after hand correction against a 1% grid overlay: station `console_left`, `bunk_bottom`, `round_table_top`, `crates_left_front`, both railings and `panel_front_right`; toy room `toy_chest_box`, `chair_right_seat`, `window_right_sill`; meadow `cattails_upper`; cabin `bed_blanket`.
`test/level_test.dart` keeps the spans honest, and `pubspec.yaml` is at 1.8.0+18.

### What is still open

- The fitter cannot tell a vertical face from a horizontal one on its own; the paint test plus the contact band gets it right on this art, and the `!` readings are what to look at when it does not.
- Cover still fires rarely on the station: its foreground hides the deck completely rather than partly. That wants see-through foreground art - railings, netting - not more meta work.

## Session 3, part two: the baked scene

The fitting work took composited finds as far as they go.
The remaining gap against a printed hidden-object page is that a sprite is drawn by a different pass than the room, so the pilot took the other trade on one scene: the space station's dense variant is now a picture with its twelve finds drawn into it.

- `docs/imgenprompts/space-station.md` gained a `## Baked scene` prompt: the dense room, plus the twelve finds listed one by one, each at crate size, each somewhere it would plausibly be left, five or six of them half behind something, none touching another and none cut by the frame.
- `tools/bake_scene.py` (`tools/scene.sh bake`) reads them back out. A vision call boxes each find, cached in `tools/scenes/space_station.dense.baked.json`; the art itself does the rest, keeping the patches of flat colour that sit mostly inside the box and adding the pen around them. That gives the tap polygon, the centre, the size and the chip icon.
- `SceneObject.drawn` is the runtime half. False means the backdrop already holds the art: no sprite, no contact shadow, and a find is marked by circling it rather than by taking it away, because a drawn object cannot leave.
- `assets/levels/space_station/scene.dense.json` is now a fixed-`objects` scene, `background_dense.jpg` is the baked picture, `baked/*.png` are the chips, and the manifest says 12/12 for the variant.

Three of the twelve boxes came back badly aimed (the planet, the boot and the wrench) and were corrected by hand in the cache file before re-running `bake`; that is the expected manual step.
Two cut-outs still carry a little of the room - the planet keeps the netting it hangs in, the boot a corner of the blanket - which reads fine at chip size.

Peek and Look still play the composited station, still different every game.
What the baked variant gives up is written down in [scene-pipeline.md](scene-pipeline.md#the-other-shape-a-baked-scene): one layout per picture, no placer knobs, no vanishing finds.
The other three levels are untouched.

### The finds have to leave the picture

First cut of the baked scene circled a find instead of removing it, on the grounds that a painted-in object cannot go anywhere.
It can, and the way is to make the art differently: generate it **from** the empty room rather than from nothing.

- `generate_art.py --from <image>` hands the model a picture to work from.
  The `## Baked scene` prompt is now "here is a finished room, return the SAME picture with these twelve things added and nothing else altered".
- The room it was handed is then a clean plate, pixel for pixel. `tools/scene.sh bake --plate <room>` diffs the two: what changed is the finds and nothing else, which is a far better cut-out than anything a single picture allows - it knows where a drawing ends and the shelf behind it begins because the shelf did not change.
- Each find gets `erase`: the patch of plate under it, and where it goes. Found, the patch fades in over the object and the room is exactly as it was. `SceneObject.erase` and `_ErasedPatch` are the runtime half; the ring is kept only for a bake with no plate.
- The patches are precached with the sprites, or a find leaves the picture a frame late, which reads as a glitch.

Numbers from the pilot: twelve finds, twelve blobs claimed, fifteen further patches the model touched up unasked (hooks, a plant, some towels) - those are reported, not shipped. Diff threshold 60, blobs joined across 0.003 of the width, labelled at quarter size because a pixel-by-pixel flood over 4 megapixels takes minutes and whole-array propagation takes a moment.

## Session 4 (2026-08-28): pools, density and a real hunt

Play test of the first baked station came back with four things, all of them the same root - one picture, one layout, drawn for a five year old.

1. **Two plates instead of one.** `## Plate look` and `## Plate hunt` in the brief. The look plate is about twice the old backdrop; the hunt plate is three to four times it - racks four and five shelves deep, packed end to end, layered near foreground with see-through occluders (railing, wire basket, ladder rungs, hose reel).
2. **Small finds.** The hunt prompt asks for objects about a twentieth of the picture across, pushed to the back of shelves, behind jars, under the bench, and at least twelve of the twenty partly hidden.
3. **A pool.** `generate_art.py --takes N` draws the same prompt N times; `bake --take i` writes `scene[.variant].<i>.json`; the manifest carries `scenes`. `Level.sceneAssetFor` picks by seed, so the room changes between playthroughs.
4. **More drawn than asked for.** The hunt pictures hold about nineteen finds and a game asks for fourteen to eighteen of them; `GameScene.asked` picks which by seed and leaves the rest in the room as decoys. So the ask changes even when the picture repeats, and the band gets its difficulty lever back: Peek 6, Look 12, Seek 16, Hunt 18.

`maxObjects` is now the least any picture in a pool holds, read off the folder by `bake` rather than from the run that happened to be last: the card promises a count before it knows which picture the player gets.

Station numbers: four look pictures holding 12-13 finds, four hunt pictures holding 18-19. Two of the twelve kinds are missing from one hunt picture, which is allowed - a playthrough asks for a subset, and the test checks every find is one of the level's own rather than that all of them appear.

Watch out for: a vision box that points at nothing in the diff ("nothing was added to the picture at ...") - usually the model drawing an object the prompt did not ask for, sometimes a real find whose blob merged into a touched-up fitting. Re-baking with `--relocate` after correcting the box in `tools/scenes/<id>[.variant].<take>.baked.json` is the fix.

## Session 5 (2026-08-28): the rollout, and the leftovers

**Leftovers.** A rubbed-out find could leave a sliver of itself behind: the erase patch was cut to the find's own blob, and a drawing's soft shadow falls outside its outline while a ring or an aerial can come back from the diff as a piece of its own. `erase_box` now takes the find plus anything else that changed within `ERASE_REACH` (2% of the width) of it, minus whatever belongs to another find, and pads by 1.2%. Re-baked all eight station pictures; tapping every find leaves the room exactly as the plate has it.

**Rollout.** Toy room, rainbow meadow and pirate cabin now have the same shape as the station: `## Plate look` and `## Plate hunt` in each brief, four `Baked look` and four `Baked hunt` pictures each, all baked with `--plate`. Two plates and eight pictures per level, 40 images and 32 vision calls in all.

Counts came out uneven, because the model does not always draw everything asked for and the locate does not always find everything drawn:

| level | look asks / drawn | hunt asks / drawn |
| --- | --- | --- |
| space_station | 12 of 12 | 14 of 18 |
| toy_room | 11 of 11 | 14 of 14 |
| rainbow_meadow | 11 of 11 | 13 of 13 |
| pirate_cabin | 12 of 13 | 14 of 15 |

Re-shooting a weak picture is one `art --only "Baked hunt" --from <plate> --force`, a rename onto the take, and one `bake --relocate`. Watch the heading case: `--only "Baked Hunt"` matches nothing and the shoot silently produces no file.

**Dead weight cleared.** Every level's `scene.json`, `meta.json`, `background.jpg`, `background_dense.jpg` and `sprites/` are gone, along with their `pubspec.yaml` sprite lines. The station folder went from 21MB to 14MB.

**Tests.** The widget tests used to lean on the cabin's composited scene, which no longer exists. `test/scene_pump.dart` now describes the baked cabin, `test/fixtures/composited_{scene,meta}.json` keep a room for `placement_test` to place in - the placer is still live code for any future level - and the tests that named particular finds now read the list off the scene, because which finds a game asks for is the seed's business.

## Session 5, part two: the plate ships, not the picture

Thirty-two baked pictures came to 58MB of level assets, which is a lot of the same room over and over.

Each picture is the plate plus its finds at known places, and both halves are already exact - so the level now ships the plate once per band and a **stamp** per find: the find's own pixels on transparency, its shadow feathered out through the diff ramp rather than cut at the threshold, placed by the stamp's own box. `SceneObject.sprite` is that stamp, `SceneObject.chip` is a small copy for the object list, and `erase`, `drawn`, `EraseArt`, `_ErasedPatch` and `_BakedFind` are all gone: a found stamp fades out exactly like a composited sprite ever did.

- **58MB to 16MB**, nothing downscaled: 6.7MB plates, 5.1MB stamps, 2.6MB chips.
- Most of that is the palette. `_packed` quantises stamps to 256 colours and chips to 128 with `FASTOCTREE`; flat cel art loses nothing and the jpeg noise the cut came from goes with it.
- Rebuilding a picture from plate plus stamps and diffing it against the baked original: 1.2% of pixels differ by more than 40, all of them at stamp edges and on fittings the model touched up unasked - and those *should* come back as the plate has them.
- The level card now shows the plate, which is a nicer thumbnail anyway: the room, with nothing given away.

This also answers the "download the levels after install" question for now. At 16MB there is nothing to download, and the app keeps the property the Kids Category listing depends on: no network package, no socket, nothing to say in the privacy policy. If the catalogue grows enough to need it, the way that keeps that property is Play Asset Delivery and iOS On-Demand Resources - the stores deliver the packs, the app makes no requests of its own - rather than an HTTP client fetching from a bucket.

## Session 6 (2026-08-29): what the reading got wrong, and the bar

Playing the shipped build turned up four things, three of them in `bake_scene.py` and one missing knob.

**Finds cut off in mid-air.** The blob was trimmed to the sighting with `blob & _box_mask(_padded(box))`, which is a rectangle over a drawing: where the vision box was aimed a little tight, the trim sliced the find along a straight line and shipped half a boat. `_trimmed` replaces it and widens the window until it stops cutting. Cutting is decided exactly rather than by eye - `(_grown(piece, 1) & blob & ~window).any()` is true only when the blob carries on immediately past the trim, which is the trim's doing, and false when the paint simply ends, which is the barrel in front of it. Widening stops at `MAX_SIZE`, where the reading has left the object and the find is thrown out instead.

**Finds cut off by the frame.** The model draws the odd find running off the edge of the canvas, and what came back was half a coin with nothing covering it. `_runs_off_frame` drops those. Dropping is free here in a way it would not be on a composited level: the plate has no coin, so the picture is simply a room without one.

**Finds with nothing left to see.** `MIN_SIZE` measured the box, so a find drawn behind the woodpile passed on the strength of a box it barely coloured in. `MIN_VISIBLE` (0.04% of the picture) now measures the paint, with `MIN_FILL` behind it as a loose guard - loose because a wand, a balloon on its string and a butterfly are all mostly empty box, and the first pass at 0.22 threw out a third of the meadow.

**The object bar.** Chips were a thumbnail of the stamp, so the bar showed this picture's copy of the thing: cut where the picture cut it, carrying the corner of the crate it was cut beside, and different in every take of the same level. They now come off the sprite sheets through `build_scene.slice_sheets`, one `baked/chip_<kind>.png` per kind, de-flecked and shared by every picture. The bar states the ask; the picture keeps the puzzle.

**The one knob a baked level has left.** Sizes, spacing and cover belong to the illustrator now, so the older bands had nothing but "which picture" and "how many". `DifficultyProfile.blendOpacity` draws the finds at less than full paint - Peek and Look at 1.0, Seek 0.92, Hunt 0.84 - so the room shows faintly through what is standing in it. It is deliberately shallow: the floor a test enforces is 0.75, below which the outline stops reading against a busy room and the hunt becomes an eyesight test. Assist does not touch it, because a find that solidified halfway through a game is the picture changing under the player.

All thirty-two pictures re-baked. Counts moved:

| level | look asks / drawn | hunt asks / drawn |
| --- | --- | --- |
| space_station | 11 of 11 | 16 of 16 |
| toy_room | 11 of 11 | 14 of 14 |
| rainbow_meadow | 10 of 10 | 13 of 13 |
| pirate_cabin | 12 of 12 | 14 of 14 |

The look numbers lost one each in the station and the meadow, to finds that were drawn off the frame or hidden past finding; the hunt numbers gained, because the trim fix recovers finds that used to be rejected as too small once they had been sliced.

**The store rig.** Taking eight shots at two sizes turned up three things in it. It hung for ten minutes at a time on `pumpAndSettle` in front of a room that was ready - the game leaves animations running for as long as they are wanted, and the hint ring pulses until the find is made - so it pumps a fixed stretch of frames instead. It tapped level cards without scrolling them into view, which the fourth level broke. And it took the finish card, which plays a whole level out by tapping a grid over the room, in the middle of the run: any failure there cost the shots after it, so it goes last now. The rig also writes a `finished` marker and `store_shots.sh` judges the run on that plus the size of every shot, rather than on an exit code that reports audioplayers' position updater still ticking as the tree comes down.

**Leftovers cleared.** A re-bake now unlinks its own take's stamps first, so a find that stops being read stops being shipped. That plus the per-stamp chips going took level assets from 16MB to 12MB.

**The room opens in the middle of itself.** Taking the store shots at phone shape made a fifth thing obvious: a 4:3 room on a 2.16:1 screen overflows it by a third of its height, and an `InteractiveViewer` left alone opens at the top left of its child. Every level started the player on the cabin's ceiling or the meadow's sky, with the floor - where half the finds are - off screen until they thought to drag. `SceneView` is stateful now and centres its view once per layout, after the frame that measured it.

**The home screen holds the catalog.** Same lesson, one screen up. The level grid sized its cards to a fixed 460 point maximum, which on a landscape phone came out as three across and one below the fold - a fourth level a child has no way of knowing is there - and on a tablet as the same three and one with a hole beside it and dead space above and below. `_GridShape` now tries every arrangement and takes the largest cards that still show every level at once; four levels land as two by two on both shapes. `test/level_grid_test.dart` holds it to that at three window shapes.

**Two test leftovers, found on the way.** `game_screen_test` named three finds it expected on the bar, which on a baked level is the seed's business - it failed about one run in fifteen. And `scene_pump.dart`'s `pirateLevel` had drifted from the manifest (counts and thumbnail both), so every widget test was playing a level the bundle does not ship; a test now holds the two equal.

`test/baked_scenes_test.dart` is the guard: every object's icon is `baked/chip_<kind>.png`, the same kind never carries two icons, and no picture in a pool holds fewer finds than the level card promises for any band.

