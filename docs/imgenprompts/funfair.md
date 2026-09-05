# Funfair - the wheel, the teacups and the stalls

Level id `funfair`, a fairground for the kids catalog ([kids-direction.md](../kids-direction.md#catalog)).
Style comes from [art-direction.md](art-direction.md) and is repeated inline below so the prompts can be generated straight from this file.

Twelve props, every one a fair thing a five-year-old can name, each with its own dominant colour.
The rides and the stalls are painted into the plates, not hidden: a child looking for a ferris wheel at a fair is looking for the scenery.
The games are a ball-toss stall and a hoopla stall rather than a shooting gallery, because the listing is 4+ in the Kids Category.
There is no hook-a-duck pool and no teddy on a prize shelf, because the duck and the bear are finds and a look-alike in the scenery makes the real one unanswerable.

This level is baked from the start, so it has no Backdrop, no Dense backdrop and no meta file: two plates, two sheets and eight pictures.
See [scene-pipeline.md](../scene-pipeline.md#the-other-shape-a-baked-scene).

Generate with:

```bash
tools/scene.sh art docs/imgenprompts/funfair.md --only "Sheet 1" --only "Sheet 2" \
               --only "Plate look" --only "Plate hunt"
```

## Sheet 1

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a brown teddy bear sitting up facing
front, a pink cotton candy cloud on a paper stick, a red and yellow vertically striped
popcorn box overflowing with yellow popcorn, a single scoop mint green ice cream in a tan
waffle cone, a small clear goldfish bag tied at the top holding pale blue water and one
orange goldfish, a yellow rubber duck with an orange beak.
Each cell holds one single solid object and nothing else: no sparkles, no stars, no
glints, no specks, no motion lines floating around it.
No white or near-white parts on any object: the popcorn box stripes are red and yellow,
never white, the ice cream is mint green, the bag's water is pale blue, the duck is
yellow all over with an orange beak.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range a cartoon fairground uses, never neon or glowing.
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

Cells in reading order: `teddy_bear`, `cotton_candy`, `popcorn`, `ice_cream`, `goldfish_bag`, `rubber_duck`.

## Sheet 2

```prompt
Six separate game asset sprites for a children's hidden object game, arranged in a 3x2
grid, evenly spaced, none touching or overlapping: a single round blue balloon on a brown
string, a purple swirl lollipop on a stick, a rainbow striped toy pinwheel on a stick, a
teal diamond shaped kite with a short tail of bows, a black top hat with a red band, a
silver grey whistle on a short cord.
Each cell holds one single solid object and nothing else: no sparkles, no stars, no
glints, no specks, no motion lines floating around it.
No white or near-white parts on any object: the balloon string is brown, the lollipop
swirl is purple and lilac, the kite tail bows are teal and dark teal, the whistle is a mid
grey with a darker grey shadow, never white.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
Matte flat colour fills only, the way a paint bucket fills a shape: one solid colour per
part, with at most one slightly darker flat shape for shadow, and hard edges between
them. NO airbrush shading, NO glossy shine, NO white or pale highlight blobs, NO shiny
dots, NO rim light, NO soft colour gradients, NO plastic or 3D render look, NO white
sticker rim around the outline. Same thick even line weight on every object.
Bright friendly colours in the range a cartoon fairground uses, never neon or glowing.
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

Cells in reading order: `blue_balloon`, `grape_lollipop`, `pinwheel`, `kite`, `top_hat`, `silver_whistle`.

## Props and labels

| Id | Label | Colour | Category |
| --- | --- | --- | --- |
| `teddy_bear` | Teddy Bear | brown | toys |
| `cotton_candy` | Cotton Candy | pink | food |
| `popcorn` | Popcorn | red | food |
| `ice_cream` | Ice Cream | mint green | food |
| `goldfish_bag` | Goldfish | orange | animals |
| `rubber_duck` | Rubber Duck | yellow | toys |
| `blue_balloon` | Balloon | blue | flying |
| `grape_lollipop` | Lollipop | purple | food |
| `pinwheel` | Pinwheel | rainbow | toys |
| `kite` | Kite | teal | flying |
| `top_hat` | Top Hat | black | - |
| `silver_whistle` | Whistle | silver | - |

The colour and category columns are what the later find-by-colour and find-by-category asks read from, so keep them accurate to the art that actually comes back.

## Plate look

The fairground the Peek and Look pictures are baked from: a whole fair seen from the air,
full of people, busy but readable at five.
See [scene-pipeline.md](../scene-pipeline.md#the-other-shape-a-baked-scene).

This level breaks two of the backdrop rules in [art-direction.md](art-direction.md) on
purpose. It is drawn from high up at a steep angle, because a fair is a field of rides
and stalls and a straight-on view shows one row of them; and it is full of cartoon
people, because a fair with nobody at it is a car park. Both were rules for the sprite
placer's rest lines, and a baked level has none.

```prompt
A big, bustling funfair on a sunny day seen from high up in the air, background art for a
hidden object game for children aged five to seven.
STRICT RULE, more important than anything else below: this picture must contain NO teddy
bears or plush toys of any kind, NO cotton candy or candy floss, NO popcorn or popcorn
boxes, NO ice cream cones, NO goldfish or fish bowls or bags of water, NO rubber ducks
or ducks of any kind, NO balloons, NO lollipops, NO pinwheels or windmills, NO kites, NO
hats or caps on anyone, NO whistles, anywhere: not on a stall shelf, not on a sign, not
as a prize and not in anybody's hand. Nobody in the picture holds or carries anything at
all; hands are empty, in pockets, waving, or holding another person's hand. Those objects
are added afterwards, and one of them painted into the scenery makes the real one
impossible to find. Prizes on the stalls are boxed board games and green plush dinosaurs;
the sweet stall sells jars of round boiled sweets and jelly beans; food stands sell hot
dogs, pretzels and lemonade. Every sign, board, booth and awning is a plain striped or
plain coloured panel with NO writing of any kind on it, not a single letter. There is NO ticket booth and NO word TICKET anywhere, NO chalkboard, NO menu
board, NO poster and NO price sign.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The view is from high above the fair at a steep three-quarter angle, like a bird flying
over it: the ground fills the frame from the bottom edge to a thin strip of sky and
distant trees along the very top, and the fair is laid out across the whole field in
rows, with sandy paths winding between the rides and the stalls and people walking on
them. Things at the bottom of the picture are nearer and bigger, things at the top are
further and smaller, like a real fairground seen from a hill or a drone.
The fair is laid out like a real one: a big ferris wheel with round gondolas, a teacup
ride with big pastel teacups on a round striped platform, a carousel of flying swings, a
helter skelter, a bumper car arena with a striped roof, a small stage with bunting, rows
of striped stalls and tents with awnings, a sweet stall with shelves of sweet jars, a
lemonade and hot dog stand, a pretzel cart, a ball-toss stall with pyramids of tin cans,
a hoopla stall with pegs and rings, a high-striker tower with a bell, a small striped
kiosk with a blank board, picnic tables and benches, litter bins, lamp posts with strings of fairy lights, stacked
crates and barrels behind the stalls, hay bales, flower tubs, striped barrier fences, a
generator trailer, and trees and hedges around the edge of the field.
The fair is full of cartoon people: grown-ups and children walking the paths in twos and
threes, queueing at the stalls, sitting in the teacups and the gondolas, standing at the
counters, children holding a grown-up's hand, a child on a grown-up's shoulders, people
sitting at the picnic tables. Simple friendly cartoon figures in exactly the same flat
style as everything else: round heads, dot eyes, big smiles, varied skin tones and hair,
bright plain clothes, no hats, and empty hands. They are small in the picture, part of
the crowd, never a close-up.
Every counter and shelf holds something and no patch of ground is bare, but each thing has
room around it: a five year old has to be able to tell one object from the next at arm's
length.
Vary the tone across the picture: darker grass in the shade of the rides and tents,
bright lawn in the open, sandy paths and grey tarmac under the bumper cars, so the field
is not one flat tone.
Bright even daylight everywhere, no dark corners, no dramatic shadows, nothing scary.
IMPORTANT: only fixed rides, stalls, furniture, decor and people; no small loose objects
lying around and nothing in anybody's hands, those are added afterwards.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No animals, no text, no letters, no numbers, no watermarks.
```

## Plate hunt

The empty fairground the Seek and Hunt pictures are baked from: three to four times as
packed, with a layered, partly see-through foreground for finds to hide behind.

```prompt
A big, bustling funfair on a sunny day seen from high up in the air, background art for a
hidden object game for children aged eight to twelve, as densely packed as a grown-up
"find the hidden objects" page.
STRICT RULE, more important than anything else below: this picture must contain NO teddy
bears or plush toys of any kind, NO cotton candy or candy floss, NO popcorn or popcorn
boxes, NO ice cream cones, NO goldfish or fish bowls or bags of water, NO rubber ducks
or ducks of any kind, NO balloons, NO lollipops, NO pinwheels or windmills, NO kites, NO
hats or caps on anyone, NO whistles, anywhere: not on a stall shelf, not on a sign, not
as a prize and not in anybody's hand. Nobody in the picture holds or carries anything at
all; hands are empty, in pockets, waving, or holding another person's hand. Those objects
are added afterwards, and one of them painted into the scenery makes the real one
impossible to find. The prize shelves hold ONLY boxed board games and green plush
dinosaurs, never a bear and never any other soft toy; the sweet stall sells jars of round
boiled sweets and jelly beans; food stands sell hot dogs, pretzels and lemonade. Every
sign, board, booth and awning is a plain striped or plain coloured panel with NO writing
of any kind on it, not a single letter. There is NO ticket booth and NO word TICKET
anywhere, NO chalkboard, NO menu board, NO poster and NO price sign. No stall is decorated
with a painting of a fish, a duck, a balloon or any animal.
Flat 2D vector cartoon illustration for a children's game.
Thick uniform dark outlines, big simple rounded shapes, flat cel shading with a single
soft shadow tone, bright saturated primary colours, cheerful and friendly.
No gradients, no texture, no painterly brushwork, no photorealism.
The view is from high above the fair at a steep three-quarter angle, like a bird flying
over it: the ground fills the frame from the bottom edge to a thin strip of sky and
distant trees along the very top, and the fair is laid out across the whole field in
rows, with sandy paths winding between the rides and the stalls and crowds walking on
them. Things at the bottom of the picture are nearer and bigger, things at the top are
further and smaller, like a real fairground seen from a hill or a drone.
The fair is laid out like a real one: a big ferris wheel with round gondolas, a teacup
ride with big pastel teacups on a round striped platform, a carousel of flying swings, a
helter skelter, a bumper car arena with a striped roof, a small stage with bunting, rows
of striped stalls and tents with awnings, a sweet stall with shelves of sweet jars, a
lemonade and hot dog stand, a pretzel cart, a ball-toss stall with pyramids of tin cans,
a hoopla stall with pegs and rings, a high-striker tower with a bell, a small striped
kiosk with a blank board, picnic tables and benches, litter bins, lamp posts with strings of fairy lights, stacked
crates and barrels behind the stalls, hay bales, flower tubs, striped barrier fences, a
generator trailer, coiled cables, a drinks fridge, stacks of plastic cups, a stack of
folding tables, deckchairs, a wheelbarrow, and trees and hedges around the edge of the
field.
Fill it: every counter, shelf and ledge is packed end to end, every path has people on
it, every ride has riders, every stall has a queue, and the spaces between are full of
benches, bins, crates, barrels, tubs and bunting poles.
The fair is crowded with cartoon people: grown-ups and children walking the paths in
groups, queueing at the stalls, sitting in the teacups, the gondolas and the swings,
standing at the counters, children holding a grown-up's hand, children on shoulders,
people sitting at the picnic tables, a crowd in front of the stage. Simple friendly
cartoon figures in exactly the same flat style as everything else: round heads, dot eyes,
big smiles, varied skin tones and hair, bright plain clothes, no hats, and empty hands.
They are small in the picture, part of the crowd, never a close-up.
Draw the small things small: a picture crowded with hand-sized objects rather than a few
big ones, dozens of separate items, so that one more object among them would not stand
out.
Layer the depth: people standing in front of counters, crates in front of stalls,
bunting poles, strings of lights, railings, netting on the ball stall and the rungs of a
stepladder, so what is behind shows in the gaps and anything standing there is partly
covered.
Vary the tone across the picture: deep shadowed spaces under the stalls and behind the
crates against pale awnings and bright ground, so there are places a dark thing can sink
into and places a light thing can.
Bright even daylight everywhere, no dark corners, nothing gloomy and nothing scary.
IMPORTANT: only fixed rides, stalls, furniture, decor and people; no small loose objects
lying around and nothing in anybody's hands, those are added afterwards.
Landscape aspect ratio 4:3, wide horizontal composition, ultra high resolution.
No animals, no text, no letters, no numbers, no watermarks.
```

## Baked look

Four pictures for Peek and Look, drawn from [Plate look](#plate-look): fourteen finds each,
two of the twelve twice.

```bash
tools/scene.sh art docs/imgenprompts/funfair.md --only "Baked look" --takes 4 \
               --from rawimages/funfair/plate_look.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these fourteen objects added into it
and nothing else altered:
1. a brown teddy bear sitting up
2. a pink cotton candy cloud on a paper stick
3. a red and yellow striped popcorn box full of yellow popcorn
4. a mint green ice cream in a tan waffle cone
5. a small bag of pale blue water with one orange goldfish in it
6. a yellow rubber duck with an orange beak
7. a single round blue balloon on a string
8. a purple swirl lollipop on a stick
9. a rainbow striped toy pinwheel on a stick
10. a teal diamond shaped kite with a short tail
11. a black top hat with a red band
12. a silver grey whistle on a cord
13. a second yellow rubber duck, somewhere else entirely
14. a second purple swirl lollipop, somewhere else entirely

Do not redraw, move, recolour or restyle anything already in the picture: every ride,
stall, counter, shelf, crate, fence, piece of decor and every person must come back
exactly as it is, in the same place, at the same size, in the same colours. Do not add,
remove or move any person. Only the fourteen objects are new, and none of them is held or
carried by a person: each one is resting, leaning, tied or lying somewhere.
Each is drawn in the picture's own style - the same thick dark outline of the same weight,
the same flat cel colours, the same single soft shadow tone - with the picture's own soft
shadow under it where it rests, so it reads as painted into the picture rather than pasted
on top of it.
Each is about as wide as one of the sweet jars on the stall shelves, roughly a fourteenth
of the picture across.
Each is left where that thing would plausibly be left, among the fair's own things: on a
counter, on a shelf, on a bench, in a teacup, on a crate, on a hay bale, on the fence
rail, by a tent. None of them stands alone in the middle of an empty patch of grass, path
or sky.
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
tools/scene.sh art docs/imgenprompts/funfair.md --only "Baked hunt" --takes 4 \
               --from rawimages/funfair/plate_hunt.jpeg --force
```

```prompt
Here is a finished cartoon picture, background art for a children's hidden object game.

Return the SAME picture, pixel for pixel unchanged, with these twenty objects added into it
and nothing else altered:
1. a brown teddy bear sitting up
2. a pink cotton candy cloud on a paper stick
3. a red and yellow striped popcorn box full of yellow popcorn
4. a mint green ice cream in a tan waffle cone
5. a small bag of pale blue water with one orange goldfish in it
6. a yellow rubber duck with an orange beak
7. a single round blue balloon on a string
8. a purple swirl lollipop on a stick
9. a rainbow striped toy pinwheel on a stick
10. a teal diamond shaped kite with a short tail
11. a black top hat with a red band
12. a silver grey whistle on a cord
13. a second yellow rubber duck
14. a second purple swirl lollipop
15. a second brown teddy bear
16. a second mint green ice cream cone
17. a second blue balloon
18. a second rainbow pinwheel
19. a second teal kite
20. a second silver grey whistle

Do not redraw, move, recolour or restyle anything already in the picture: every ride,
stall, counter, shelf, crate, fence, piece of decor and every person must come back
exactly as it is, in the same place, at the same size, in the same colours. Do not add,
remove or move any person. Only the twenty objects are new, and none of them is held or
carried by a person: each one is resting, leaning, tied or lying somewhere.
Each is drawn in the picture's own style - the same thick dark outline of the same weight,
the same flat cel colours, the same single soft shadow tone - with the picture's own soft
shadow under it where it rests, so it reads as painted into the picture rather than pasted
on top of it.
Draw them SMALL: each object is about a twentieth of the picture across, the size of the
smallest things already in the fair, never bigger than one of the sweet jars. A child of
eleven should have to look for them.
Each goes deep among the fair's own things, where a real object would end up: pushed to
the back of a shelf, half inside a crate, behind the sweet jars, under a counter, tucked
into the netting, inside a teacup, between the hay bales, behind the foreground fence, on
top of an awning. None of them stands alone on an empty patch of grass, path or sky.
At least twelve of the twenty are partly hidden behind something already in the picture,
so only part of each one shows - but never hide one completely: a piece of every object
stays visible.
No two of the twenty touch or overlap each other, and none is cut off by the edge of the
frame.
No text, no letters, no numbers, no people, no watermarks.
```
