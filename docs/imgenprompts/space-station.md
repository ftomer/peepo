# Space Station - world five

Level id `space_station`, first level of the Space world ([kids-direction.md](../kids-direction.md#catalog)).
Style comes from [art-direction.md](art-direction.md) and is repeated inline below so the prompts can be generated straight from this file.

Twelve props, every one nameable by a five-year-old, each with its own dominant colour.
Space is where the silhouette-match ask lands, so every prop is chosen for a shape a child can recognise as an outline: a rocket, a boot, a wrench, a saucer.

Generate with:

```bash
tools/scene.sh art docs/imgenprompts/space-station.md
```

## Backdrop

```prompt
A bright cheerful cartoon space station room, background art for a hidden object game for
children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain NO
rockets, NO space helmets, NO stars, NO ringed planets or planet models, NO aliens, NO
moon rocks, NO moon buggies or rovers, NO boots, NO jetpacks, NO spanners or wrenches, NO
flying saucers, NO walkie talkies or handsets. Those are all added later as separate
cut-out sprites, and one of them painted into the scenery makes the real one impossible
to find. Fill the shelves and surfaces with plain storage crates, stacked supply boxes,
folded blankets, cable coils, drink pouches and potted plants instead. Outside the
porthole draw only a smiling crescent moon and a few small stars - no planet of any
kind, ringed or plain, because the level's own find is a ringed planet.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two rounded metal walls
meeting in a corner, a wide flat pale blue floor across the bottom third with a round
orange rug in the middle.
On the left a low control desk with a big flat empty top and two chunky screens showing
plain coloured bars, and beside it a bunk bed with a flat mattress and a soft blue
blanket. In the centre a round table on a single post with a flat empty top, and behind
it a tall open storage rack with three wide shelves and two closed crates. On the
right a very large round window porthole with a smiling crescent moon and a few small
stars outside and nothing else, a wide flat window sill under it, a green potted plant
on a low stand, and a docking hatch door with a round wheel handle.
The station is lived in rather than empty: the shelves and the desk carry everyday
supplies - stacked crates, folded blankets, a cable coil, a row of drink pouches, a
second potted plant - with visible gaps between them where one more small thing could
sit, while the rug, the desk top, the round table, the crate lids, the bunk mattress,
the window sill and the bare floor still keep open surfaces to rest something on.
Along the very bottom edge of the frame draw a shallow near foreground of two stacked
supply crates and a low equipment locker, standing in front of the floor behind them, so
that things further back can be partly hidden by them.
Vary the tone across the picture: a deep blue bunk alcove and dark grey rack against pale
metal walls and a bright floor, so the room is not one flat tone.
Bright even light everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed furniture and fittings, no small loose objects, tools or toys lying
around, those are added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no astronauts, no text, no letters, no numbers, no watermarks.
```

## Sheet 1

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a red rocket with fins, a blue space
helmet with a dark visor, a yellow five pointed star with a smiling face, an orange
planet with a gold ring around it, a friendly little green alien, a dark grey speckled
moon rock.
No white or near-white parts on any object: the planet's ring is gold, not white, and
every eye is drawn as a plain dark dot rather than a white oval.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range the station itself uses, never neon or glowing.
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

Cells in reading order: `rocket`, `space_helmet`, `star`, `ringed_planet`, `alien`, `moon_rock`.

## Sheet 2

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a purple moon buggy with four chunky
wheels, a brown space boot, a silver jetpack with two orange straps, a gold spanner
wrench, a teal flying saucer with a round dome, a pink walkie talkie with a short aerial.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range the station itself uses, never neon or glowing.
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

Cells in reading order: `moon_buggy`, `space_boot`, `jetpack`, `wrench`, `flying_saucer`, `walkie_talkie`.

## Props and labels

| Id | Label | Colour | Category |
| --- | --- | --- | --- |
| `rocket` | Rocket | red | flying |
| `space_helmet` | Space Helmet | blue | gear |
| `star` | Star | yellow | sky |
| `ringed_planet` | Planet | orange | sky |
| `alien` | Alien | green | - |
| `moon_rock` | Moon Rock | grey | sky |
| `moon_buggy` | Moon Buggy | purple | wheels |
| `space_boot` | Space Boot | brown | gear |
| `jetpack` | Jetpack | silver | gear |
| `wrench` | Wrench | gold | tools |
| `flying_saucer` | Flying Saucer | teal | flying |
| `walkie_talkie` | Walkie Talkie | pink | tools |

The colour and category columns are what the later find-by-colour and find-by-category asks read from, so keep them accurate to the art that actually comes back.
Grey and silver sit close together; the moon rock is the darker of the two on purpose, so a child sorting by colour is never asked to split them.

## What the build settled on

The analyzer's room read was good but three regions were wrong in ways only the preview shows, and all three are worth knowing before the next room is built.

The bench under the porthole was given a rect running to `x` 0.965, past the end of the bench and across bare wall, so a prop landed hovering beside the plant.
Its rest line was also a single number at the slab's bottom front edge, which sank every prop through the bench's front face; the top of that slab is slanted, so it needs a rest polyline, not a scalar.
Both are the general case of a region described from the bounding box rather than from the surface.

`tucked_in` was offered by the open shelves and by the two bunk mattresses, and a tucked prop ignores the rest line: a wrench floated mid-compartment and a moon rock hung above the bed.
Nothing in this room is tuckable except the monitor gap, the plant pot base and the airlock wheel, and those are the three that kept it.
That left the rocket and the star, both written as tuck-only floaters, with too little of the room to hide in, so both were given `rests_on` as well - a toy rocket standing on a shelf reads fine.

Prop widths came back at 0.04 to 0.11 of scene width, narrower than the toy room's first pass, and the level places all twelve objects on all forty seeds `test/level_test.dart` tries.

## Dense backdrop

The Seek and Hunt variant, per [art-direction.md](art-direction.md#dense-variants).
Same station, same viewpoint, same modules where they are - roughly twice as much in it,
and a near foreground props can sit behind.

```prompt
The inside of a bright friendly space station, background art for a hidden object game
for children aged eight to twelve.
STRICT RULE, more important than anything else below. This picture must contain NO
spacesuits, NO space helmets, NO helmet domes, NO visors and NO human figures or
silhouettes of any kind, anywhere - the wall lockers are sealed with their doors shut,
not suits. Also NO rockets, NO stars or planets inside the room, NO aliens, NO moon
rocks, NO moon buggies, NO boots, NO jetpacks, NO wrenches or spanners, NO flying saucers
and NO walkie talkies. Outside the porthole draw only a smiling crescent moon and a few
small stars - no planet of any kind, because the level's own find is a ringed planet.
Every one of those is added later as a separate cut-out sprite, and one painted into the
scenery makes the real one impossible to find. Fill the racks and lockers with plain
sealed crates, stacked supply boxes, folded blankets, cable coils, drink pouches, blank
screens and potted plants instead.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two rounded metal walls
meeting in a corner, a wide flat pale blue floor across the bottom third with a round
orange rug in the middle.
Keep every landmark exactly where it is: the low control desk with its two chunky
screens on the left, the bunk bed with its blue blanket beside it, the round table on a
single post in the centre, the tall open storage rack behind it, and on the right the
very large round porthole, the flat window sill under it, the potted plant on its stand
and the docking hatch with a round wheel handle.
Add to the station around them so it is busy rather than calm, about as busy as a grown
up's puzzle picture: a second bank of control panels with rows of coloured buttons,
more open racks of crates and sealed lockers, cargo netting holding boxes, coiled cables
and pipes along the walls, a ladder, hanging grab handles, a workbench with clamps, a
stack of drink pouches, more folded blankets and a second potted plant.
Along the very bottom of the frame draw a near foreground of stacked supply crates, a
yellow safety railing and a low equipment locker, standing in front of the deck behind
them, so that things further back are partly hidden by them.
Vary the tone across the picture: a deep blue bunk alcove and a dark grey rack against
pale metal walls and a bright floor, so the station is not one flat tone.
Bright even lighting everywhere, no dark corners and no dark ceiling: the bulkheads, the
upper walls and the roof are pale grey and pale blue like the rest of the station, and
only the round porthole itself is dark. Nothing gloomy, nothing scary.
IMPORTANT: only fixed fittings and decor, no small loose objects lying around, those are
added later as separate sprites.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Decoy sheet

Six station things that are never asked for, per [art-direction.md](art-direction.md#decoy-sheets).

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a red fire extinguisher, a yellow
torch, a blue clipboard, a green oxygen tank, an orange satellite dish on a stand, a
purple crystal sample jar with a lid.
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
Bright friendly colours in the range the station itself uses, never neon or glowing.
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

Cells in reading order: `fire_extinguisher`, `torch`, `clipboard`, `oxygen_tank`, `satellite_dish`, `sample_jar`.

## Plate look

The empty room the Peek and Look pictures are baked from: busy, but readable at five.
About twice what the old backdrop held.

```prompt
The inside of a bright friendly space station, background art for a hidden object game for
children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain NO rockets,
NO space helmets, NO stars, NO planets of any kind, NO aliens, NO moon rocks, NO moon
buggies or rovers, NO boots, NO jetpacks, NO spanners or wrenches, NO flying saucers and NO
walkie talkies, anywhere. Those are added afterwards, and one of them painted into the
scenery makes the real one impossible to find. Outside the porthole draw only a smiling
crescent moon and a few small stars.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two rounded metal walls
meeting in a corner, a wide flat pale blue floor across the bottom third with a round orange
rug in the middle.
The station is lived in and full of its own things, about as busy as a tidy child's bedroom:
a low control desk with two chunky screens and a bank of coloured buttons, a bunk bed with a
blue blanket and a pillow, a round table on a single post, two tall open storage racks
holding sealed crates, stacked supply boxes, folded blankets, drink pouches and cable coils,
a big round porthole with a flat window sill under it, a potted plant on a stand, a docking
hatch with a round wheel handle, a ladder, a row of hanging grab handles, cargo netting
holding boxes, pipes along the walls and a workbench with clamps.
Every shelf holds something and no wall is bare, but each thing on a shelf has room around
it: a five year old has to be able to tell one object from the next at arm's length.
Along the very bottom of the frame draw a near foreground of stacked supply crates, a yellow
safety railing and a low equipment locker, standing in front of the deck behind them, so
that things further back are partly hidden by them.
Vary the tone across the picture: a deep blue bunk alcove and a dark grey rack against pale
metal walls and a bright floor.
Bright even lighting everywhere, no dark corners and no dark ceiling; only the round porthole
itself is dark. Nothing gloomy, nothing scary.
IMPORTANT: only fixed fittings and decor, no small loose objects lying around, those are
added afterwards.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Plate hunt

The empty room the Seek and Hunt pictures are baked from.
Three to four times the old dense backdrop: deep racks, layered foreground, and a great deal
of small drawn detail for a find to disappear into.

```prompt
The inside of a busy working space station, background art for a hidden object puzzle for
children aged eight to twelve, as densely packed as a grown-up "find the hidden objects"
page.
STRICT RULE, more important than anything else below: this picture must contain NO rockets,
NO space helmets, NO stars, NO planets of any kind, NO aliens, NO moon rocks, NO moon
buggies or rovers, NO boots, NO jetpacks, NO spanners or wrenches, NO flying saucers, NO
walkie talkies, NO spacesuits and NO human figures, anywhere. Those are added afterwards,
and one of them painted into the scenery makes the real one impossible to find. Outside the
porthole draw only a smiling crescent moon and a few small stars.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single soft
shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The room is seen straight on from a gentle three-quarter angle, two rounded metal walls
meeting in a corner, a wide flat pale blue floor across the bottom third with a round orange
rug in the middle.
Fill it: every wall carries racks, lockers, pinboards, pipes, cable runs, gauges and hanging
grab handles; every rack is four or five shelves deep and every shelf is packed end to end
with sealed crates, stacked supply boxes, labelled bins, folded blankets in different
colours, drink pouches, jars, coiled hoses, tool rolls and small potted plants; cargo netting
bulges with parcels; a workbench carries clamps, gears, spools and a tool board; a bunk bed
is made up with blankets and cushions; a round table stands on the rug with cups and pouches
on it.
Draw the small things small: a picture crowded with hand-sized objects rather than a few big
ones, dozens of separate items, so that one more object among them would not stand out.
Layer the depth. Along the bottom third build a near foreground of stacked crates, a yellow
safety railing, a low equipment locker, a hose reel and a mop bucket, and make some of it
see-through - railings, netting, a wire basket, the rungs of a ladder - so the deck behind
shows in the gaps and anything standing there is partly covered.
Vary the tone across the picture: a deep blue bunk alcove, a dark grey rack and a shadowed
under-bench against pale metal walls and a bright floor, so there are places a dark thing can
sink into and places a light thing can.
Bright even lighting everywhere, no dark corners and no dark ceiling; only the round porthole
itself is dark. Busy and cheerful, never gloomy, never scary.
IMPORTANT: only fixed fittings, stores and decor, no small loose toys lying around, those are
added afterwards.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No characters, no people, no text, no letters, no numbers, no watermarks.
```

## Baked look

Four pictures for Peek and Look, drawn from [Plate look](#plate-look).
Fourteen finds each: the twelve the level asks for, and two of them twice, so which fourteen
a game asks for can vary.

```bash
tools/scene.sh art docs/imgenprompts/space-station.md --only "Baked look" --takes 4 \
               --from rawimages/space_station/plate_look.jpeg --force
```

```prompt
Here is a finished cartoon room, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these fourteen objects added into
it and nothing else altered:
1. a small red toy rocket with a blue window and three fins, standing upright
2. a blue space helmet with a dark oval visor
3. a yellow five-pointed star with a small smiling face
4. an orange planet with a golden ring tilted around it
5. a small round green alien with two antennae and a smiling face
6. a lumpy grey moon rock with darker craters
7. a small purple moon buggy with a domed cabin and four black wheels
8. a brown leather space boot with a buckle
9. an orange and white jetpack with two tanks and shoulder straps
10. a yellow spanner
11. a pale teal flying saucer with a clear dome on top
12. a pink walkie talkie with a stubby aerial and a grille
13. a second yellow five-pointed star with a smiling face, somewhere else entirely
14. a second lumpy grey moon rock, somewhere else entirely

Do not redraw, move, recolour or restyle anything already in the picture: the walls, the
shelves, the crates, the bunk, the table, the rug, the porthole, the railing, the plant and
every other fitting must come back exactly as they are, in the same places, at the same
size, in the same colours. Only the fourteen objects are new.
Each is drawn in the picture's own style - the same thick dark outline of the same weight,
the same flat cel colours, the same single soft shadow tone - with the room's own soft
shadow under it where it rests, so it reads as painted into the picture rather than pasted
on top of it.
Each is about as wide as one of the storage boxes on the shelves, roughly a fourteenth of
the picture across.
Each is left where that thing would plausibly be left, among the room's own things: on a
shelf between the boxes, on the workbench, in the cargo netting, on the rug, on the bunk, on
the table, on the console, on a crate. None of them stands alone in the middle of an empty
patch of floor or wall.
Four or five of the fourteen are partly behind something already in the room - a crate, the
yellow railing, the edge of a shelf, the plant, the table - so only part of each shows.
No two of the fourteen touch or overlap each other, and none is cut off by the edge of the
frame.
No text, no letters, no numbers, no people, no watermarks.
```

## Baked hunt

Four pictures for Seek and Hunt, drawn from [Plate hunt](#plate-hunt).
Twenty finds each and much smaller, most of them broken by something in front: Seek is asked
for sixteen of the twenty and Hunt for all of them, so eight of the twelve things the level
hides turn up twice and which copies count changes with the game.

```bash
tools/scene.sh art docs/imgenprompts/space-station.md --only "Baked hunt" --takes 4 \
               --from rawimages/space_station/plate_hunt.jpeg --force
```

```prompt
Here is a finished cartoon room, background art for a hidden object puzzle for children aged
eight to twelve.

Return the SAME picture, pixel for pixel unchanged, with these twenty objects added into it
and nothing else altered:
1. a small red toy rocket with a blue window and three fins
2. a blue space helmet with a dark oval visor
3. a yellow five-pointed star with a small smiling face
4. an orange planet with a golden ring tilted around it
5. a small round green alien with two antennae and a smiling face
6. a lumpy grey moon rock with darker craters
7. a small purple moon buggy with a domed cabin and four black wheels
8. a brown leather space boot with a buckle
9. an orange and white jetpack with two tanks and shoulder straps
10. a yellow spanner
11. a pale teal flying saucer with a clear dome on top
12. a pink walkie talkie with a stubby aerial and a grille
13. a second red toy rocket, somewhere else entirely
14. a second yellow five-pointed star, somewhere else entirely
15. a second orange ringed planet, somewhere else entirely
16. a second lumpy grey moon rock, somewhere else entirely
17. a second yellow spanner, somewhere else entirely
18. a second pink walkie talkie, somewhere else entirely
19. a second green alien, somewhere else entirely
20. a second pale teal flying saucer, somewhere else entirely

Do not redraw, move, recolour or restyle anything already in the picture: every rack, shelf,
crate, box, blanket, hose, locker, plant, gauge, pipe, railing and fitting must come back
exactly as it is, in the same place, at the same size, in the same colours. Only the twenty
objects are new.
Each is drawn in the picture's own style - the same thick dark outline of the same weight,
the same flat cel colours, the same single soft shadow tone - with the room's own soft
shadow under it where it rests, so it reads as painted into the picture rather than pasted
on top of it.
Draw them SMALL: each object is about a twentieth of the picture across, the size of the
jars and the folded blankets already on the shelves, never bigger than one of the storage
boxes. A child of eleven should have to look for them.
Each goes deep among the room's own things, where a real object would end up: pushed to the
back of a shelf between the crates, half inside a wire basket, behind the jars, under the
workbench, tucked into the cargo netting, between the folded blankets, behind the hose reel,
on top of a locker, beside the mop bucket, on the bunk under a corner of blanket. None of
them stands alone on an empty patch of floor, deck or wall.
At least twelve of the twenty are partly hidden: behind the yellow railing, behind a crate,
behind the wire basket, behind the ladder rungs, behind the plant, behind the hose reel,
under a shelf edge - so only part of each one shows, the way a real thing in a packed store
room is half buried. Never hide one completely: a piece of every object stays visible.
No two of the twenty touch or overlap each other, and none is cut off by the edge of the
frame.
No text, no letters, no numbers, no people, no watermarks.
```

