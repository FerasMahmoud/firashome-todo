#!/usr/bin/env python3
"""Build an index.html gallery of device screenshots in Apple device frames.
Usage: build_gallery.py <gallery_dir>   # expects <gallery_dir>/img/<device>/*.png
"""
import base64
import os
import sys
import html
from pathlib import Path

DEVICE_LABELS = {
    "iphone-17-pro-max": ("iPhone 17 Pro Max", "phone"),
    "iphone-17-pro": ("iPhone 17 Pro", "phone"),
    "ipad-pro-13-inch-m4": ("iPad Pro 13″ (M4)", "tablet"),
    "ipad-mini-a17-pro": ("iPad mini (A17 Pro)", "tablet"),
}

def main():
    root = Path(sys.argv[1])
    img = root / "img"
    devices = {}
    if img.exists():
        for d in sorted(img.iterdir()):
            if d.is_dir():
                pngs = sorted(d.glob("*.png"))
                if pngs:
                    devices[d.name] = pngs

    cards = []
    for slug, pngs in devices.items():
        label, kind = DEVICE_LABELS.get(slug, (slug, "phone"))
        for png in pngs:
            data = base64.b64encode(png.read_bytes()).decode()
            cls = "frame tablet" if kind == "tablet" else "frame"
            title = png.stem.replace("-", " ").replace("_", " ").strip()
            cards.append(f'''
      <figure>
        <div class="{cls}">
          <div class="notch"></div>
          <img src="data:image/png;base64,{data}" alt="{html.escape(title)}">
        </div>
        <figcaption><span class="dev">{html.escape(label)}</span><span class="pg">{html.escape(title)}</span></figcaption>
      </figure>''')

    devices_nav = "".join(
        f'<button data-dev="{html.escape(k)}">{html.escape(DEVICE_LABELS.get(k,(k,))[0])}</button>'
        for k in devices
    )

    html_out = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tasks — preview gallery</title>
<style>
:root{{--bg:#0c0c0e;--ink:#fff;--soft:rgba(255,255,255,.7);--line:rgba(255,255,255,.12);--accent:#e53935;--r:18px}}
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:var(--bg);color:var(--ink);font:-apple-system,BlinkMacSystemFont,"SF Pro Display",system-ui,sans-serif;min-height:100vh}}
header{{position:sticky;top:0;backdrop-filter:blur(20px);background:rgba(12,12,14,.6);border-bottom:1px solid var(--line);padding:16px clamp(16px,4vw,48px);display:flex;align-items:center;gap:16px;z-index:5}}
header .brand{{font-size:20px;font-weight:700;letter-spacing:-.02em}}
header .brand b{{color:var(--accent)}}
header .url{{font-size:13px;color:var(--soft);margin-left:auto}}
nav.filters{{display:flex;gap:8px;padding:16px clamp(16px,4vw,48px);flex-wrap:wrap}}
nav.filters button{{background:rgba(255,255,255,.06);border:1px solid var(--line);color:var(--ink);padding:8px 14px;border-radius:999px;font-size:13px;font-weight:500;cursor:pointer}}
nav.filters button.active{{background:var(--accent);border-color:var(--accent)}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:40px;padding:24px clamp(16px,4vw,48px) 80px}}
figure{{display:flex;flex-direction:column;align-items:center;gap:14px}}
.frame{{position:relative;width:280px;aspect-ratio:9/19.5;border-radius:42px;background:#000;padding:8px;box-shadow:0 30px 60px rgba(0,0,0,.5),inset 0 0 0 2px rgba(255,255,255,.08)}}
.frame.tablet{{aspect-ratio:4/5.4;border-radius:32px}}
.frame img{{width:100%;height:100%;object-fit:cover;border-radius:34px;display:block}}
.frame.tablet img{{border-radius:24px}}
.notch{{position:absolute;top:14px;left:50%;transform:translateX(-50%);width:100px;height:26px;background:#000;border-radius:14px;z-index:2}}
.frame.tablet .notch{{display:none}}
figcaption{{text-align:center;display:flex;flex-direction:column;gap:2px}}
.dev{{font-size:12px;color:var(--soft);text-transform:uppercase;letter-spacing:.06em;font-weight:600}}
.pg{{font-size:14px;color:var(--ink);font-weight:500}}
footer{{text-align:center;padding:40px;color:var(--soft);font-size:12px;border-top:1px solid var(--line)}}
</style></head>
<body>
<header><div class="brand">Tasks <b>·</b> Firashome</div><div class="url">todo.firashome.uk</div></header>
<nav class="filters" id="nav"><button class="active" data-dev="all">All</button>{devices_nav}</nav>
<main class="grid" id="grid">{''.join(cards) or '<p style="color:var(--soft);grid-column:1/-1">No screenshots yet — push to main to capture.</p>'}</main>
<footer>Native SwiftUI build · auto-captured on GitHub Actions macOS runners</footer>
<script>
const nav=document.getElementById('nav');const items=[...document.querySelectorAll('#grid figure')];
nav.addEventListener('click',e=>{{if(e.target.tagName!=='BUTTON')return;
[...nav.children].forEach(b=>b.classList.remove('active'));e.target.classList.add('active');
const d=e.target.dataset.dev;items.forEach(f=>f.style.display=(d==='all'||f.querySelector('.dev').textContent.includes(''))?'':'none');}});
</script>
</body></html>"""
    (root / "index.html").write_text(html_out)
    print(f"Wrote {(root/'index.html')} — {len(cards)} screenshots")

if __name__ == "__main__":
    main()
