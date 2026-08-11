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
OVERLAP = 190          # canvas px of the repainted context kept for cross-fading

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
    # Cache the raw model output so compositing can be iterated on for free.
    cache = OUT.parent / f"wing_{side}_raw.png"
    if cache.exists() and "--regen" not in sys.argv:
        print(f"  reusing cached {side} wing ({cache.name})")
        return Image.open(cache).convert("RGB")
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
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(cache)
    return out


def main() -> None:
    key = api_key()
    src = Image.open(SRC).convert("RGBA")
    W, H = src.size
    print(f"source {W}x{H} ({W/H:.2f}:1)")

    raw = {s: outpaint(src, s, key) for s in ("left", "right")}

    import numpy as np
    scale = H / GEN                       # canvas px -> final px
    wing_w = H                            # the pure extension each side adds
    over = int(round(OVERLAP * scale))    # blended band, sits ON TOP of the original
    new_w = W + 2 * wing_w

    base = np.zeros((H, new_w, 4), dtype=float)
    s_arr = np.asarray(src, dtype=float)
    base[:, wing_w:wing_w + W] = s_arr    # original in the middle

    # The banner fades out at the bottom via alpha; carry that same ramp into
    # the wings so they melt into the map fog exactly like the original does.
    bottom = np.asarray(src.split()[3].resize((1, H), Image.LANCZOS), dtype=float).reshape(H, 1) / 255.0

    for side in ("left", "right"):
        # Crop past the seam into the context zone the model also repainted, so
        # there is material to cross-fade with. A hard butt-join showed a clear
        # vertical step in both tone and detail.
        c = raw[side]
        box = (0, 0, GEN + OVERLAP, GEN) if side == "left" else (CANVAS - GEN - OVERLAP, 0, CANVAS, GEN)
        w_img = c.crop(box).resize((wing_w + over, H), Image.LANCZOS)
        w_arr = np.asarray(w_img, dtype=float)

        # Gentle tone match: line the wing's seam band up with the original's
        # edge band so the cross-fade is not fading between two exposures.
        if side == "left":
            wing_band, src_band = w_arr[:, wing_w:wing_w + over], s_arr[:, :over, :3]
        else:
            wing_band, src_band = w_arr[:, :over], s_arr[:, W - over:, :3]
        gain = np.clip(src_band.mean(axis=(0, 1)) / np.maximum(wing_band.mean(axis=(0, 1)), 1e-6), 0.75, 1.33)
        w_arr = np.clip(w_arr * gain, 0, 255)

        # Horizontal alpha: solid across the extension, ramping to zero across
        # the overlap so the original wins at the seam.
        ramp = np.ones(wing_w + over)
        fade = np.linspace(1.0, 0.0, over)
        if side == "left":
            ramp[wing_w:] = fade
            x0 = 0
        else:
            ramp[:over] = fade[::-1]
            x0 = W + wing_w - over
        a = (ramp.reshape(1, -1) * bottom)[..., None]
        dst = base[:, x0:x0 + wing_w + over]
        dst[..., :3] = w_arr * a + dst[..., :3] * (1 - a)
        dst[..., 3:4] = np.maximum(dst[..., 3:4], a * 255)

    out = Image.fromarray(np.clip(base, 0, 255).astype("uint8"), "RGBA")
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
