import base64, pathlib
SCREENS = [
 ("today","Today","Default home. Today's tasks + progress ring + glass add bar."),
 ("inbox","Inbox","Tasks with no project. Catch-all bucket."),
 ("upcoming","Upcoming","Next 14 days, grouped per day."),
 ("filters","Filters","Priority 1 / Overdue / Today / Next 7 / No date."),
 ("projects","Projects","All projects with color dots + counts."),
 ("taskdetail","Task Detail","Tap a task → edit + subtasks checklist."),
 ("quickadd","Quick Add","Natural-language add: 'brief p1 tomorrow'."),
 ("account","Account","Links the app to the live Fly.io backend."),
]
def b64(name): return base64.b64encode(pathlib.Path(f"/tmp/board/{name}.png").read_bytes()).decode()
# primary flow: today -> taskdetail ; quickadd as sheet
def phone(slug,label,sub,classes=""):
    return f'''
  <figure class="phone {classes}" data-screen="{slug}">
    <div class="frame"><div class="island"></div><img alt="{label}" src="data:image/png;base64,{b64(slug)}"></div>
    <figcaption><b>{label}</b><span>{sub}</span></figcaption>
  </figure>'''
flow = f'''
  {phone("today","Today","Home + progress ring","hero")}
  <div class="conn"><svg viewBox="0 0 60 24"><path d="M2 12 H50" stroke="#dc4c4e" stroke-width="2" fill="none"/><path d="M50 12 l-8 -6 v12 z" fill="#dc4c4e"/></svg><span>tap a task</span></div>
  {phone("taskdetail","Task Detail","Subtasks checklist")}
  <div class="conn"><svg viewBox="0 0 60 24"><path d="M2 12 H50" stroke="#6f6f76" stroke-width="2" fill="none" stroke-dasharray="4 4"/><path d="M50 12 l-8 -6 v12 z" fill="#6f6f76"/></svg><span>+ Add bar</span></div>
  {phone("quickadd","Quick Add","NL add sheet")}
'''
grid = "".join(phone(s,l,desc) for s,l,desc in SCREENS if s not in ("today","taskdetail","quickadd"))

html = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Firashome Tasks — App Board</title>
<style>
:root{{--bg:#0b0b0e;--card:#15151b;--line:#2a2a33;--ink:#fff;--soft:rgba(255,255,255,.6);--faint:rgba(255,255,255,.35);--accent:#dc4c4e}}
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:radial-gradient(120% 90% at 50% -10%,#181820,#0b0b0e 60%);color:var(--ink);font:-apple-system,BlinkMacSystemFont,"SF Pro Display",Inter,system-ui,sans-serif;min-height:100vh;padding:40px clamp(16px,5vw,64px) 80px}}
header{{text-align:center;margin-bottom:40px}}
header h1{{font-size:clamp(26px,4vw,42px);font-weight:800;letter-spacing:-.02em}}
header h1 b{{color:var(--accent)}}
header p{{color:var(--soft);margin-top:8px;font-size:14px}}
section{{max-width:1400px;margin:0 auto 56px}}
h2{{font-size:13px;font-weight:600;color:var(--faint);text-transform:uppercase;letter-spacing:.12em;margin-bottom:22px;text-align:center}}
.flow{{display:flex;align-items:center;justify-content:center;gap:14px;flex-wrap:wrap}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:26px;justify-items:center}}
.phone{{display:flex;flex-direction:column;align-items:center;gap:12px;width:200px}}
.phone.hero{{width:230px}}
.frame{{position:relative;width:100%;aspect-ratio:9/19.5;background:#000;border-radius:38px;padding:7px;box-shadow:0 24px 50px rgba(0,0,0,.55),0 0 0 2px #2c2c33,inset 0 0 0 2px #000}}
.frame img{{width:100%;height:100%;object-fit:cover;border-radius:31px;display:block}}
.island{{position:absolute;top:14px;left:50%;transform:translateX(-50%);width:88px;height:26px;background:#000;border-radius:14px;z-index:2}}
.phone.hero .frame{{border-radius:44px;padding:8px}}
.phone.hero .island{{width:100px}}
figcaption{{text-align:center;display:flex;flex-direction:column;gap:2px}}
figcaption b{{font-size:14px;font-weight:600}}
figcaption span{{font-size:11px;color:var(--soft);line-height:1.4;max-width:190px}}
.conn{{display:flex;flex-direction:column;align-items:center;gap:6px;color:var(--soft);font-size:11px}}
.conn svg{{width:60px;height:24px}}
.legend{{max-width:1400px;margin:0 auto;display:flex;gap:24px;justify-content:center;flex-wrap:wrap;color:var(--soft);font-size:12px}}
.legend i{{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:6px;vertical-align:-1px}}
footer{{text-align:center;color:var(--faint);font-size:12px;margin-top:40px}}
@media(max-width:720px){{.conn{{transform:rotate(90deg);margin:8px 0}}}}
</style></head><body>
<header><h1>Firashome <b>Tasks</b> — App Board</h1>
<p>iOS 17+ · SwiftUI · Liquid Glass · Live on simulator · every screen + how they connect</p></header>

<section><h2>Primary flow</h2><div class="flow">{flow}</div></section>
<section><h2>Sidebar destinations (menu)</h2><div class="grid">{grid}</div></section>
<div class="legend">
 <span><i style="background:#dc4c4e"></i>solid = tap navigation</span>
 <span><i style="background:#6f6f76"></i>dashed = sheet/modal</span>
</div>
<footer>Auto-generated from the live iOS 26.3 simulator · updated as the app evolves</footer>
</body></html>"""
pathlib.Path("/tmp/board/board.html").write_text(html)
print("board.html written:", len(html), "bytes")
