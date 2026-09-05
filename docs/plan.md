# Build Plan

Audience is children aged 3-12, decided 2026-08-22: see [kids-direction.md](kids-direction.md).
The pirate cabin stays as the MVP proof of the engine and the pipeline.
Everything below still holds except where the pivot overrides it, which is marked inline.

Ship order matters: playable core, then pipeline speed test, then content, then monetization.
Most clones die at the content pipeline stage, not the code stage.

## Week 1: Playable Core

- Flutter app with 3 hand-made scenes.
- `InteractiveViewer` for zoom/pan.
- JSON scene loader from asset bundle (format in [tech-stack.md](tech-stack.md)).
- Tap hit-test: `onTapUp` coords through the `TransformationController` matrix to normalized image coords, point-in-polygon.
- Object list UI with checkoff on find.
- Found-object sparkle/checkmark animation.
- Level-complete screen.

## Week 2: Content Pipeline (viability gate)

- Build or adopt a hotspot annotation tool.
- Options: makesense.ai or CVAT off-label (polygon over image, JSON export), or a tiny custom web tool (canvas + polygon draw + JSON export).
- Scene sourcing for MVP: composite approach - AI/stock background plus separately pasted object sprites.
- Composite approach gives exact hotspot coords for free and easy difficulty tuning.
- Pure AI clutter scenes rarely have fair findable objects; human curation required regardless.
- Target: produce 1 complete scene in under 1 hour.
- If pipeline cannot hit that pace, rethink before writing more code.

## Week 3: Game Shell

- Level select screen with progress indicators.
- Progress persistence, local only (`shared_preferences` for MVP).
- Hint system (reveal area pulse at hintCenter).
- Settings (sound, haptics).

## Week 4+: Content and Validation

- Produce 24 levels across six worlds, four each ([catalog](kids-direction.md#catalog)).
- TestFlight beta, gather retention and completion data.
- No ads. A children's game does not carry third-party advertising, which retires the earlier `google_mobile_ads` plan.

## Differentiation

- No third-party advertising at all.
- A guide character children come back for, rather than a list of nouns.
- Asks that vary by world (count, colour, category, silhouette, odd one out) instead of one flat mechanic.
- Reading practice as a visible parent-facing benefit: every chip carries the word.
- Offline play.
- No currency, no timers.

## Asset Pipeline Notes

- Art direction is bright, flat and thickly outlined for the Look band (5-7), not the painterly HD the incumbent uses.
- AI base art (Midjourney-class or Gemini image gen) plus human cleanup is the common 2026 workflow.
- Legal caution: purely AI-generated art is likely not copyrightable, which weakens IP defense against clones.
- Keep meaningful human editing in the pipeline; get legal review before scaling an AI-heavy pipeline.
- Commissioned HOPA art studios (iLogos, Punchev) are the scale-up route if the game earns.

## Open Decisions

- App name: `Peepo`, chosen 2026-08-22 for the kids audience, replacing `Curiosa`. See [branding.md](branding.md).
- Visual identity: icon, logotype, palette.
- The guide character: species, name, voice.
- Android release timing (build comes nearly free with Flutter; gate on iOS retention data).
