# Art direction

One style, every kids world.
This file is the source of truth: the style block below is pasted byte-identical into every backdrop and every sprite prompt, so a level built next year matches the one built today.

Audience is children aged 3-12 ([kids-direction.md](../kids-direction.md)), but art is authored for the Look band (5-7) only.
The Peek, Seek and Hunt bands are derived from the same scene at runtime by `lib/models/difficulty.dart`, so nothing here is drawn twice.
That is what every rule here is for.

## Style block

```style
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
```

## Why flat, not painterly

The old direction was painterly HD, aimed at adults.
A 5-year-old reads shape before texture, so a thick outline and a flat fill separate an object from its background far faster than rendering does.
It is also cheaper and far more repeatable: flat art comes back consistent from the same prompt, painterly art drifts.

## Backdrop rules

Every level ships one backdrop drawn to these rules, and may ship a second, denser one for the older bands - see [Dense variants](#dense-variants).
These rules describe the first, which is what Peek and Look play.

- Bright even daylight across the whole frame, no dark corners, no dramatic shadow, nothing that reads as scary.
- Large flat surfaces the eye can rest on: floor, rug, tabletop, shelf, bed. These become the regions props are placed on, so the scene needs plenty of them.
- Lived in, not empty. The first backdrops were drawn at half adult density and it made every find trivial: a sprite resting on a bare field is the only loose thing in sight, so it reads as the answer before it reads as an object. Aim for about two thirds of an adult scene, with the extra density spent on everyday decor - rows of books, baskets, folded cloth, plants - and visible gaps in that decor where one more small thing could sit. A prop dropped into such a gap reads as part of the room.
- A shallow near-foreground strip along the bottom edge - cushions, a crate, tall grass, the back of a chair - drawn in front of the ground behind it. This is what the occlusion axis tucks props behind, and a backdrop with no overlapping foreground gives it nothing to work with at any band.
- Mild tonal variety across the frame: warmer and cooler patches, lighter and darker surfaces, never one flat tone. Camouflage placement chooses regions by tone and needs something to choose between.
- Nothing loose. Only fixed furniture and decor, because everything findable is composited as a sprite afterwards.
- Nothing that looks like a find. Name the level's own props and forbid them outright in the *first* lines of the prompt, not the last - the same ban placed at the end was ignored twice running and obeyed immediately once it led. The busier the backdrop, the likelier the model is to paint one of them into the scenery, and a clover painted into the lawn makes "find the clover" unanswerable.
- Colour separation between areas, so a prop can always be placed somewhere it contrasts.
- Landscape 4:3, viewed straight on or from a gentle three-quarter angle. Steep perspective makes rest lines hard to author and hard to read.
- No characters, no people, no text, no numbers, no letters, no watermarks.

## Dense variants

A backdrop calm enough for a three year old is one an eleven year old clears at a glance, and no amount of shrinking the props fixes that.
`lib/models/difficulty.dart` will draw a Hunt prop at roughly half a Look prop's width and hide part of it behind the scenery, but on a flat green field a small sprite with a thick dark outline is still the only thing in the frame that is not grass.

So a level may ship a **dense** second backdrop, played by Seek and Hunt.
It is the same room, so the level keeps its name, its music and its find list; what changes is how much there is to look past.

Build it as its own spec beside the original - `tools/scenes/<id>.dense.build.json`, carrying `"variant": "dense"` - and run the same three stages against it.
It writes `background_dense.jpg`, `meta.dense.json` and `scene.dense.json` into the level folder and adds `dense` to the level's `variants` in the catalog. Nothing about the authored scene is touched.

The prompt is the level's own backdrop prompt with these changes, and no others:

- **The same room.** Same camera, same angle, same landmarks in the same places - the tree here, the well there, the bridge on the right. A player who knows the level should recognise it instantly. This is also what keeps the level card and the music honest.
- **Busy, not different.** The full density of an adult hidden object scene, half again the base rule above: more furniture, more foliage, more clutter on the surfaces that are already there.
- **Deeper foreground.** The base backdrop's near-foreground strip grows into real cover: taller grass, bigger crates, more of the frame's bottom edge overlapped, so the occlusion axis has room to hide half a prop instead of a sliver.
- **Stronger tonal variety.** The base backdrop varies tone mildly; here light and dark patches should alternate across the whole frame, because Seek and Hunt lean on camouflage placement hardest.
- **Every other rule unchanged.** Flat vector, thick outlines, bright even daylight, no deep shadow, nothing scary, only fixed scenery and no loose objects, no characters, no text.

Still no dark corners: dense is more to look at, never harder to see. A prop lost in shadow reads as unfair at any age, and the Hunt band is eleven, not adult.

## Decoy sheets

A decoy is a sprite in the room that is on no list and cannot be found.
It is the difficulty that comes from having to look at a thing and decide it is not the thing, which is searching rather than eyesight.

The placer takes decoys first from the props a band is not being asked to find, and at Hunt there are none, because Hunt is asked for everything the level has.
So a level that wants decoys at the top band ships a sheet of its own: six props from the same world, drawn to the sprite sheet rules above, listed under `decoys` in the build spec rather than `props`.

Pick things that belong in the room and are worth a second look - near-misses of real finds are ideal, and anything a child would name confidently is fine. They are never asked for, so they need no label discipline beyond being recognisable.

## Sprite sheet rules

- Exactly six props per sheet, in a 3x2 grid, evenly spaced, none touching or overlapping.
- Pure white background, `#FFFFFF`, because `tools/build_scene.py` cuts the background by flooding near-white from the tile border.
- No cast shadow, no ground plane, no reflection, said at that length: "NO drop shadow, NO cast shadow, NO shadow ellipse beneath the object". A baked shadow ruins a prop the moment it is placed on a wall or a shelf, and it doubles with the contact shadow the renderer draws under it. The short form of the ban is not enough - the station's first find sheet came back with a grey ellipse under all six props.
- Every prop fully inside its cell, complete silhouette, nothing cropped.
- One dominant colour per prop, and no two props in a world sharing it. That keeps them distinct on the backdrop and makes the find-by-colour mechanic possible without extra art.
- Thick dark outline on every prop, which is also what stops a pale prop from dissolving into the white sheet.
- The same flat cel rendering as the backdrops, said explicitly and negatively: fills the way a paint bucket fills a shape, one solid colour per part with at most one darker flat shape for shadow; no airbrush shading, no glossy shine, no white highlight blobs, no shiny dots, no rim light, no soft colour gradients, no 3D render look, no white sticker rim around the outline. Asked only for "flat vector" the model drifts toward glossy sticker art, and the short version of the ban is not enough on its own - the meadow sheets came back with specular highlights on the balloon and gradients in the crystal even with "NO glossy shine or highlights" in the prompt. A rounded, shiny prop on a flat cel room reads as pasted on from across the frame - it is the single biggest tell that a thing is findable.
- Colours bright and friendly but in the range the room itself uses, never neon. A prop should look like it was bought for the room, not lit from inside.
- Avoid white and near-white props. The cutter cannot tell them from the sheet, and a white bunny comes back with holes in it.
- No grid lines, borders or frames between the cells. `tools/build_scene.py` cuts each cell out and floods the near-white paper inwards from its border; a drawn line around the cell stops the flood dead and the sprite ships with a white block behind it. Say so in the prompt, in every sheet prompt including the plain ones - asked for a "3x2 grid" the model will sometimes draw the grid, and the meadow's two find sheets came back ruled into six boxes the first time the ban was left off them.

## Belonging

A find should look like part of the picture, the way a printed hidden object page works, and three things together make that true.
The sprite is rendered exactly like the room (the negative rules above).
The room offers pockets of decor a prop can sit inside instead of bare fields (the density rule above).
And the renderer grounds each resting prop with a soft contact shadow at runtime, which is why sprites must never bake one in.
That shadow has to be strong enough to read against flat cel art: the first pass drew it at a tenth of an opacity and it was invisible at play size, so it now sits at a third, twenty percent of the sprite's height, blurred by a quarter of that.
None of the three is optional: a glossy sprite, a bare field or a floating prop each breaks the illusion on its own.

## Object choice for the Look band (5-7)

- Every prop is something the child can already name without help.
- Eight to twelve per level.
- Nothing that needs a word they have not met: `spyglass` and `sextant` are fine for adults and wrong here.
- Prefer props that are obviously one thing, not a set. A single drum, not a drum kit; one block, not a pile.

## Per-world briefs

- [toy-room.md](toy-room.md) - world one.
- [space-station.md](space-station.md) - world five, the silhouette-match world.
- [rainbow-meadow.md](rainbow-meadow.md) - the unicorn world.
- [christmas-living-room.md](christmas-living-room.md) - seasonal, needs restyling to this document before it is built.

Legacy, written for the adult direction and kept for reference only: [pirate-ship-cabin.md](pirate-ship-cabin.md) (the MVP level, already built), [inventors-workshop.md](inventors-workshop.md).
