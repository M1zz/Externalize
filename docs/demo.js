// 뇌모리 웹 체험: 적고, 지금 끝내기로 하나씩 결말을 낸다.
// 규칙은 앱과 같다: 결말은 지금 하기(2분 타이머) · 시간 정하기 · 버리기 (ReviewView),
// 시간 보기는 ScheduleOption.date (오늘 저녁 19시 · 내일 아침 9시 · 토요일 10시 · 월요일 9시). 문구는 앱 번역 그대로.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text), A = T.app;
  const lang = document.documentElement.lang;
  const f = (s, ...v) => s.replace(/\{(\d)\}/g, (_, i) => v[i - 1]);
  const esc = s => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const ago = new Intl.RelativeTimeFormat(lang, { numeric: "auto" });
  const when = new Intl.DateTimeFormat(lang, { weekday: "short", hour: "numeric", minute: "2-digit" });

  const now = Date.now(), H = 3600e3;
  let memos = T.examples.slice(0, 2).map((text, i) => ({ text, at: now - [27, 3][i] * H }));
  let screen = "list", total = 0, settled = 0, doingSince = null, tick;

  // ScheduleOption.date 와 같은 계산. 오늘 저녁은 30분 넘게 남았을 때만.
  function options() {
    const d = new Date(), wd = d.getDay() + 1;   // 1 = 일요일 (Swift Calendar 와 같게)
    const at = (h, days) => { const x = new Date(d); x.setDate(x.getDate() + days); x.setHours(h, 0, 0, 0); return x; };
    const evening = at(19, 0);
    return [new Date(d.getTime() + H), evening - d > 30 * 60e3 ? evening : null, at(9, 1),
            at(10, wd === 7 ? 7 : 7 - wd), at(9, (9 - wd) % 7 === 0 ? 7 : (9 - wd) % 7)];
  }

  root.innerHTML = `
    <div class="nm-screen" aria-live="polite"></div>
    <div class="nm-side">
      <form class="nm-capture">
        <input type="text" class="nm-input" placeholder="${esc(A.input)}" aria-label="${esc(A.input)}" maxlength="80">
        <button type="submit" class="nm-send" aria-label="${esc(A.write)}">
          <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="currentColor" d="M12 4l7 7-1.4 1.4L13 7.8V20h-2V7.8l-4.6 4.6L5 11z"/></svg>
        </button>
      </form>
      <div class="nm-chips">${T.examples.slice(2).map(x =>
        `<button type="button" class="nm-chip" data-add="${esc(x)}">+ ${esc(x)}</button>`).join("")}</div>
      <p class="muted small">${esc(T.note)}</p>
    </div>`;
  const $ = s => root.querySelector(s), view = $(".nm-screen"), input = $(".nm-input");

  const open = () => memos.filter(m => !m.remind);
  const later = () => memos.filter(m => m.remind).sort((a, b) => a.remind - b.remind);
  const meta = m => m.remind ? `<span class="nm-meta">${esc(when.format(m.remind))}</span>`
    : Date.now() - m.at > 24 * H ? `<span class="nm-meta stale">${esc(A.stale)}</span>`
    : `<span class="nm-meta">${esc(ago.format(-Math.round((Date.now() - m.at) / H), "hour"))}</span>`;
  const rows = list => `<ul class="nm-list">${list.map(m => `<li>${esc(m.text)}${meta(m)}</li>`).join("")}</ul>`;
  const mmss = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  function render() {
    clearInterval(tick);
    const o = open(), cur = o[0];
    if (screen === "list") {
      view.innerHTML = `<h3 class="nm-title">${esc(A.name)}</h3>` + (o.length + later().length === 0
        ? `<div class="nm-empty"><strong>${esc(A.clear)}</strong><p class="muted">${esc(A.empty).replace("\n", "<br>")}</p></div>`
        : (o.length ? `<button type="button" class="nm-primary" data-go="review">${esc(f(A.settle, o.length))}</button>
            <p class="nm-head">${esc(A.onMind)}</p>${rows(o)}<p class="nm-foot">${esc(A.footer)}</p>` : "")
          + (later().length ? `<p class="nm-head">${esc(A.scheduled)}</p>${rows(later())}` : ""));
    } else if (screen === "pick") {
      view.innerHTML = `<div class="nm-bar"><button type="button" class="nm-link" data-go="review">${esc(A.cancel)}</button>
        <strong>${esc(A.when)}</strong><span></span></div><ul class="nm-list nm-opts">${options().map((d, i) => d ?
        `<li><button type="button" data-at="${+d}">${esc(A["o" + (i + 1)])}<span class="nm-meta">${esc(when.format(d))}</span></button></li>` : "").join("")}</ul>`;
    } else if (!cur) {
      view.innerHTML = `<div class="nm-done"><div class="nm-spark" aria-hidden="true">✦</div><h3>${esc(A.clear)}</h3>
        ${settled ? `<p class="muted">${esc(f(A.settled, settled))}</p>` : ""}
        <button type="button" class="nm-primary" data-go="list">${esc(A.close)}</button></div>`;
    } else {
      const head = `<div class="nm-bar"><span class="nm-count">${esc(f(A.of, Math.min(settled + 1, total), total))}</span>
        <progress max="${total}" value="${settled}" aria-hidden="true"></progress><button type="button" class="nm-x" data-go="list" aria-label="${esc(A.close)}">×</button></div>
        <div class="nm-card"><p class="nm-big">${esc(cur.text)}</p>${meta(cur)}</div>`;
      view.innerHTML = head + (doingSince ? `<div class="nm-actions"><p class="nm-timer">${mmss(120)}</p>
          <p class="muted small">${esc(A.goDo)}</p>
          <button type="button" class="nm-btn go" data-end="done">${esc(A.done)}</button>
          <button type="button" class="nm-link" data-back>${esc(A.notNow)}</button></div>`
        : `<div class="nm-actions"><button type="button" class="nm-btn go" data-doing>${esc(A.doNow)}<small>${esc(A.doNowSub)}</small></button>
          <button type="button" class="nm-btn time" data-go="pick">${esc(A.pick)}</button>
          <button type="button" class="nm-btn drop" data-end="drop">${esc(A.drop)}</button></div>`);
      if (doingSince) tick = setInterval(() => {
        const left = Math.max(0, 120 - Math.floor((Date.now() - doingSince) / 1000)), el = $(".nm-timer");
        if (el) el.textContent = mmss(left);
      }, 1000);
    }
    const first = view.querySelector("button");
    if (first && root.contains(document.activeElement) && !input.matches(":focus")) first.focus();
  }

  function settle(change) {
    const cur = open()[0];
    if (!cur) return;
    change(cur); settled++; doingSince = null; screen = "review"; render();
  }

  root.addEventListener("click", e => {
    const b = e.target.closest("button");
    if (!b || !root.contains(b)) return;
    if (b.dataset.add) { add(b.dataset.add); b.remove(); return; }
    if (b.dataset.go) {
      if (b.dataset.go === "review" && screen === "list") { total = open().length; settled = 0; }
      screen = b.dataset.go; render(); return;
    }
    if ("doing" in b.dataset) { doingSince = Date.now(); render(); return; }
    if ("back" in b.dataset) { doingSince = null; render(); return; }
    if (b.dataset.end) settle(m => { memos = memos.filter(x => x !== m); });
    if (b.dataset.at) settle(m => { m.remind = +b.dataset.at; });
  });

  function add(text) {
    text = text.trim();
    if (!text) return;
    memos.push({ text, at: Date.now() });
    if (screen !== "list") return;
    render();
    const list = view.querySelectorAll(".nm-list")[0];
    list && list.lastElementChild && list.lastElementChild.classList.add("new");
  }
  $(".nm-capture").addEventListener("submit", e => { e.preventDefault(); add(input.value); input.value = ""; });

  render();
})();
