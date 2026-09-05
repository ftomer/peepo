#!/usr/bin/env python3
"""Cut Peepo's poses out of their flat background, ready for the screens.

    tools/scene.sh mascot

Reads every `rawimages/peepo_mascot/icon_peepo_<pose>.png` the art step wrote
from docs/imgenprompts/peepo-mascot.md, strips the flat background colour off
each one and writes `assets/peepo/<pose>.png` with transparency.

The background is only removed where it is connected to the border, so the
white of an eye and the cream of a belly survive: the flood never reaches
them. Edge pixels keep a partial alpha, which is what stops the thick outline
coming out jagged against a dark screen.
"""
import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "rawimages" / "peepo_mascot"
OUT = ROOT / "assets" / "peepo"

# A pixel this close to the background colour is background; one this far from
# it is subject. In between it is an antialiased edge and keeps partial alpha.
NEAR = 12
FAR = 46
SIZE = 512


def background(image):
    w, h = image.size
    corners = [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]
    pixels = [image.getpixel(p) for p in corners]
    return tuple(sum(c[i] for c in pixels) // len(pixels) for i in range(3))


def distance(image, bg):
    """Per pixel distance from the background colour, as an L band."""
    diff = ImageChops.difference(image, Image.new("RGB", image.size, bg))
    red, green, blue = diff.split()
    return ImageChops.lighter(ImageChops.lighter(red, green), blue)


def outside(dist, width, height):
    """The background region reachable from the border, flood filled."""
    near = dist.load()
    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        for y in (0, height - 1):
            queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if seen[index] or near[x, y] > NEAR:
            continue
        seen[index] = 1
        if x > 0:
            queue.append((x - 1, y))
        if x < width - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < height - 1:
            queue.append((x, y + 1))
    return seen


def cut(image):
    """The subject on transparency, trimmed to its own bounds."""
    bg = background(image)
    dist = distance(image, bg)
    width, height = image.size
    seen = outside(dist, width, height)

    # Opaque wherever the flood never reached; inside the flooded ring the
    # alpha ramps with the distance from the background colour, which is what
    # keeps the outline smooth instead of stair stepped.
    ramp = dist.point(
        lambda v: 0 if v <= NEAR else
        255 if v >= FAR else round((v - NEAR) * 255 / (FAR - NEAR))
    )
    solid = Image.frombytes(
        "L", image.size, bytes(0 if flooded else 255 for flooded in seen))
    alpha = ImageChops.lighter(solid, ramp)

    out = image.convert("RGBA")
    out.putalpha(alpha)
    box = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if not box:
        sys.exit("nothing left after the cut: is the background flat?")
    return out.crop(box)


def fit(art, size):
    """The cutout centred on a transparent square of `size`."""
    scale = size / max(art.size)
    art = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )
    square = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    square.paste(art, ((size - art.width) // 2, (size - art.height) // 2))
    return square


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("poses", nargs="*",
                        help="pose names to cut, default all of them")
    parser.add_argument("--size", type=int, default=SIZE,
                        help=f"square output size, default {SIZE}")
    args = parser.parse_args()

    sources = sorted(RAW.glob("icon_peepo_*.png"))
    if not sources:
        sys.exit(f"no art in {RAW.relative_to(ROOT)}: run tools/scene.sh art "
                 "docs/imgenprompts/peepo-mascot.md first")
    OUT.mkdir(parents=True, exist_ok=True)
    for source in sources:
        pose = source.stem.removeprefix("icon_peepo_")
        if args.poses and pose not in args.poses:
            continue
        art = fit(cut(Image.open(source).convert("RGB")), args.size)
        path = OUT / f"{pose}.png"
        art.save(path)
        print(f"{path.relative_to(ROOT)}: {args.size}px")


if __name__ == "__main__":
    main()
