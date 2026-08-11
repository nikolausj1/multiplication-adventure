#!/usr/bin/env python3
"""Widen map_banner.png so it reaches the screen edges on iPhone landscape.

The painted banner is 2732x766 (3.57:1). Capped at ~150pt tall on a 956pt-wide
iPhone screen it only spans ~535pt, leaving bare map either side. Scaling it up
to fill the width instead blows up the wordmark and crops the art, so the fix is
to EXTEND the painting horizontally and leave the logo at its natural size.

Each wing is generated in one pass at 1024x1024 and scaled DOWN to 766x766 (a
downscale, so no upscaling softness), giving 4264x766 = 5.57:1 — enough to cover
956pt at a 172pt cap.

Usage:
    export OPENAI_API_KEY=$(cat ~/.secrets/openai_key)   # or your own source
    python3 scripts/outpaint-banner.py

Writes map_banner_wide.png next to the script's output dir and, with --install,
replaces the asset in Assets.xcassets (the original is backed up first).
"""
import base64
import io
import os
import sys
from pathlib import Path

import requests
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources/App/Resources/Assets.xcassets/map_banner.imageset/map_banner.png"
OUT = ROOT / "build" / "map_banner_wide.png"

MODEL = "gpt-image-1"
CANVAS = 1536          # generated canvas is CANVAS x 1024
GEN = 1024             # the square region the model fills, per side
CONTEXT = CANVAS - GEN # source context handed to the model on the inner side

PROMPT = (
    "Extend this painted fantasy game banner further to the {side}. Continue the "
    "existing matte-painting landscape seamlessly: {desc} Match the existing "
    "brush style, lighting direction, atmospheric haze and colour grade exactly. "
    "It must look like one continuous wide vista painted by the same artist. "
    "Absolutely no text, no letters, no logos, no emblems, no banners, no signs, "
    "no characters — landscape and sky only."
)
LEFT_DESC = ("cool blue sky with layered cumulus cloud, and distant snow-capped "
             "mountain ridges receding into pale haze at the far left")
RIGHT_DESC = ("warm golden sunset sky, and jagged rocky spires with mossy green "
              "cliffs receding into warm haze at the far right")


def api_key() -> str:
    k = os.environ.get("OPENAI_API_KEY", "").strip()
    if not k:
        sys.exit("OPENAI_API_KEY is not set. See the usage note at the top of this file.")
    return k


def png_bytes(im: Image.Image) -> bytes:
    b = io.BytesIO()
    im.save(b, format="PNG")
    return b.getvalue()


def build_request_images(src: Image.Image, side: str):
    """Canvas with source context on the inner edge and a hole to fill."""
    W, H = src.size
    scale = GEN / H                      # source scaled so its height fills the canvas
    ctx_src_w = int(round(CONTEXT / scale))
    if side == "left":
        strip = src.crop((0, 0, ctx_src_w, H))
    else:
        strip = src.crop((W - ctx_src_w, 0, W, H))
    strip = strip.convert("RGB").resize((CONTEXT, GEN), Image.LANCZOS)

    canvas = Image.new("RGB", (CANVAS, GEN), (20, 22, 30))
    mask = Image.new("RGBA", (CANVAS, GEN), (0, 0, 0, 0))      # alpha 0 => generate here
    keep = Image.new("RGBA", (CONTEXT, GEN), (0, 0, 0, 255))   # alpha 255 => keep
    if side == "left":
        canvas.paste(strip, (GEN, 0))
        mask.paste(keep, (GEN, 0))
    else:
        canvas.paste(strip, (0, 0))
        mask.paste(keep, (0, 0))
    return canvas, mask


def outpaint(src: Image.Image, side: str, key: str) -> Image.Image:
    canvas, mask = build_request_images(src, side)
    desc = LEFT_DESC if side == "left" else RIGHT_DESC
    print(f"  requesting {side} wing ({CANVAS}x{GEN})…", flush=True)
    r = requests.post(
        "https://api.openai.com/v1/images/edits",
        headers={"Authorization": f"Bearer {key}"},
        files={
            "image": ("canvas.png", png_bytes(canvas), "image/png"),
            "mask": ("mask.png", png_bytes(mask), "image/png"),
        },
        data={"model": MODEL, "prompt": PROMPT.format(side=side, desc=desc),
              "size": f"{CANVAS}x{GEN}", "n": "1"},
        timeout=600,
    )
    if r.status_code != 200:
        sys.exit(f"API error {r.status_code}: {r.text[:600]}")
    out = Image.open(io.BytesIO(base64.b64decode(r.json()["data"][0]["b64_json"]))).convert("RGB")
    if out.size != (CANVAS, GEN):
        out = out.resize((CANVAS, GEN), Image.LANCZOS)
    wing = out.crop((0, 0, GEN, GEN)) if side == "left" else out.crop((CANVAS - GEN, 0, CANVAS, GEN))
    return wing


def main() -> None:
    key = api_key()
    src = Image.open(SRC).convert("RGBA")
    W, H = src.size
    print(f"source {W}x{H} ({W/H:.2f}:1)")

    wings = {s: outpaint(src, s, key) for s in ("left", "right")}

    wing_w = H                                   # 1024x1024 scaled to HxH
    new_w = W + 2 * wing_w
    out = Image.new("RGBA", (new_w, H), (0, 0, 0, 0))

    # The banner fades out at the bottom via alpha; carry that ramp into the
    # wings so they melt into the map fog exactly like the original does.
    alpha_profile = src.split()[3].resize((1, H), Image.LANCZOS).resize((wing_w, H), Image.LANCZOS)
    for side, wing in wings.items():
        w = wing.resize((wing_w, H), Image.LANCZOS).convert("RGBA")
        w.putalpha(alpha_profile)
        out.paste(w, (0 if side == "left" else W + wing_w, 0))
    out.paste(src, (wing_w, 0), src)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(f"wrote {OUT}  ->  {new_w}x{H} ({new_w/H:.2f}:1)")
    print(f"covers {new_w/H*172:.0f}pt at a 172pt cap (iPhone landscape is 956pt)")

    if "--install" in sys.argv:
        backup = SRC.with_suffix(".original.png")
        if not backup.exists():
            SRC.rename(backup)
            print(f"backed up original -> {backup.name}")
        out.save(SRC)
        print(f"installed into {SRC}")


if __name__ == "__main__":
    main()
