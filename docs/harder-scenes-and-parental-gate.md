# Harder scenes for the older bands, and a one-shot parental gate

## Context

Four things are wrong, and three of them share one root cause.

The gate lets a wrong answer be retried against the same sum, which is a gate a child can brute-force by tapping.
The settings screen shows a band's ages as a bare `5-7`, which does not say years.
And `rainbow_meadow` plays almost identically at every age: props are too big even for Peek, and Seek and Hunt get nothing that a five-year-old does not also get.

That last one is not a rainbow bug, it is structural, and it holds for all four levels:

- **The band cannot shrink anything.** `placement.dart:298` takes `low = max(prop.minWidth, region.minWidth)`, and `DifficultyProfile.width` only ever raises that floor to the band's own `minWidth`. The meadow's region floors run 0.045-0.09, above Hunt's 0.04 and Seek's 0.05, so both bands play at the Look band's sizes. `widthBias` is the only lever left and it buys about a 2x spread from Peek to Hunt.
- **The band cannot get more to find.** `objectCount(12, capacity: 12)` returns 12 for Look, Seek *and* Hunt, because every rainbow prop is `copies: [1, 1]`. Same for `toy_room` (12/12/12/12) and `pirate_cabin` (7/14/14/14). Only `space_station` scales at all.
- **The art is authored sparse on purpose.** `docs/imgenprompts/art-direction.md` says "roughly half the visual density of the pirate cabin", and the rainbow brief repeats it. The backdrop is a flat green field with large empty surfaces. Nothing hides on it at any size.
- **Every hiding mechanism in the meta schema is inert.** `occludedBy`, `contrast`, `clutter`, `depth` and `palette` are authored into all four meta files and read by no Dart code at all - `occludedBy` and `contrast` are not even parsed by `lib/models/scene_meta.dart`.

The outcome wanted: Peek keeps exactly the scene it has, Look steps up, Seek is a real search, and Hunt is difficult for an adult.

## Approach

Two backdrops per level - the current one for Peek and Look, a **dense** variant for Seek and Hunt - and four new difficulty axes that give the older bands something to do with it.
Levels ship one sprite set and one prop catalog; a variant is a second backdrop with its own meta and its own placement rules over the same props.

The engine work lands first and is testable on the existing art. The dense art is the second half.

---

## 1. Parental gate: one shot per question

`lib/game/parental_gate.dart`.

Today `showParentalGate` picks the sum once and `_GateDialog` only sets `_wrong = true` on a miss, leaving the same four buttons up.

- Move sum generation out of `showParentalGate` into a small `_Sum` record/class with a `_Sum.random(Random)` factory, so it can be regenerated.
- `_GateDialogState` holds the current `_Sum` in state. A wrong tap calls `setState` to draw a **new** sum with new options, and shows the existing `'Not quite - try again.'` message reworded to say the question changed - e.g. `'Not quite - here is another one.'`
- A right tap still pops `true`. Cancel and `barrierDismissible: true` are unchanged; a grown-up who mis-tapped is not locked out, they just do a different sum.

`test/age_settings_test.dart` already reads the question out of the dialog to solve it (`_tapAnswer`). Extend the existing `'the settings are behind a sum a child cannot do'` test: after a wrong tap, assert the question `Text` differs from the one captured before, then solve the new one and reach `SettingsScreen`.

## 2. Age labels say years

`lib/models/difficulty.dart` - add next to `ageLabel`:

```dart
/// e.g. "5-7 yrs". The badge on its own has to say what the numbers are.
String get ageBadge => '$minAge-$maxAge yrs';
```

Use it in the two places a range is shown without context:

- `lib/game/settings_screen.dart` `_AgeBadge` (line ~336), which renders bare `band.ageLabel`.
- `lib/game/level_select_screen.dart` `_BandButton` (line ~377), same.

`_BandCard`'s semantics label already says `'${band.label}, ages ${band.ageLabel}'` and stays as is.
`AgeBandPicker.summaryOf` copy is fine.

Also add a one-line lead under `_SectionTitle('How old is the player?')` if one is not already clear enough - the picker is the only place a parent learns what the bands mean.

`test/age_settings_test.dart` finds bands by `find.text('5-7')`; update those finders to the new badge text.

## 3. Four new difficulty axes

`lib/models/difficulty.dart` - four fields on `DifficultyProfile`, one preset value per band. Every one is a no-op at its Look value, so the authored baseline is unchanged by definition.

| field | peek | look | seek | hunt | what it does |
| --- | --- | --- | --- | --- | --- |
| `widthFloorScale` | 1.0 | 1.0 | 0.80 | 0.62 | scales the room's own `low` before the band floor is applied |
| `decoyScale` | 0.0 | 0.25 | 0.6 | 1.0 | decoys placed, as a fraction of the objects hidden |
| `occlusionMax` | 0.0 | 0.15 | 0.35 | 0.50 | most of a sprite's area that may sit behind foreground art |
| `camouflage` | -1.0 | 0.0 | 0.6 | 1.0 | -1 prefers a region the prop contrasts, +1 prefers one it blends into |

This is the one place the rule "the room is the meta file's word" is deliberately loosened, and only downward, and only to the band's `minWidth` - which is what finally makes `minWidth` mean something. Document that in the `widthFloorScale` doc comment.

`withAssist()` must carry all four through unchanged: assist only ever adds help, and none of these are help.

### 3a. Sub-floor shrink

`lib/game/placement.dart:298`:

```dart
final low = math.max(
  math.max(prop.minWidth, region.minWidth) * profile.widthFloorScale,
  profile.minWidth,
);
```

`DifficultyProfile.width` keeps its `math.max(low, minWidth)` guard, which is now redundant but harmless. On rainbow this takes Hunt from ~0.05-0.09 down to 0.04-0.056, and Seek to 0.04-0.072.

### 3b. Decoys

A decoy is a placed sprite that is not on the list and cannot be tapped for a find. It is the cheapest real difficulty available here, because most of the art already exists and is simply not being drawn.

- `_copyPlan` in `placement.dart` already drops whole props when the band asks for fewer than the catalog holds. Return the dropped ones as the first decoy pool rather than discarding them - at Peek that is six unicorn-meadow props already paid for, though Peek's `decoyScale` is 0 so it sees none.
- Hunt places every prop, so it needs a pool of its own: one extra six-prop sheet per level, cut by the existing pipeline into `sprites/decoy_*.png` and listed in `scene.json` under a new `decoys` array of `PropDef`s. Same schema, same cutter, no new tooling beyond a flag.
- `layoutScene` places decoys after the findables, through the same `_trySpot`, obeying the same rules, spacing and no-go zones. If the room runs out, decoys are what gets dropped - never a findable.
- `Placement` gains `bool findable`. `GameScene.fromLayout` puts decoys in `objects` so they render, but excludes them from the object list and from `hitTest`: a tap on a decoy is a miss, with the existing miss ripple and miss cue. No penalty - there is no fail state in this game and there is not going to be one.

Decoys must never duplicate a findable prop id in the same layout, or the player is asked to find a unicorn while two identical unicorns sit on screen. Assert that in `placement_test.dart`.

### 3c. Partial occlusion

The `occludedBy` field is authored in three of four metas and read by nobody.

- `lib/models/scene_meta.dart`: parse `occludedBy` (list of region ids) and `contrast` (string) onto `SceneRegion`. Both are currently dropped on the floor.
- `placement.dart`: when a chosen region has `occludedBy` and the band's `occlusionMax > 0`, resolve the occluder region's rect and, where the sprite box overlaps it, keep the placement and record the visible sub-rect on `Placement.clip` (normalized scene coordinates). Reject the placement if the hidden fraction exceeds `occlusionMax`, or if the visible remainder is smaller than a tap target.
- Render it by clipping, not by layering. The backdrop already contains the occluder art, so a `ClipRect` on the visible sub-rect in `_FindableSprite` (`lib/game/scene_view.dart:141`) makes the prop read as tucked behind the hedge with **no new foreground asset**. Clip before `Transform.rotate` so the clip is in scene space.
- `SceneObject` carries the same `clip`, and `SceneObject.contains` / `distanceTo` in `lib/models/scene.dart` must reject points in the hidden part - otherwise the older bands get a tap target the player cannot see.

Rainbow has no `occludedBy` regions today; the dense meta authored in step 5 is where it gets them.

### 3d. Camouflage placement

`_pickRegion` currently weights by region area and by how unused a region is.

- Give each prop a `tone` (`light` / `medium` / `dark`), computed by `tools/build_scene.py` from the mean luminance of the sprite's opaque pixels and baked into `scene.json`. No hand authoring, and it is derived from the art so it cannot drift from it.
- Weight each candidate region by `1 + camouflage * match`, where `match` is +1 when the region's `contrast` equals the prop's `tone` and -1 when it is the opposite. Peek's `-1.0` makes the existing informal "put it where it shows" rule explicit for the first time; Hunt's `+1.0` puts the green clover in the hedge instead of on the red picnic blanket.
- It is a weight, never a filter: no band may make a region unreachable, or a seed with a bad draw places nothing.

## 4. Give the older bands more to find

`objectScale` of 1.15 and 1.4 do nothing on three of four levels because `maxObjects == objectCount`.

Raise `copies` to `[1, 2]` on the props in each level that read as plural (clover, butterfly, crystal, sunflower, horseshoe in the meadow - not the unicorn, not the castle-scale props), rebuild, and let `build_scene.py` recompute `maxObjects`.
Target `maxObjects` around 1.5x `objectCount`: rainbow 12 -> 18, toy_room 12 -> 18, pirate_cabin 14 -> 20.
The `ObjectGroup` chip already shows `foundCount/total` for multi-copy props, so nothing in the UI changes.

## 5. Dense backdrops for Seek and Hunt

A variant is a second, self-contained scene over the same sprite folder. Nothing about the existing files changes.

```
assets/levels/rainbow_meadow/
  scene.json          background.jpg        meta.json          # Peek, Look
  scene.dense.json    background_dense.jpg  meta.dense.json    # Seek, Hunt
  sprites/*.png                                                # shared
```

- `lib/models/level.dart`: `sceneAsset` becomes `sceneAssetFor(AgeBand)`, returning the dense scene when the band asks for it and the level ships one, and the base scene otherwise. `loadScene` already resolves `background` and `metaFile` out of the scene JSON, so both variants work unchanged below that line. `thumbnail` should follow the same rule, so the level card shows the room the child will actually get.
- `assets/levels/levels.json` gains an optional `"variants": ["dense"]` per level, written by the build, so nothing has to probe the bundle for a file that may not exist.
- `pubspec.yaml` needs the extra asset lines; `tools/scene.sh build` already maintains those two lines per level and extends to the variant.
- Missing variant is not an error: a level with no dense scene plays its base scene at every band, which is what ships on day one and what keeps this landable in pieces.

### Pipeline

`tools/scene.sh` gains `--variant dense` on `analyze`, `place`, `build` and `preview`, threading a suffix through `tools/analyze_scene.py`, `tools/place_objects.py`, `tools/build_scene.py` and `tools/preview_scene.py`. The variant runs the same three stages against the dense backdrop and writes `tools/scenes/<id>.dense.meta.json` and the dense level files. Regions are authored fresh per variant, so region ids need not match across variants - the prop `regions` allow-lists live in the variant's own `scene.dense.json`.

`tools/layout.dart` gains `--variant` alongside its existing `--band`, so a dense seed can be inspected without launching the app.

### Art brief

`docs/imgenprompts/art-direction.md` currently states the sparse rule as universal. Split it: the sparse rule becomes the **Peek/Look backdrop** rule, and a new **dense variant** section says the opposite for Seek/Hunt.

Per level, add a `## Dense backdrop` block to its brief (`rainbow-meadow.md`, `toy-room.md`, `space-station.md`, `pirate-ship-cabin.md`), taking the existing backdrop prompt and adding:

- The same room, same camera, same major landmarks in the same places, so the level is still recognisably itself and the music and name still fit.
- Roughly the density of a busy adult scene: more surfaces, more overlapping scenery, tall grass, bushes, crates, shelves, foliage in the near foreground that other things can sit behind.
- Deliberate foreground occluders, because that is what `occludedBy` needs to exist at all, and there is none in the meadow today.
- Varied tone across the frame - light patches and dark patches - because camouflage placement has nothing to choose between on a uniform green field.
- Every other art-direction rule unchanged: flat vector, thick outlines, bright even daylight, nothing scary, no loose objects, no characters, no text.

Plus one `## Decoy sheet` block per level: six props in the level's own world that are not on any find list, same sprite-sheet rules as the existing sheets.

Order of art work: `rainbow_meadow` first and reviewed end to end at all four bands, then `toy_room`, `space_station`, `pirate_cabin`.

## 6. Docs and version

- `docs/kids-direction.md` - "What difficulty means" gains the four new axes; the work-queue item *"Levels authored for the outer bands"* is what this closes, and the Peek/Look-only scene design rules get the dense counterpart.
- `docs/scene-meta.md` - `occludedBy` and `contrast` are now read at runtime, not documentation.
- `README.md` - level folder layout gains the variant files; the difficulty bullet gains decoys.
- `pubspec.yaml` - `1.4.2+12` -> `1.5.0+13`. New gameplay feature and visible behaviour change, so minor per the versioning rules in `CONTRIBUTING.md`.

---

## Critical files

| File | Change |
| --- | --- |
| `lib/game/parental_gate.dart` | new sum on every wrong answer |
| `lib/models/difficulty.dart` | `ageBadge`; four new profile fields + presets; carry them through `withAssist` |
| `lib/game/settings_screen.dart`, `lib/game/level_select_screen.dart` | badges say "yrs" |
| `lib/game/placement.dart` | sub-floor width, decoy pass, occlusion clip, camouflage weight in `_pickRegion` |
| `lib/models/scene_meta.dart` | parse `occludedBy` and `contrast` |
| `lib/models/scene.dart` | `SceneObject.clip` + `findable`; honour both in `contains`/`distanceTo`/`hitTest` |
| `lib/models/prop_catalog.dart` | `decoys` array, `tone` on `PropDef` |
| `lib/game/scene_view.dart` | `ClipRect` on a partly hidden sprite |
| `lib/models/level.dart` | `sceneAssetFor(band)`, variant-aware thumbnail |
| `assets/levels/*/scene.json` | `copies: [1, 2]` on the plural props |
| `tools/build_scene.py`, `place_objects.py`, `analyze_scene.py`, `preview_scene.py`, `scene.sh`, `layout.dart` | `--variant`, decoy sheets, `tone` |
| `docs/imgenprompts/*.md`, `docs/kids-direction.md`, `docs/scene-meta.md`, `README.md` | as above |

Reuse rather than rebuild: `DifficultyProfile.width`/`rules`/`maxWidth` already exist and take the new fields; `_trySpot` places decoys unchanged; `PlacementRules.relaxed` already degrades gracefully when a room is full; `ObjectGroup` already renders multi-copy props; `build_scene.py` already cuts sprite sheets and computes `aspect`/`silhouette` for decoys as they stand.

## Verification

Unit and widget:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
flutter test
flutter analyze
```

New assertions to add:

- `test/age_settings_test.dart` - a wrong gate answer changes the question; badges read `5-7 yrs`.
- `test/difficulty_test.dart` - Look is still exactly neutral on all four new fields; no band's effective width floor goes below its `minWidth`; assist changes none of the four.
- `test/placement_test.dart` - Hunt places strictly smaller sprites than Look on the same seed and level; decoy count matches `decoyScale` and never collides with a findable id; no placement hides more than `occlusionMax`; every band still places what it asked for across a spread of seeds.
- `test/scene_test.dart` - a tap in a sprite's occluded part misses; a decoy is never returned by `hitTest`.
- `test/level_test.dart` - a band picks the dense scene when one exists and the base scene when it does not.

Offline, before any art is generated - this is what proves the engine change without waiting on backdrops:

```bash
dart run tools/layout.dart rainbow_meadow --seed 7 --band peek
dart run tools/layout.dart rainbow_meadow --seed 7 --band hunt
tools/scene.sh preview rainbow_meadow --seed 7 --outlines
```

Hunt's widths must come out visibly under Look's, and the decoys must appear in the preview.

End to end, which is the part that actually settles whether it is fun:

```bash
flutter run -d macos
```

Play `rainbow_meadow` at each of the four bands in turn and judge it by eye: Peek unchanged from today, Look a real but gentle hunt, Seek genuinely slow, Hunt hard for an adult. Check the gate rejects and re-asks, and that the settings badges read as years. Re-run `tools/scene.sh preview` on three or four seeds per band per level before calling any level done - the existing rainbow build notes show that is what caught the floating props last time.
