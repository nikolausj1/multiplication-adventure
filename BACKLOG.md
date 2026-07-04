# Backlog

Ideas and deferred work, roughly ordered by value. Nothing here blocks launch.

## Features
- **Boss idle videos** — replace boss stills with seamless idle loops (Kling
  image-to-video, start=end frame on chroma green/magenta → HEVC-alpha →
  `AVPlayerLooper` behind the existing flinch/crit/defeat effects). Pilot with
  2–3 bosses first. Full plan discussed 2026-07-04; Claude generates the
  chroma input frames when ready.
- **True/False lightning round** — mid-summer freshness drop ("7 × 8 = 54,
  true or false?"), big tap targets, fast pace. Good for the week attention dips.
- **Progress export/import** — Parent Area button to export the profile as JSON
  via share sheet (and re-import). Cheap insurance against device loss or a
  botched update; simpler and better-fitting than CloudKit for one kid/one iPad.
- **Per-world ambience loops / background music** — Kling prompts already
  drafted in conversation; volume-ducked under SFX, parent toggle.

## Audio
- **sfx_complete replacement** (session wrap) — last remaining Kenney pick.
  Kling prompt: "Warm short victory jingle, adventurous fantasy feel, gentle
  rising melody, two seconds, celebratory but calm."
- **sfx_world_unlock** — user may still replace (map smoke-reveal + boss verdict).
- **Re-listen to sfx_milestone** — trimmed from a 10s render; may want a re-cut.

## Pre-launch logistics (parent tasks)
- **Apple Developer account decision** — free Apple ID provisioning expires
  every 7 days (app won't open until re-deployed from Xcode; data survives).
  $99/yr removes the treadmill and enables TestFlight.
- **Real-iPad shakedown** — sounds at hardware volume, haptics, touch targets.
- **Fresh profile before day 1** — wipe dev/test data on the son's iPad.
- **Watch the first real boss fight** — CRITICAL! visual lands? 85% pass bar
  feels fair? Quest length/rollover pacing in real play.
