# Rainbow Meadow - unicorns and rainbows

Level id `rainbow_meadow`, a unicorn world for the kids catalog ([kids-direction.md](../kids-direction.md#catalog)).
Style comes from [art-direction.md](art-direction.md) and is repeated inline below so the prompts can be generated straight from this file.

Twelve props, every one nameable by a five-year-old, each with its own dominant colour.
The rainbow itself is painted into the backdrop, not hidden: a child looking for a rainbow in a rainbow scene is looking for the scenery.

Generate with:

```bash
tools/scene.sh art docs/imgenprompts/rainbow-meadow.md
```

## Backdrop

```prompt
A bright magical unicorn meadow under a big rainbow, background art for a hidden object
game for children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain NO
clover, NO shamrock leaves, NO butterflies, NO sunflowers, NO horseshoes, NO crystals or
gems, NO balloons, NO magic wands, NO lollipops, NO unicorns, NO unicorn horns, NO boots,
NO hedgehogs. Those are all added later as separate cut-out sprites, and one of them
painted into the scenery makes the real one impossible to find. Use tulips, long grass,
ferns, leafy bushes, hedges and reeds for greenery instead - never clover.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The meadow is seen straight on from a gentle three-quarter angle, rolling green hills
across the middle and a wide grassy foreground along the bottom third.
A huge rainbow arcs over the whole sky from the left hill to the right hill, with a few
fat round clouds and a pale pink castle with pointed turrets small in the distance.
On the left a wooden fence with a flat top rail, a big flat tree stump beside a round
leafy tree, and a flower bed of simple tulips. In the centre a checked picnic blanket
laid flat on the grass, a low wooden cart with an empty flat bed, and a small stone
well. On the right a little arched wooden bridge over a blue stream, three round
stepping stones, a hay bale and a striped market stall with an empty flat counter.
The meadow is lived in rather than bare: clumps of tulips, patches of tall grass, a few
low leafy bushes, round stones and a stack of flowerpots by the stall, with visible gaps
between them where one more small thing could sit, while the blanket, the stump, the
fence rail, the cart bed, the well rim, the bridge deck, the stall counter and the hay
bale still keep open surfaces to rest something on.
Along the very bottom edge of the frame draw a shallow near foreground of tall grass,
leafy ferns and a low flowering bush, standing in front of the lawn behind them, so that
things further back can be partly hidden by them.
Vary the greens across the picture: darker shaded grass under the tree and beside the
bushes, bright light lawn in the open, a sandy path and grey stones, so the meadow is
not one flat tone.
Bright even daylight everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed scenery and plants, no small loose objects lying around and no
unicorns, those are added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no animals, no text, no letters, no numbers, no watermarks.
```

## Sheet 1

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a pink cuddly toy unicorn standing
side on, a gold spiral unicorn horn, a magic wand with a purple stick and a purple star on the tip, no yellow on it, a
rainbow striped swirl lollipop on a stick, a red heart shaped balloon with a string, a
blue crystal gem.
Each cell holds one single solid object and nothing else: no sparkles, no stars, no
glints, no specks, no motion lines floating around it.
No white or near-white parts on any object: the unicorn's muzzle, mane and hooves are
pink, not white, and the balloon string is brown.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range the meadow itself uses, never neon or glowing.
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

Cells in reading order: `unicorn_toy`, `unicorn_horn`, `magic_wand`, `rainbow_lollipop`, `heart_balloon`, `crystal`.

## Sheet 2

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a silver horseshoe, an orange
butterfly with open wings seen from above, a yellow sunflower with a stem and two
leaves, a green four leaf clover, one single teal rubber rain boot standing upright
with a teal sole, a brown hedgehog seen from the side.
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
Bright friendly colours in the range the meadow itself uses, never neon or glowing.
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

Cells in reading order: `horseshoe`, `butterfly`, `sunflower`, `clover`, `rain_boot`, `hedgehog`.

## Dense backdrop

The Seek and Hunt variant, per [art-direction.md](art-direction.md#dense-variants).
The same meadow from the same viewpoint, with the same landmarks in the same places, but twice as much in it and a near foreground props can sit behind.
The flat lawn across the bottom third is the whole problem: it is a third of the frame with nothing in it, so a sprite there is the only object in a green field however small it is drawn.

```prompt
A bright magical unicorn meadow under a big rainbow, background art for a hidden object
game for children aged eight to twelve.
STRICT RULE, more important than anything else below: this picture must contain NO clover,
NO shamrock, NO three or four leaf clover leaves, NO daisies, NO mushrooms, NO toadstools,
NO butterflies, NO sunflowers, NO horseshoes, NO crystals or gems, NO balloons, NO wands,
NO lollipops, NO unicorns, NO unicorn horns, NO boots, NO hedgehogs, NO watering cans, NO
picnic baskets, NO birds' nests. Those are all added later as separate cut-out sprites, and
one of them painted into the scenery makes the real one impossible to find. Use tulips,
long grass, ferns, leafy bushes, hedges and reeds for greenery instead - never clover.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The meadow is seen straight on from a gentle three-quarter angle, rolling green hills
across the middle and a grassy foreground along the bottom third.
A huge rainbow arcs over the whole sky from the left hill to the right hill, with fat
round clouds and a pale pink castle with pointed turrets small in the distance.
Keep every landmark exactly where it is: on the left a wooden fence with a flat top
rail, a big flat tree stump beside a round leafy tree, and a flower bed of tulips; in
the centre a checked picnic blanket laid flat on the grass, a low wooden cart with an
open bed, and a small stone well; on the right a little arched wooden bridge over a
blue stream, three round stepping stones, a hay bale and a striped market stall.
Fill the meadow around them so it is busy rather than bare, about as busy as a grown
up's puzzle picture: more tulips and daisies in clumps across the lawn, patches of tall
grass and clover, low leafy bushes and a hedge, a second smaller tree, mushrooms and
round stones, wooden crates and a stack of flowerpots by the stall, a coil of rope and
a watering can by the well, bunting between the fence posts, more hay bales, a garden
trellis with climbing flowers, lily pads along the stream.
Along the very bottom of the frame draw a band of tall grass, leafy ferns and flowering
bushes in the near foreground, standing in front of the lawn behind them, so that
things further back are partly hidden by them.
Vary the greens across the picture: dark shaded grass under the tree and the hedge,
bright light lawn in the open, sandy path and grey stones, so the meadow is not one
flat tone.
Bright even daylight everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed scenery and plants, no small loose objects lying around and no
unicorns, those are added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no animals, no text, no letters, no numbers, no watermarks.
```

The meta file for this backdrop is authored fresh - region ids need not match the
authored scene's, because each variant ships its own `scene.*.json` with its own region
lists. Give the near-foreground band its own regions and put every region behind it in
their `occludedBy`: that near strip is the only thing in this level that can cover
anything, and without it the occlusion axis stays switched off here.

## Decoy sheet

Six meadow things that are never asked for, per [art-direction.md](art-direction.md#decoy-sheets).
Two of them are deliberate near-misses of real finds - a pink cosmos against the sunflower, a
plain pebble against the crystal - because a decoy worth having is one that costs a
second look.

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a pink cosmos flower with a yellow
centre, a stem and two leaves, a smooth grey river pebble, a red spotted toadstool mushroom, a
brown woven picnic basket, a green watering can, a small brown bird's nest with no eggs
in it.
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
Bright friendly colours in the range the meadow itself uses, never neon or glowing.
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

Cells in reading order: `pink_flower`, `pebble`, `toadstool`, `picnic_basket`, `watering_can`, `birds_nest`.

## Props and labels

| Id | Label | Colour | Category |
| --- | --- | --- | --- |
| `unicorn_toy` | Unicorn | pink | animals |
| `unicorn_horn` | Unicorn Horn | gold | magic |
| `magic_wand` | Magic Wand | purple | magic |
| `rainbow_lollipop` | Lollipop | rainbow | food |
| `heart_balloon` | Heart Balloon | red | flying |
| `crystal` | Crystal | blue | magic |
| `horseshoe` | Horseshoe | silver | - |
| `butterfly` | Butterfly | orange | flying |
| `sunflower` | Sunflower | yellow | plants |
| `clover` | Clover | green | plants |
| `rain_boot` | Rain Boot | teal | - |
| `hedgehog` | Hedgehog | brown | animals |

The colour and category columns are what the later find-by-colour and find-by-category asks read from, so keep them accurate to the art that actually comes back.

## What the build settled on

Three things the first previews caught, all of them in the meta file rather than the art.

The analyzer gave the two distant hillsides their own regions.
A prop resting there is drawn against open sky above the horizon, so the lollipop and the crystal appeared to hang in the air; both regions were deleted and every prop's region list re-derived without them.

Both hay bale regions were pinned over the market stall to their right, and the stall counter's rest line sat on the counter's front panel rather than its top edge.
The fence rail and the stump rested about a tenth of the frame below the surface a prop actually stands on.
All five were measured off the backdrop and corrected.

The tree canopy accepted `tucked_in`, and the placer only asks that a prop's centre be inside a region, so a boot tucked at the canopy's edge hung half of itself in the sky.
The canopy now takes `hangs_on` only - a balloon on a string is the one prop that reads correctly there - and its outline is pulled in to 82% so a hanging prop still starts among leaves.

The horn is the one prop with its own width ceiling, 0.06 against the room's 0.13.
It is three times as tall as it is wide, so at a width the other props wear comfortably it filled a third of the frame.

## Plate look

The empty room the Peek and Look pictures are baked from: busy, but readable at five.
See [scene-pipeline.md](../scene-pipeline.md#the-other-shape-a-baked-scene).

```prompt
A bright magical unicorn meadow under a big rainbow, background art for a hidden object game for
children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain
NO clover or shamrock leaves, NO butterflies, NO sunflowers, NO horseshoes, NO crystals
or gems, NO balloons, NO magic wands, NO lollipops, NO unicorns, NO unicorn horns, NO boots
and NO hedgehogs, anywhere. Those are added afterwards, and one of
them painted into the scenery makes the real one impossible to find. Use
tulips, daisies, long grass, ferns, leafy bushes, hedges, reeds, round stones,
flowerpots and wooden crates instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The meadow is seen straight on from a gentle three-quarter angle, rolling green hills
across the middle and a wide grassy foreground along the bottom third. A huge rainbow arcs
over the sky from the left hill to the right, with fat round clouds and a small pale pink
castle in the distance.
Keep every landmark: On the left a wooden fence with a flat top rail, a big flat tree stump beside a round leafy
tree, and a bed of tulips. In the centre a checked picnic blanket laid flat, a low wooden
cart with a flat bed, and a small stone well. On the right a little arched bridge over a
blue stream, three round stepping stones, a hay bale and a striped market stall with a flat
counter.
The room is lived in and full of its own things, about as busy as a tidy child's bedroom:
a second flower bed, a row of beehives, a washing line strung with bunting, a wheelbarrow
of flowerpots, stacked crates of vegetables, a watering can, garden tools leaning on the
fence, a bird table, a log pile, hanging baskets on the stall, more hay bales and dense
clumps of ferns, reeds and tall grass.
Every shelf holds something and no wall or patch of ground is bare, but each thing has room
around it: a five year old has to be able to tell one object from the next at arm's length.
Along the bottom of the frame draw a near foreground of long grass, ferns, a low hedge, a wooden crate and a scattering of round stones, standing in front of
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
A bright magical unicorn meadow under a big rainbow, background art for a hidden object game for
children aged eight to twelve, as densely packed as a grown-up "find the hidden
objects" page.
STRICT RULE, more important than anything else below: this picture must contain
NO clover or shamrock leaves, NO butterflies, NO sunflowers, NO horseshoes, NO crystals
or gems, NO balloons, NO magic wands, NO lollipops, NO unicorns, NO unicorn horns, NO boots
and NO hedgehogs, anywhere. Those are added afterwards, and one of
them painted into the scenery makes the real one impossible to find. Use
tulips, daisies, long grass, ferns, leafy bushes, hedges, reeds, round stones,
flowerpots and wooden crates instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The meadow is seen straight on from a gentle three-quarter angle, rolling green hills
across the middle and a wide grassy foreground along the bottom third. A huge rainbow arcs
over the sky from the left hill to the right, with fat round clouds and a small pale pink
castle in the distance.
Keep every landmark: On the left a wooden fence with a flat top rail, a big flat tree stump beside a round leafy
tree, and a bed of tulips. In the centre a checked picnic blanket laid flat, a low wooden
cart with a flat bed, and a small stone well. On the right a little arched bridge over a
blue stream, three round stepping stones, a hay bale and a striped market stall with a flat
counter.
Fill it: a second flower bed, a row of beehives, a washing line strung with bunting, a wheelbarrow
of flowerpots, stacked crates of vegetables, a watering can, garden tools leaning on the
fence, a bird table, a log pile, hanging baskets on the stall, more hay bales and dense
clumps of ferns, reeds and tall grass. Every shelf, ledge and surface is packed end to end, and the walls carry
things too.
Draw the small things small: a picture crowded with hand-sized objects rather than a few big
ones, dozens of separate items, so that one more object among them would not stand out.
Layer the depth. Along the bottom third build a near foreground of long grass, ferns, a low hedge, a wooden crate and a scattering of round stones, and make
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
tools/scene.sh art docs/imgenprompts/rainbow-meadow.md --only "Baked look" --takes 4 \
               --from rawimages/rainbow_meadow/plate_look.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these fourteen objects added into it
and nothing else altered:
1. a small pink toy unicorn with a white mane
2. a gold unicorn horn, a spiral cone
3. a purple magic wand with a yellow star on top
4. a rainbow swirl lollipop on a stick
5. a red heart-shaped balloon on a string
6. a blue crystal gem with flat faces
7. a silver horseshoe
8. an orange butterfly with open wings
9. a yellow sunflower with a brown centre
10. a green four-leaf clover
11. a teal rain boot
12. a small brown hedgehog
13. a second green four-leaf clover, somewhere else entirely
14. a second orange butterfly, somewhere else entirely

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
tools/scene.sh art docs/imgenprompts/rainbow-meadow.md --only "Baked hunt" --takes 4 \
               --from rawimages/rainbow_meadow/plate_hunt.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these twenty objects added into it
and nothing else altered:
1. a small pink toy unicorn with a white mane
2. a gold unicorn horn, a spiral cone
3. a purple magic wand with a yellow star on top
4. a rainbow swirl lollipop on a stick
5. a red heart-shaped balloon on a string
6. a blue crystal gem with flat faces
7. a silver horseshoe
8. an orange butterfly with open wings
9. a yellow sunflower with a brown centre
10. a green four-leaf clover
11. a teal rain boot
12. a small brown hedgehog
13. a second green four-leaf clover
14. a second orange butterfly
15. a second silver horseshoe
16. a second blue crystal gem
17. a second yellow sunflower
18. a second gold unicorn horn
19. a second rainbow lollipop
20. a second red heart balloon

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
