# Object Sprites - Hidden Object Game Assets

Findable objects generated separately from backgrounds, composited in-engine.
Gemini cannot output transparent PNG - generate on solid background, strip with `rembg`.

## Single object prompt

Replace `[OBJECT]` per generation, e.g. "a red umbrella", "a brass pocket watch".

```
A single [OBJECT], game asset sprite for a hidden object mobile game.
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated
colors, slight glossy highlights.
The object is shown alone, centered, fully visible, complete silhouette, no cropping.
Neutral three-quarter angle, generic soft ambient lighting, NO cast shadow, no ground plane,
no reflections, no background elements.
Plain solid pure white background (#FFFFFF), high contrast between object and background.
Ultra high resolution, sharp crisp details.
No text, no watermarks.
```

## Batch grid prompt

Faster, and style stays consistent within one generation.
Trade-off: each object gets lower resolution - use for small sprites.

```
Six separate game asset sprites for a hidden object mobile game, arranged in a 3x2 grid,
evenly spaced, none touching or overlapping: [OBJECT 1], [OBJECT 2], [OBJECT 3],
[OBJECT 4], [OBJECT 5], [OBJECT 6].
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated
colors, slight glossy highlights.
Each object fully visible, complete silhouette, neutral three-quarter angle.
Generic soft ambient lighting, NO cast shadows, no ground plane, no reflections,
no background elements.
Plain solid pure white background (#FFFFFF).
Ultra high resolution, sharp crisp details.
No text, no watermarks.
```

## Pipeline notes

- Style block is identical to the background prompts (`christmas-living-room.md`,
  `inventors-workshop.md`) - keep it byte-identical for consistency.
- Attach a previously generated sprite to Gemini as reference:
  "match this exact art style" - beats text for style lock.
- White background works for most objects; for white-ish objects (snowman, teacup)
  use solid magenta `#FF00FF` instead.
- Strip background: `rembg i in.png out.png` (free, local, handles anti-aliased
  cartoon edges well). Slice batch grids before stripping.
- "NO cast shadow, no ground plane" is critical - a baked shadow ruins the sprite
  when placed on a wall or shelf. Add drop shadow in-engine instead.
- Generate at ~2x display size so zoom-in stays sharp.
- In-game, keep sprite outlines slightly bolder or 5-10% brighter than background
  clutter so findables stay fair.
