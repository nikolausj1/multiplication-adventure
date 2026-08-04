#!/bin/bash
# Turn a ProRes 4444 boss master (with alpha) into a shippable looping
# HEVC-with-alpha asset.
#
#   ./scripts/make-boss-video.sh <master.mov> <worldN> [quality]
#   e.g. ./scripts/make-boss-video.sh _inbox/bossVideos/world2boss.MOV world2
#
# Three things happen, and all three matter:
#   1. Measure — find the union bounding box of the opaque pixels across EVERY
#      frame (the boss moves; a crop tight on frame 0 clips him mid-sway), and
#      find the first/last frames that actually contain the boss at all.
#      Some renders fade in from a fully transparent frame — world 5's frame 0
#      was 100% transparent, which both breaks the bbox math and would make the
#      boss blink out at the loop point. Those frames get trimmed.
#   2. ffmpeg — trim, crop, and bake a ping-pong loop (forward, then reversed
#      minus the duplicated end frames) so it repeats seamlessly. Kling renders
#      do NOT loop on their own.
#   3. AVAssetWriter (prores2hevcalpha.swift) — re-encode to Apple's
#      AVVideoCodecType.hevcWithAlpha.
#
# Why step 3 instead of letting ffmpeg encode HEVC directly: ffmpeg's
# `hevc_videotoolbox -alpha_quality` produces a file that ADVERTISES alpha
# (AVFoundation reports ContainsAlphaChannel=1) and that ffmpeg itself can
# decode back with alpha intact — but it tags AlphaChannelMode as
# PremultipliedAlpha, and AVPlayerLayer ignores that at playback: the boss
# renders in a white box showing the original un-keyed background. Apple's own
# encoder writes StraightAlpha and composites correctly. Verified 2026-08-03.
set -euo pipefail
cd "$(dirname "$0")/.."

MASTER="${1:?usage: make-boss-video.sh <master.mov> <worldN> [quality]}"
WORLD="${2:?missing world key, e.g. world2}"
QUALITY="${3:-0.9}"
OUT="Sources/App/Resources/BossVideos/${WORLD}_boss.mov"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Measuring opaque bounding box and usable frame range"
ffmpeg -v error -y -i "$MASTER" -vsync 0 "$TMP/%04d.png"

MEASURE=$(python3 - "$TMP" <<'PY'
import sys, glob
import numpy as np
from PIL import Image

files = sorted(glob.glob(sys.argv[1] + "/*.png"))
if not files:
    sys.exit("no frames extracted")

x0 = y0 = 10**9; x1 = y1 = -1
first_good = last_good = None
W = H = 0
for i, f in enumerate(files):
    a = np.asarray(Image.open(f).convert("RGBA"))[..., 3] > 16
    H, W = a.shape
    if not a.any():
        continue                      # fully transparent frame — skip entirely
    if first_good is None:
        first_good = i
    last_good = i
    ys, xs = np.where(a)
    x0 = min(x0, xs.min()); x1 = max(x1, xs.max())
    y0 = min(y0, ys.min()); y1 = max(y1, ys.max())

if first_good is None:
    sys.exit("every frame is fully transparent — is this really an alpha master?")

PAD = 6                                # safety margin, clamped to the frame
x0 = max(0, x0 - PAD); y0 = max(0, y0 - PAD)
x1 = min(W - 1, x1 + PAD); y1 = min(H - 1, y1 + PAD)
w = (x1 - x0 + 1) // 2 * 2             # even dimensions for the encoder
h = (y1 - y0 + 1) // 2 * 2
print(w, h, x0, y0, first_good, last_good, len(files))
PY
)
read -r CW CH CX CY F0 F1 NTOTAL <<<"$MEASURE"
NKEEP=$(( F1 - F0 + 1 ))
echo "  crop=${CW}:${CH}:${CX}:${CY}   frames ${F0}..${F1} of ${NTOTAL} (${NKEEP} kept)"
if [ "$NKEEP" -lt "$NTOTAL" ]; then
  echo "  (trimmed $(( NTOTAL - NKEEP )) fully-transparent frame(s))"
fi
if [ "$NKEEP" -lt 8 ]; then
  echo "  ERROR: only $NKEEP usable frames — refusing to build a loop from that" >&2
  exit 1
fi

echo "→ Pass 1: trim + crop + ping-pong loop (ProRes 4444 intermediate)"
# The reversed half drops its first and last frames, otherwise the turnaround
# stutters on a duplicated frame.
REV_LAST=$(( NKEEP - 2 ))
ffmpeg -v error -y -i "$MASTER" -filter_complex \
  "[0:v]select='between(n\,${F0}\,${F1})',setpts=N/FRAME_RATE/TB,crop=${CW}:${CH}:${CX}:${CY},split[a][b];\
   [b]reverse,select='between(n\,1\,${REV_LAST})',setpts=N/FRAME_RATE/TB[r];\
   [a][r]concat=n=2:v=1[out]" \
  -map "[out]" -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -an -sn "$TMP/intermediate.mov"

echo "→ Pass 2: re-encode to Apple hevcWithAlpha"
swift scripts/prores2hevcalpha.swift "$TMP/intermediate.mov" "$OUT" "$QUALITY" 2>/dev/null | tail -4

echo "→ Verifying alpha survived"
if ! swift scripts/alphacheck.swift "$OUT" 2>/dev/null | grep -q "containsAlphaChannel): true"; then
  echo "  ERROR: output does not report an alpha channel" >&2
  exit 1
fi
swift scripts/alphacheck.swift "$OUT" 2>/dev/null | grep -E "AlphaChannelMode|naturalSize"
ls -lh "$OUT"
echo "✓ $OUT — rebuild the app to pick it up"
