"""Usage : python3 engine.py spec.json sortie.html

Génère une page d'exercice à partir d'un fichier de spécification JSON.
Reprend le style des exercices existants (avec les correctifs de rendu) et un moteur générique :
options par question, réponses acceptées multiples, biais nommés, diagnostic qui compte aussi
les erreurs sans biais nommé."""
import json, sys, html

import os
head = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "style.html")).read()

spec = json.load(open(sys.argv[1]))
head = head.replace("<title>__TITLE__</title>", f"<title>{html.escape(spec['title'])}</title>")
rule = "".join(f"<span><b>{html.escape(b)}</b> {html.escape(t)}</span>" for b, t in spec["rule"])

JS = r'''
const SPEC = __SPEC__;
const Q = SPEC.questions;
let i = 0; const answers = [];
const card = document.getElementById("card"), progress = document.getElementById("progress");
const lbl = (q, id) => (q.opts.find(o => o.id === id) || {}).h || id;
function esc(s) { return s.replace(/[&<>]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c])); }
function renderProgress() { progress.innerHTML = Q.map((_, k) => { const a = answers[k]; return `<i class="${a ? (a.good ? "ok" : "ko") : ""}${k === i ? " cur" : ""}"></i>`; }).join(""); }
function renderQuestion() {
  const q = Q[i];
  card.innerHTML = `<div class="meta"><span class="src">${esc(q.src)}</span><span class="eyebrow">Cas ${i + 1} / ${Q.length}</span></div>
    <p class="q">${esc(q.q)}</p>${q.code ? `<pre>${esc(q.code)}</pre>` : ""}
    <div class="opts" id="opts">${q.opts.map(o => `<button type="button" data-o="${o.id}"><span class="n">${esc(o.h)}</span><span>${esc(o.s)}</span></button>`).join("")}</div>
    <div id="fb"></div><div class="actions" id="act"></div>`;
  card.querySelectorAll("#opts button").forEach(b => b.addEventListener("click", () => answer(b.dataset.o)));
  renderProgress();
}
function answer(pick) {
  const q = Q[i]; const good = q.ok.includes(pick); const trap = !good && q.trap && q.trap[pick];
  answers[i] = { pick, good, trap: trap || null };
  card.querySelectorAll("#opts button").forEach(b => { b.disabled = true; if (q.ok.includes(b.dataset.o)) b.classList.add("good"); if (b.dataset.o === pick && !good) b.classList.add("wrong"); });
  let title = good ? (q.ok.length > 1 ? "Exact · réponses acceptées : " + q.ok.map(o => lbl(q, o)).join(" ou ") : "Exact") : `Attendu : ${q.ok.map(o => lbl(q, o)).join(" ou ")}`;
  if (trap) title = `Biais repéré : ${trap}`;
  document.getElementById("fb").innerHTML = `<div class="fb ${good ? "" : trap ? "trap" : "ko"}"><span class="t">${esc(title)}</span><p>${esc(q.why)}</p></div>`;
  document.getElementById("act").innerHTML = `<button type="button" class="btn" id="next">${i + 1 < Q.length ? "Cas suivant" : "Voir le diagnostic"}</button>`;
  const n = document.getElementById("next"); n.addEventListener("click", () => { i++; i < Q.length ? renderQuestion() : renderScore(); }); n.focus();
  renderProgress();
}
function renderScore() {
  const n = answers.filter(a => a.good).length;
  const counts = {}; answers.forEach(a => { if (a.trap) counts[a.trap] = (counts[a.trap] || 0) + 1; });
  const unnamed = answers.filter(a => !a.good && !a.trap).length;
  const rows = Object.entries(counts).sort((x, y) => y[1] - x[1]);
  let verdict;
  if (n === Q.length) verdict = SPEC.perfect;
  else if (rows.length && (rows[0][1] >= 2 || unnamed === 0)) verdict = (SPEC.verdicts[rows[0][0]] || SPEC.fallback);
  else verdict = SPEC.fallback;
  card.innerHTML = `<div class="score"><span class="eyebrow">Diagnostic</span><div class="big">${n}<small> / ${Q.length}</small></div>
    <div class="diag">${rows.map(([k, v]) => `<div><span>Biais « ${esc(k)} »</span><span class="k">${v}</span></div>`).join("")}
      <div><span>Erreurs sans biais nommé</span><span class="k">${unnamed}</span></div></div>
    <div class="verdict"><p>${esc(verdict)}</p></div>
    <div class="actions"><button type="button" class="btn ghost" id="review">Revoir les erreurs</button><button type="button" class="btn" id="again">Recommencer</button></div></div>`;
  document.getElementById("again").addEventListener("click", () => { i = 0; answers.length = 0; renderQuestion(); });
  document.getElementById("review").addEventListener("click", renderReview);
  progress.innerHTML = "";
}
function renderReview() {
  const missed = answers.map((a, k) => ({ a, k })).filter(x => !x.a.good);
  card.innerHTML = `<span class="eyebrow">Erreurs à revoir</span>${missed.length === 0 ? "<p>Aucune.</p>" : missed.map(({ a, k }) => `<div>
    <div class="meta"><span class="src">${esc(Q[k].src)}</span><span class="eyebrow">Tu as dit ${esc(lbl(Q[k], a.pick))}, attendu ${esc(Q[k].ok.map(o => lbl(Q[k], o)).join(" ou "))}</span></div>
    <p class="q">${esc(Q[k].q)}</p>${Q[k].code ? `<pre>${esc(Q[k].code)}</pre>` : ""}
    <div class="fb ${a.trap ? "trap" : "ko"}" style="margin-top:8px"><span class="t">${a.trap ? "Biais : " + esc(a.trap) : "Pourquoi"}</span><p>${esc(Q[k].why)}</p></div></div>`).join("")}
    <div class="actions"><button type="button" class="btn" id="again">Recommencer</button></div>`;
  document.getElementById("again").addEventListener("click", () => { i = 0; answers.length = 0; renderQuestion(); });
}
renderQuestion();
'''
# Contrôles de cohérence des données avant génération
for k, q in enumerate(spec["questions"]):
    ids = [o["id"] for o in q["opts"]]
    assert len(ids) == len(set(ids)), f"q{k+1}: ids dupliqués"
    assert all(o in ids for o in q["ok"]), f"q{k+1}: réponse attendue absente des options"
    assert all(t in ids and t not in q["ok"] for t in q.get("trap", {})), f"q{k+1}: piège invalide"

body = f'''<div class="wrap">
  <header>
    <span class="eyebrow">{html.escape(spec["eyebrow"])}</span>
    <h1>{html.escape(spec["title"])}</h1>
    <p class="lede">{spec["lede"]}</p>
    <div class="rule">{rule}</div>
  </header>
  <div class="progress" id="progress" aria-hidden="true"></div>
  <section class="card" id="card"></section>
</div>
<script>{JS.replace("__SPEC__", json.dumps(spec, ensure_ascii=False))}</script>
'''
out = sys.argv[2]
open(out, "w").write(head + body)
print(f"{out} : {len(spec['questions'])} cas")
