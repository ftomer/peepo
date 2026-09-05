# Branding

## Name

**Peepo**

App store title: `Peepo: Find Hidden Things` (25 chars, fits Apple's 30 and Google's 30).

Chosen 2026-08-22 for the kids-first audience ([kids-direction.md](kids-direction.md)), replacing `Curiosa`.

### Why

`Peepo` is peek-a-boo shortened, so it names the mechanic to a parent while staying two syllables a five year old can say and remember.
It is a real word to a child before it is a brand, which is what a children's listing rewards.
It also doubles as the guide character, so the animal guide the kids direction calls for is Peepo, an owl: big eyes, the thing that sees, and one sprite set that carries the name across every level.

### Availability check (2026-08-22)

Apple App Store (iTunes Search API, term "peepo", entity software, US): zero games and zero relevant results.
Nearest hits are unrelated Shopping and Sticker entries.

Google Play (store search, term "peepo", apps, US): 29 fuzzy results, none named Peepo.
Nearest are `com.endigitaluy.peepostickers` (a sticker pack) and assorted Pepe meme apps.
No game collision.

Rejected alternatives and why:

- `Seekaboo` - `SEEKABOO: Find Objects` already exists on Apple in Games. Same genre, exact phonetic match.
- `Spotto` - `Spotto: Toddler Speech Games` plus three more Spotto apps, two of them games.
- `Zizzle` - two live entities, Zizzle LLC (which ships a game) and Zizzle Lab Inc. Trademark exposure.
- `Pipkin` - clear in Games on both stores, but says nothing about finding, so the name carries no keyword weight.
- `Peekaloo` - no exact match, but the peekaboo phonetic space holds 10+ kids apps on Play and the Peek-a-Zoo family on Apple. Confusion risk.
- `Findo`, `Hidey`, `Pockit`, `Bimble`, `Doodlebug` - all crowded or squatted outside Games.

### Known caveats

`Peepo!` is a 1981 Janet and Allan Ahlberg picture book, still in print from Puffin.
Different class of goods and a title rather than a mark, but the overlap in audience is real and it belongs in the clearance search.

`peepo` is also a Twitch emote name with a large meme corpus behind it.
No store collision, but it is search noise on the open web and makes `peepo.com` style domains unlikely.

Trademark clearance was NOT completed.
The USPTO search API is not publicly callable, so no authoritative Class 9 / Class 41 search has been run.
Do this before spending on brand assets.

### Superseded: Curiosa

`Curiosa` was chosen 2026-08-22 for a cozy adult audience and dropped the same day by the kids-first pivot.
For a game sold to parents of young children it said nothing about what it is, a child could not pronounce or remember it, and the antiquarian book trade's dated sense of *curiosa* as a euphemism for erotica was a real liability on a children's listing.
Nothing had shipped, so the name and the bundle id were both still free to change.

Its availability work rejected `Curio` (7+ Apple and 10+ Play collisions, plus Curio Interactive and Curio LLC), `Nooks` (existing app plus NOOK and nooks.ai marks), `Clutterly` (`Clutter 1000: Hidden Object` off the same root), `Trove` (six exact matches, one in Games) and `Spyglass` (exact match in Navigation).
Those findings stand.

## App icon

Peepo the owl holding a magnifying glass up to one eye, so the icon says both the brand and the mechanic in one shape.
Decided 2026-08-22, replacing the default Flutter logo that shipped on every platform until then.

- Background `#FDD84C`, sunny yellow, the same flat field the kids art direction uses.
- Owl teal, magnifier red, beak yellow, thick dark outline, no gradients ([imgenprompts/art-direction.md](imgenprompts/art-direction.md)).
- One subject, no text. Anything with a letter in it is unreadable at 40 pixels and unlocalisable besides.
- The red lens is the colour anchor: it is what still reads on a crowded home screen when the icon is 40 pixels wide.

Three concepts were drawn and rejected against it: the plain owl face (clean, but says nothing about finding), the owl peeking over a band (on-name, weaker at thumbnail size) and the owl hugging a star (cutest, but the star and the body compete).
All four prompts stay in [imgenprompts/app-icon.md](imgenprompts/app-icon.md).

The master is `rawimages/app_icon/master.png`, a single square image - source art, so it lives with the rest of the raw art rather than in the bundle.
`tools/scene.sh icon` recentres it and writes the iOS, macOS, Android and web assets, so no platform's icon is ever edited by hand.
The Android adaptive icon's background layer is a solid colour resource matching the master's background.
The launch screens on both mobile platforms now use the level list's own background, so starting the app no longer flashes white.

## Palette

The app's colours are Peepo's colours, sampled off the shipped art rather than picked.
They live in [lib/theme.dart](../lib/theme.dart) as `PeepoColors`, and nothing else in `lib/` holds a `Color(0x...)` literal.

Settled 2026-08-22, replacing the brown-and-gold set the UI had carried since the *Curiosa* pitch.
That palette was built for a cozy adult hidden-object game; when the audience became 3-12 the mascot, the icon and the art direction all moved to flat and bright, and the chrome did not follow.
Nothing in the old UI palette appeared anywhere in the art, and the variable names said so: `_parchment`, `_brass`, `_gold`, `_fogColor`.

| Token | Value | Sampled from | Job |
| --- | --- | --- | --- |
| `teal` | `#44BCB9` | Peepo's body | Anything interactive or selected |
| `tealDeep` | `#268587` | his shaded side | Pressed, and a found object |
| `sunny` | `#FDD84C` | the icon's field | Reward and attention: hints, seals, stars |
| `beak` | `#EDAF13` | his beak | Low stop of the gold gradients |
| `cream` | `#F7E8C7` | his belly | Primary text, and any large light surface |
| `berry` | `#F24C50` | the magnifying glass | A miss, or wiping progress |
| `sky` | `#529BD0` | his hand | Confetti only |
| `outlineArt` | `#183C6C` | the line around every asset | The art's own outline |

The ground `#12294A`, the panels `#1B3A64` / `#26507F`, the secondary text `#A6BEDC` and the UI line `#0B1D38` are all derived from `outlineArt` rather than added to the set.

Three rules hold the palette together, and breaking one is what broke the old one:

- **The dark ground stays dark.** The home screen is a gallery of bright 4:3 artwork, and artwork needs something to sit against.
  So the ground moved from brown to navy; it did not move to yellow.
  Sunny is the reward colour and never a whole screen.
- **Dark text on a coloured fill, never light.** Cream on teal is 4.4:1 and fails AA; the outline navy on teal is 4.8:1 and on sunny 7.9:1.
  Berry is 4.1:1 on the ground, so it may carry a shape or a ring but not a word - `berryText` `#FF7A78` exists for the cases where the alarm has to be text.
- **A dark line only reads on a bright surround.** Every asset in the game carries a thick dark outline ([imgenprompts/art-direction.md](imgenprompts/art-direction.md)), and that idiom assumes a bright frame.
  On a navy panel the same line disappears, so chrome uses `outline` where it sits on artwork or on an accent fill, and `rim` `#2C5A8F` or teal where one dark surface meets another.

## Owl marks, and the Duolingo question

An owl mascot in a kids app sits next to the most famous owl in software, so the distance is designed in rather than hoped for.

What is actually true: nobody owns "an owl". Duolingo owns a family of US registrations, several of them design marks for its own owl, and it enforces them publicly. The test that matters is likelihood of confusion in the overall commercial impression, in related goods and services - and downloadable software (Class 9) and online game services (Class 41) are exactly where both live. So the question is not "is it an owl", it is "would a parent think this came from them".

How Peepo is kept apart, on purpose. None of these are free to change later without redoing this analysis:

- **Colour.** Peepo is teal on sunny yellow. Duo is a signature bright green, and colour is the strongest recall cue a mascot has. Peepo is never green.
- **Line.** Peepo carries a thick dark navy outline, which is the house style of every asset in the game. Duo has no outline at all.
- **Silhouette.** Peepo has pointed ear tufts and a cream belly patch. Duo's head is smooth and round, with no tufts and no belly.
- **Prop.** The magnifying glass is in the icon and in the search pose, so the mark reads "find things", not "learn things".
- **Positioning.** A hidden object game for 3-12s, sold once. No lessons, no streaks, no nagging mascot, no `-lingo` in the name.

Before shipping, do the free half of this yourself, in an hour:

- A USPTO search in Classes 9 and 41 covering the bird design search codes, not just word marks.
- A sweep of the App Store and Play for owl mascots in children's games.

That is proportionate for a game that has not shipped and earns nothing yet.
A lawyer is worth paying in exactly three cases, and none of them are true today: a search turns up a close owl mark in Class 9 or 41 and the call is not obvious; `Peepo` gets filed as a registered mark, where an attorney meaningfully raises the odds it survives examination; or a cease and desist actually arrives.

The real protection is the design distance above, kept intact.
Enforcement lands on things that trade on Duo - a green owl teaching languages, in his voice. Peepo is none of that.

This section is a design rationale, not legal advice.

## Pre-launch checklist

- [x] Design the app icon (done 2026-08-22, Peepo with a magnifying glass).
- [ ] Search the owl, not just the name: USPTO Classes 9 and 41 including bird design codes, plus an App Store and Play sweep for owl mascots in kids games. An hour, free, no lawyer unless it turns something up.
- [x] Reserve the App Store Connect listing (done 2026-08-22, Apple ID `6804279043`). `Peepo` alone is taken, so the reserved name is `Peepo Hidden Objects for Kids`; the on-device label stays `Peepo` via `CFBundleDisplayName`.
- [ ] Reserve the Play Console listing.
- [ ] USPTO clearance search, Class 9 (downloadable game software) and Class 41 (online game services), including the Ahlberg title.
- [ ] Register a domain. `peepo.com` and `peepo.app` are likely taken by the meme corpus, so expect a modifier such as `peepogame` or `playpeepo`.
- [x] Settle the name for the kids audience before submission (done 2026-08-22, `Peepo`).
- [x] Rename bundle id to `com.glydeo.peepo` (done 2026-08-22, along with the Dart package, Kotlin package, display names and web metadata; was briefly `com.tomerfayer.peepo`, realigned to the Glydeo brand to match the App Store Connect record). Bundle ids cannot be changed after first submission.

## Store listing

The submission-ready fields for both stores - title, subtitle, keyword field, descriptions,
screenshot plan and review notes - are kept out of this repository.
The name reasoning above is the part that is useful publicly; the listing copy itself is not.
