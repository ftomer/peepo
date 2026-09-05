# Kids-first direction

Decided 2026-08-22.

Peepo (formerly `Curiosa`) pivots from cozy-adult hidden object to a hidden object game for children aged 3-12.
The pirate cabin level stays exactly as it is: it is the MVP proof that the engine and the art pipeline work end to end, and it is playable content while the kids catalog is built.

## Audience

Children aged 3-12, playing on a parent's phone or a family tablet, with a parent choosing and paying.

The span is served by four `AgeBand`s rather than by one design, because a three year old and a twelve year old want the same scene at very different densities.
See `lib/models/difficulty.dart`.

| Band | Ages | What changes |
| --- | --- | --- |
| Peek | 3-4 | Pre-reading. Few objects, all large, forgiving taps, a hint before frustration. |
| Look | 5-7 | Early reading. The band the scene art and the meta files are authored for. |
| Seek | 8-10 | Fluent reading. More objects, smaller, closer together, less help. |
| Hunt | 11-12 | Full clutter, no automatic help, a rating at the end. |

Look is the authored baseline: scenes are drawn and placed for it, and the other three bands are derived from it at runtime.
Everywhere in these docs that says "5-7" describes that baseline, not the audience.

What the Look band can do, which is what the baseline design is built on:

- Early reading, three to six letter words, so a picture chip with the word under it teaches while it plays.
- Counting to ten reliably, so "find 3 eggs" is a real mechanic rather than a chore.
- Sorting by category and colour, which is the single most useful cognitive hook at this age.
- Fine motor control good enough for ordinary taps, but not for a 40 pixel target.

What it cannot do, which is what the design removes:

- Read a sentence of instructions.
- Tolerate a fail state, a timer, or a score that goes down.
- Ask for a hint. If a child is stuck, the game has to notice.

## What this supersedes

| Was | Now |
| --- | --- |
| Ads (`google_mobile_ads`) after retention | No third-party ads, ever. The audience is children, which is reason enough independent of any store category. |
| Painterly HD art, dim and moody | Bright, flat, thickly outlined, high contrast. Cheaper to generate and far more legible to a child. |
| "Relaxing seek and find" adult positioning | A children's game sold to parents. |
| The name `Curiosa` | `Peepo`, chosen for the kids audience, see [branding.md](branding.md). |

Engine, scene pipeline, hit testing, the smoke reveal and the level folder layout are all unaffected.
None of the pivot touches code that already works.

## Monetization

Not decided publicly, and not part of what this repository documents.
What is settled: no third-party advertising, ever, and no timers or fail states.

## Compliance, before any store work

- Apple age rating **4+**, and enrolled in the **Kids Category** (decided 2026-08-25, reversing the opt-out below).
  The category forces a single band out of "5 and under", "6-8" or "9-11", and the original decision was that declaring one would misdescribe a 3-12 product.
  The shelf placement and the clearer signal to parents won out: the listing declares "5 and under", and the four in-app `AgeBand`s still serve the whole span regardless.
- Enrollment makes the obligations binding rather than self-imposed: COPPA, App Review guidelines 1.3 and 5.1.4, no third-party ads, no third-party analytics, and a parental gate in front of every purchase and every outbound link.
  The app already met all of them voluntarily, so enrollment changed the listing, not the product.
- Google Play: complete the Families policy declaration and target a families-appropriate content rating.
- COPPA: no personal data collection from under-13s. Local progress storage only, which is what `shared_preferences` already does.
- A published privacy policy URL is mandatory in both stores.

## Catalog

Six worlds, four levels each, one new kind of ask per world so the game teaches itself without instructions.

| World | Levels | New ask | Why it fits the Look band |
| --- | --- | --- | --- |
| Toy Room | 4 | find from a list | Onboarding, every object already familiar |
| Farm | 4 | find by count, "3 eggs" | Counting to ten is exactly this age |
| Beach | 4 | find by colour | Sorting, and colour is already sprite metadata |
| Dino Valley | 4 | find by category, "things that fly" | Peak dinosaur age, teaches grouping |
| Space | 4 | silhouette match | First real step into abstraction |
| Bakery | 4 | odd one out | Needs inference, so it comes last |

Christmas is a seasonal add-on rather than a world, and `docs/imgenprompts/christmas-living-room.md` is already written for it.

A named animal guide appears in every level, loses the things the player finds, and reacts when each one turns up.
At this age a character is what makes a child open the app again, and it costs one sprite set.

## What difficulty means

Difficulty is six axes, not one slider, and `lib/models/difficulty.dart` holds one preset vector per band rather than a single multiplier.

| # | Axis | What moves | Where it lands |
| --- | --- | --- | --- |
| 1 | Visual search load | objects hidden, sprite size, spacing, objects per region, decoys, cover, camouflage, which backdrop | `layoutScene` |
| 2 | Motor precision | how near a tap has to land | `GameScene.hitTest` |
| 3 | Ask abstraction | picture, picture and word, word, count, category | object chips |
| 4 | Working memory | how much of the list is held at once | object list bar |
| 5 | Scaffolding | how soon and how long the game helps, and how often | `GameScreen` hint timers |
| 6 | Pressure | whether the ending judges the playthrough | level-complete card |

Axes 1, 2, 5 and 6 are implemented.
Axis 3 so far only chooses between a picture chip and a picture-and-word chip; the count, colour, category, silhouette and odd-one-out asks are the catalog's job and land per world.
Axis 4 is not varied yet.

Axis 1 is five things rather than three, because size and count on their own ran out.
Every region in every shipped level floors at 0.045 of scene width or above, so a band that could not go under the room's own floor drew a Hunt prop at exactly Look's size; and every prop shipped at one copy, so `objectScale` of 1.4 asked for more than the level could give and got the same twelve back.

| Field | Peek | Look | Seek | Hunt | What it moves |
| --- | --- | --- | --- | --- | --- |
| `widthFloorScale` | 1.0 | 1.0 | 0.80 | 0.62 | scales the room's own floor before `minWidth` catches it |
| `decoyScale` | 0 | 0.25 | 0.6 | 1.0 | sprites in the room that are on no list |
| `occlusionMax` | 0 | 0.15 | 0.35 | 0.50 | most of a prop that may sit behind the scenery |
| `camouflage` | -1.0 | 0 | 0.6 | 1.0 | put it where it shows, or where it does not |
| `sceneVariant` | - | - | dense | dense | which backdrop the band plays |

Three of them need something from the art before they do anything, which is what the dense backdrops are for - see [art-direction.md](imgenprompts/art-direction.md#dense-variants).
Cover needs a near foreground to hide behind; the authored meadow has no `occludedBy` on any of its twenty regions, and the dense one has six.
Camouflage needs regions that differ in tone; the authored meadow is `clutter: low` on sixteen of twenty, and the dense one runs seven dark, fourteen medium and six light.
Decoys need spare sprites, and above Look every authored prop is already on the list, so each variant ships six of its own.

What the four levels actually play, averaged over sixty seeds:

| Band | Backdrop | Finds | Decoys | Sprite width |
| --- | --- | --- | --- | --- |
| Peek | authored | 6-7 | none | ~0.09 |
| Look | authored | 12-14 | none | ~0.07 |
| Seek | dense | 14-16 | 3-9 | ~0.05 |
| Hunt | dense | 17-18 | 7-17 | ~0.04 |

Three rules hold all of it in place.
Nothing may cost a find: cover gives way before an object goes unplaced, and a prop that cannot be tucked behind anything is simply drawn whole.
Nothing may be tapped that cannot be seen: the covered part of a prop is out of the hit test and out of its tap tolerance too.
And nothing reaches Peek, which plays exactly the level it played before any of this.

Shrinking sprites is the cheapest difficulty available and the worst on its own: it buys difficulty out of eyesight and thumb size rather than out of searching, and it reads as unfair at every age.
Two things hold it back.
Every band carries a `minWidth` floor, below which the placer will not go while the room allows better, and the oldest band's floor is still a target a thumb can hit.
The Peek band carries the opposite, `maxWidthBoost`, which lets it draw a prop larger than the artist sized it as long as the region it sits in still has the room: the cabin's coin was drawn for older eyes and at 3 a speck is not a hidden object.

Two rules constrain the whole system.
The room is the meta file's word: no band overrides which regions hold what, where the rest lines run, or how big a region says a prop may be.
And nothing gets harder on its own.
Assist - two hints gone by without a find - brings help forward, holds it longer, widens the tap and drops any hint allowance, and it never moves in the other direction.
A child is never told it happened.

## Scene design rules for the Look band (5-7)

These describe the authored baseline.
Peek, Seek and Hunt are derived from it by `lib/models/difficulty.dart` and are not authored separately.

- Eight to twelve findable objects per scene.
- Sprite width roughly six to twelve percent of scene width, and never smaller than about 90 pixels on a phone.
  This is the Peek and Look figure. Seek and Hunt are drawn under it - down to their own `minWidth`, which is where a thumb stops being able to hit the thing.
  Wider than that and one prop fills a whole shelf, which starves the room: the toy room could only place nine of twelve props until the widths came down.
- Mild camouflage only: a prop may sit behind something, but it must contrast the tone it sits against.
  Peek enforces this outright, by preferring a region whose tone the prop stands out against; Seek and Hunt reverse it on their own backdrop.
- Bright, evenly lit rooms with no deep shadow, because a prop lost in shadow reads as unfair rather than hard.
- Objects spread across the whole picture, one or two per region, so the eye travels without the child having to pan.

These map onto the existing meta schema: `sizeRange` floors around 0.045 with a cap near 0.13, `minSeparation` around 0.08, `maxPerRegion` of three, and a preference for `clutter: low` regions.
The numbers come from the toy room, where anything tighter left props unplaced, and they are what `--audience kids` writes into a new meta file.

## Work queue

Engine, in payoff order:

Done:

- Age bands, the settings screen behind a parental gate, and the first-run age card.
- Tap tolerance per band, applied at hit-test time rather than baked into the polygons, so one build serves every age.
- Automatic hints on a per-band timer, plus assist for a player who is stuck.
- Settings and finished levels persisted with `shared_preferences`.

Next, in payoff order:

1. Level catalog with worlds and unlock progression.
   `assets/levels/levels.json` grows a world grouping and stays what it is: shipped, read-only data saying which levels exist and in what order.
   It already carries `maxObjects`, the copy ceiling the older bands' object counts stop at.
   Unlock state is per-player and mutable, so it belongs in level progress next to the finished levels `shared_preferences` now keeps.
   Keeping the two apart is what lets an app update add a world without stomping a child's progress.
2. Spoken object names: tap a chip, hear the word, one audio file per object id.
   The Peek band needs this most - it plays without words at all.
3. Celebration on find: the object flies to its chip, plus a badge at level end.
4. The five alternative asks, each a chip renderer and a win condition over the same `scene.json`.
   This is axis 3, and it is what gives the Hunt band a difficulty that is not just smaller sprites.
5. ~~Dense backdrops for Seek and Hunt~~ - done, all four levels.
   Each ships `background_dense.jpg`, `meta.dense.json` and `scene.dense.json`, played by Seek and Hunt, plus a six-prop decoy sheet that is on no list.
   A level without a variant still plays as it always did, at every band.

Pipeline:

1. A `--difficulty kid` preset in `place_objects.py` carrying the numbers above.
2. Art briefs in `docs/imgenprompts/` rewritten bright and sparse.
3. A `reachable` band in the scene meta, so nothing hides in a top corner that a small hand cannot reach on a phone.

## Open decisions

- The guide character's species and voice. The name is `Peepo`, taken from the app name.
- Price of the unlock, and how many levels sit in front of it.
- Whether object-name audio is synthesized or recorded by a person.
