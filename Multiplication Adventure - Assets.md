---
title: "Multiplication Adventure — Asset Production Guide"
created: 2026-06-24
revised: 2026-06-27
companion_to: "Multiplication Adventure - Spec.md"
image_tool: "ChatGPT Images 2.0"
---

# Asset Production Guide

A **step-by-step checklist**. Do the steps **in order, top to bottom, one prompt at a
time.** Every prompt is fully self-contained (style is baked in — nothing to assemble) and
written as a single block you can copy in one go. Each step tells you whether to start a
**new chat** or stay in the **same** one, what **reference image** to attach, and what to
**save the result as**.

**Tone:** these worlds should feel **cool, epic, and rewarding for a 9–10-year-old** — a
real adventure (think a modern action-adventure platformer), bright and vibrant but never
babyish or cutesy.

---

## How to read each step

> **Thread:** 🆕 new chat (with the name to give it) · ↳ stay in the current chat
> **Attach:** the reference image to drag in (or *none*)
> **Prompt:** copy the whole block
> **Save as:** the exact filename to download it as

---

## Consistency strategy (the 30-second version)

1. **Step 1 makes your "Style Key."** The very first image (World 1 background) defines the
   whole game's look. After you make it, **download it as `world1_bg.jpg` — you will attach
   it again and again.** Generate it 2–3 times and pick your favorite before locking it.
2. **Backgrounds** are made in one chat, each new one attaching the Style Key so all 7
   worlds match.
3. **Nodes** and **buttons** are each made in their own chat; for each world you attach
   **that world's finished background** so the little badge/button matches its environment.
4. **Shared assets** attach the Style Key so they belong to the same family.

### Images 2.0 tips
- Just talk to it normally — it follows instructions well and honors **aspect-ratio** and
  **transparent-background** requests written in plain English.
- **Attach a reference image** with the paperclip/＋, then say "match the attached image's
  style." This is the single biggest lever for a cohesive set.
- Generate **one image per request.** If stray text/letters sneak in, reply **"regenerate
  with no text anywhere."** To tweak, just say "make the lava brighter," "more epic," etc.
- Backgrounds: it may render slightly wider/narrower than an iPad screen — that's fine, the
  app scale-fills, which is why every prompt keeps important content centered.

### World palette reference (names are placeholders; for you + the app's placeholder colors)
| World | Tables | Key colors |
|---|---|---|
| 1 Highland Trail | ×0 ×1 ×2 | grass `#6BBF59` · sky `#8FD3FF` · sunshine `#FFD23F` · stone `#9E9E8A` |
| 2 Shipwreck Cove | ×10 ×5 | turquoise `#2EC4B6` · sand `#FFE3A3` · palm `#3FA34D` · timber `#7A4A2B` |
| 3 Jungle Temple | ×11 ×3 | jungle `#2F7D32` · leaf `#7CB342` · stone `#9E9E8A` · gold `#FFC107` |
| 4 Desert Canyon | ×4 ×9 | sand `#E8B04B` · canyon `#C8893B` · sky `#FBD78B` · bronze `#A9762F` |
| 5 Frozen Summit | ×6 | ice `#A8E1FF` · snow `#F2FBFF` · glacier `#5FB0E5` · aurora `#B388FF` |
| 6 Volcano Depths | ×7 ×8 | lava `#FF7A18` · ember `#E23E2C` · basalt `#3A2C2A` · glow `#FFC93C` |
| 7 Sky Citadel | ×12 | twilight `#5B4B8A` · star gold `#FFD24C` · cloud `#EAE6FF` · teal `#38D6C6` |

---

# PART A — VISUAL ASSETS (24 steps)

## Backgrounds (Steps 1–7) — chat: **"MA Backgrounds"**

### Step 1 — World 1 background · 🌄 Highland Trail
> **Thread:** 🆕 new chat, name it **MA Backgrounds**
> **Attach:** *none* (this image defines the style)

```
Create a wide landscape image, 3:2 aspect ratio. Vibrant, polished stylized 3D adventure-game environment art — like a modern console/mobile action-adventure platformer: bold confident shapes, rich saturated colors, dramatic depth and sense of scale, crisp dynamic lighting with long shadows and subtle god rays. Scene: the starting region of an epic quest — rolling green highlands with rugged rocky outcrops, a few sturdy windswept trees, and a winding adventurer's trail that climbs over the hills toward a distant landmark: weathered castle ruins on a far peak with hazy mountains beyond. A simple wooden signpost and a small stone archway mark the trailhead; scattered boulders, tall grass, and drifting clouds add depth. Bright late-morning light, adventurous and inviting — the launch point of a grand journey, not babyish or overly cute. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world1_bg.jpg`  ← **this is your Style Key. Keep it handy.**

---

### Step 2 — World 2 background · ⚓ Shipwreck Cove
> **Thread:** ↳ same chat (MA Backgrounds)
> **Attach:** `world1_bg.jpg`

```
Create a wide landscape image, 3:2 aspect ratio, in the SAME vibrant, polished stylized 3D adventure-game art style, color richness, lighting, and rendering as the attached reference image, so it looks like part of the same game. Scene: a rugged tropical adventure coast — a brilliant turquoise lagoon ringed by dramatic rocky cliffs and palm-covered outcrops, a half-buried shipwreck on golden sand, a wooden rope bridge spanning a sea gap, a waterfall spilling into the crashing surf, a distant island on the horizon, bright sun-glints on the water. Exotic, bright, and adventurous — a hidden cove worth exploring. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world2_bg.jpg`

---

### Step 3 — World 3 background · 🛕 Jungle Temple
> **Thread:** ↳ same chat · **Attach:** `world1_bg.jpg`

```
Create a wide landscape image, 3:2 aspect ratio, in the SAME vibrant, polished stylized 3D adventure-game art style, color richness, lighting, and rendering as the attached reference image, so it looks like part of the same game. Scene: a dense, mysterious jungle hiding a colossal lost temple — giant carved stone idols and crumbling ziggurat steps swallowed by thick vines and huge leaves, faint glowing runes, a rope bridge over a misty ravine, dramatic shafts of sunlight breaking through the canopy, a small waterfall and pool. A lost-world expedition mood: exciting, overgrown, full of secrets. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world3_bg.jpg`

---

### Step 4 — World 4 background · 🏜️ Desert Canyon
> **Thread:** ↳ same chat · **Attach:** `world1_bg.jpg`

```
Create a wide landscape image, 3:2 aspect ratio, in the SAME vibrant, polished stylized 3D adventure-game art style, color richness, lighting, and rendering as the attached reference image, so it looks like part of the same game. Scene: a vast sun-scorched desert of towering mesas and deep carved canyons — a colossal half-buried ancient pyramid and broken stone columns jutting from the dunes, a winding canyon trail, weathered rock arches, a far-off dust haze, hard golden light and long dramatic shadows. An epic lost-civilization adventure across blazing sands. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world4_bg.jpg`

---

### Step 5 — World 5 background · 🏔️ Frozen Summit
> **Thread:** ↳ same chat · **Attach:** `world1_bg.jpg`

```
Create a wide landscape image, 3:2 aspect ratio, in the SAME vibrant, polished stylized 3D adventure-game art style, color richness, lighting, and rendering as the attached reference image, so it looks like part of the same game. Scene: a towering frozen mountain range under a dramatic aurora sky — jagged glacial peaks, deep blue crevasses, a ruined ice fortress carved into a cliff face, a narrow ice bridge crossing a chasm, wind-driven snow and sharp crystalline light. Harsh, majestic, and adventurous — a brutal climb to a frozen stronghold. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world5_bg.jpg`

---

### Step 6 — World 6 background · 🌋 Volcano Depths
> **Thread:** ↳ same chat · **Attach:** `world1_bg.jpg`

```
Create a wide landscape image, 3:2 aspect ratio, in the SAME vibrant, polished stylized 3D adventure-game art style, color richness, lighting, and rendering as the attached reference image, so it looks like part of the same game. Scene: a dramatic volcanic realm — rivers of glowing molten lava carving through black basalt cliffs, suspended rock platforms and a cavern fortress built into the stone, drifting embers and heat shimmer, a massive volcano erupting in the distance against a smoky orange sky. Intense and epic, thrilling but not gory or frightening — a daring trek through fire and rock. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world6_bg.jpg`

---

### Step 7 — World 7 background · 🏰 Sky Citadel
> **Thread:** ↳ same chat · **Attach:** `world1_bg.jpg`

```
Create a wide landscape image, 3:2 aspect ratio, in the SAME vibrant, polished stylized 3D adventure-game art style, color richness, lighting, and rendering as the attached reference image, so it looks like part of the same game. Scene: a breathtaking realm of floating islands high above the clouds — colossal sky-temples and a grand summit fortress crowning the highest island, glowing light-bridges linking drifting landmasses, soaring waterfalls pouring off into open sky, golden celestial light breaking through dramatic clouds, distant stars at dusk. The triumphant, awe-inspiring final destination of the whole journey. Keep the horizon centered and leave a calmer, less-busy area in the middle of the frame for overlaying interface panels; keep key elements away from the far left and right edges. No people, no characters, no text, no letters, no numbers, no UI, no watermark.
```
> **Save as:** `world7_bg.jpg`

---

## Map nodes (Steps 8–14) — chat: **"MA Map Nodes"**

The circular badges on the map. New chat so the circular/transparent format doesn't bleed
into the backgrounds. For each one, attach **that world's background** so the badge matches.

### Step 8 — World 1 node · 🌄 Highland Trail
> **Thread:** 🆕 new chat, name it **MA Map Nodes**
> **Attach:** `world1_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image. Inside the circle: a grassy highland hilltop with a small stone archway trailhead and a distant castle peak. Bold, iconic, centered, with a soft vignette inside the circle and clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world1_node.png`

---

### Step 9 — World 2 node · ⚓ Shipwreck Cove
> **Thread:** ↳ same chat (MA Map Nodes) · **Attach:** `world2_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other map badges in this chat. Inside the circle: a rocky tropical island with a palm tree, a turquoise lagoon, and a tiny shipwreck. Bold, iconic, centered, soft vignette inside the circle, clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world2_node.png`

---

### Step 10 — World 3 node · 🛕 Jungle Temple
> **Thread:** ↳ same chat · **Attach:** `world3_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other map badges in this chat. Inside the circle: a vine-covered jungle temple with a carved stone idol and a big green leaf. Bold, iconic, centered, soft vignette inside the circle, clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world3_node.png`

---

### Step 11 — World 4 node · 🏜️ Desert Canyon
> **Thread:** ↳ same chat · **Attach:** `world4_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other map badges in this chat. Inside the circle: a canyon mesa with a half-buried ancient pyramid and a cactus. Bold, iconic, centered, soft vignette inside the circle, clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world4_node.png`

---

### Step 12 — World 5 node · 🏔️ Frozen Summit
> **Thread:** ↳ same chat · **Attach:** `world5_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other map badges in this chat. Inside the circle: a jagged snowy peak with a glowing blue ice crystal. Bold, iconic, centered, soft vignette inside the circle, clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world5_node.png`

---

### Step 13 — World 6 node · 🌋 Volcano Depths
> **Thread:** ↳ same chat · **Attach:** `world6_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other map badges in this chat. Inside the circle: an erupting volcano with glowing orange lava and embers. Bold, iconic, centered, soft vignette inside the circle, clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world6_node.png`

---

### Step 14 — World 7 node · 🏰 Sky Citadel
> **Thread:** ↳ same chat · **Attach:** `world7_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A circular game-map level icon (a round badge/emblem) for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other map badges in this chat. Inside the circle: a floating island summit with a grand temple and a bright star. Bold, iconic, centered, soft vignette inside the circle, clean crisp edges. Everything outside the circular badge must be transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world7_node.png`

---

## Button skins (Steps 15–21) — chat: **"MA Buttons"**

One reusable themed button per world. Attach **that world's background** for material/color.

> ⚠️ **Heads-up:** AI can struggle to make a perfectly even, empty, stretchable button. If
> one looks lopsided or the center isn't flat/clear, send me whatever you get — I'll fall
> back to a palette-colored button for that world. Don't burn lots of retries here.

### Step 15 — World 1 button · 🌄 Highland Trail
> **Thread:** 🆕 new chat, name it **MA Buttons**
> **Attach:** `world1_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, drawn in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image. Material: rugged polished wood banded with iron, mossy stone accents and a brass rim. The button has an even border/rim all the way around and a flat, completely empty, uncluttered center (no icon, no symbol, no text). Front view, centered, with generous transparent padding around it and a slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world1_button.png`

---

### Step 16 — World 2 button · ⚓ Shipwreck Cove
> **Thread:** ↳ same chat (MA Buttons) · **Attach:** `world2_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other buttons in this chat. Material: weathered ship timber and bamboo with brass fittings and a turquoise gem rim. Even border/rim all the way around, flat completely empty uncluttered center (no icon, no symbol, no text). Front view, centered, generous transparent padding, slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world2_button.png`

---

### Step 17 — World 3 button · 🛕 Jungle Temple
> **Thread:** ↳ same chat · **Attach:** `world3_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other buttons in this chat. Material: carved temple stone with vine accents and a glowing gold rune rim. Even border/rim all the way around, flat completely empty uncluttered center (no icon, no symbol, no text). Front view, centered, generous transparent padding, slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world3_button.png`

---

### Step 18 — World 4 button · 🏜️ Desert Canyon
> **Thread:** ↳ same chat · **Attach:** `world4_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other buttons in this chat. Material: carved sandstone with bronze edging and a turquoise gem rim. Even border/rim all the way around, flat completely empty uncluttered center (no icon, no symbol, no text). Front view, centered, generous transparent padding, slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world4_button.png`

---

### Step 19 — World 5 button · 🏔️ Frozen Summit
> **Thread:** ↳ same chat · **Attach:** `world5_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other buttons in this chat. Material: polished blue ice crystal with a frosted steel rim and a faint inner glow. Even border/rim all the way around, flat completely empty uncluttered center (no icon, no symbol, no text). Front view, centered, generous transparent padding, slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world5_button.png`

---

### Step 20 — World 6 button · 🌋 Volcano Depths
> **Thread:** ↳ same chat · **Attach:** `world6_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other buttons in this chat. Material: dark obsidian rock with a glowing molten-orange cracked rim and iron studs. Even border/rim all the way around, flat completely empty uncluttered center (no icon, no symbol, no text). Front view, centered, generous transparent padding, slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world6_button.png`

---

### Step 21 — World 7 button · 🏰 Sky Citadel
> **Thread:** ↳ same chat · **Attach:** `world7_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background. A single horizontal rounded-rectangle video-game UI button for an adventure game, in the SAME vibrant, polished stylized 3D adventure-game art style and color palette as the attached reference image, and matching the other buttons in this chat. Material: golden cloud-stone with a glowing starlight rim and faint sparks. Even border/rim all the way around, flat completely empty uncluttered center (no icon, no symbol, no text). Front view, centered, generous transparent padding, slight soft drop shadow. Everything outside the button is transparent. No text, no letters, no numbers, no watermark.
```
> **Save as:** `world7_button.png`

---

## Shared assets (Steps 22–24) — chat: **"MA Shared"**

### Step 22 — Neutral map background
> **Thread:** 🆕 new chat, name it **MA Shared**
> **Attach:** `world1_bg.jpg` (for style family only)

```
Create a wide landscape image, 3:2 aspect ratio, in a rich, polished adventure-game art style that feels like the same game as the attached reference image. A classic adventurer's world map seen from above: aged parchment or weathered terrain, a long winding journey path of stepping-stone markers curving from the lower-left toward the upper-right, most regions left undefined or hidden beneath drifting clouds and mist so no specific places are recognizable, a carved compass rose in one corner, a rugged exploratory feel. IMPORTANT: do not depict any specific biome (no beach, jungle, desert, ice, volcano, etc.) — keep all regions generic and hidden so nothing is spoiled. No text, no letters, no labels, no place names, no people, no watermark.
```
> **Save as:** `map_bg.jpg`

---

### Step 23 — Locked node (mystery stop)
> **Thread:** ↳ same chat (MA Shared) · **Attach:** `world1_bg.jpg`

```
Create a 1024x1024 square image with a fully transparent background, in the same polished stylized 3D adventure-game art style as the attached reference image. A circular game-map locked-level icon: a swirling orb of dark mist and fog with a faint cold glow, mysterious and intriguing, centered. Keep the very center fairly clear and simple. Everything outside the circular misty badge must be transparent. No text, no letters, no numbers, no question mark, no symbols, no watermark.
```
> **Save as:** `node_locked.png`

---

### Step 24 — App icon
> **Thread:** ↳ same chat · **Attach:** `world1_bg.jpg`

```
Create a 1024x1024 square image (solid background, NOT transparent), in the same polished stylized 3D adventure-game art style as the attached reference image. An app icon for a kids' multiplication adventure game: a bold white multiplication "x" cross-mark set above a rugged adventure-map-and-mountain emblem, on a bright dramatic gradient background (deep blue to warm gold), strong rounded 3D shapes, centered, bold and simple so it reads at small sizes. Fill the whole square edge to edge, no rounded corners (the system rounds them), no transparency. No text, no letters, no numbers, no words, no watermark.
```
> **Save as:** `app_icon.png`

---

✅ **That's all 24 visual assets.** Drop them into a folder named `Art/` in the project.

---

# PART B — AUDIO ASSETS

Short **sound effects only, no background music** (per the spec). Keep them satisfying and
punchy but gentle — especially "wrong," which must **never** be a harsh buzzer (the
no-punishment rule). These are **not** made in ChatGPT Images — see the sources/tools below.

## B.1 Sound manifest
| Event (code) | Filename | Character | Length | Used for |
|---|---|---|---|---|
| `correct` | `sfx_correct.wav` | bright rewarding marimba/xylophone ding | ~0.4s | right answer |
| `wrong` | `sfx_wrong.wav` | soft gentle low "boop", kind/neutral | ~0.3s | wrong answer (no buzzer!) |
| `keyTap` | `sfx_key.wav` | soft tactile tick/pop | ~0.1s | number-pad key press |
| (button) | `sfx_button.wav` | friendly soft UI pop | ~0.15s | menu / Continue buttons |
| (xp tick) | `sfx_xp.wav` | light sparkle/coin tick | ~0.2s | XP counting up |
| `levelUp` | `sfx_world_unlock.wav` | triumphant heroic reveal swell + sparkles | ~1.5s | clearing a world / unlocking next |
| `milestone` | `sfx_milestone.wav` | celebratory success jingle | ~1.0s | 25/50/75%, table done, streak |
| `complete` | `sfx_complete.wav` | big victorious fanfare + sparkle/cheer | ~3.0s | 100% completion finale |
| (star) | `sfx_star.wav` | bright single twinkle | ~0.5s | a fact reaching "mastered" |
| (streak) | `sfx_streak.wav` | quick warm whoosh | ~0.5s | daily streak continues |

`.wav` is perfect (I'll convert to `.caf` if needed). Mono is fine. Drop into an `Audio/`
folder with this exact naming and I'll wire them with no renaming.

## B.2 Where to get them (royalty-free, App-Store-safe)
**Best first stop — CC0 (no attribution, commercial OK):**
- **Kenney.nl** → "Interface Sounds", "UI Audio", "Digital Audio", "Casino Audio" (sparkles/coins). CC0; covers most of the list by itself.
- **Pixabay Audio** (pixabay.com/sound-effects) — royalty-free, commercial OK.
- **Mixkit** (mixkit.co/free-sound-effects) — free license, commercial OK.

Also good (check per-file license): **Freesound.org** (filter to "Creative Commons 0"),
**ZapSplat** (free w/ attribution, or paid).

**Search terms:** correct → "correct answer chime / positive ding"; wrong → "soft incorrect
/ gentle wrong / neutral boop"; key → "ui click / tick / pop"; world_unlock → "level unlock
/ level complete / magic reveal / power up"; milestone → "success jingle / achievement";
complete → "win fanfare / victory"; star → "twinkle / sparkle / collect"; streak → "whoosh".

## B.3 If you'd rather generate them (AI SFX tools: ElevenLabs Sound Effects, Optic, Stable Audio)
Copy any line as the prompt:
```
a short bright cheerful positive ding for a correct answer in a kids' game, marimba, uplifting, about 0.5 seconds, clean, no music bed
a soft gentle neutral "boop" for a wrong answer in a children's game, friendly and encouraging, not harsh, not a buzzer, about 0.3 seconds
a soft subtle tactile tick for tapping a number key, very short, about 0.1 seconds
a friendly soft UI button press pop for a kids' app, about 0.15 seconds
a light sparkly coin/point tick for earning points, about 0.2 seconds
a triumphant heroic reveal flourish with rising sparkles for unlocking a new world in an adventure game, epic but kid-friendly, about 1.5 seconds
a celebratory short success jingle for reaching a milestone in a kids' game, warm and happy, about 1 second
a big victorious fanfare with sparkles and a soft cheer for finishing a kids' game, triumphant and joyful, about 3 seconds
a bright single magical twinkle, a star-earned chime, about 0.5 seconds
a quick warm whoosh for a daily streak continuing, about 0.5 seconds
```

## B.4 Licensing checklist
- Prefer **CC0** (no attribution, commercial use, App Store fine).
- If a file is **CC-BY**, keep an attributions list (I can add a Credits screen).
- Avoid anything that sounds like a known game/brand.
- AI-generated SFX from the tools above are cleared for commercial use under their terms.

---

# PART C — DELIVERY CHECKLIST
```
Art/
  world1_bg.jpg  world2_bg.jpg  world3_bg.jpg  world4_bg.jpg  world5_bg.jpg  world6_bg.jpg  world7_bg.jpg
  world1_node.png  …  world7_node.png
  world1_button.png  …  world7_button.png
  map_bg.jpg   node_locked.png   app_icon.png
Audio/
  sfx_correct.wav  sfx_wrong.wav  sfx_key.wav  sfx_button.wav  sfx_xp.wav
  sfx_world_unlock.wav  sfx_milestone.wav  sfx_complete.wav  sfx_star.wav  sfx_streak.wav
```

**You don't need everything before I build.** The minimum to wire the whole pipeline is:
**Steps 1, 8, 15 (World 1 bg + node + button), Steps 22–24 (shared), and the audio.** The
other worlds slot in as you make them; until then the app shows palette placeholders built
from the hex values in the table above.
