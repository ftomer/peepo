#!/usr/bin/env python3
"""Stage 2 of the scene pipeline: decide how every prop is allowed to hide.

Where a prop ends up is no longer decided here. The game places props when a
level is played, so that no two playthroughs hide the same room the same way
(see lib/game/placement.dart). What is decided here is the freedom the placer
has with each prop: which regions it belongs in, how it meets them, how big it
may be, how far it may turn and how many of it there can be.

The rules are checked against the same meta the placer reads, so a prop the
room cannot actually hold is caught here rather than quietly missing from the
level.

    tools/scene.sh place <id> [--retries 2] [--difficulty medium]
"""
import argparse
import json
import re
import sys

import build_scene
from claude_json import ROOT, ask_json

SCENES = ROOT / "tools" / "scenes"

# Copies beyond one per prop, when the props allow them. Two things hidden
# twice in a scene of a dozen is enough to keep the object list interesting
# without the room feeling like a warehouse.
EXTRA_COPIES = 2

PROMPT = """You are setting the rules for hiding objects in a hand-drawn scene.

Read, in this order:

1. {meta} - the description of the room: regions, depth, lighting, no-go zones
   and placement rules. This is the source of truth; obey it.
2. {background} - the backdrop itself. Look at it closely.
{sheet_lines}

The game places these props itself, freshly every time the level is played. It
picks a region, a size, an angle and a spot, and it obeys the meta while doing
it. Your job is to say what it is allowed to do with each prop.

Set the rules for every one of these props:

{props}

Hard rules:

- "places" is how the prop can meet a region, one or more of: rests_on,
  lies_flat, hangs_on, pinned_to, leans_against, tucked_in, inside. Say what is
  true of the object itself: a bottle rests or leans, it does not hang; a hat
  rests or hangs; a coin rests, lies flat or goes inside something.
- "regions" is a list of region ids the prop belongs in, or [] for "anywhere
  the meta allows". Prefer [] - the more regions a prop can use, the less
  predictable the game is. Name regions only when the prop would look absurd
  elsewhere.
- "width" is [min, max] as a fraction of scene width. Give a real range, not a
  point: the placer narrows it to what each region's depth allows, so a range
  that overlaps several regions is what lets one prop turn up near and far.
  Keep it inside the sizeRange of the regions it can use.
- "rotate" is [min, max] degrees, clockwise on screen. Upright things get a few
  degrees either way; a long thing that lies along a surface can take a lot
  more.
- "copies" is [min, max] times the prop may appear. Give a max above 1 only to
  things that plausibly come in numbers - coins, cannonballs, bottles - and
  never to a unique object.

Difficulty is {difficulty}: {difficulty_note}

Reply with only this JSON array, one entry per prop:

[
  {{"id": "...", "places": ["rests_on"], "regions": [], "width": [0.0, 0.0],
    "rotate": [0, 0], "copies": [1, 1],
    "why": "one short sentence on where this prop belongs in this room"}}
]"""

DIFFICULTY = {
    "kid": "this level is for children aged five to seven. Every prop goes "
           "where a child would look: in plain view, on a surface, resting "
           "the way the real object rests. Keep \"places\" to the plain-view "
           "kinds and leave out tucked_in. Widths run about 0.055 to 0.12 of "
           "scene width: a small prop is not harder here, it is unfair, and a "
           "prop wider than that fills a whole surface and leaves the placer "
           "nowhere for the next one. Rotation stays small, so nothing reads "
           "as knocked over. Leave the busiest regions out of any prop's "
           "list.",
    "easy": "keep the size ranges towards the large end and let props into "
            "low-clutter regions, so a first-time player finds most of them "
            "in a single sweep of the room.",
    "medium": "give most props a range that spans clutter levels, so some "
              "games put them in the open and others tuck them into busy "
              "artwork.",
    "hard": "favour the small end of every size range and regions where the "
            "backdrop already has similar shapes and colours, so props "
            "camouflage.",
}

RULE_KEYS = ("places", "regions", "width", "rotate", "copies")


def format_props(props):
    return "\n".join(
        f"- {p['id']} ({p['label']}): {p.get('shape', '')}" for p in props
    )


def render_props(spec, rules, props):
    """Write the rules back into the build spec, one prop per line."""
    labels = {p["id"]: p["label"] for p in props}
    shapes = {p["id"]: p.get("shape") for p in props}
    # A decoy is ruled on exactly like a find - same rules, same room - and is
    # only told apart when the level is built. Carried through here because
    # this is what rewrites the spec.
    decoys = {p["id"] for p in props if p.get("decoy")}
    spec["props"] = [
        {
            "id": rule["id"],
            "label": labels[rule["id"]],
            **({"shape": shapes[rule["id"]]} if shapes.get(rule["id"]) else {}),
            **({"decoy": True} if rule["id"] in decoys else {}),
            "places": list(rule["places"]),
            "regions": list(rule.get("regions", [])),
            "width": [round(float(w), 4) for w in rule["width"]],
            "rotate": [round(float(r), 1) for r in rule.get("rotate", [0, 0])],
            "copies": [int(c) for c in rule.get("copies", [1, 1])],
        }
        for rule in rules
    ]
    spec["objectCount"] = object_count(spec["props"])
    spec.pop("objects", None)
    text = json.dumps(spec, indent=2)
    # Collapse each prop onto one line, the way the specs are hand-written.
    return re.sub(
        r"\{\s+(\"id\".*?)\s+\}",
        lambda m: "{ " + re.sub(r"\s*\n\s*", " ", m.group(1)) + " }",
        text,
        flags=re.S,
    ) + "\n"


def object_count(props):
    """How many objects a playthrough hides: one of each, plus a few copies.

    Decoys do not count. They go in the room and on no list, so counting them
    here would have the level card promise finds that are not findable.
    """
    finds = [p for p in props if not p.get("decoy")]
    least = sum(p["copies"][0] for p in finds)
    most = sum(p["copies"][1] for p in finds)
    return max(least, min(most, len(finds) + EXTRA_COPIES))


def check_coverage(rules, props):
    """Every prop ruled on exactly once, nothing invented."""
    wanted = {p["id"] for p in props}
    problems = []
    got = []
    for rule in rules:
        if not isinstance(rule, dict) or "id" not in rule:
            problems.append(f"{rule!r}: not a rule object")
            continue
        got.append(rule["id"])
        for key in RULE_KEYS:
            if key not in rule:
                problems.append(f"{rule['id']}: missing {key}")
    for missing in sorted(wanted - set(got)):
        problems.append(f"{missing}: no rules given")
    for extra in sorted(set(got) - wanted):
        problems.append(f"{extra}: not a prop in this scene")
    for pid in sorted({p for p in got if got.count(p) > 1}):
        problems.append(f"{pid}: ruled on more than once")
    return problems


def place(scene_id, retries, difficulty, variant=None):
    dotted = f".{variant}" if variant else ""
    build_path = SCENES / f"{scene_id}{dotted}.build.json"
    if not build_path.exists():
        sys.exit(f"{build_path.relative_to(ROOT)} not found; run analyze first")
    spec = json.loads(build_path.read_text())
    meta = build_scene.load_meta(spec, build_path)
    if meta is None:
        sys.exit(f"{scene_id} has no meta file; run analyze first")
    props = spec.get("props")
    if not props:
        sys.exit(f"{build_path.relative_to(ROOT)} lists no props")

    sheet_lines = "\n".join(
        f"{i + 3}. {sheet['source']} - the sprite sheet the props are cut from."
        for i, sheet in enumerate(spec["sheets"])
    )
    prompt = PROMPT.format(
        meta=spec["meta"],
        background=spec["background"]["source"],
        sheet_lines=sheet_lines,
        props=format_props(props),
        difficulty=difficulty,
        difficulty_note=DIFFICULTY[difficulty],
    )

    rules, problems = None, []
    for attempt in range(retries + 1):
        asked = prompt
        if rules is not None:
            listed = "\n".join(f"- {p}" for p in problems)
            asked = (
                f"{prompt}\n\nYour previous rules had these problems:\n"
                f"{listed}\n\nHere they were:\n{json.dumps(rules)}\n\n"
                f"Fix every problem and keep the rules that were fine."
            )
        print(f"ruling on {len(props)} props (attempt {attempt + 1})",
              file=sys.stderr)
        rules = ask_json(asked)
        if not isinstance(rules, list):
            rules = rules.get("props", rules.get("objects", []))

        problems = check_coverage(rules, props)
        if not problems:
            # The build runs this same check, against this same meta.
            trial = [
                {
                    "id": rule["id"],
                    "places": rule["places"],
                    "regions": rule.get("regions", []),
                    "width": [float(w) for w in rule["width"]],
                    "copies": [int(c) for c in rule.get("copies", [1, 1])],
                }
                for rule in rules
            ]
            problems = build_scene.validate_catalog(
                trial, meta, object_count(trial)
            )
        if not problems:
            break

    build_path.write_text(render_props(spec, rules, props))
    print(f"{build_path.relative_to(ROOT)}: {len(rules)} props ruled on, "
          f"hiding {spec['objectCount']} objects a game")
    for rule in rules:
        why = rule.get("why", "")
        where = ", ".join(rule.get("regions") or ["anywhere it fits"])
        print(f"  {rule['id']} -> {'/'.join(rule['places'])} in {where} {why}")
    for problem in problems:
        print(f"  warning: {problem}")
    if problems:
        print("fix these by hand in the build spec, or re-run with more "
              "--retries")
    tail = f" --variant {variant}" if variant else ""
    print(f"review the rules, then: tools/scene.sh build {scene_id}{tail}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--retries", type=int, default=2,
                        help="re-proposals after a failed validation")
    parser.add_argument("--difficulty", default="medium",
                        choices=sorted(DIFFICULTY))
    parser.add_argument("--variant",
                        help="rule on a variant's spec instead, e.g. dense")
    args = parser.parse_args()
    place(args.scene_id, args.retries, args.difficulty, args.variant)


if __name__ == "__main__":
    main()
