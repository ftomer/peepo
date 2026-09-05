#!/usr/bin/env python3
"""Cut the app icon master into every platform's launcher assets.

    tools/scene.sh icon rawimages/app_icon/icon_3_owl_and_magnifier.png

The master is one square image on a flat background colour, as generated from
docs/imgenprompts/app-icon.md. The model never centres it exactly, so this
script does: it finds the subject's bounding box, drops it back onto a clean
canvas of the background colour at the margin each platform wants, and writes
every size iOS, macOS, Android and the web ask for.

Margins differ because the masks differ. iOS and the web round the corners, so
the art nearly fills the square. Android masks anything from a circle to a
squircle and animates the foreground layer, so both the legacy icon and the
adaptive foreground keep the subject well inside the safe circle.
"""
import argparse
import json
import shutil
import sys
import xml.sax.saxutils as sax
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "rawimages" / "app_icon" / "master.png"

# How much empty background rings the subject, as a fraction of the canvas per
# side. Android's adaptive foreground is drawn on a 108dp canvas of which only
# the middle 72dp is guaranteed visible, and the middle 66dp under a circle.
MARGIN = {"ios": 0.10, "macos": 0.10, "web": 0.09,
          "android_legacy": 0.16, "adaptive": 0.26, "maskable": 0.22}

ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144,
                  "xxxhdpi": 192}
ANDROID_ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
                    "xxxhdpi": 432}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

COLOR_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- The icon master's background, so the adaptive icon's background layer
         matches the art exactly. Written by tools/make_icons.py. -->
    <color name="ic_launcher_background">{hex}</color>
</resources>
"""


def background(image):
    """The master's flat background colour, read from its corners."""
    w, h = image.size
    corners = [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]
    pixels = [image.getpixel(p) for p in corners]
    return tuple(sum(c[i] for c in pixels) // len(pixels) for i in range(3))


def subject(image, bg, tolerance=24):
    """The master cropped to its subject, background trimmed off every side."""
    diff = ImageChops.difference(image, Image.new("RGB", image.size, bg))
    red, green, blue = diff.split()
    channel = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    box = channel.point(lambda v: 255 if v > tolerance else 0).getbbox()
    if not box:
        sys.exit("no subject found: the master looks like one flat colour")
    return image.crop(box)


def canvas(art, bg, size, margin):
    """The subject centred on a `size` square of `bg`, ringed by `margin`."""
    inner = round(size * (1 - 2 * margin))
    scale = inner / max(art.size)
    fitted = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )
    out = Image.new("RGB", (size, size), bg)
    out.paste(fitted, ((size - fitted.width) // 2,
                       (size - fitted.height) // 2))
    return out


def appiconset(art, bg, folder, margin):
    """Every size the Xcode asset catalog at `folder` lists."""
    contents = json.loads((folder / "Contents.json").read_text())
    written = {}
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        px = round(float(entry["size"].split("x")[0]) * float(
            entry["scale"].rstrip("x")))
        written.setdefault(name, px)
        written[name] = max(written[name], px)
    for name, px in sorted(written.items()):
        canvas(art, bg, px, margin).save(folder / name)
    return len(written)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("master", nargs="?", default=str(MASTER),
                        help=f"square icon art (default {MASTER.relative_to(ROOT)})")
    parser.add_argument("--keep-master", action="store_true",
                        help="do not copy the pick over the current master")
    args = parser.parse_args()

    src = Path(args.master)
    if not src.exists():
        sys.exit(f"{src}: no such file")
    image = Image.open(src).convert("RGB")
    if image.width != image.height:
        sys.exit(f"{src}: master must be square, got {image.size}")

    bg = background(image)
    art = subject(image, bg)
    print(f"master {src.name}: {image.size[0]}px, background #"
          f"{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}, subject {art.size[0]}x"
          f"{art.size[1]}")

    if not args.keep_master and src.resolve() != MASTER.resolve():
        MASTER.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, MASTER)
        print(f"{MASTER.relative_to(ROOT)}: master copied")

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    count = appiconset(art, bg, ios, MARGIN["ios"])
    print(f"{ios.relative_to(ROOT)}: {count} icons")

    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    count = appiconset(art, bg, mac, MARGIN["macos"])
    print(f"{mac.relative_to(ROOT)}: {count} icons")

    res = ROOT / "android/app/src/main/res"
    for density, px in ANDROID_LEGACY.items():
        folder = res / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        canvas(art, bg, px, MARGIN["android_legacy"]).save(
            folder / "ic_launcher.png")
    for density, px in ANDROID_ADAPTIVE.items():
        folder = res / f"mipmap-{density}"
        # Opaque, and the same colour as the background layer, so the parallax
        # the launcher applies to the foreground never exposes an edge.
        canvas(art, bg, px, MARGIN["adaptive"]).save(
            folder / "ic_launcher_foreground.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML)
    hexcolor = sax.escape(f"#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}")
    (res / "values" / "ic_launcher_background.xml").write_text(
        COLOR_XML.format(hex=hexcolor))
    print(f"{res.relative_to(ROOT)}: {len(ANDROID_LEGACY)} legacy + "
          f"{len(ANDROID_ADAPTIVE)} adaptive icons")

    web = ROOT / "web"
    canvas(art, bg, 32, MARGIN["web"]).save(web / "favicon.png")
    for px in (192, 512):
        canvas(art, bg, px, MARGIN["web"]).save(web / "icons" / f"Icon-{px}.png")
        canvas(art, bg, px, MARGIN["maskable"]).save(
            web / "icons" / f"Icon-maskable-{px}.png")
    print(f"{web.relative_to(ROOT)}: favicon + 4 icons")


if __name__ == "__main__":
    main()
