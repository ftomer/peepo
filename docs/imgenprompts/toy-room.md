# Toy Room - world one

Level id `toy_room`, first world of the kids catalog ([kids-direction.md](../kids-direction.md#catalog)).
Style comes from [art-direction.md](art-direction.md) and is repeated inline below so the prompts can be generated straight from this file.

Twelve props, every one nameable by a five-year-old, each with its own dominant colour.

Generate with:

```bash
tools/scene.sh art docs/imgenprompts/toy-room.md
```

## Backdrop

```prompt
A bright cheerful children's toy room, background art for a hidden object game for
children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain NO toy
cars, NO rubber ducks, NO balls, NO toy dinosaurs, NO teddy bears or soft toys, NO
xylophones, NO toy robots, NO kites, NO skipping ropes, NO drums, NO spinning tops, NO
trumpets or horns. Those are all added later as separate cut-out sprites, and one of
them painted into the scenery makes the real one impossible to find. Fill shelves and
surfaces with books, folded blankets, storage baskets, board game boxes and plants
instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two walls meeting in a
corner, a wooden floor across the bottom third and a large round rug with a simple bold
pattern in the middle.
On the left a low open toy shelf with coloured bins, rows of picture books and a folded
blanket, and a big wooden toy box with its lid propped open. In the centre a small
round play table with two little chairs, and behind it a play tent shaped like a
castle. On the right a window with a sunny sky and a rainbow outside, yellow curtains,
a low bookshelf with picture books standing upright with a few gaps between them, and a
green beanbag chair. Bunting flags across the top of the wall, a few simple animal wall
stickers, a small pinboard with paper shapes, and two empty wall hooks.
The room is comfortably lived in rather than empty: shelves and sills carry everyday
decor - books, baskets, folded cloth, a potted plant - with visible gaps in the decor
where one more small thing could sit, while the rug, the table top, the toy box lid and
the floor still keep open space to rest something on.
Along the very bottom edge of the frame draw a shallow near foreground of two floor
cushions and the corner of an open toy crate, standing in front of the floor behind
them, so that things further back can be partly hidden by them.
Vary the tone gently across the picture: warm wooden floor and a deep-coloured rug
against paler walls, so the room is not one flat tone.
Bright even daylight everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed furniture and decor, no small loose toys or objects lying around,
those are added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Sheet 1

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a red toy car, a yellow rubber duck,
a blue bouncy ball with a white star on it, a green toy dinosaur, a brown teddy bear,
a rainbow coloured xylophone with a wooden beater.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range a children's room uses, never neon or glowing.
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

Cells in reading order: `toy_car`, `rubber_duck`, `star_ball`, `toy_dinosaur`, `teddy_bear`, `toy_xylophone`.

## Sheet 2

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a silver and blue toy robot, a red
diamond kite with a ribbon tail, a pink skipping rope with wooden handles, an orange toy
drum with two sticks, a purple spinning top, a gold toy trumpet.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range a children's room uses, never neon or glowing.
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

Cells in reading order: `toy_robot`, `kite`, `jump_rope`, `toy_drum`, `spinning_top`, `toy_trumpet`.

## Props and labels

| Id | Label | Colour | Category |
| --- | --- | --- | --- |
| `toy_car` | Toy Car | red | wheels |
| `rubber_duck` | Rubber Duck | yellow | animals |
| `star_ball` | Bouncy Ball | blue | round |
| `toy_dinosaur` | Toy Dinosaur | green | animals |
| `teddy_bear` | Teddy Bear | brown | animals |
| `toy_xylophone` | Xylophone | rainbow | music |
| `toy_robot` | Toy Robot | silver | - |
| `kite` | Kite | red | flying |
| `jump_rope` | Skipping Rope | pink | - |
| `toy_drum` | Drum | orange | music |
| `spinning_top` | Spinning Top | purple | round |
| `toy_trumpet` | Trumpet | gold | music |

The colour and category columns are what the later find-by-colour and find-by-category asks read from, so keep them accurate to the art that actually comes back.

## What the build settled on

Prop widths ended at 0.055 to 0.12 of scene width, and the room's regions at a 0.045 floor and a 0.13 cap.
The first pass ran wider, 0.09 to 0.15, and the level could only place nine or ten of the twelve props: one prop that wide fills a whole shelf, so the room ran out of legal spots.
Breadth matters as much as size: the kite started out able to hang on two curtains and two castle corners only, and the xylophone, trumpet and rope were the widest props while being restricted to five or six regions each, so they took the good surfaces and stranded whatever came after them.
Giving those four more regions is what took the level from eleven objects on the occasional seed to twelve on all forty tried.
That is the test that matters, and `test/level_test.dart` enforces it.

## Dense backdrop

The Seek and Hunt variant, per [art-direction.md](art-direction.md#dense-variants).
Same playroom, same viewpoint, same furniture where it is - roughly twice as much in it,
and a near foreground props can sit behind.

```prompt
A bright cheerful children's playroom, background art for a hidden object game for
children aged eight to twelve.
STRICT RULE, more important than anything else below: this picture must contain NO toy
cars, NO rubber ducks, NO balls, NO toy dinosaurs, NO teddy bears or soft toys, NO
xylophones, NO toy robots, NO kites, NO skipping ropes, NO drums, NO spinning tops, NO
trumpets or horns, NO fire engines, NO watering cans, NO toy telephones, NO pinwheels, NO
loose wooden blocks. Those are all added later as separate cut-out sprites, and one of them
painted into the scenery makes the real one impossible to find. Fill the shelves and bins
with books, folded blankets, storage baskets, board game boxes and plants instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, with a wooden floor, a
round rug, and shelving along the walls.
Keep every landmark exactly where it is and add to the room around them: more open
shelving with rows of boxes and bins, a low toy chest, a bookcase packed with books, a
play table with chairs, a rail of dressing up clothes, a cork board with paper shapes
pinned to it, a rug with a bold pattern, cushions and a beanbag, a stack of board game
boxes, potted plants, a play tent in the corner.
Along the very bottom of the frame draw a near foreground of stacked cushions, an open
toy crate and the back of a low armchair, standing in front of the floor behind them,
so that things further back are partly hidden by them.
Vary the tone across the picture: a dark bookcase and a dark rug against pale walls and
a light wooden floor, so the room is not one flat tone.
Bright even daylight everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed furniture and decor, no small loose toys lying around, those are
added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Decoy sheet

Six playroom things that are never asked for, per [art-direction.md](art-direction.md#decoy-sheets).

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a red toy fire engine, a purple
skipping ball with a handle, a stack of three coloured wooden blocks, a green toy
watering can, a blue toy telephone, an orange spinning windmill on a stick.
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
Bright friendly colours in the range a children's room uses, never neon or glowing.
Each object fully visible inside its own cell, complete silhouette, nothing cropped,
neutral three-quarter angle, big simple readable shapes.
Think of the picture as three equal columns and two equal rows, and draw each object well
inside its own box: every object must be surrounded by empty white on all four sides, and
no part of any object may come near the invisible line where its box ends. Draw the wide
objects - the fire engine and the ball with its cord - noticeably smaller than the others
so they still sit clear of their neighbours.
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

Cells in reading order: `fire_engine`, `skipping_ball`, `wooden_blocks`, `toy_watering_can`, `toy_phone`, `pinwheel`.

## Plate look

The empty room the Peek and Look pictures are baked from: busy, but readable at five.
See [scene-pipeline.md](../scene-pipeline.md#the-other-shape-a-baked-scene).

```prompt
A bright cheerful children's toy room, background art for a hidden object game for
children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain
NO toy cars, NO rubber ducks, NO balls, NO toy dinosaurs, NO teddy bears or soft toys,
NO xylophones, NO toy robots, NO kites, NO skipping ropes, NO drums, NO spinning tops and
NO trumpets or horns, anywhere. Those are added afterwards, and one of
them painted into the scenery makes the real one impossible to find. Use
books, folded blankets, storage baskets, board game boxes, stacking cups, wooden
bricks, jigsaw boxes and potted plants instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two walls meeting in a
corner, a wooden floor across the bottom third and a large round rug with a bold simple
pattern in the middle.
Keep every landmark: On the left a low open toy shelf with coloured bins and rows of picture books, and a big
wooden toy box with its lid propped open. In the centre a small round play table with two
little chairs, and behind it a play tent shaped like a castle. On the right a window with
a sunny sky and a rainbow outside, yellow curtains, a low bookshelf and a green beanbag
chair. Bunting flags across the top of the wall.
The room is lived in and full of its own things, about as busy as a tidy child's bedroom:
a tall shelving unit of open cubbies packed with baskets, folded jumpers, board game
boxes and stacking cups, a pegboard hung with dressing-up clothes, a craft table with pots
of pencils and rolls of paper, a laundry basket, a row of wall hooks, a rail of hanging
bags, a doll's house, a bookcase filled end to end, and cushions and blankets heaped on the
rug.
Every shelf holds something and no wall or patch of ground is bare, but each thing has room
around it: a five year old has to be able to tell one object from the next at arm's length.
Along the bottom of the frame draw a near foreground of a wooden toy crate, a low stool, a laundry basket and a folded play mat, standing in front of
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
A bright cheerful children's toy room, background art for a hidden object game for
children aged eight to twelve, as densely packed as a grown-up "find the hidden
objects" page.
STRICT RULE, more important than anything else below: this picture must contain
NO toy cars, NO rubber ducks, NO balls, NO toy dinosaurs, NO teddy bears or soft toys,
NO xylophones, NO toy robots, NO kites, NO skipping ropes, NO drums, NO spinning tops and
NO trumpets or horns, anywhere. Those are added afterwards, and one of
them painted into the scenery makes the real one impossible to find. Use
books, folded blankets, storage baskets, board game boxes, stacking cups, wooden
bricks, jigsaw boxes and potted plants instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two walls meeting in a
corner, a wooden floor across the bottom third and a large round rug with a bold simple
pattern in the middle.
Keep every landmark: On the left a low open toy shelf with coloured bins and rows of picture books, and a big
wooden toy box with its lid propped open. In the centre a small round play table with two
little chairs, and behind it a play tent shaped like a castle. On the right a window with
a sunny sky and a rainbow outside, yellow curtains, a low bookshelf and a green beanbag
chair. Bunting flags across the top of the wall.
Fill it: a tall shelving unit of open cubbies packed with baskets, folded jumpers, board game
boxes and stacking cups, a pegboard hung with dressing-up clothes, a craft table with pots
of pencils and rolls of paper, a laundry basket, a row of wall hooks, a rail of hanging
bags, a doll's house, a bookcase filled end to end, and cushions and blankets heaped on the
rug. Every shelf, ledge and surface is packed end to end, and the walls carry
things too.
Draw the small things small: a picture crowded with hand-sized objects rather than a few big
ones, dozens of separate items, so that one more object among them would not stand out.
Layer the depth. Along the bottom third build a near foreground of a wooden toy crate, a low stool, a laundry basket and a folded play mat, and make
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
tools/scene.sh art docs/imgenprompts/toy-room.md --only "Baked look" --takes 4 \
               --from rawimages/toy_room/plate_look.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these fourteen objects added into it
and nothing else altered:
1. a small red toy car with round wheels
2. a yellow rubber duck with an orange beak
3. a blue bouncy ball with a white star on it
4. a green toy dinosaur with a friendly face
5. a brown teddy bear sitting up
6. a xylophone with coloured bars and a beater
7. a silver toy robot with square eyes
8. a red kite with a ribbon tail
9. a coiled pink skipping rope with wooden handles
10. an orange toy drum with two sticks
11. a purple spinning top
12. a gold toy trumpet
13. a second blue bouncy ball, somewhere else entirely
14. a second purple spinning top, somewhere else entirely

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
tools/scene.sh art docs/imgenprompts/toy-room.md --only "Baked hunt" --takes 4 \
               --from rawimages/toy_room/plate_hunt.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these twenty objects added into it
and nothing else altered:
1. a small red toy car with round wheels
2. a yellow rubber duck with an orange beak
3. a blue bouncy ball with a white star on it
4. a green toy dinosaur with a friendly face
5. a brown teddy bear sitting up
6. a xylophone with coloured bars and a beater
7. a silver toy robot with square eyes
8. a red kite with a ribbon tail
9. a coiled pink skipping rope with wooden handles
10. an orange toy drum with two sticks
11. a purple spinning top
12. a gold toy trumpet
13. a second blue bouncy ball
14. a second purple spinning top
15. a second yellow rubber duck
16. a second red toy car
17. a second green toy dinosaur
18. a second gold toy trumpet
19. a second orange toy drum
20. a second silver toy robot

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
