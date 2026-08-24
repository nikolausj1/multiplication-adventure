#!/usr/bin/env python3
"""Build an audio review page from the sounds ACTUALLY INSTALLED in the app.

Reads Sources/App/Resources/Audio (not build/), so the page can never drift from
what ships. Stamps the version and a per-file hash on every row, so there is no
guessing which set you are hearing.

    python3 scripts/make-sfx-page.py            # current set only
    python3 scripts/make-sfx-page.py --vs 1     # A/B against build/sfx-v1
"""
import argparse, base64, datetime, hashlib, json, pathlib, struct, wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIVE = ROOT / "Sources/App/Resources/Audio"
OUT  = ROOT / "build"

USE = {
 "sfx_key":         ("Every number-pad key press", ".keyTap", "most repeated sound in the app"),
 "sfx_correct":     ("Correct answer, streak 0-2", ".correct", ""),
 "sfx_correct2":    ("Correct answer, streak 3-4", ".correct", "pitched up"),
 "sfx_correct3":    ("Correct answer, streak 5-7", ".correct", "pitched up"),
 "sfx_correct4":    ("Correct answer, streak 8+",  ".correct", "pitched up, with sparkle"),
 "sfx_wrong":       ("Wrong answer", ".wrong", "deliberately gentle: a miss costs nothing"),
 "sfx_star_slam":   ("STAR EARNED, star hits its socket", ".starSlam", ""),
 "sfx_world_unlock":("World unlocked", ".levelUp", ""),
 "sfx_boss_hit":    ("Boss takes a hit", ".bossHit", ""),
 "sfx_boss_defeat": ("Boss defeated", ".bossDefeat", ""),
 "sfx_phase_zap":   ("Quest Meter phase jolt", ".phaseJolt", ""),
 "sfx_milestone":   ("Milestone celebration", ".milestone", ""),
 "sfx_complete":    ("Full completion fanfare", ".complete", ""),
}

def read(p):
    with wave.open(str(p), "rb") as f:
        n, ch, sr = f.getnframes(), f.getnchannels(), f.getframerate()
        raw = f.readframes(n)
    s = np.array(struct.unpack("<%dh" % (len(raw)//2), raw), dtype=float) / 32768
    if ch == 2: s = s[::2]
    return s, sr

def high_pct(p):
    s, sr = read(p)
    S = np.abs(np.fft.rfft(s * np.hanning(len(s)))); fr = np.fft.rfftfreq(len(s), 1/sr)
    return 100 * S[fr >= 3000].sum() / max(S.sum(), 1e-9)

def svg(p, color, w=420, h=34):
    s, _ = read(p)
    b = 190; st = max(1, len(s)//b)
    pk = [np.abs(s[i:i+st]).max() for i in range(0, len(s), st)][:b]
    bw = w / max(len(pk), 1)
    bars = "".join(f'<rect x="{i*bw:.2f}" y="{h/2-max(1,v*h/2):.2f}" width="{bw*.78:.2f}" '
                   f'height="{max(1.5,v*h):.2f}" rx=".6" fill="{color}"/>' for i, v in enumerate(pk))
    return f'<svg viewBox="0 0 {w} {h}" width="100%" height="{h}" preserveAspectRatio="none">{bars}</svg>'

def b64(p): return base64.b64encode(p.read_bytes()).decode()
def sha(p):  return hashlib.sha256(p.read_bytes()).hexdigest()[:8]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vs", type=int, help="also show build/sfx-vN for comparison")
    a = ap.parse_args()

    man = json.loads((ROOT/"build/sfx/MANIFEST.json").read_text())
    ver, note = man["version"], man["note"]
    prev = ROOT / f"build/sfx-v{a.vs}" if a.vs else None
    if prev and not prev.exists(): prev = None

    rows = []
    for name, (where, cue, extra) in USE.items():
        cur = LIVE / f"{name}.wav"
        if not cur.exists(): continue
        cells = ""
        if prev and (prev/f"{name}.wav").exists():
            o = prev/f"{name}.wav"
            cells += (f'<div class="side old"><div class="lbl">v{a.vs} <span class="hz t3">'
                      f'{high_pct(o):.0f}% &gt;3kHz</span></div>{svg(o,"#B4B2A9")}'
                      f'<audio controls preload="none" src="data:audio/wav;base64,{b64(o)}"></audio></div>')
        cells += (f'<div class="side"><div class="lbl">v{ver} &middot; LIVE IN THE APP '
                  f'<span class="hz ok">{high_pct(cur):.0f}% &gt;3kHz</span></div>{svg(cur,"#1D9E75")}'
                  f'<audio controls preload="none" src="data:audio/wav;base64,{b64(cur)}"></audio>'
                  f'<div class="num">#{sha(cur)}</div></div>')
        rows.append(f'<div class="card"><div class="hdr"><span class="nm">{name}</span>'
                    f'<span class="use">{where} &middot; <code>{cue}</code>'
                    f'{" &middot; <i>"+extra+"</i>" if extra else ""}</span></div>'
                    f'<div class="pair{" two" if prev else ""}">{cells}</div></div>')

    doc = f"""<!doctype html><meta charset="utf-8"><title>Sound set v{ver}</title><style>
 body{{font:15px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;max-width:980px;margin:0 auto;
  padding:28px 20px 70px;color:#1a1a1a;background:#fff}}
 h1{{font-size:25px;margin:0}} .sub{{color:#888;margin:2px 0 0}}
 .ver{{display:inline-block;background:#0F6E56;color:#fff;font-weight:700;font-size:12px;
  padding:3px 11px;border-radius:20px;letter-spacing:.04em;vertical-align:4px;margin-left:8px}}
 .card{{border:1px solid #e4e4e4;border-radius:11px;margin-bottom:12px;overflow:hidden}}
 .hdr{{display:flex;justify-content:space-between;gap:14px;align-items:baseline;padding:9px 15px;
  background:#fafafa;border-bottom:1px solid #eee}}
 .nm{{font-weight:600;font-size:14.5px}} .use{{font-size:12.5px;color:#777;text-align:right}}
 code{{background:rgba(29,158,117,.13);padding:1px 5px;border-radius:4px;font-size:11.5px}}
 .pair{{display:grid;grid-template-columns:1fr}} .pair.two{{grid-template-columns:1fr 1fr}}
 .side{{padding:11px 15px}} .old{{border-right:1px solid #eee;background:#fcfcfc}}
 .lbl{{font-size:10.5px;font-weight:700;letter-spacing:.09em;color:#666;margin-bottom:4px}}
 .hz{{font-weight:600;letter-spacing:0;padding:1.5px 7px;border-radius:20px;margin-left:6px;font-size:10px}}
 .t3{{background:#FCEBEB;color:#A32D2D}} .ok{{background:#E1F5EE;color:#0F6E56}}
 .num{{font-size:10.5px;color:#aaa;font-family:ui-monospace,Menlo,monospace;margin-top:3px}}
 audio{{width:100%;height:32px;margin-top:3px}}
 .note{{background:#E1F5EE;border-left:3px solid #0F6E56;padding:12px 15px;border-radius:6px;
  margin:16px 0;font-size:14px}}
 @media(prefers-color-scheme:dark){{body{{background:#111;color:#eaeaea}}
  .card,.hdr,.old{{border-color:#333}} .hdr{{background:#191919}} .old{{background:#151515}}
  .use{{color:#8d8d8d}} .note{{background:#0d2620}} .t3{{background:#4A1B1B;color:#F09595}}
  .ok{{background:#08302a;color:#5DCAA5}}}}
 @media(max-width:700px){{.pair.two{{grid-template-columns:1fr}}
  .old{{border-right:0;border-bottom:1px solid #eee}}}}
</style>
<h1>Sound set<span class="ver">v{ver}</span></h1>
<p class="sub">{note}<br>Generated {datetime.datetime.now():%Y-%m-%d %H:%M} from the files installed in
<code>Sources/App/Resources/Audio</code>{f' &middot; compared against v{a.vs}' if prev else ''}</p>
<div class="note"><b>How to be sure this is current.</b> Every green player reads the file that is actually
in the app right now, not a build artefact. The hash under each one matches
<code>build/sfx/MANIFEST.json</code>. Regenerate this page any time with
<code>python3 scripts/make-sfx-page.py --vs {a.vs or 1}</code>.</div>
{''.join(rows)}</body>"""
    out = OUT / f"sfx-v{ver}-review.html"
    out.write_text(doc)
    print(f"wrote {out}  ({out.stat().st_size/1024/1024:.2f} MB)  v{ver}, {len(rows)} cues")

if __name__ == "__main__":
    main()
