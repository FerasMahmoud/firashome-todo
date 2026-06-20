import base64, pathlib
META = {
 "today":("Today","Default home — today's tasks, glass add bar, progress ring."),
 "inbox":("Inbox","No-project bucket — the catch-all."),
 "upcoming":("Upcoming","Next 14 days, grouped per day."),
 "filters":("Filters","Priority 1 / Overdue / Today / Next 7 / No date."),
 "projects":("Projects","Color dots + open-task counts."),
 "taskdetail":("Task Detail","Tap a task → edit + subtasks checklist."),
 "quickadd":("Quick Add","Natural-language add: 'brief p1 tomorrow'."),
 "account":("Account","Links the app to the live Fly.io backend."),
}
def b64(n): return base64.b64encode(pathlib.Path(f"/tmp/board/{n}.png").read_bytes()).decode()
def phone(slug):
    label, sub = META[slug]
    return '<figure class="phone"><div class="frame"><span class="island"></span><img alt="%s" src="data:image/png;base64,%s"></div><figcaption><b>%s</b><span>%s</span></figcaption></figure>' % (label, b64(slug), label, sub)
flow = (phone("today")
    + '<div class="conn"><svg class="ar" viewBox="0 0 60 24"><path d="M2 12 H49" stroke="rgba(255,255,255,.85)" stroke-width="1.2" fill="none"/><path d="M49 12 l-7 -5 v10 z" fill="rgba(255,255,255,.85)"/></svg><em>tap a task</em></div>'
    + phone("taskdetail")
    + '<div class="conn"><svg class="ar" viewBox="0 0 60 24"><path d="M2 12 H49" stroke="rgba(255,255,255,.4)" stroke-width="1.2" fill="none" stroke-dasharray="3 4"/><path d="M49 12 l-7 -5 v10 z" fill="rgba(255,255,255,.4)"/></svg><em>+ add bar</em></div>'
    + phone("quickadd"))
grid = "".join(phone(s) for s in ["today","inbox","upcoming","filters","projects","account"])
CSS = """
video.bg{position:fixed;inset:0;width:100%;height:100%;object-fit:cover;z-index:0;filter:saturate(1.05) brightness(.68)}
.veil{position:fixed;inset:0;z-index:1;pointer-events:none;background:radial-gradient(120% 100% at 50% 120%,rgba(0,0,0,.55),rgba(0,0,0,0) 55%),linear-gradient(180deg,rgba(0,0,0,.45),rgba(0,0,0,.32))}
:root{--ink:#fff;--soft:rgba(255,255,255,.82);--faint:rgba(255,255,255,.55);--ghost:rgba(255,255,255,.38);--s2:rgba(255,255,255,.09);--hair:rgba(255,255,255,.12)}
*{box-sizing:border-box;margin:0;padding:0}
body{background:#000;color:var(--ink);font-family:Inter,"SF Pro Text",system-ui,sans-serif;min-height:100vh;overflow-x:hidden}
.wrap{position:relative;z-index:2;max-width:1320px;margin:0 auto;padding:88px clamp(20px,5vw,56px) 96px}
header{text-align:center;margin-bottom:84px}
.kicker{font-size:12px;letter-spacing:.32em;text-transform:uppercase;color:var(--ghost);margin-bottom:22px}
h1{font-family:"Source Serif 4",serif;font-style:italic;font-weight:500;font-size:clamp(40px,7vw,84px);letter-spacing:-.02em;line-height:1;text-shadow:0 2px 40px rgba(0,0,0,.5)}
.lead{max-width:560px;margin:30px auto 0;color:var(--soft);font-size:16px;line-height:1.6}
section{margin-bottom:96px}
.sec-label{display:flex;align-items:center;gap:18px;margin-bottom:36px}
.sec-label .ln{flex:1;height:1px;background:var(--hair)}
.sec-label span{font-size:11px;letter-spacing:.28em;text-transform:uppercase;color:var(--faint)}
.flow{display:flex;align-items:center;justify-content:center;gap:18px;flex-wrap:wrap}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:34px;justify-items:center}
.phone{display:flex;flex-direction:column;align-items:center;gap:16px;width:210px}
.frame{position:relative;width:100%;aspect-ratio:9/19.5;background:#000;border-radius:36px;padding:6px;box-shadow:0 30px 70px rgba(0,0,0,.8);border:1px solid var(--s2)}
.frame::after{content:"";position:absolute;inset:6px;border-radius:30px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.06);pointer-events:none;z-index:4}
.frame img{width:100%;height:100%;object-fit:cover;border-radius:30px;display:block}
.island{position:absolute;top:13px;left:50%;transform:translateX(-50%);width:92px;height:26px;background:#000;border-radius:14px;z-index:3}
figcaption{text-align:center;display:flex;flex-direction:column;gap:4px;max-width:200px}
figcaption b{font-size:14px;font-weight:600;letter-spacing:-.01em;color:var(--ink)}
figcaption span{font-size:11.5px;color:var(--soft);line-height:1.5}
.conn{display:flex;flex-direction:column;align-items:center;gap:8px}
.conn .ar{width:60px;height:24px}
.conn em{font-style:normal;font-size:10.5px;letter-spacing:.12em;text-transform:uppercase;color:var(--faint)}
.legend{display:flex;gap:30px;justify-content:center;flex-wrap:wrap;color:var(--soft);font-size:12.5px}
.legend i{display:inline-block;width:22px;height:2px;margin-right:8px;vertical-align:3px}
footer{text-align:center;margin-top:96px;color:var(--ghost);font-size:12px;letter-spacing:.04em}
footer b{color:var(--soft);font-weight:500}
@media(max-width:760px){.conn{transform:rotate(90deg);margin:6px 0}.wrap{padding-top:56px}header{margin-bottom:56px}}
@media(prefers-reduced-motion:reduce){video.bg{display:none}}
"""
html = ("<!doctype html><html lang='en'><head><meta charset='utf-8'>"
 "<meta name='viewport' content='width=device-width,initial-scale=1'>"
 "<title>Tasks — Firashome</title>"
 "<link rel='preconnect' href='https://fonts.googleapis.com'><link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>"
 "<link href='https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@1,8..60,400;1,8..60,500&family=Inter:wght@400;500;600&display=swap' rel='stylesheet'>"
 "<style>" + CSS + "</style></head><body>"
 "<video class='bg' autoplay muted loop playsinline><source src='bg.mp4' type='video/mp4'></video>"
 "<div class='veil'></div><div class='wrap'>"
 "<header><div class='kicker'>Firashome · iOS</div><h1>Tasks</h1>"
 "<p class='lead'>A glassy, offline-first task app. SwiftUI + Liquid Glass + SwiftData, synced to a live backend. This board maps every screen and how they connect.</p></header>"
 "<section><div class='sec-label'><span>Primary flow</span><div class='ln'></div></div><div class='flow'>" + flow + "</div></section>"
 "<section><div class='sec-label'><span>Sidebar destinations</span><div class='ln'></div></div><div class='grid'>" + grid + "</div></section>"
 "<div class='legend'><span><i style='background:rgba(255,255,255,.85)'></i>tap navigation</span>"
 "<span><i style='background:repeating-linear-gradient(90deg,rgba(255,255,255,.4) 0 3px,transparent 3px 7px)'></i>sheet / modal</span></div>"
 "<footer><b>todo.firashome.uk</b> &nbsp;·&nbsp; rendered from the live iOS 26 simulator &nbsp;·&nbsp; refreshed as the app evolves</footer>"
 "</div></body></html>")
pathlib.Path("/tmp/board/board.html").write_text(html)
print("brand+video board:", len(html), "bytes")
