#!/usr/bin/env python3
"""Generate a level's raw art from its brief.

The brief in docs/imgenprompts/<level>.md is the source of truth: every fenced
```prompt block under a heading becomes one image, written into
rawimages/<level>/. Editing the brief and re-running is how art gets iterated,
so the prompt that produced a level is always the prompt sitting in the repo.

    tools/scene.sh art docs/imgenprompts/toy-room.md [--force] [--only Backdrop]

Needs GEMINI_API_KEY in the environment.
"""
import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "rawimages"
ENDPOINT = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}"
    ":generateContent?key={key}"
)
# Backdrops need the room's proportions; a 3x2 sheet needs cells that come out
# square, which is what 3:2 gives. An app icon is square by definition.
ASPECT = {"backdrop": "4:3", "sheet": "3:2", "icon": "1:1"}
# A heading, then anything that is not another heading, then its prompt fence.
#
# The heading is matched without crossing a newline and the prose under it is
# tempered against a further "## ", so a section may explain itself before its
# prompt and a section with no prompt at all claims nothing. Written as one
# greedy `.+?` under re.S this swallowed every paragraph between a heading and
# the next fence into the heading itself, which is silent: the prompt sent is
# still right, but it lands in a file named after six hundred characters of
# prose and is sized as whatever `kind` makes of them.
BLOCK = re.compile(
    r"^##[ \t]+(?P<heading>[^\n]+?)[ \t]*$"
    r"(?P<between>(?:(?!^##[ \t]).)*?)"
    r"^```prompt\n(?P<prompt>.*?)\n```",
    re.M | re.S,
)


def blocks(brief):
    """[(heading, prompt)] for every ```prompt block in the brief."""
    return [
        (m.group("heading"), m.group("prompt").strip())
        for m in BLOCK.finditer(brief)
    ]


def output_name(heading):
    """Backdrop -> background.jpeg, Sheet 1 -> sheet_1.jpeg."""
    slug = re.sub(r"[^a-z0-9]+", "_", heading.lower()).strip("_")
    if slug == "backdrop":
        return "background.jpeg"
    # Icons are cut out and rescaled, so they need lossless alpha-capable PNG.
    return f"{slug}.png" if slug.startswith("icon") else f"{slug}.jpeg"


def kind(heading):
    """What shape this block wants: a sheet, an icon, or a backdrop.

    Matched anywhere in the heading rather than on its first word, so "Decoy
    sheet" is a sheet. Getting this wrong is quiet and expensive: a sheet
    generated at a backdrop's 4:3 comes back with cells that are not square,
    and the cutter slices six lopsided sprites out of it without complaining.
    """
    words = set(re.split(r"[^a-z0-9]+", heading.lower()))
    if "icon" in words:
        return "icon"
    return "sheet" if "sheet" in words else "backdrop"


def generate(prompt, model, aspect, size, key, source=None):
    """One image. With [source], the model is handed a picture to work from.

    Handing it the room it is meant to add to is what makes a baked scene
    possible: the picture that comes back is the same room with the finds in
    it, so the room as it was is a clean plate, pixel for pixel, and a find
    can be rubbed out again by painting the plate back over it.
    """
    parts = [{"text": prompt}]
    if source is not None:
        parts.append({
            "inlineData": {
                "mimeType": "image/jpeg",
                "data": base64.b64encode(source.read_bytes()).decode(),
            }
        })
    body = json.dumps({
        "contents": [{"parts": parts}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "imageConfig": {"aspectRatio": aspect, "imageSize": size},
        },
    }).encode()
    request = urllib.request.Request(
        ENDPOINT.format(model=model, key=key),
        data=body,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode()[:500]
        raise SystemExit(f"gemini {error.code}: {detail}") from error

    candidates = payload.get("candidates") or []
    if not candidates:
        raise SystemExit(f"no image returned: {json.dumps(payload)[:400]}")
    for part in candidates[0]["content"]["parts"]:
        if "inlineData" in part:
            return base64.b64decode(part["inlineData"]["data"])
    text = " ".join(
        p.get("text", "") for p in candidates[0]["content"]["parts"]
    )
    raise SystemExit(f"model replied with text instead of an image: {text[:300]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("brief", help="docs/imgenprompts/<level>.md")
    parser.add_argument("--model", default="gemini-3-pro-image")
    parser.add_argument("--size", default="2K", choices=["1K", "2K", "4K"])
    parser.add_argument("--only", action="append",
                        help="generate just this heading, repeatable")
    parser.add_argument("--force", action="store_true",
                        help="overwrite art that already exists")
    parser.add_argument("--takes", type=int, default=1,
                        help="how many pictures to draw from each prompt, "
                             "numbered; a scene that wants a different layout "
                             "every playthrough needs several")
    parser.add_argument("--from", dest="source", metavar="IMAGE",
                        help="a picture to work from, e.g. the room a baked "
                             "scene adds its finds to")
    args = parser.parse_args()

    # Either key: the project's own, or the studio-wide one the .env carries.
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GEMINI_GLYDEO")
    if not key:
        sys.exit("neither GEMINI_API_KEY nor GEMINI_GLYDEO is set")

    source = Path(args.source) if args.source else None
    if source is not None and not source.exists():
        sys.exit(f"{source} not found")

    brief = Path(args.brief)
    level = re.sub(r"[^a-z0-9]+", "_", brief.stem.lower()).strip("_")
    out_dir = RAW / level
    out_dir.mkdir(parents=True, exist_ok=True)

    found = blocks(brief.read_text())
    if not found:
        sys.exit(f"{brief}: no ```prompt blocks")

    for heading, prompt in found:
        if args.only and heading not in args.only:
            continue
        for take in range(1, args.takes + 1):
            name = output_name(heading)
            if args.takes > 1:
                stem, dot, ext = name.rpartition(".")
                name = f"{stem}_{take}{dot}{ext}"
            path = out_dir / name
            if path.exists() and not args.force:
                print(f"{path.relative_to(ROOT)}: exists, skipped")
                continue
            print(f"generating {heading} -> {path.relative_to(ROOT)}",
                  file=sys.stderr)
            image = generate(prompt, args.model, ASPECT[kind(heading)],
                             args.size, key, source=source)
            path.write_bytes(image)
            print(f"{path.relative_to(ROOT)}: {len(image) // 1024} KB")

    print(f"art in {out_dir.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
