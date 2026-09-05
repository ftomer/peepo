# Pirate Ship Cabin - world zero

Level id `pirate_cabin`, the level the game opens on and the first thing anyone sees of it.
Style comes from [art-direction.md](art-direction.md) and is repeated inline below so the prompts can be generated straight from this file.

Twelve props, every one nameable by a five-year-old, each with its own dominant colour.

Restyled 2026-08-23.
The cabin was the MVP level and was drawn to the old painterly adult direction: a dim candlelit room at sunset, packed edge to edge, with `spyglass`, `sextant`, a jeweled dagger and a rum bottle among the things to find.
Three problems, in the order they matter.
It sits first in the level list next to two flat bright rooms, so the whole catalog looks like two games.
Half its props are words a five-year-old has not met, which [art-direction.md](art-direction.md) rules out by name.
And a **4+** listing does not want a rum bottle or a dagger in it, however cartoon the rendering ([kids-direction.md](../kids-direction.md)).

The old brief is in git history at `2f54681` if the painterly version is ever wanted back.

Generate with:

```bash
tools/scene.sh art docs/imgenprompts/pirate-ship-cabin.md
```

## Backdrop

```prompt
A bright cheerful pirate captain's cabin aboard a wooden sailing ship, background art for
a hidden object game for children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain NO
parrots, NO coins, NO rolled maps, charts, scrolls or parchment of any kind, NO pirate
hats, NO telescopes or spyglasses, NO anchors, NO starfish, NO shells, NO lanterns, NO toy
boats, NO octopuses and NO fish. Those are all added later as separate cut-out sprites,
and one of them painted into the scenery makes the real one impossible to find. Fill the
shelves and surfaces with plain wooden boxes, folded cloth, stacked planks, sealed barrels
and coiled rope instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The cabin is seen straight on from a gentle three-quarter angle, two wooden walls meeting
in a corner, a plank floor across the bottom third and a big round striped rug in the
middle.
On the left a tall open cupboard with two wide shelves and a ship's wheel mounted on
the wall above it. In the centre a heavy captain's desk with a large clear top, and behind
it a big open treasure chest, empty inside, with its lid propped up. On the right a wide
round stern window with bright blue sea, a clear sky and white clouds outside, blue
curtains tied back, a low bunk bed with a striped blanket, and a wooden crate beside it.
A row of triangular signal flags across the top of the wall.
The cabin is lived in rather than bare: the shelves and the crate carry everyday ship
things - wooden boxes, folded cloth, a stack of planks, a coil of rope, a small potted
plant - with visible gaps between them where one more small thing could sit, while the
rug, the desk top, the chest lid, the window sill, the bunk blanket and the bare floor
still keep open surfaces to rest something on.
Along the very bottom edge of the frame draw a shallow near foreground of two stacked
barrels and a low coil of thick rope, standing in front of the floor behind them, so that
things further back can be partly hidden by them.
Vary the tone across the picture: dark stained timber on the cupboard and the chest
against pale sunlit planking and a bright window, so the cabin is not one flat brown.
Bright even daylight everywhere, midday sun through the window, no dark corners, no
candles, no lanterns lit, no dramatic shadows, nothing scary.
Friendly and adventurous, not spooky: no skulls, no crossbones, no weapons, no bottles of
drink.
IMPORTANT: only fixed furniture and decor, no small loose objects lying around, those are
added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Sheet 1

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a green parrot with a yellow beak, a
round shiny gold coin, a rolled treasure map on cream paper tied with string, a navy blue
pirate hat with a gold trim and a red feather, a brown wooden telescope with brass rings,
a grey iron anchor.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range the cabin itself uses, never neon or glowing.
Each object fully visible inside its own cell, complete silhouette, nothing cropped,
neutral three-quarter angle, big simple readable shapes.
Blank surfaces, no letters or numbers anywhere, especially on the map.
Generic soft ambient lighting. Every object floats on empty white with nothing under it:
NO drop shadow, NO cast shadow, NO grey or coloured shadow ellipse beneath the object, NO
contact shadow of any kind, no ground plane, no reflections, no background elements. The
game draws its own shadow when it places the object, so one drawn here is one too many.
Do NOT draw the grid: no lines, no borders, no frames and no boxes between or around the
cells, just the six objects floating on one unbroken white field.
Plain solid pure white background #FFFFFF.
Ultra high resolution, sharp crisp linework.
No text, no watermarks.
```

Cells in reading order: `parrot`, `gold_coin`, `treasure_map`, `pirate_hat`, `telescope`, `anchor`.

## Sheet 2

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: an orange starfish, a pink spiral sea
shell, a red ship's lantern with a handle, a small blue toy sailing boat with a white
sail, a purple smiling cartoon octopus, a turquoise cartoon fish.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range the cabin itself uses, never neon or glowing.
Each object fully visible inside its own cell, complete silhouette, nothing cropped,
neutral three-quarter angle, big simple readable shapes.
Generic soft ambient lighting. Every object floats on empty white with nothing under it:
NO drop shadow, NO cast shadow, NO grey or coloured shadow ellipse beneath the object, NO
contact shadow of any kind, no ground plane, no reflections, no background elements. The
game draws its own shadow when it places the object, so one drawn here is one too many.
Do NOT draw the grid: no lines, no borders, no frames and no boxes between or around the
cells, just the six objects floating on one unbroken white field.
Plain solid pure white background #FFFFFF.
Ultra high resolution, sharp crisp linework.
No text, no watermarks.
```

Cells in reading order: `starfish`, `sea_shell`, `lantern`, `toy_boat`, `octopus`, `fish`.

## Props and labels

| Id | Label | Colour | Category |
| --- | --- | --- | --- |
| `parrot` | Parrot | green | animals |
| `gold_coin` | Gold Coin | gold | treasure |
| `treasure_map` | Treasure Map | cream | treasure |
| `pirate_hat` | Pirate Hat | navy | clothes |
| `telescope` | Telescope | brown | sailing |
| `anchor` | Anchor | grey | sailing |
| `starfish` | Starfish | orange | animals |
| `sea_shell` | Shell | pink | beach |
| `lantern` | Lantern | red | sailing |
| `toy_boat` | Little Boat | blue | sailing |
| `octopus` | Octopus | purple | animals |
| `fish` | Fish | turquoise | animals |

The colour and category columns are what the later find-by-colour and find-by-category asks read from, so keep them accurate to the art that actually comes back.

Four animals, four sailing things, two pieces of treasure: enough of each for a
find-by-category ask to have somewhere to go without the answer being obvious.

## What the build settled on

Two corrections to the meta, both about props that had no support under them.

The analyzer offered `wall_center` and `wall_above_bed`, two bare plank walls, as regions that support `hangs_on`.
Nothing is drawn on those walls to hang from - no hook, no peg, no shelf - so a hat or a rolled map placed there floated against flat timber and read as pasted onto the picture rather than left in the room.
Both regions are gone, and the only things a prop can hang from now are the ship's wheel, the cupboard door, the two curtains and the bed post.
The room still places all fourteen objects on all forty seeds `test/level_test.dart` tries, so the capacity was never the reason to keep them.

Two more rects ran wider than the furniture they described.
`chest_lid` was anchored at the top of the chest's open mouth, so a leaning prop hung in the air above it; it now starts at the chest rim.
`bed_pillow` reached three points further left than the pillow is drawn, which put anything resting on it against the bare wall beside the bed.

The lesson generalises: a region's rect is a promise that the surface is really there, and the placer believes it.

## Dense backdrop

The Seek and Hunt variant, per [art-direction.md](art-direction.md#dense-variants).
Same cabin, same viewpoint, same furniture where it is - roughly twice as much in it,
and a near foreground props can sit behind.

This level's brief above is legacy, written for the old adult direction; the variant
follows the current [art-direction.md](art-direction.md) style block like every other
level, so the two backdrops match each other and the rest of the catalog.

```prompt
The inside of a friendly pirate ship's cabin, background art for a hidden object game
for children aged eight to twelve.
STRICT RULE, more important than anything else below. This picture must contain absolutely
NO rolled scrolls, NO rolled paper, NO parchment, NO charts and NO maps of any kind, anywhere,
not on the shelves and not on the walls. Also NO parrots, NO coins, NO pirate hats, NO
telescopes or spyglasses, NO anchors, NO starfish, NO shells, NO lanterns, NO toy boats, NO
octopuses and NO fish. Every one of those is added later as a separate cut-out sprite, and one
painted into the scenery makes the real one impossible to find. Leave the shelves holding
plain wooden boxes, folded cloth and stacked planks instead of anything rolled up.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The cabin is seen straight on from a gentle three-quarter angle, two wooden walls
meeting in a corner, a plank floor across the bottom third and a big round striped rug in
the middle.
Keep every landmark exactly where it is: the tall open cupboard on the left with the
ship's wheel mounted above it, the heavy captain's desk in the centre with the big open
treasure chest behind it, the wide round stern window on the right with its blue curtains
tied back, the low bunk bed with its striped blanket beside the window, and the row of
triangular signal flags across the top of the wall.
Add to the cabin around them: more open
shelving with plain wooden boxes and folded cloth, stacked barrels and crates, a hanging
hammock, coiled rope and rigging, a cupboard with its doors open, a sea chest, a rack of
tools, netting draped in a corner, a small round table with a stool, a row of signal
flags.
Along the very bottom of the frame draw a near foreground of stacked barrels, a coil of
thick rope and a low crate, standing in front of the floor behind them, so that things
further back are partly hidden by them.
Vary the tone across the picture: dark stained timber and a dark chest against pale
sunlit planking and a bright porthole, so the cabin is not one flat brown.
Bright even daylight everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed furniture and decor, no small loose objects lying around, those
are added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Decoy sheet

Six cabin things that are never asked for, per [art-direction.md](art-direction.md#decoy-sheets).

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a brown wooden barrel, a green glass
message-in-a-bottle with a cork and a small rolled note visible inside it, a red compass
with a round face, a coil of tan rope, a gold hand bell, a blue and white striped
sailor's cap.
Each cell holds one single solid object and nothing else: no sparkles, no stars, no
glints, no specks. No white or near-white parts on any object.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range the cabin itself uses, never neon or glowing.
Each object fully visible inside its own cell, complete silhouette, nothing cropped,
neutral three-quarter angle, big simple readable shapes.
Generic soft ambient lighting. Every object floats on empty white with nothing under it:
NO drop shadow, NO cast shadow, NO grey or coloured shadow ellipse beneath the object, NO
contact shadow of any kind, no ground plane, no reflections, no background elements. The
game draws its own shadow when it places the object, so one drawn here is one too many.
Do NOT draw the grid: no lines, no borders, no frames and no boxes between or around the
cells, just the six objects floating on one unbroken white field.
Plain solid pure white background #FFFFFF.
Ultra high resolution, sharp crisp linework.
No text, no watermarks.
```

Cells in reading order: `barrel`, `bottle`, `compass`, `rope_coil`, `hand_bell`, `sailor_cap`.

## Plate look

The empty room the Peek and Look pictures are baked from: busy, but readable at five.
See [scene-pipeline.md](../scene-pipeline.md#the-other-shape-a-baked-scene).

```prompt
A bright cheerful pirate captain's cabin aboard a wooden sailing ship, background art for a hidden object game for
children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain
NO parrots, NO coins, NO rolled maps, charts, scrolls or parchment, NO pirate hats,
NO telescopes or spyglasses, NO anchors, NO starfish, NO shells, NO lanterns, NO toy boats,
NO octopuses and NO fish, anywhere. Those are added afterwards, and one of
them painted into the scenery makes the real one impossible to find. Use
plain wooden boxes, folded cloth, stacked planks, sealed barrels, coiled rope,
glass jars, hanging keys and tin mugs instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The cabin is seen straight on from a gentle three-quarter angle, two wooden walls meeting
in a corner, a plank floor across the bottom third and a big round striped rug in the
middle.
Keep every landmark: On the left a tall open cupboard with two wide shelves and a ship's wheel mounted above it.
In the centre a heavy captain's desk with a clear top, and behind it a big open treasure
chest with its lid propped up. On the right a wide round stern window with blue sea
outside, blue curtains tied back, a low bunk bed with a striped blanket and a wooden crate.
A row of triangular signal flags across the top of the wall.
The room is lived in and full of its own things, about as busy as a tidy child's bedroom:
a second wall of deep shelves packed with sealed barrels, crates, folded sailcloth, glass
jars and tin mugs, a rope net slung across the beams, a rack of hanging keys, a hammock, a
row of coat hooks, a barrel stack, a plank rack, a bucket and mop, a rolled hammock, a
chart table with weights on it, and lanternless brass fittings along the beams.
Every shelf holds something and no wall or patch of ground is bare, but each thing has room
around it: a five year old has to be able to tell one object from the next at arm's length.
Along the bottom of the frame draw a near foreground of a barrel, a stack of crates, a coil of rope and a wooden bucket, standing in front of
what is behind them.
Vary the tone across the picture, so it is not one flat tone.
Bright even lighting everywhere, no dark ceiling, nothing gloomy and nothing scary.
IMPORTANT: only fixed fittings, stores and decor, no small loose objects lying around, those
are added afterwards.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Plate hunt

The empty room the Seek and Hunt pictures are baked from: three to four times as packed,
with a layered, partly see-through foreground for finds to hide behind.

```prompt
A bright cheerful pirate captain's cabin aboard a wooden sailing ship, background art for a hidden object game for
children aged eight to twelve, as densely packed as a grown-up "find the hidden
objects" page.
STRICT RULE, more important than anything else below: this picture must contain
NO parrots, NO coins, NO rolled maps, charts, scrolls or parchment, NO pirate hats,
NO telescopes or spyglasses, NO anchors, NO starfish, NO shells, NO lanterns, NO toy boats,
NO octopuses and NO fish, anywhere. Those are added afterwards, and one of
them painted into the scenery makes the real one impossible to find. Use
plain wooden boxes, folded cloth, stacked planks, sealed barrels, coiled rope,
glass jars, hanging keys and tin mugs instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The cabin is seen straight on from a gentle three-quarter angle, two wooden walls meeting
in a corner, a plank floor across the bottom third and a big round striped rug in the
middle.
Keep every landmark: On the left a tall open cupboard with two wide shelves and a ship's wheel mounted above it.
In the centre a heavy captain's desk with a clear top, and behind it a big open treasure
chest with its lid propped up. On the right a wide round stern window with blue sea
outside, blue curtains tied back, a low bunk bed with a striped blanket and a wooden crate.
A row of triangular signal flags across the top of the wall.
Fill it: a second wall of deep shelves packed with sealed barrels, crates, folded sailcloth, glass
jars and tin mugs, a rope net slung across the beams, a rack of hanging keys, a hammock, a
row of coat hooks, a barrel stack, a plank rack, a bucket and mop, a rolled hammock, a
chart table with weights on it, and lanternless brass fittings along the beams. Every shelf, ledge and surface is packed end to end, and the walls carry
things too.
Draw the small things small: a picture crowded with hand-sized objects rather than a few big
ones, dozens of separate items, so that one more object among them would not stand out.
Layer the depth. Along the bottom third build a near foreground of a barrel, a stack of crates, a coil of rope and a wooden bucket, and make
some of it see-through - railings, netting, a wire basket, rungs, stems - so what is behind
shows in the gaps and anything standing there is partly covered.
Vary the tone across the picture: deep shadowed corners and dark recesses against pale
surfaces and bright ground, so there are places a dark thing can sink into and places a
light thing can.
Bright even lighting everywhere, no dark ceiling, nothing gloomy and nothing scary.
IMPORTANT: only fixed fittings, stores and decor, no small loose objects lying around, those
are added afterwards.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Baked look

Four pictures for Peek and Look, drawn from [Plate look](#plate-look): fourteen finds each,
two of the twelve twice.

```bash
tools/scene.sh art docs/imgenprompts/pirate-ship-cabin.md --only "Baked look" --takes 4 \
               --from rawimages/pirate_ship_cabin/plate_look.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these fourteen objects added into it
and nothing else altered:
1. a green parrot with a red beak
2. a round gold coin
3. a rolled cream treasure map tied with string
4. a navy pirate hat with a skull badge
5. a brown telescope
6. a grey anchor
7. an orange starfish
8. a pink spiral sea shell
9. a red ship lantern
10. a small blue toy sailing boat
11. a purple octopus with curled arms
12. a turquoise fish
13. a second round gold coin, somewhere else entirely
14. a second orange starfish, somewhere else entirely

Do not redraw, move, recolour or restyle anything already in the picture: every wall, shelf,
box, surface, fitting and piece of decor must come back exactly as it is, in the same place,
at the same size, in the same colours. Only the fourteen objects are new.
Each is drawn in the picture's own style - the same thick dark outline of the same weight,
the same flat cel colours, the same single soft shadow tone - with the picture's own soft
shadow under it where it rests, so it reads as painted into the picture rather than pasted
on top of it.
Each is about as wide as one of the boxes already on the shelves, roughly a fourteenth of
the picture across.
Each is left where that thing would plausibly be left, among the room's own things: on a
shelf, on a table, in a basket, on the rug, on a chair, on a ledge. None of them stands
alone in the middle of an empty patch of floor, ground or wall.
Four or five of the fourteen are partly behind something already in the picture, so only
part of each shows.
No two of the fourteen touch or overlap each other, and none is cut off by the edge of the
frame.
No text, no letters, no numbers, no people, no watermarks.
```

## Baked hunt

Four pictures for Seek and Hunt, drawn from [Plate hunt](#plate-hunt): twenty finds each,
eight of the twelve twice, all of them small.

```bash
tools/scene.sh art docs/imgenprompts/pirate-ship-cabin.md --only "Baked hunt" --takes 4 \
               --from rawimages/pirate_ship_cabin/plate_hunt.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these twenty objects added into it
and nothing else altered:
1. a green parrot with a red beak
2. a round gold coin
3. a rolled cream treasure map tied with string
4. a navy pirate hat with a skull badge
5. a brown telescope
6. a grey anchor
7. an orange starfish
8. a pink spiral sea shell
9. a red ship lantern
10. a small blue toy sailing boat
11. a purple octopus with curled arms
12. a turquoise fish
13. a second round gold coin
14. a second orange starfish
15. a second pink sea shell
16. a second turquoise fish
17. a second green parrot
18. a second blue toy boat
19. a second grey anchor
20. a second purple octopus

Do not redraw, move, recolour or restyle anything already in the picture: every wall, shelf,
box, surface, fitting and piece of decor must come back exactly as it is, in the same place,
at the same size, in the same colours. Only the twenty objects are new.
Each is drawn in the picture's own style - the same thick dark outline of the same weight,
the same flat cel colours, the same single soft shadow tone - with the picture's own soft
shadow under it where it rests, so it reads as painted into the picture rather than pasted
on top of it.
Draw them SMALL: each object is about a twentieth of the picture across, the size of the
smallest things already in the room, never bigger than one of the boxes. A child of eleven
should have to look for them.
Each goes deep among the room's own things, where a real object would end up: pushed to the
back of a shelf, half inside a basket, behind the jars, under a table, tucked into netting,
between folded cloth, behind the foreground clutter, on top of a cupboard. None of them
stands alone on an empty patch of floor, ground or wall.
At least twelve of the twenty are partly hidden behind something already in the picture, so
only part of each one shows - but never hide one completely: a piece of every object stays
visible.
No two of the twenty touch or overlap each other, and none is cut off by the edge of the
frame.
No text, no letters, no numbers, no people, no watermarks.
```
