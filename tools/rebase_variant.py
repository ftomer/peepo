#!/usr/bin/env python3
"""Point a variant's build spec at the level's own props.

    tools/rebase_variant.py <scene id> --variant dense --decoys a b c d e f

Stage 1 reads the sprite sheets fresh for every scene it describes, so a
variant of a level that already exists comes back with the same art under new
names: the meadow's `unicorn_toy` is `pink_unicorn` again, and `clover` is
`four_leaf_clover`. That is right for a new level and wrong for a variant,
which has to hide the same things as the scene it is a variant of - same ids,
same sprites, same find list, one catalog entry.

This replaces the re-derived props with the base spec's own, appends the decoy
sheet's props marked as decoys, and leaves the room description alone. What it
does not do is rule on any of them: the regions in a variant's meta are its
own, so `tools/scene.sh place <id> --variant <name>` still has to run after it.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENES = ROOT / "tools" / "scenes"


def rebase(scene_id, variant, decoy_ids):
    base_path = SCENES / f"{scene_id}.build.json"
    variant_path = SCENES / f"{scene_id}.{variant}.build.json"
    for path in (base_path, variant_path):
        if not path.exists():
            sys.exit(f"{path.relative_to(ROOT)} not found")

    base = json.loads(base_path.read_text())
    spec = json.loads(variant_path.read_text())

    # The variant's own sheets, in the order stage 1 read them: the level's
    # sheets first, the decoy sheet last.
    sheets = spec["sheets"]
    if len(sheets) != len(base["sheets"]) + 1:
        sys.exit(
            f"{scene_id}: expected the level's {len(base['sheets'])} sheets "
            f"plus one decoy sheet, got {len(sheets)}"
        )
    for i, sheet in enumerate(base["sheets"]):
        sheets[i]["names"] = list(sheet["names"])
    if len(decoy_ids) != len(sheets[-1]["names"]):
        sys.exit(
            f"{scene_id}: decoy sheet holds {len(sheets[-1]['names'])} cells "
            f"but {len(decoy_ids)} ids were given"
        )
    sheets[-1]["names"] = list(decoy_ids)

    # The re-derived props are thrown away; their shape notes are keyed to the
    # names stage 1 invented and mean nothing against the level's own ids.
    props = [dict(prop) for prop in base["props"]]
    # Regions are the one thing that cannot carry over: a variant's meta
    # describes a different room, and a prop pinned to a region id that is not
    # in it can be placed nowhere at all.
    for prop in props:
        prop["regions"] = []
    props += [
        {
            "id": pid,
            "label": pid.replace("_", " ").title(),
            "decoy": True,
            "places": ["rests_on"],
            "regions": [],
            "width": [0.04, 0.09],
            "rotate": [-10, 10],
            "copies": [1, 1],
        }
        for pid in decoy_ids
    ]
    spec["props"] = props
    spec["objectCount"] = base["objectCount"]
    variant_path.write_text(json.dumps(spec, indent=2) + "\n")

    finds = [p for p in props if not p.get("decoy")]
    print(
        f"{variant_path.relative_to(ROOT)}: {len(finds)} props from "
        f"{base_path.name} + {len(decoy_ids)} decoys, hiding "
        f"{spec['objectCount']} objects a game"
    )
    print(f"now: tools/scene.sh place {scene_id} --variant {variant}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_id")
    parser.add_argument("--variant", default="dense")
    parser.add_argument("--decoys", nargs="+", required=True,
                        help="ids for the decoy sheet's cells, reading order")
    args = parser.parse_args()
    rebase(args.scene_id, args.variant, args.decoys)


if __name__ == "__main__":
    main()
