#!/bin/bash
# Turn a ProRes 4444 boss master (with alpha) into a shippable looping
# HEVC-with-alpha asset.
#
#   ./scripts/make-boss-video.sh <master.mov> <worldN> [quality]
#   e.g. ./scripts/make-boss-video.sh _inbox/bossVideos/world2boss.MOV world2
#
# Two passes, and BOTH are required:
#   1. ffmpeg — crop to the union bounding box of the animation (so the video
#      drops into BossPanel at the same size the still occupied) and bake a
#      ping-pong loop (forward, then reversed minus the duplicated end frames)
#      so it repeats seamlessly. Kling renders do NOT loop on their own.
#   2. AVAssetWriter (prores2hevcalpha.swift) — re-encode to Apple's
#      AVVideoCodecType.hevcWithAlpha.
#
# Why pass 2 instead of just letting ffmpeg encode HEVC directly: ffmpeg's
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

echo "→ Measuring the animation's union bounding box"
# The boss MOVES, so crop to the union of every frame's opaque area, not
# frame 0's. A crop that is tight on frame 0 will clip him mid-sway.
ffmpeg -v error -y -i "$MASTER" -vsync 0 "$TMP/%04d.png"
read -r CW CH CX CY <<EOF
$(python3 - "$TMP" <<'PY'
import sys, glob
import numpy as np
from PIL import Image
x0 = y0 = 10**9; x1 = y1 = -1
for f in sorted(glob.glob(sys.argv[1] + "/*.png")):
    a = np.asarray(Image.open(f).convert("RGBA"))[..., 3] > 16
    ys, xs = np.where(a)
    x0 = min(x0, xs.min()); x1 = max(x1, xs.max())
    y0 = min(y0, ys.min()); y1 = max(y1, ys.max())
    H, W = a.shape
# 6px of safety, clamped to the frame, and even dimensions for the encoder
PAD = 6
x0 = max(0, x0 - PAD); y0 = max(0, y0 - PAD)
x1 = min(W - 1, x1 + PAD); y1 = min(H - 1, y1 + PAD)
w = (x1 - x0 + 1) // 2 * 2
h = (y1 - y0 + 1) // 2 * 2
print(w, h, x0, y0)
PY
)
EOF
echo "  crop=${CW}:${CH}:${CX}:${CY}"

echo "→ Pass 1: crop + ping-pong loop (ProRes 4444 intermediate)"
# reverse then drop the first and last reversed frames, otherwise the turnaround
# stutters on a duplicated frame.
ffmpeg -v error -y -i "$MASTER" -filter_complex \
  "[0:v]crop=${CW}:${CH}:${CX}:${CY},split[a][b];\
   [b]reverse,select='between(n\,1\,$(( $(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$MASTER") - 2 )))',setpts=N/FRAME_RATE/TB[r];\
   [a][r]concat=n=2:v=1[out]" \
  -map "[out]" -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -an -sn "$TMP/intermediate.mov"

echo "→ Pass 2: re-encode to Apple hevcWithAlpha"
swift scripts/prores2hevcalpha.swift "$TMP/intermediate.mov" "$OUT" "$QUALITY" 2>/dev/null | tail -4

echo "→ Verifying alpha survived"
swift scripts/alphacheck.swift "$OUT" 2>/dev/null | grep -E "containsAlphaChannel|AlphaChannelMode|naturalSize"
ls -lh "$OUT"
echo "✓ $OUT — rebuild the app to pick it up"
