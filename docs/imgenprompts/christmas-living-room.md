# Christmas Living Room - Hidden Object Background

Target: iPad landscape 4:3. Background only - loose objects added in-engine as sprites.

## Prompt

```
A cluttered cozy Christmas living room interior, background art for a hidden object mobile game.
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated colors.
Wide panoramic view of the room from a slightly elevated three-quarter angle,
showing two walls meeting in a corner, with strong depth: detailed foreground furniture at
the bottom edge, midground seating area, background walls full of decor.
The wide frame is packed edge to edge: on the left a tall bookcase crowded with books and a
wooden cabinet with open doors showing dishes and teapots; in the center a brick fireplace
with roaring fire, garland, candles and hanging stockings, framed pictures and a wreath above;
on the right a decorated Christmas tree with lights and a window with snowy night, red curtains,
gift boxes stacked beneath the tree; string lights spanning the ceiling across the whole scene,
patterned rug, armchair with blankets, side tables, wicker baskets, firewood pile.
Every area is filled with rich layered detail, busy composition, no empty flat areas.
Framed pictures contain simple landscapes and patterns, no faces.
IMPORTANT: all clutter is large fixed furniture and decor attached to the scene - no small
loose handheld objects like keys, cups, toys or tools lying around, those will be added later.
Many small usable flat spots remain across shelves, tables, floor and mantel for game
objects to be placed on.
Even warm lighting, consistent across the scene, no harsh spotlights.
Ultra high resolution, 4K, extremely detailed, sharp crisp linework.
Landscape aspect ratio 4:3, wide horizontal composition.
No characters, no people, no animals, no text, no watermarks.
```

## Sprite prompts

Theme object set, generated as two batch grids (see `object-sprites.md` for pipeline).

Batch 1:

```
Six separate game asset sprites for a hidden object mobile game, arranged in a 3x2 grid,
evenly spaced, none touching or overlapping: a brass pocket watch, a striped candy cane,
a red glass Christmas ornament ball, a gingerbread man cookie, a golden jingle bell,
a red-and-white Santa hat.
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated
colors, slight glossy highlights.
Each object fully visible, complete silhouette, neutral three-quarter angle.
Generic soft ambient lighting, NO cast shadows, no ground plane, no reflections,
no background elements.
Plain solid pure white background (#FFFFFF).
Ultra high resolution, sharp crisp details.
No text, no watermarks.
```

Batch 2:

```
Six separate game asset sprites for a hidden object mobile game, arranged in a 3x2 grid,
evenly spaced, none touching or overlapping: a pair of red knitted mittens, a snow globe
with a tiny house inside, a wrapped gift box with a golden bow, a mug of hot cocoa with
marshmallows, a pinecone, an old brass key.
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated
colors, slight glossy highlights.
Each object fully visible, complete silhouette, neutral three-quarter angle.
Generic soft ambient lighting, NO cast shadows, no ground plane, no reflections,
no background elements.
Plain solid pure white background (#FFFFFF).
Ultra high resolution, sharp crisp details.
No text, no watermarks.
```

Note: snow globe and mug are white-ish - if edges blend into white, regenerate those two
alone on solid magenta `#FF00FF`.

## Notes

- Pick 4:3 explicitly in the Gemini image settings; text alone is sometimes ignored.
  If only 16:9 is available, generate 16:9 and crop the sides.
- iPad ratios vary (4:3 most models, 10:7 Air/Pro 11").
  Keep critical detail out of the outer ~4% horizontal margin so one image fits all.
- Left/center/right zones are spelled out on purpose - landscape needs explicit horizontal
  distribution or the edges come out empty.
- Keep the style block identical across all theme prompts for cross-level consistency.
