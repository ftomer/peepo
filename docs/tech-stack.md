# Tech Stack Decision

Audience is children aged 3-12 ([kids-direction.md](kids-direction.md)), which changes the art direction and the monetization stack but none of the engine choices below.

Key insight: this genre is technically trivial.
It is an image viewer with pan/zoom, polygon hit-testing, and a list UI, not a real "game engine" problem.
The hard part is the content pipeline, not the code.

## Decision

Plain Flutter, no Flame.
Chosen because the developer has a very strong Flutter background, which outweighs framework micro-differences for an app this simple, and Android comes nearly free later.

Rationale:

- `InteractiveViewer` handles pinch/pan/zoom out of the box, best-in-class ergonomics for this genre.
- Flame is a game-loop/component engine and adds nothing for static scenes with tap targets; skip it.
- Tap handling: `GestureDetector` with `onTapUp`, transform tap coords via `InteractiveViewer`'s `TransformationController` matrix into image space, normalize, point-in-polygon test (~50 lines of Dart).
- If a purchase is ever added, it goes through the official `in_app_purchase` plugin, behind a parental gate. See Purchases below.
- No ad SDK. The audience is children aged 3-12 ([kids-direction.md](kids-direction.md)), so third-party ads are out regardless of which store category the listing sits in.
- Persistence: `shared_preferences` for MVP, drift or Isar if state grows.
- Found-object effects (sparkle, checkmark) via standard Flutter implicit/explicit animations.
- Level JSON loaded from the asset bundle.

## Alternatives Considered

| Approach | Fit | Why not |
|---|---|---|
| Native Swift (SwiftUI + UIScrollView) | Excellent for iOS-only | First-party StoreKit 2/AdMob and smallest binary, but iOS-only and no existing Swift expertise advantage here |
| SpriteKit | Good but overkill | Scene graph and physics buy nothing for static scenes |
| Unity 2D | Safe but heavy | Editor bloat and binary size for a static-image app; choose only if we later need ad mediation depth or mini-games |
| Godot 4 | Very good, cross-platform | Camera2D + Area2D/CollisionPolygon2D map perfectly to polygon hotspots; cost is monetization plugin maintenance (community AdMob plugin, version-pin tax) |
| React Native / Expo | Good if RN-fluent | Assembling third-party gesture/zoom libs plus native glue for StoreKit2/AdMob |
| Flutter + Flame | Rejected variant | Flame adds unneeded game-loop machinery; plain Flutter InteractiveViewer already solves zoom/pan |

Android: comes nearly free with Flutter; ship iOS first, enable Android after retention is proven.

## Level Data Format

A level ships what it hides, not where: the room is hidden freshly, from a seed, every time it is played.
Everything is in normalized [0, 1] coordinates, so the same JSON works at any screen size and image resolution.

```json
{
  "sceneId": "kitchen_01",
  "background": "background.jpg",
  "meta": "meta.json",
  "size": { "w": 4096, "h": 2730 },
  "objectCount": 14,
  "props": [
    {
      "id": "teapot",
      "label": "Teapot",
      "sprite": "sprites/teapot.png",
      "aspect": 0.82,
      "places": ["rests_on", "lies_flat"],
      "regions": [],
      "width": [0.04, 0.07],
      "rotate": [-10, 10],
      "copies": [1, 2],
      "silhouette": [[-0.42, -0.31], [0.18, -0.40], [0.44, 0.28], [-0.36, 0.34]]
    }
  ]
}
```

`silhouette` is the convex hull of the sprite's opaque pixels in sprite-local units, where the sprite box runs from -0.5 to 0.5.
The placer scales, rotates and moves it into the scene to make the tap polygon, so the hotspot always matches the art wherever the prop lands.

`meta.json` beside it describes the room itself - regions, depth, rest lines, no-go zones - and is what the placer places against; see [scene-meta.md](scene-meta.md).

Hit-test flow: tap point in screen space, invert the InteractiveViewer transformation matrix to image space, divide by image size to normalize, run point-in-polygon against each unfound object.

## Purchases (later phase)

Whether the app ever carries a purchase is not settled publicly, and this repository does not document it.
What is fixed, whatever the answer turns out to be:

- A parental gate sits in front of any purchase and any outbound link.
  The listing is 4+ and enrolled in the Kids Category ([kids-direction.md](kids-direction.md)), so App Review guidelines 1.3 and 5.1.4 and COPPA make this binding rather than self-imposed.
- No third-party advertising and no third-party analytics SDK, ever.
- Nothing that reaches the network gets added without meeting both of the above.
