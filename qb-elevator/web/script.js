(function () {
  "use strict";

  const isBrowser = !window.invokeNative;
  const RESOURCE = window.GetParentResourceName ? window.GetParentResourceName() : "qb-elevator";

  const app = document.getElementById("app");
  const floorsEl = document.getElementById("floors");
  const buildingEl = document.getElementById("building");
  const digitEl = document.getElementById("digit");
  const floorNameEl = document.getElementById("floorName");
  const arrowEl = document.getElementById("arrow");

  let open = false;
  let sending = false;
  let floors = [];

  // Never wait for Lua: the UI hides itself first, so it can't get stuck.
  function post(name, data) {
    if (isBrowser) return;
    fetch(`https://${RESOURCE}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  function show(data) {
    floors = (data.floors || []).slice().sort((a, b) => {
      const na = parseFloat(a.floor), nb = parseFloat(b.floor);
      if (!isNaN(na) && !isNaN(nb) && na !== nb) return nb - na; // top floor first
      return b.index - a.index;
    });
    buildingEl.textContent = data.building || "";
    const cur = floors.find((f) => f.current);
    digitEl.textContent = cur ? cur.floor : "-";
    floorNameEl.textContent = cur ? cur.name : "";
    arrowEl.innerHTML = "&#9679;";

    floorsEl.innerHTML = floors
      .map(
        (f) => `
        <button class="floor-btn ${f.current ? "current" : ""} ${f.locked ? "locked" : ""}" data-index="${f.index}" ${f.current || f.locked ? "disabled" : ""}>
          <span class="num">${esc(f.floor)}</span>
          <span class="label">${esc(f.name)}<span class="tag">${f.current ? "You are here" : f.locked ? "Restricted" : ""}</span></span>
        </button>`
      )
      .join("");

    sending = false;
    open = true;
    app.classList.remove("hidden");
  }

  function hide() {
    open = false;
    app.classList.add("hidden");
  }

  function close() {
    if (!open) return;
    hide();
    post("close");
  }

  function choose(index) {
    if (!open || sending) return;
    const f = floors.find((x) => String(x.index) === String(index));
    if (!f || f.current || f.locked) return;
    sending = true;

    const btn = floorsEl.querySelector(`[data-index="${f.index}"]`);
    if (btn) btn.classList.add("pressed");
    const cur = floors.find((x) => x.current);
    arrowEl.innerHTML = cur && parseFloat(f.floor) < parseFloat(cur.floor) ? "&#9660;" : "&#9650;";
    digitEl.textContent = f.floor;
    floorNameEl.textContent = f.name;

    setTimeout(() => {
      hide();
      post("goTo", { floor: f.index });
    }, 350);
  }

  floorsEl.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-index]");
    if (btn) choose(btn.dataset.index);
  });
  document.getElementById("close").addEventListener("click", close);

  window.addEventListener("keydown", (e) => {
    if (!open) return;
    if (e.key === "Escape" || e.key === "Backspace") return close();
    // number keys pick the floor with that number
    const f = floors.find((x) => x.floor === e.key);
    if (f) choose(f.index);
  });

  window.addEventListener("message", (e) => {
    const d = e.data || {};
    if (d.action === "open") show(d);
    else if (d.action === "close") hide();
  });

  if (isBrowser) {
    show({
      building: "Crastenburg Hotel",
      floors: [
        { index: 1, floor: "0", name: "Reception", current: true },
        { index: 2, floor: "1", name: "First Floor" },
        { index: 3, floor: "2", name: "Second Floor" },
        { index: 4, floor: "3", name: "Third Floor", locked: true },
        { index: 5, floor: "4", name: "Fourth Floor" },
        { index: 6, floor: "5", name: "Fifth Floor" },
      ],
    });
  }
})();
