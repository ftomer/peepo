# Inventor's Workshop - Hidden Object Background

Target: iPad landscape 4:3. Background only - loose objects added in-engine as sprites.

## Prompt

```
A cluttered vintage inventor's workshop interior, background art for a hidden object mobile game.
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated colors.
Wide panoramic view of the room from a slightly elevated three-quarter angle,
showing two walls meeting in a corner, with strong depth: detailed foreground workbench at
the bottom edge, midground work area, background walls full of equipment.
The wide frame is packed edge to edge: on the left tall wooden shelving crowded with jars,
coiled springs, gear assemblies and rolled blueprints, a pegboard wall hung with mounted tools;
in the center a large workbench with a built-in vice, an overhead pulley system with ropes and
chains, a half-built brass flying machine on a stand, hanging cage lamps; on the right a big
arched window with warm evening light, a cast iron stove with a kettle pipe, a drafting table
with pinned diagrams, wooden crates and barrels stacked in the corner, a rolling ladder against
the shelves; copper pipes running along the ceiling across the whole scene, worn plank floor
with an oil-stained rug, steam gauges and clock faces mounted on the walls.
Every area is filled with rich layered detail, busy composition, no empty flat areas.
Blueprints and diagrams show simple line drawings and shapes, no readable text.
IMPORTANT: all clutter is large fixed furniture and equipment attached to the scene - no small
loose handheld objects like screwdrivers, cups, keys or gadgets lying around, those will be
added later.
Many small usable flat spots remain across the workbench, shelves, crates, drafting table and
floor for game objects to be placed on.
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
evenly spaced, none touching or overlapping: a brass gear wheel, a red adjustable wrench,
a pair of leather aviator goggles, an oil can with a long spout, a coiled metal spring,
a horseshoe magnet with red tips.
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
evenly spaced, none touching or overlapping: a wooden-handled screwdriver, a brass pressure
gauge with a round dial, a lightbulb with a glowing filament, a small wind-up robot toy,
a rolled blueprint tied with string, a vintage brass telescope.
Vibrant 2D cartoon illustration, clean bold outlines, painterly shading, rich saturated
colors, slight glossy highlights.
Each object fully visible, complete silhouette, neutral three-quarter angle.
Generic soft ambient lighting, NO cast shadows, no ground plane, no reflections,
no background elements.
Plain solid pure white background (#FFFFFF).
Ultra high resolution, sharp crisp details.
No text, no watermarks.
```

Note: gauge dial tempts garbled numbers - if lettering appears, add "blank dial face,
no numbers" and regenerate that one alone.

## Notes

- Same skeleton and style block as `christmas-living-room.md` - only the theme content differs.
  Keep it that way for cross-level style consistency.
- "No readable text" line matters extra here: blueprints, gauges and labels tempt Gemini
  into garbled lettering.
- Theme suits mechanical sprite sets: wrenches, gears, oil cans, goggles, springs, magnets.
