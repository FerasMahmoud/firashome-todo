import base64, pathlib
META = {
 "today":("Today","Today's tasks + progress ring + glass add bar."),
 "inbox":("Inbox","No-project bucket."),
 "upcoming":("Upcoming","Next 14 days, grouped per day."),
 "filters":("Filters","Priority / Overdue / Today / Next 7."),
 "projects":("Projects","Color dots + counts."),
 "taskdetail":("Task Detail","Subtasks checklist."),
 "quickadd":("Quick Add","Natural-language add."),
 "account":("Account","Backend link + theme picker."),
}
def b64(path): return base64.b64encode(pathlib.Path(path).read_bytes()).decode()
def phone(slug):
    label, sub = META[slug]
    light = b64(f"/tmp/board/{slug}.png")
    dark = b64(f"/tmp/board-dark/{slug}.png")
    return ('<figure class="phone"><div class="frame"><span class="island"></span>'
            f'<img class="lt" alt="{label}" src="data:image/png;base64,{light}">'
            f'<img class="dg" alt="{label}" src="data:image/png;base64,{dark}">'
            '</div><figcaption><b>{}</b><span>{}</span></figcaption></figure>').format(label,sub)
flow = (phone("today")
    + '<div class="conn"><svg class="ar" viewBox="0 0 60 24"><path d="M2 12 H49" stroke="rgba(255,255,255,.85)" stroke-width="1.2" fill="none"/><path d="M49 12 l-7 -5 v10 z" fill="rgba(255,255,255,.85)"/></svg><em>tap task</em></div>'
    + phone("taskdetail")
    + '<div class="conn"><svg class="ar" viewBox="0 0 60 24"><path d="M2 12 H49" stroke="rgba(255,255,255,.4)" stroke-width="1.2" fill="none" stroke-dasharray="3 4"/><path d="M49 12 l-7 -5 v10 z" fill="rgba(255,255,255,.4)"/></svg><em>+ add</em></div>'
    + phone("quickadd"))
grid = "".join(phone(s) for s in ["today","inbox","upcoming","filters","projects","account"])
CSS = """
body[data-t=light] .dg{display:none} body[data-t=dark] .lt{display:none}
video.bg{position:fixed;inset:0;width:100%;height:100%;object-fit:cover;z-index:0;filter:saturate(1.05) brightness(.68)}
.veil{position:fixed;inset:0;z-index:1;pointer-events:none;background:radial-gradient(120% 100% at 50% 120%,rgba(0,0,0,.55),transparent 55%),linear-gradient(180deg,rgba(0,0,0,.45),rgba(0,0,0,.32))}
:root{--ink:#fff;--soft:rgba(255,255,255,.82);--faint:rgba(255,255,255,.55);--ghost:rgba(255,255,255,.38);--s2:rgba(255,255,255,.09);--hair:rgba(255,255,255,.12)}
*{box-sizing:border-box;margin:0;padding:0}
body{background:#000;color:var(--ink);font-family:Inter,system-ui,sans-serif;min-height:100vh;overflow-x:hidden}
.wrap{position:relative;z-index:2;max-width:1320px;margin:0 auto;padding:60px clamp(20px,5vw,56px) 80px}
header{text-align:center;margin-bottom:48px}
.kicker{font-size:12px;letter-spacing:.32em;text-transform:uppercase;color:var(--ghost);margin-bottom:18px}
h1{font-family:"Source Serif 4",serif;font-style:italic;font-weight:500;font-size:clamp(36px,6vw,68px);letter-spacing:-.02em;text-shadow:0 2px 40px rgba(0,0,0,.5)}
.toggle{display:inline-flex;margin-top:28px;background:var(--s2);border:1px solid var(--hair);border-radius:999px;padding:4px}
.toggle button{background:none;border:none;color:var(--soft);padding:10px 28px;border-radius:999px;font-size:14px;font-weight:500;cursor:pointer;transition:all .3s ease}
.toggle button.on{background:var(--ink);color:#000}
.lead{max-width:520px;margin:22px auto 0;color:var(--soft);font-size:15px;line-height:1.6}
section{margin-bottom:72px}
.sec-label{display:flex;align-items:center;gap:18px;margin-bottom:28px}
.sec-label .ln{flex:1;height:1px;background:var(--hair)}
.sec-label span{font-size:11px;letter-spacing:.28em;text-transform:uppercase;color:var(--faint)}
.flow{display:flex;align-items:center;justify-content:center;gap:18px;flex-wrap:wrap}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:30px;justify-items:center}
.phone{display:flex;flex-direction:column;align-items:center;gap:14px;width:200px}
.frame{position:relative;width:100%;aspect-ratio:9/19.5;background:#000;border-radius:34px;padding:6px;box-shadow:0 28px 64px rgba(0,0,0,.8);border:1px solid var(--s2)}
.frame img{width:100%;height:100%;object-fit:cover;border-radius:28px;display:block}
.frame::after{content:"";position:absolute;inset:6px;border-radius:28px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.06);pointer-events:none;z-index:4}
.island{position:absolute;top:12px;left:50%;transform:translateX(-50%);width:86px;height:24px;background:#000;border-radius:13px;z-index:3}
figcaption{text-align:center;display:flex;flex-direction:column;gap:3px;max-width:190px}
figcaption b{font-size:13px;font-weight:600}
figcaption span{font-size:11px;color:var(--ghost);line-height:1.5}
.conn{display:flex;flex-direction:column;align-items:center;gap:7px}
.conn .ar{width:56px;height:22px}
.conn em{font-style:normal;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:var(--faint)}
.legend{display:flex;gap:28px;justify-content:center;flex-wrap:wrap;color:var(--soft);font-size:12px}
.legend i{display:inline-block;width:20px;height:2px;margin-right:7px;vertical-align:3px}
footer{text-align:center;margin-top:64px;color:var(--ghost);font-size:12px}
footer b{color:var(--soft)}
@media(max-width:760px){.conn{transform:rotate(90deg);margin:5px 0}}
"""
html = ("<!doctype html><html lang='en' data-t='light'><head><meta charset='utf-8'>"
 "<meta name='viewport' content='width=device-width,initial-scale=1'>"
 "<title>Tasks — Firashome</title>"
 "<link rel='preconnect' href='https://fonts.googleapis.com'><link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>"
 "<link href='https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@1,8..60,400;1,8..60,500&family=Inter:wght@400;500;600&display=swap' rel='stylesheet'>"
 "<style>" + CSS + "</style></head><body data-t='light'>"
 "<video class='bg' autoplay muted loop playsinline><source src='bg.mp4' type='video/mp4'></video>"
 "<div class='veil'></div><div class='wrap'>"
 "<header><div class='kicker'>Firashome · iOS</div><h1>Tasks</h1>"
 "<div class='toggle'><button class='on' onclick='setT(\"light\")'>Light</button><button onclick='setT(\"dark\")'>Dark Glass</button></div>"
 "<p class='lead'>Toggle between themes to compare. SwiftUI + Liquid Glass + SwiftData.</p></header>"
 "<section><div class='sec-label'><span>Primary flow</span><div class='ln'></div></div><div class='flow'>" + flow + "</div></section>"
 "<section><div class='sec-label'><span>All screens</span><div class='ln'></div></div><div class='grid'>" + grid + "</div></section>"
 "<div class='legend'><span><i style='background:rgba(255,255,255,.85)'></i>tap</span>"
 "<span><i style='background:repeating-linear-gradient(90deg,rgba(255,255,255,.4) 0 3px,transparent 3px 7px)'></i>sheet</span></div>"
 "<footer><b>todo.firashome.uk</b> · live from iOS 26 simulator</footer>"
 "</div>"
 "<script>function setT(t){document.body.dataset.t=t;document.documentElement.dataset.t=t;"
 "document.querySelectorAll('.toggle button').forEach(function(b){b.classList.toggle('on',b.textContent.toLowerCase().includes(t==='dark'?'dark':'light'))})}"
 "</script>"
 "</body></html>")
pathlib.Path("/tmp/board/board.html").write_text(html)
print("comparison board:", len(html), "bytes")
