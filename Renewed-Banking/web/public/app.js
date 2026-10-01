/* =========================================================================
   Renewed-Banking NUI - dependency free, no build step.
   Every prompt (amounts, PINs, confirmations, names) is rendered inside
   the NUI itself - never window.prompt / window.confirm / alert, which
   open native browser dialogs outside the game.
   ========================================================================= */

(function () {
  "use strict";

  /* ---------------------------------------------------------------------
     Helpers
  --------------------------------------------------------------------- */
  const isEnvBrowser = () => !window.invokeNative;
  const RESOURCE = (() => {
    try {
      return window.GetParentResourceName ? window.GetParentResourceName() : "Renewed-Banking";
    } catch (e) {
      return "Renewed-Banking";
    }
  })();

  async function fetchNui(eventName, data) {
    data = data || {};
    if (isEnvBrowser()) return mockFetchNui(eventName, data);
    try {
      const resp = await fetch(`https://${RESOURCE}/${eventName}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data),
      });
      return await resp.json();
    } catch (e) {
      console.error("fetchNui error", eventName, e);
      return false;
    }
  }

  const moneyFmt = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 });
  const money = (n) => moneyFmt.format(Number(n) || 0);

  function compactMoney(n) {
    n = Number(n) || 0;
    const a = Math.abs(n);
    const sign = n < 0 ? "-" : "";
    if (a >= 1e6) return `${sign}$${(a / 1e6).toFixed(a >= 1e7 ? 0 : 1)}M`;
    if (a >= 1e3) return `${sign}$${(a / 1e3).toFixed(a >= 1e4 ? 0 : 1)}k`;
    return `${sign}$${Math.round(a)}`;
  }

  function esc(str) {
    if (str === null || str === undefined) return "";
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  // Translations come from locales/*.lua (Translations.ui, a flat table).
  function t(key, fallback, params) {
    let str = state.translations && typeof state.translations[key] === "string" ? state.translations[key] : fallback;
    if (params) str = String(str).replace(/%\{(\w+)\}/g, (m, k) => (k in params ? params[k] : m));
    return str;
  }

  function maskIban(iban) {
    iban = String(iban || "");
    return iban.length > 4 ? `•••• ${iban.slice(-4)}` : iban;
  }

  function setClipboard(text) {
    const el = document.createElement("textarea");
    el.value = text;
    el.style.position = "fixed";
    el.style.opacity = "0";
    document.body.appendChild(el);
    el.select();
    try {
      document.execCommand("copy");
    } catch (e) {
      /* nothing more we can do */
    }
    document.body.removeChild(el);
  }

  function toCSV(header, rows) {
    const line = (arr) => arr.map((v) => JSON.stringify(v === undefined || v === null ? "" : v)).join(",");
    return [line(header), ...rows.map(line)].join("\n");
  }

  const pad2 = (n) => String(n).padStart(2, "0");
  const dayStart = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dayKey = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  const fmtDay = (d) => d.toLocaleDateString("en-GB", { day: "2-digit", month: "short" });
  const fmtWeekday = (d) => d.toLocaleDateString("en-GB", { weekday: "short" });
  const fmtDateTime = (ts) =>
    new Date(ts * 1000).toLocaleString("en-GB", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });

  const COLORS = { in: "#1fce8f", out: "#f2554c", line: "#4f8ff7", grid: "rgba(255,255,255,0.06)", label: "rgba(234,240,251,0.45)" };

  /* ---------------------------------------------------------------------
     State
  --------------------------------------------------------------------- */
  const state = {
    visible: false,
    mode: "bank", // bank | atm
    loading: false,
    busy: false,
    tab: "dashboard", // dashboard | accounts | cards | stats
    accounts: [],
    cash: 0,
    costs: {},
    restricted: false,
    receivedAt: 0,
    activeId: null,
    accSelectedId: null,
    accSubtab: "transactions",
    statsAccountId: null,
    statsPeriod: 7,
    txSearch: "",
    txFilter: "all",
    openTx: null,
    accSearch: "",
    members: {},
    atm: { step: "cards", cards: [], card: null, error: "" },
    translations: {},
  };

  const getAccount = (id) => state.accounts.find((a) => a.id === id) || null;
  const activeAccount = () => getAccount(state.activeId) || state.accounts[0] || null;

  function applyData(d) {
    if (!d || !Array.isArray(d.accounts)) return false;
    state.accounts = d.accounts;
    state.cash = Number(d.cash) || 0;
    if (d.costs) state.costs = d.costs;
    state.restricted = !!d.restricted;
    state.receivedAt = Date.now();
    const first = state.accounts[0] ? state.accounts[0].id : null;
    if (!getAccount(state.activeId)) state.activeId = first;
    if (!getAccount(state.accSelectedId)) state.accSelectedId = state.activeId;
    if (!getAccount(state.statsAccountId)) state.statsAccountId = state.activeId;
    return true;
  }

  /* ---------------------------------------------------------------------
     NUI messages
  --------------------------------------------------------------------- */
  window.addEventListener("message", (event) => {
    const data = event.data || {};
    switch (data.action) {
      case "setLoading":
        state.loading = !!data.status;
        renderLoading();
        break;
      case "open":
        state.mode = "bank";
        applyData(data.data);
        state.tab = data.tab || "dashboard";
        state.txSearch = "";
        state.txFilter = "all";
        state.accSearch = "";
        state.openTx = null;
        state.members = {};
        state.loading = false;
        state.visible = true;
        render();
        break;
      case "atmInsert":
        openAtm(data.cards || []);
        break;
      case "close":
        hideInterface();
        break;
      case "notify":
        toast(data.status, data.kind);
        break;
      case "updateLocale":
        state.translations = data.translations || {};
        if (state.visible) forceRerender();
        break;
    }
  });

  window.addEventListener("keydown", (e) => {
    if (e.key !== "Escape") return;
    if (modal.resolve) {
      closeModal(null);
      return;
    }
    if (state.visible) closeInterface();
  });

  window.addEventListener("resize", () => {
    if (state.visible) drawCharts();
  });

  function closeInterface() {
    fetchNui("closeInterface");
    hideInterface();
  }

  function hideInterface() {
    closeModal(null);
    destroyAtmPad();
    state.visible = false;
    state.loading = false;
    render();
  }

  /* ---------------------------------------------------------------------
     Toasts
  --------------------------------------------------------------------- */
  function toast(msg, kind) {
    if (!msg) return;
    kind = kind || "info";
    const icons = { success: "fa-circle-check", error: "fa-circle-exclamation", info: "fa-circle-info" };
    const el = document.createElement("div");
    el.className = `notify-toast ${kind}`;
    el.innerHTML = `<i class="fa-solid ${icons[kind] || icons.info}"></i><span>${esc(msg)}</span>`;
    const root = document.getElementById("notification-root");
    root.appendChild(el);
    while (root.children.length > 4) root.removeChild(root.firstChild);
    setTimeout(() => {
      el.classList.add("leaving");
      setTimeout(() => el.remove(), 250);
    }, 3800);
  }

  /* ---------------------------------------------------------------------
     Server actions
  --------------------------------------------------------------------- */
  async function run(action, data) {
    if (state.busy) return false;
    state.busy = true;
    setBusy(true);
    const res = await fetchNui(action, data);
    state.busy = false;
    setBusy(false);
    if (res && res.accounts) applyData(res);
    else if (res && res.data && res.data.accounts) applyData(res.data);
    if (state.visible) render();
    return res;
  }

  function setBusy(on) {
    const panel = document.querySelector(".bank-panel");
    if (panel) panel.classList.toggle("busy", on);
  }

  const MONEY_ACTIONS = {
    deposit: { icon: "fa-arrow-down", key: "deposit_but", fallback: "Deposit" },
    withdraw: { icon: "fa-arrow-up", key: "withdraw_but", fallback: "Withdraw" },
    transfer: { icon: "fa-right-left", key: "transfer_but", fallback: "Transfer" },
  };

  async function moneyAction(kind, accountId) {
    const acc = getAccount(accountId);
    const cfg = MONEY_ACTIONS[kind];
    if (!acc || !cfg) return;
    if (acc.isFrozen) return toast(t("frozen", "This account is frozen"), "error");

    const max = kind === "deposit" ? state.cash : acc.amount;
    const quick = [100, 500, 1000, 5000].filter((v) => v <= max).map((v) => ({ label: money(v), value: v }));
    if (max > 0) quick.push({ label: t("all", "All"), value: Math.floor(max) });

    const fields = [
      {
        name: "amount",
        type: "amount",
        label: t("amount", "Amount"),
        hint: `${t("available", "Available")}: ${money(max)}`,
        max: Math.floor(max),
        quick,
        required: true,
      },
    ];
    if (kind === "transfer") {
      fields.push({
        name: "stateid",
        type: "text",
        label: t("transfer", "Recipient"),
        placeholder: t("transfer_ph", "IBAN, account name, citizen ID or player ID"),
        maxlength: 50,
        required: true,
      });
    }
    fields.push({ name: "comment", type: "text", label: t("comment", "Comment"), placeholder: t("comment_ph", "Optional note"), maxlength: 80 });

    const values = await openForm({
      title: `${t(cfg.key, cfg.fallback)} — ${acc.name}`,
      icon: cfg.icon,
      accent: kind,
      fields,
      confirmLabel: t(cfg.key, cfg.fallback),
    });
    if (!values) return;
    await run(kind, { fromAccount: acc.id, amount: values.amount, comment: values.comment || "", stateid: values.stateid || "" });
  }

  /* ---- Accounts ---- */
  async function newAccountMenu() {
    const ownedExtra = state.accounts.filter((a) => a.personal && !a.isDefault && a.isCreator).length;
    const costs = (state.costs && state.costs.personal) || [];
    const nextCost = costs[ownedExtra];
    const choice = await openChoice({
      title: t("new_account", "New account"),
      icon: "fa-plus",
      options: [
        {
          id: "personal",
          icon: "fa-user",
          label: t("open_personal", "Open personal account"),
          desc: nextCost === undefined ? t("open_personal_max", "Maximum personal accounts reached") : t("open_personal_desc", "An extra personal account for %{cost}", { cost: money(nextCost) }),
          disabled: nextCost === undefined,
        },
        {
          id: "shared",
          icon: "fa-users",
          label: t("create_shared", "Create shared account"),
          desc: t("create_shared_desc", "Share an account with other citizens") + (state.costs.shared ? ` (${money(state.costs.shared)})` : ""),
        },
      ],
    });
    if (choice === "personal") {
      const before = new Set(state.accounts.map((a) => a.id));
      const res = await run("openAccount", {});
      const created = res && res.accounts && res.accounts.find((a) => !before.has(a.id));
      if (created) {
        state.accSelectedId = created.id;
        render();
      }
    } else if (choice === "shared") {
      const values = await openForm({
        title: t("create_shared", "Create shared account"),
        icon: "fa-users",
        fields: [{ name: "name", type: "text", label: t("shared_name", "Account name"), placeholder: t("shared_name_ph", "3-24 letters, numbers or _"), maxlength: 24, pattern: "^[a-zA-Z0-9_]{3,24}$", required: true }],
        confirmLabel: t("confirm", "Confirm"),
      });
      if (!values) return;
      const res = await run("createShared", { name: values.name });
      const id = values.name.toLowerCase();
      if (res && getAccount(id)) {
        state.accSelectedId = id;
        render();
      }
    }
  }

  async function accountAction(action, accountId, extra) {
    const acc = getAccount(accountId);
    if (!acc) return;
    if (action === "freeze") {
      await run("toggleFreeze", { account: acc.id });
    } else if (action === "rename") {
      const values = await openForm({
        title: t("rename", "Rename account"),
        icon: "fa-pen",
        fields: [{ name: "newName", type: "text", label: t("new_name", "New name"), placeholder: t("shared_name_ph", "3-24 letters, numbers or _"), maxlength: 24, pattern: "^[a-zA-Z0-9_]{3,24}$", value: acc.id, required: true }],
        confirmLabel: t("confirm", "Confirm"),
      });
      if (!values) return;
      const res = await run("renameAccount", { account: acc.id, newName: values.newName });
      if (res && res.renamed) {
        state.members[res.renamed] = state.members[acc.id];
        delete state.members[acc.id];
        if (state.accSelectedId === acc.id) state.accSelectedId = res.renamed;
        if (state.activeId === acc.id) state.activeId = res.renamed;
        render();
      }
    } else if (action === "close") {
      const ok = await openConfirm({
        title: t("close_acc", "Close account"),
        icon: "fa-trash",
        danger: true,
        message: t("close_confirm", "Close %{name}? The remaining %{amount} will be moved to your main account.", { name: acc.name, amount: money(acc.amount) }),
      });
      if (!ok) return;
      await run("closeAccount", { fromAccount: acc.id });
    } else if (action === "add-member") {
      const values = await openForm({
        title: t("add_member", "Add member"),
        icon: "fa-user-plus",
        fields: [{ name: "member", type: "text", label: t("member_id", "Citizen ID or player ID"), maxlength: 50, required: true }],
        confirmLabel: t("add_member", "Add member"),
      });
      if (!values) return;
      const res = await run("addMember", { account: acc.id, member: values.member });
      if (res && res.members) {
        state.members[acc.id] = res.members;
        render();
      }
    } else if (action === "remove-member") {
      const list = state.members[acc.id] || [];
      const member = list.find((m) => m.cid === extra);
      const ok = await openConfirm({
        title: t("remove", "Remove"),
        icon: "fa-user-minus",
        danger: true,
        message: t("remove_member_confirm", "Remove %{name} from this account?", { name: member ? member.name : extra }),
      });
      if (!ok) return;
      const res = await run("removeMember", { account: acc.id, cid: extra });
      if (res && res.members) {
        state.members[acc.id] = res.members;
        render();
      }
    }
  }

  async function loadMembers(accountId) {
    if (state.members[accountId] !== undefined) return;
    state.members[accountId] = null; // loading
    const res = await fetchNui("getMembers", { account: accountId });
    state.members[accountId] = res && res.members ? res.members : [];
    if (state.visible) render();
  }

  /* ---- Cards ---- */
  async function cardAction(action, accountId) {
    const acc = getAccount(accountId);
    if (!acc) return;
    if (action === "request") {
      await run("requestCard", { fromAccount: acc.id });
    } else if (action === "freeze") {
      await run("toggleFreeze", { account: acc.id });
    } else if (action === "pin") {
      const pin = await openPinModal({
        title: acc.cardPin ? t("change_pin", "Change PIN") : t("set_pin", "Set PIN"),
        note: state.costs.pin ? t("pin_cost", "Setting a PIN costs %{cost}", { cost: money(state.costs.pin) }) : "",
      });
      if (!pin) return;
      await run("setCardPin", { fromAccount: acc.id, pin });
    } else if (action === "load") {
      const room = Math.max(0, (state.costs.maxCard || 0) - (acc.cardBalance || 0));
      const max = Math.floor(Math.min(acc.amount, room));
      const quick = [500, 1000, 5000, 10000].filter((v) => v <= max).map((v) => ({ label: money(v), value: v }));
      if (max > 0) quick.push({ label: t("max", "Max"), value: max });
      const values = await openForm({
        title: t("load_title", "Load card"),
        icon: "fa-arrow-right-to-bracket",
        desc: t("load_desc", "Move money from the account onto the card (max %{max} on the card)", { max: money(state.costs.maxCard || 0) }),
        fields: [{ name: "amount", type: "amount", label: t("amount", "Amount"), hint: `${t("available", "Available")}: ${money(max)}`, max, quick, required: true }],
        confirmLabel: t("load", "Load"),
      });
      if (!values) return;
      await run("loadCard", { fromAccount: acc.id, amount: values.amount });
    } else if (action === "unload") {
      await run("unloadCard", { fromAccount: acc.id });
    } else if (action === "replace") {
      const ok = await openConfirm({
        title: t("lost_stolen", "Lost / Stolen"),
        icon: "fa-triangle-exclamation",
        danger: true,
        message: t("replace_confirm", "Report this card lost/stolen? The old card stops working immediately and a new one costs %{cost}.", { cost: money(state.costs.replace || 0) }),
      });
      if (!ok) return;
      await run("replaceCard", { fromAccount: acc.id });
    }
  }

  /* ---- Export ---- */
  function exportTransactions(acc) {
    if (!acc || !acc.transactions || !acc.transactions.length) return toast(t("nothing_to_export", "Nothing to export!"), "error");
    const header = ["trans_id", "date", "type", "title", "amount", "balance_after", "issuer", "receiver", "message"];
    const rows = acc.transactions.map((tx) => [tx.trans_id, fmtDateTime(tx.timestamp), tx.trans_type, tx.title, tx.amount, tx.balance, tx.issuer, tx.receiver, tx.message]);
    setClipboard(toCSV(header, rows));
    toast(t("exported", "Transactions copied to clipboard as CSV!"), "success");
  }

  function exportStats() {
    const acc = getAccount(state.statsAccountId);
    if (!acc) return;
    const stats = computeStats(acc, state.statsPeriod);
    const rows = stats.buckets
      .filter((b) => b.inCount || b.outCount)
      .map((b) => [dayKey(b.date), b.inCount, b.in, b.outCount, b.out, b.net, b.closing]);
    if (!rows.length) return toast(t("nothing_to_export", "Nothing to export!"), "error");
    setClipboard(toCSV(["date", "deposits", "deposited", "withdrawals", "withdrawn", "net", "closing_balance"], rows));
    toast(t("exported", "Copied to clipboard as CSV!"), "success");
  }

  /* ---------------------------------------------------------------------
     Statistics
  --------------------------------------------------------------------- */
  function computeStats(acc, days) {
    const txs = ((acc && acc.transactions) || []).filter((tx) => Number(tx.timestamp) > 0);
    const today = dayStart(new Date());

    let span = days;
    if (!days) {
      let oldest = Infinity;
      txs.forEach((tx) => (oldest = Math.min(oldest, tx.timestamp)));
      span = isFinite(oldest) ? Math.round((today - dayStart(new Date(oldest * 1000))) / 86400000) + 1 : 7;
      span = Math.max(7, Math.min(span, 90));
    }

    const buckets = [];
    const byKey = {};
    for (let i = span - 1; i >= 0; i--) {
      const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
      const b = { date: d, key: dayKey(d), in: 0, out: 0, inCount: 0, outCount: 0, net: 0, closing: null, lastTs: -1 };
      buckets.push(b);
      byKey[b.key] = b;
    }
    const startTs = buckets[0].date.getTime() / 1000;
    const periodTxs = days ? txs.filter((tx) => tx.timestamp >= startTs) : txs;

    const summary = { totalIn: 0, totalOut: 0, inCount: 0, outCount: 0, largestIn: null, largestOut: null, count: periodTxs.length };
    periodTxs.forEach((tx) => {
      const amount = Number(tx.amount) || 0;
      if (tx.trans_type === "withdraw") {
        summary.totalOut += amount;
        summary.outCount++;
        if (!summary.largestOut || amount > summary.largestOut.amount) summary.largestOut = tx;
      } else {
        summary.totalIn += amount;
        summary.inCount++;
        if (!summary.largestIn || amount > summary.largestIn.amount) summary.largestIn = tx;
      }
    });
    summary.net = summary.totalIn - summary.totalOut;
    summary.avg = summary.count ? (summary.totalIn + summary.totalOut) / summary.count : 0;
    summary.top = periodTxs.slice().sort((a, b) => (Number(b.amount) || 0) - (Number(a.amount) || 0)).slice(0, 6);

    txs.forEach((tx) => {
      const b = byKey[dayKey(new Date(tx.timestamp * 1000))];
      if (!b) return;
      const amount = Number(tx.amount) || 0;
      if (tx.trans_type === "withdraw") {
        b.out += amount;
        b.outCount++;
      } else {
        b.in += amount;
        b.inCount++;
      }
      if (typeof tx.balance === "number" && tx.timestamp > b.lastTs) {
        b.closing = tx.balance;
        b.lastTs = tx.timestamp;
      }
    });

    // carry the closing balance forward over days without activity, seeded
    // with the last known balance before the period started
    let carry = null;
    for (const tx of txs) {
      if (tx.timestamp < startTs && typeof tx.balance === "number") {
        carry = tx.balance;
        break;
      }
    }
    buckets.forEach((b) => {
      b.net = b.in - b.out;
      if (b.closing === null) b.closing = carry;
      else carry = b.closing;
    });
    if (acc) buckets[buckets.length - 1].closing = acc.amount;

    return { buckets, summary, span };
  }

  /* ---------------------------------------------------------------------
     Rendering
     The shell (panel/header) is built once per mode; each view builds a
     skeleton once (keyed) and afterwards only its dynamic regions are
     refreshed, so inputs keep focus and entrance animations don't replay.
  --------------------------------------------------------------------- */
  const appRoot = document.getElementById("app");
  let shellMode = null;
  let lastBalances = {};

  // Rebuilds `el` only when `key` changed. Returns true when (re)built.
  function ensure(el, key, html) {
    if (!el) return false;
    if (el.dataset.key === key) return false;
    el.innerHTML = html;
    el.dataset.key = key;
    return true;
  }

  function forceRerender() {
    shellMode = null;
    render();
  }

  function render() {
    renderLoading();
    if (!state.visible) {
      if (shellMode !== null) {
        appRoot.innerHTML = "";
        shellMode = null;
        lastBalances = {};
      }
      hideTooltip();
      return;
    }

    if (shellMode !== state.mode) {
      appRoot.innerHTML = `
        <div id="bank-overlay">
          <div class="backdrop"></div>
          <div class="bank-panel" data-mode="${state.mode}">
            <div class="busy-bar"></div>
            <header class="bank-header" id="bank-header"></header>
            <main id="bank-main"></main>
          </div>
        </div>`;
      shellMode = state.mode;
    }

    renderHeader();
    renderMain();
    flashBalance();
  }

  function renderLoading() {
    const el = document.getElementById("loading-overlay");
    if (!state.loading) {
      el.classList.add("hidden");
      el.innerHTML = "";
      return;
    }
    if (!el.classList.contains("hidden")) return;
    el.classList.remove("hidden");
    el.innerHTML = `
      <div class="loading-card">
        <div class="spinner-ring"></div>
        <div class="loading-text">${esc(t("loading", "Loading..."))}</div>
        <div class="loading-bar"><div></div></div>
      </div>`;
  }

  /* ---- Header ---- */
  function renderHeader() {
    const header = document.getElementById("bank-header");
    const isAtm = state.mode === "atm";
    const tabs = [
      { id: "dashboard", label: t("dashboard", "Dashboard"), icon: "fa-table-columns" },
      { id: "accounts", label: t("accounts", "Accounts"), icon: "fa-wallet" },
      { id: "cards", label: t("cards", "Cards"), icon: "fa-credit-card" },
      { id: "stats", label: t("statistics", "Statistics"), icon: "fa-chart-line" },
    ];
    ensure(
      header,
      `${state.mode}:${JSON.stringify(state.translations).length}`,
      `
      <div class="brand"><i class="fa-solid fa-building-columns"></i><span>${esc(isAtm ? t("atm", "ATM") : t("bank_name", "Los Santos Bank"))}</span></div>
      ${
        isAtm
          ? ""
          : `<nav class="tabs">${tabs
              .map((tab) => `<button class="tab" data-tab="${tab.id}"><i class="fa-solid ${tab.icon}"></i><span>${esc(tab.label)}</span></button>`)
              .join("")}</nav>`
      }
      <div class="header-spacer"></div>
      <div class="cash-pill" title="${esc(t("cash", "Cash"))}"><i class="fa-solid fa-money-bill-wave"></i><span id="hdr-cash"></span></div>
      <button class="close-btn" id="closeBtn" title="${esc(t("close", "Close"))}"><i class="fa-solid fa-xmark"></i></button>`
    );
    header.querySelectorAll(".tab").forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === state.tab));
    const cash = document.getElementById("hdr-cash");
    if (cash) cash.textContent = money(state.cash);
    const pill = header.querySelector(".cash-pill");
    if (pill) pill.classList.toggle("hidden", isAtm && state.atm.step !== "main");
  }

  /* ---- Main ---- */
  function renderMain() {
    const main = document.getElementById("bank-main");
    let key;
    let html;
    if (state.mode === "atm") {
      key = `atm:${state.atm.step}`;
      html = atmSkeleton();
    } else {
      key = `bank:${state.tab}`;
      html = { dashboard: dashSkeleton, accounts: accountsSkeleton, cards: cardsSkeleton, stats: statsSkeleton }[state.tab]();
    }
    if (main.dataset.key !== key) {
      destroyAtmPad();
      hideTooltip();
      main.innerHTML = html;
      main.dataset.key = key;
      main.scrollTop = 0;
      const view = main.querySelector(".view");
      if (view) setTimeout(() => view.classList.remove("anim"), 700);
      if (state.mode === "atm" && state.atm.step === "pin") mountAtmPad();
    }

    if (state.mode === "atm") updateAtm();
    else if (state.tab === "dashboard") updateDash();
    else if (state.tab === "accounts") updateAccounts();
    else if (state.tab === "cards") updateCards();
    else updateStats();
  }

  function flashBalance() {
    const el = document.getElementById("balance-value");
    const acc = state.mode === "atm" ? state.accounts[0] : activeAccount();
    if (!el || !acc) return;
    const prev = lastBalances[acc.id];
    if (prev !== undefined && prev !== acc.amount) {
      el.classList.remove("bump-up", "bump-down");
      void el.offsetWidth;
      el.classList.add(acc.amount > prev ? "bump-up" : "bump-down");
    }
    lastBalances[acc.id] = acc.amount;
  }

  /* ---- Shared pieces ---- */
  function accountOptions(selectedId) {
    return state.accounts
      .map((a) => `<option value="${esc(a.id)}" ${a.id === selectedId ? "selected" : ""}>${esc(a.name)} · ${esc(a.type)}</option>`)
      .join("");
  }

  function actionButtons(acc, kinds) {
    return kinds
      .map((k) => {
        const cfg = MONEY_ACTIONS[k];
        return `<button class="act-btn ${k}" data-money="${k}" data-account="${esc(acc.id)}" ${acc.isFrozen ? "disabled" : ""}><i class="fa-solid ${cfg.icon}"></i>${esc(t(cfg.key, cfg.fallback))}</button>`;
      })
      .join("");
  }

  function emptyState(icon, text) {
    return `<div class="empty-state"><i class="fa-solid ${icon}"></i><span>${esc(text)}</span></div>`;
  }

  function kpiTile(icon, cls, label, value, sub) {
    return `
      <div class="kpi ${cls}">
        <div class="kpi-icon"><i class="fa-solid ${icon}"></i></div>
        <div class="kpi-body">
          <div class="kpi-label">${esc(label)}</div>
          <div class="kpi-value">${value}</div>
          ${sub ? `<div class="kpi-sub">${sub}</div>` : ""}
        </div>
      </div>`;
  }

  /* ---- Transactions panel (dashboard + accounts tab) ---- */
  function txPanelSkeleton(scope, title) {
    return `
      <section class="panel tx-panel">
        <div class="panel-head">
          <h4><i class="fa-solid fa-receipt"></i>${esc(title)}</h4>
          <button class="ghost-btn" data-export="${scope}"><i class="fa-solid fa-file-export"></i>${esc(t("export_data", "Export CSV"))}</button>
        </div>
        <div class="search-row">
          <div class="search-input-wrap">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="text" data-search="tx" placeholder="${esc(t("search_tx", "Search transactions..."))}" value="${esc(state.txSearch)}" maxlength="60" />
          </div>
        </div>
        <div class="filter-row">
          <div class="seg" id="tx-${scope}-filters"></div>
          <span class="result-count" id="tx-${scope}-count"></span>
        </div>
        <div class="tx-scroll" id="tx-${scope}-list"></div>
      </section>`;
  }

  function updateTxPanel(scope, acc) {
    const list = document.getElementById(`tx-${scope}-list`);
    if (!list) return;
    const filters = document.getElementById(`tx-${scope}-filters`);
    const opts = [
      ["all", t("filter_all", "All")],
      ["in", t("filter_in", "Money in")],
      ["out", t("filter_out", "Money out")],
    ];
    filters.innerHTML = opts.map(([id, label]) => `<button class="${state.txFilter === id ? "active" : ""}" data-filter="${id}">${esc(label)}</button>`).join("");

    const all = (acc && acc.transactions) || [];
    const q = state.txSearch.trim().toLowerCase();
    const filtered = all.filter((tx) => {
      if (state.txFilter === "in" && tx.trans_type === "withdraw") return false;
      if (state.txFilter === "out" && tx.trans_type !== "withdraw") return false;
      if (!q) return true;
      return `${tx.message || ""} ${tx.trans_id || ""} ${tx.receiver || ""} ${tx.issuer || ""} ${tx.title || ""} ${tx.amount}`.toLowerCase().includes(q);
    });

    document.getElementById(`tx-${scope}-count`).textContent = t("showing", "Showing %{shown} of %{total}", { shown: filtered.length, total: all.length });
    list.innerHTML = filtered.length ? filtered.slice(0, 150).map(txRow).join("") : emptyState("fa-inbox", t("no_transactions", "No transactions found"));
  }

  function txRow(tx) {
    const out = tx.trans_type === "withdraw";
    const cls = out ? "withdraw" : "deposit";
    const counterparty = out ? tx.receiver : tx.issuer;
    const open = state.openTx === tx.trans_id;
    return `
      <div class="tx-row ${open ? "open" : ""}" data-tx="${esc(tx.trans_id)}">
        <div class="tx-main">
          <div class="tx-icon ${cls}"><i class="fa-solid ${out ? "fa-arrow-up" : "fa-arrow-down"}"></i></div>
          <div class="tx-mid">
            <div class="tx-title">${esc(tx.title)}</div>
            <div class="tx-sub">${esc(tx.time)}${counterparty ? ` • ${esc(counterparty)}` : ""}</div>
          </div>
          <div class="tx-right">
            <div class="tx-amount ${cls}">${out ? "-" : "+"}${money(tx.amount)}</div>
            ${typeof tx.balance === "number" ? `<div class="tx-bal">${money(tx.balance)}</div>` : ""}
          </div>
        </div>
        <div class="tx-details">
          <div><span>${esc(t("date", "Date"))}</span><b>${esc(fmtDateTime(tx.timestamp))}</b></div>
          <div><span>ID</span><b class="mono">${esc(tx.trans_id)}</b></div>
          <div><span>From</span><b>${esc(tx.issuer)}</b></div>
          <div><span>To</span><b>${esc(tx.receiver)}</b></div>
          ${tx.message ? `<div class="full"><span>${esc(t("comment", "Comment"))}</span><b>${esc(tx.message)}</b></div>` : ""}
        </div>
      </div>`;
  }

  /* ---- Dashboard ---- */
  function dashSkeleton() {
    return `
      <div class="view anim">
        <section class="acc-info-card" id="dash-info"></section>
        <div class="kpi-row" id="dash-kpis"></div>
        <div class="dash-grid">
          <section class="panel">
            <div class="panel-head">
              <h4><i class="fa-solid fa-chart-column"></i>${esc(t("latest_transactions", "Activity (last 7 days)"))}</h4>
              <div class="legend"><span class="in"><i></i>${esc(t("money_in", "Money in"))}</span><span class="out"><i></i>${esc(t("money_out", "Money out"))}</span></div>
            </div>
            <div class="chart-wrap"><canvas id="dash-chart"></canvas></div>
          </section>
          ${txPanelSkeleton("dash", t("recent_transactions", "Recent Transactions"))}
        </div>
      </div>`;
  }

  function updateDash() {
    const acc = activeAccount();
    const info = document.getElementById("dash-info");
    if (!acc) {
      info.innerHTML = emptyState("fa-building-columns", t("no_accounts", "No accounts found"));
      return;
    }
    info.innerHTML = `
      <div class="acc-info-top">
        <div class="acc-select-block">
          <div class="acc-kicker">${esc(t("account_title_label", "Account information"))}</div>
          <div class="acc-select-wrap">
            <select id="dash-account-select">${accountOptions(acc.id)}</select>
            <i class="fa-solid fa-chevron-down"></i>
          </div>
        </div>
        <div class="balance-block">
          <div class="balance-label">${esc(t("balance", "Available Balance"))}</div>
          <div class="balance-value" id="balance-value">${money(acc.amount)}</div>
        </div>
      </div>
      <div class="acc-info-row">
        <div class="info-box">
          <div><span class="info-label">${esc(t("iban", "IBAN"))}</span><span class="info-value mono">${esc(acc.iban || acc.id)}</span></div>
          <button class="icon-btn" data-copy="${esc(acc.iban || acc.id)}" title="${esc(t("copy", "Copy"))}"><i class="fa-solid fa-copy"></i></button>
        </div>
        <div class="info-box">
          <div><span class="info-label">${esc(t("cash", "Cash"))}</span><span class="info-value">${money(state.cash)}</span></div>
          <i class="fa-solid fa-money-bill-wave info-ico"></i>
        </div>
        <div class="acc-actions">${actionButtons(acc, ["deposit", "transfer", "withdraw"])}</div>
      </div>
      ${acc.isFrozen ? `<div class="frozen-banner"><i class="fa-solid fa-lock"></i>${esc(t("frozen", "This account is frozen - transactions are disabled"))}</div>` : ""}`;

    const stats = computeStats(acc, 7);
    const s = stats.summary;
    document.getElementById("dash-kpis").innerHTML =
      kpiTile("fa-arrow-trend-down", "in", t("money_in", "Money in"), money(s.totalIn), `${s.inCount} × ${esc(t("deposits", "Deposits"))}`) +
      kpiTile("fa-arrow-trend-up", "out", t("money_out", "Money out"), money(s.totalOut), `${s.outCount} × ${esc(t("withdrawals", "Withdrawals"))}`) +
      kpiTile("fa-scale-balanced", s.net >= 0 ? "in" : "out", t("net", "Net"), `${s.net >= 0 ? "+" : "-"}${money(Math.abs(s.net))}`, esc(t("days7", "7 days"))) +
      kpiTile("fa-hashtag", "blue", t("tx_count", "Transactions"), String(s.count), esc(t("days7", "7 days")));

    drawCharts();
    updateTxPanel("dash", acc);
  }

  /* ---- Accounts tab ---- */
  function accountsSkeleton() {
    return `
      <div class="view anim accounts-view-grid">
        <div class="accounts-col">
          <div class="search-row">
            <div class="search-input-wrap">
              <i class="fa-solid fa-magnifying-glass"></i>
              <input type="text" data-search="acc" placeholder="${esc(t("search_acc", "Search accounts..."))}" value="${esc(state.accSearch)}" maxlength="40" />
            </div>
            <button class="icon-btn primary" id="newAccountBtn" title="${esc(t("new_account", "New account"))}"><i class="fa-solid fa-plus"></i></button>
          </div>
          <div class="acc-list" id="acc-list"></div>
        </div>
        <div class="accounts-col detail-col" id="acc-detail"></div>
      </div>`;
  }

  function accountCaps(acc) {
    const canFreeze = !!acc.isCreator;
    const canRename = !!(acc.shared && acc.isCreator);
    const canClose = !!(acc.isCreator && ((acc.personal && !acc.isDefault) || acc.shared));
    return { canFreeze, canRename, canClose, members: !!(acc.shared && acc.isCreator), settings: canFreeze || canRename || canClose };
  }

  function updateAccounts() {
    const q = state.accSearch.trim().toLowerCase();
    const list = state.accounts.filter((a) => !q || `${a.name} ${a.id} ${a.iban}`.toLowerCase().includes(q));
    const listEl = document.getElementById("acc-list");
    listEl.innerHTML = list.length
      ? list
          .map(
            (a) => `
        <div class="acc-card ${a.id === state.accSelectedId ? "active" : ""} ${a.isFrozen ? "frozen" : ""}" data-select-account="${esc(a.id)}">
          <div class="acc-card-top">
            <span class="type-badge ${a.shared ? "shared" : a.personal ? "personal" : "org"}"><i class="fa-solid ${a.shared ? "fa-users" : a.personal ? "fa-user" : "fa-briefcase"}"></i>${esc(a.type)}</span>
            ${a.isFrozen ? `<span class="frozen-tag"><i class="fa-solid fa-lock"></i>${esc(t("frozen_tag", "Frozen"))}</span>` : ""}
          </div>
          <div class="acc-card-name">${esc(a.name)}</div>
          <div class="acc-card-bottom">
            <span class="acc-card-iban mono">${esc(maskIban(a.iban))}</span>
            <span class="acc-card-amt">${money(a.amount)}</span>
          </div>
        </div>`
          )
          .join("")
      : emptyState("fa-magnifying-glass", t("no_accounts", "No accounts found"));

    const acc = getAccount(state.accSelectedId);
    const detail = document.getElementById("acc-detail");
    if (!acc) {
      ensure(detail, "empty", emptyState("fa-hand-pointer", t("select_account", "Select an account")));
      return;
    }

    const caps = accountCaps(acc);
    if ((state.accSubtab === "members" && !caps.members) || (state.accSubtab === "settings" && !caps.settings)) state.accSubtab = "transactions";
    const sub = state.accSubtab;

    let body;
    if (sub === "members") {
      body = `
        <section class="panel">
          <div class="panel-head">
            <h4><i class="fa-solid fa-users"></i>${esc(t("members", "Members"))}</h4>
            <button class="ghost-btn" data-acc-action="add-member" data-account="${esc(acc.id)}"><i class="fa-solid fa-user-plus"></i>${esc(t("add_member", "Add member"))}</button>
          </div>
          <div class="member-list" id="acc-members"></div>
        </section>`;
    } else if (sub === "settings") {
      body = `<div class="settings-list" id="acc-settings"></div>`;
    } else {
      body = txPanelSkeleton("acc", t("transactions", "Transactions"));
    }

    ensure(
      detail,
      `${acc.id}:${sub}`,
      `<section class="detail-head" id="acc-head"></section>
       <div class="subtabs" id="acc-subtabs"></div>
       <div class="detail-body">${body}</div>`
    );

    document.getElementById("acc-head").innerHTML = `
      <div class="detail-top">
        <div>
          <div class="acc-kicker">${esc(acc.type)}${acc.isFrozen ? ` · <span class="frozen-tag"><i class="fa-solid fa-lock"></i>${esc(t("frozen_tag", "Frozen"))}</span>` : ""}</div>
          <h2>${esc(acc.name)}</h2>
          <div class="detail-iban"><span class="mono">${esc(acc.iban)}</span><button class="icon-btn sm" data-copy="${esc(acc.iban)}" title="${esc(t("copy", "Copy"))}"><i class="fa-solid fa-copy"></i></button></div>
        </div>
        <div class="balance-block">
          <div class="balance-label">${esc(t("balance", "Available Balance"))}</div>
          <div class="balance-value">${money(acc.amount)}</div>
        </div>
      </div>
      <div class="acc-actions">${actionButtons(acc, ["deposit", "transfer", "withdraw"])}</div>`;

    const tabs = [["transactions", "fa-receipt", t("transactions", "Transactions")]];
    if (caps.members) tabs.push(["members", "fa-users", t("members", "Members")]);
    if (caps.settings) tabs.push(["settings", "fa-gear", t("settings", "Settings")]);
    const subtabs = document.getElementById("acc-subtabs");
    subtabs.classList.toggle("hidden", tabs.length < 2);
    subtabs.innerHTML = tabs.map(([id, icon, label]) => `<button class="${sub === id ? "active" : ""}" data-subtab="${id}"><i class="fa-solid ${icon}"></i>${esc(label)}</button>`).join("");

    if (sub === "transactions") {
      updateTxPanel("acc", acc);
    } else if (sub === "members") {
      const membersEl = document.getElementById("acc-members");
      const members = state.members[acc.id];
      if (members === undefined) loadMembers(acc.id);
      if (!members) {
        membersEl.innerHTML = `<div class="empty-state"><i class="fa-solid fa-spinner fa-spin"></i></div>`;
      } else {
        membersEl.innerHTML = members
          .map(
            (m) => `
          <div class="member-row">
            <div class="avatar">${esc((m.name || "?").trim().charAt(0).toUpperCase())}</div>
            <div class="member-info"><b>${esc(m.name)}</b><span class="mono">${esc(m.cid)}</span></div>
            ${
              m.creator
                ? `<span class="owner-tag"><i class="fa-solid fa-crown"></i>${esc(t("owner", "Owner"))}</span>`
                : `<button class="ghost-btn danger" data-acc-action="remove-member" data-account="${esc(acc.id)}" data-cid="${esc(m.cid)}"><i class="fa-solid fa-user-minus"></i>${esc(t("remove", "Remove"))}</button>`
            }
          </div>`
          )
          .join("");
      }
    } else {
      const rows = [];
      if (caps.canFreeze)
        rows.push(
          settingRow(
            acc.isFrozen ? "fa-lock-open" : "fa-snowflake",
            acc.isFrozen ? t("unfreeze_acc", "Unfreeze account") : t("freeze_acc", "Freeze account"),
            t("freeze_desc", "Block every deposit, withdrawal and transfer"),
            "freeze",
            acc,
            acc.isFrozen ? t("unfreeze", "Unfreeze") : t("freeze", "Freeze")
          )
        );
      if (caps.canRename) rows.push(settingRow("fa-pen", t("rename", "Rename account"), t("rename_desc", "Change the name (ID) of this shared account"), "rename", acc, t("rename", "Rename")));
      if (caps.canClose) rows.push(settingRow("fa-trash", t("close_acc", "Close account"), t("close_acc_desc", "The remaining balance moves to your main account"), "close", acc, t("close_acc", "Close account"), true));
      document.getElementById("acc-settings").innerHTML = rows.join("");
    }
  }

  function settingRow(icon, title, desc, action, acc, btn, danger) {
    return `
      <div class="setting-row ${danger ? "danger" : ""}">
        <div class="setting-icon"><i class="fa-solid ${icon}"></i></div>
        <div class="setting-text"><b>${esc(title)}</b><span>${esc(desc)}</span></div>
        <button class="ghost-btn ${danger ? "danger" : ""}" data-acc-action="${action}" data-account="${esc(acc.id)}">${esc(btn)}</button>
      </div>`;
  }

  /* ---- Cards tab ---- */
  function cardsSkeleton() {
    return `
      <div class="view anim">
        <div class="cards-grid" id="cards-grid"></div>
      </div>`;
  }

  const CARD_COLORS = ["blue", "gold", "silver", "purple", "green", "red", "black"];

  function updateCards() {
    const grid = document.getElementById("cards-grid");
    const accounts = state.accounts.filter((a) => a.canCard);
    if (!accounts.length) {
      grid.innerHTML = emptyState("fa-credit-card", t("no_cards", "You don't own any account that supports cards"));
      return;
    }
    grid.innerHTML = accounts.map(cardTile).join("");
  }

  function cardTile(acc) {
    const iban = acc.iban || "";
    if (!acc.hasCard) {
      if (acc.cardPending) {
        const readyAt = state.receivedAt + (acc.cardReadyIn || 0) * 1000;
        return `
          <div class="request-card-tile pending">
            <i class="fa-solid fa-hourglass-half"></i>
            <b>${esc(acc.name)}</b>
            <span>${esc(t("card_pending", "Your card is being prepared"))}</span>
            <span class="countdown" data-countdown="${readyAt}"></span>
          </div>`;
      }
      return `
        <div class="request-card-tile">
          <i class="fa-solid fa-credit-card"></i>
          <b>${esc(acc.name)}</b>
          <span>${esc(t("no_card_yet", "No card issued for this account yet."))}</span>
          <button class="act-btn transfer" data-card-action="request" data-account="${esc(acc.id)}"><i class="fa-solid fa-plus"></i>${esc(t("request_card", "Request card"))}</button>
        </div>`;
    }

    const color = CARD_COLORS.includes(acc.cardColor) ? acc.cardColor : "blue";
    const masked = iban.length > 4 ? `•••• •••• ${iban.slice(-4)}` : iban;
    const frozen = !!acc.isFrozen;
    return `
      <div class="card-tile">
        <div class="credit-card color-${color} ${frozen ? "frozen-card" : ""}">
          <div class="card-glow"></div>
          ${frozen ? `<div class="card-frozen-badge"><i class="fa-solid fa-snowflake"></i>${esc(t("frozen_tag", "Frozen"))}</div>` : ""}
          <div class="card-top-row">
            <div class="card-chip"></div>
            <div class="card-issuer">
              <span class="card-brand">${esc(t("bank_name", "Los Santos Bank"))}</span>
              <span class="card-network">VISA</span>
            </div>
          </div>
          <div class="card-number">${esc(masked)}</div>
          <div class="card-bottom-row">
            <div>
              <div class="card-label">${esc(t("card_holder", "Card holder"))}</div>
              <div class="card-value">${esc(acc.name)}</div>
            </div>
            <div class="right">
              <div class="card-label">${esc(t("card_balance", "Card balance"))}</div>
              <div class="card-value">${acc.cardOnYou ? money(acc.cardBalance) : "—"}</div>
            </div>
          </div>
        </div>
        <div class="card-status">
          <span class="pill ${acc.cardPin ? "ok" : "warn"}"><i class="fa-solid ${acc.cardPin ? "fa-shield-halved" : "fa-triangle-exclamation"}"></i>${esc(acc.cardPin ? t("pin_protected", "PIN protected") : t("no_pin", "No PIN - withdraw only"))}</span>
          ${acc.cardOnYou ? "" : `<span class="pill muted"><i class="fa-solid fa-circle-question"></i>${esc(t("card_not_on_you", "Card not in your inventory"))}</span>`}
        </div>
        <div class="card-actions">
          <button class="card-btn ${frozen ? "is-frozen" : ""}" data-card-action="freeze" data-account="${esc(acc.id)}"><i class="fa-solid ${frozen ? "fa-lock-open" : "fa-snowflake"}"></i>${esc(frozen ? t("unfreeze", "Unfreeze") : t("freeze", "Freeze"))}</button>
          <button class="card-btn" data-card-action="pin" data-account="${esc(acc.id)}"><i class="fa-solid fa-key"></i>${esc(acc.cardPin ? t("change_pin", "Change PIN") : t("set_pin", "Set PIN"))}</button>
          <button class="card-btn" data-card-action="load" data-account="${esc(acc.id)}" ${acc.cardOnYou && !frozen ? "" : "disabled"}><i class="fa-solid fa-arrow-right-to-bracket"></i>${esc(t("load", "Load"))}</button>
          <button class="card-btn" data-card-action="unload" data-account="${esc(acc.id)}" ${acc.cardOnYou && acc.cardBalance > 0 ? "" : "disabled"}><i class="fa-solid fa-arrow-right-from-bracket"></i>${esc(t("unload", "Unload"))}</button>
          <button class="card-btn" data-copy="${esc(iban)}"><i class="fa-solid fa-copy"></i>${esc(t("iban", "IBAN"))}</button>
          <button class="card-btn danger" data-card-action="replace" data-account="${esc(acc.id)}"><i class="fa-solid fa-triangle-exclamation"></i>${esc(t("lost_stolen", "Lost / Stolen"))}</button>
        </div>
      </div>`;
  }

  setInterval(() => {
    document.querySelectorAll("[data-countdown]").forEach((el) => {
      const left = Math.max(0, Math.ceil((Number(el.dataset.countdown) - Date.now()) / 1000));
      el.textContent = left > 0 ? `${left}s` : t("card_ready", "Ready - collect it from the teller");
      el.classList.toggle("ready", left === 0);
    });
  }, 500);

  /* ---- Statistics tab ---- */
  function statsSkeleton() {
    return `
      <div class="view anim stats-view">
        <div class="stats-toolbar">
          <div class="acc-select-wrap">
            <select id="stats-account-select"></select>
            <i class="fa-solid fa-chevron-down"></i>
          </div>
          <div class="seg" id="stats-period"></div>
          <div class="header-spacer"></div>
          <button class="ghost-btn" data-export="stats"><i class="fa-solid fa-file-export"></i>${esc(t("export_data", "Export CSV"))}</button>
        </div>
        <div class="kpi-row six" id="stats-kpis"></div>
        <div class="stats-grid">
          <section class="panel">
            <div class="panel-head">
              <h4><i class="fa-solid fa-chart-column"></i>${esc(t("daily_flow", "Daily money flow"))}</h4>
              <div class="legend"><span class="in"><i></i>${esc(t("money_in", "Money in"))}</span><span class="out"><i></i>${esc(t("money_out", "Money out"))}</span></div>
            </div>
            <div class="chart-wrap tall"><canvas id="stats-flow"></canvas></div>
          </section>
          <section class="panel">
            <div class="panel-head"><h4><i class="fa-solid fa-chart-line"></i>${esc(t("balance_trend", "Balance trend"))}</h4></div>
            <div class="chart-wrap tall"><canvas id="stats-balance"></canvas></div>
          </section>
        </div>
        <div class="stats-grid wide-left">
          <section class="panel">
            <div class="panel-head"><h4><i class="fa-solid fa-table"></i>${esc(t("daily_table", "Daily breakdown"))}</h4></div>
            <div class="table-wrap" id="stats-table"></div>
          </section>
          <section class="panel">
            <div class="panel-head"><h4><i class="fa-solid fa-ranking-star"></i>${esc(t("top_tx", "Largest transactions"))}</h4></div>
            <div class="top-list" id="stats-top"></div>
          </section>
        </div>
      </div>`;
  }

  function updateStats() {
    const acc = getAccount(state.statsAccountId) || activeAccount();
    document.getElementById("stats-account-select").innerHTML = accountOptions(acc && acc.id);
    const periods = [
      [7, t("days7", "7 days")],
      [30, t("days30", "30 days")],
      [0, t("all_time", "All")],
    ];
    document.getElementById("stats-period").innerHTML = periods
      .map(([d, label]) => `<button class="${state.statsPeriod === d ? "active" : ""}" data-period="${d}">${esc(label)}</button>`)
      .join("");
    if (!acc) return;

    const { buckets, summary: s } = computeStats(acc, state.statsPeriod);
    document.getElementById("stats-kpis").innerHTML =
      kpiTile("fa-arrow-trend-down", "in", t("total_in", "Total deposited"), money(s.totalIn), `${s.inCount} × ${esc(t("deposits", "Deposits"))}`) +
      kpiTile("fa-arrow-trend-up", "out", t("total_out", "Total withdrawn"), money(s.totalOut), `${s.outCount} × ${esc(t("withdrawals", "Withdrawals"))}`) +
      kpiTile("fa-scale-balanced", s.net >= 0 ? "in" : "out", t("net_flow", "Net flow"), `${s.net >= 0 ? "+" : "-"}${money(Math.abs(s.net))}`, "") +
      kpiTile("fa-hashtag", "blue", t("tx_count", "Transactions"), String(s.count), `${esc(t("avg_tx", "Average transaction"))}: ${money(s.avg)}`) +
      kpiTile("fa-circle-arrow-down", "in", t("largest_in", "Largest deposit"), s.largestIn ? money(s.largestIn.amount) : "—", s.largestIn ? esc(s.largestIn.time) : "") +
      kpiTile("fa-circle-arrow-up", "out", t("largest_out", "Largest withdrawal"), s.largestOut ? money(s.largestOut.amount) : "—", s.largestOut ? esc(s.largestOut.time) : "");

    const active = buckets.filter((b) => b.inCount || b.outCount).reverse();
    const table = document.getElementById("stats-table");
    if (!active.length) {
      table.innerHTML = emptyState("fa-table", t("no_data", "No data for this period yet"));
    } else {
      const tot = active.reduce(
        (a, b) => ({ inCount: a.inCount + b.inCount, in: a.in + b.in, outCount: a.outCount + b.outCount, out: a.out + b.out }),
        { inCount: 0, in: 0, outCount: 0, out: 0 }
      );
      const netCell = (n) => `<td class="num ${n > 0 ? "pos" : n < 0 ? "neg" : ""}">${n > 0 ? "+" : n < 0 ? "-" : ""}${money(Math.abs(n))}</td>`;
      table.innerHTML = `
        <table class="stats-table">
          <thead>
            <tr>
              <th>${esc(t("date", "Date"))}</th>
              <th class="num">${esc(t("deposits", "Deposits"))}</th>
              <th class="num">${esc(t("money_in", "Money in"))}</th>
              <th class="num">${esc(t("withdrawals", "Withdrawals"))}</th>
              <th class="num">${esc(t("money_out", "Money out"))}</th>
              <th class="num">${esc(t("net", "Net"))}</th>
              <th class="num">${esc(t("closing", "Closing balance"))}</th>
            </tr>
          </thead>
          <tbody>
            ${active
              .map(
                (b) => `
              <tr>
                <td><span class="weekday">${esc(fmtWeekday(b.date))}</span> ${esc(fmtDay(b.date))}</td>
                <td class="num muted">${b.inCount}</td>
                <td class="num pos">${b.in ? money(b.in) : "—"}</td>
                <td class="num muted">${b.outCount}</td>
                <td class="num neg">${b.out ? money(b.out) : "—"}</td>
                ${netCell(b.net)}
                <td class="num">${b.closing === null ? "—" : money(b.closing)}</td>
              </tr>`
              )
              .join("")}
          </tbody>
          <tfoot>
            <tr>
              <td>${esc(t("total", "Total"))}</td>
              <td class="num">${tot.inCount}</td>
              <td class="num pos">${money(tot.in)}</td>
              <td class="num">${tot.outCount}</td>
              <td class="num neg">${money(tot.out)}</td>
              ${netCell(tot.in - tot.out)}
              <td class="num">${money(acc.amount)}</td>
            </tr>
          </tfoot>
        </table>`;
    }

    const top = document.getElementById("stats-top");
    const maxAmount = s.top.length ? Number(s.top[0].amount) || 1 : 1;
    top.innerHTML = s.top.length
      ? s.top
          .map((tx) => {
            const out = tx.trans_type === "withdraw";
            const pct = Math.max(4, Math.round(((Number(tx.amount) || 0) / maxAmount) * 100));
            return `
            <div class="top-row">
              <div class="top-line">
                <span class="top-title"><i class="fa-solid ${out ? "fa-arrow-up" : "fa-arrow-down"} ${out ? "neg" : "pos"}"></i>${esc(tx.title)}</span>
                <b class="${out ? "neg" : "pos"}">${out ? "-" : "+"}${money(tx.amount)}</b>
              </div>
              <div class="top-bar"><div class="${out ? "out" : "in"}" style="width:${pct}%"></div></div>
              <div class="top-sub">${esc(tx.time)} • ${esc(out ? tx.receiver : tx.issuer)}</div>
            </div>`;
          })
          .join("")
      : emptyState("fa-ranking-star", t("no_data", "No data for this period yet"));

    drawCharts();
  }

  /* ---- ATM ---- */
  function openAtm(cards) {
    state.mode = "atm";
    state.accounts = [];
    state.txSearch = "";
    state.openTx = null;
    state.atm = { step: "cards", cards, card: null, error: "" };
    state.visible = true;
    state.loading = false;
    if (cards.length === 1) {
      selectAtmCard(cards[0].slot);
      return;
    }
    render();
  }

  function selectAtmCard(slot) {
    const card = state.atm.cards.find((c) => String(c.slot) === String(slot));
    if (!card) return;
    state.atm.card = card;
    state.atm.error = "";
    if (card.hasPin) {
      state.atm.step = "pin";
      render();
    } else {
      insertCard("");
    }
  }

  let atmPad = null;
  function destroyAtmPad() {
    if (atmPad) atmPad.destroy();
    atmPad = null;
  }

  function mountAtmPad() {
    const el = document.getElementById("atm-pinpad");
    if (!el) return;
    atmPad = createPinPad(el, { onComplete: (pin) => insertCard(pin) });
    if (state.atm.error) atmPad.reset(state.atm.error, true);
  }

  async function insertCard(pin) {
    const card = state.atm.card;
    if (!card) return;
    const onPinStep = state.atm.step === "pin";
    if (onPinStep && atmPad) atmPad.busy(t("loading", "Loading..."));
    else {
      state.atm.step = "reading";
      render();
    }

    const res = await fetchNui("atmInsertCard", { slot: card.slot, pin });
    if (!state.visible || state.mode !== "atm") return;

    if (res && res.accounts) {
      applyData(res);
      state.atm.step = "main";
      state.atm.error = "";
      render();
      if (state.restricted) toast(t("restricted", "No PIN on this card - withdraw only"), "info");
      return;
    }

    let message = (res && res.error) || t("loading_failed", "Failed to load Banking Data!");
    if (res && res.attemptsLeft) message += ` · ${t("attempts_left", "%{n} attempt(s) left", { n: res.attemptsLeft })}`;

    if (res && res.needPin && !res.locked) {
      card.hasPin = true;
      state.atm.error = res.error ? message : "";
      if (state.atm.step === "pin" && atmPad) atmPad.reset(state.atm.error, !!res.error);
      else {
        state.atm.step = "pin";
        render();
      }
      return;
    }

    // locked / deactivated / invalid: back to card choice with the error
    state.atm.error = message;
    state.atm.step = "cards";
    toast(message, "error");
    render();
  }

  function atmSkeleton() {
    const step = state.atm.step;
    if (step === "cards") {
      return `
        <div class="view anim atm-view">
          <div class="atm-step-head">
            <div class="atm-step-icon"><i class="fa-solid fa-credit-card"></i></div>
            <h3>${esc(t("insert_card", "Insert your card"))}</h3>
            <p>${esc(t("insert_card_desc", "Choose the card you want to use"))}</p>
          </div>
          <div class="atm-error hidden" id="atm-error"></div>
          <div class="atm-card-list" id="atm-card-list"></div>
        </div>`;
    }
    if (step === "pin") {
      return `
        <div class="view anim atm-view">
          <div class="atm-step-head">
            <div id="atm-pin-card"></div>
            <h3>${esc(t("enter_pin", "Enter PIN"))}</h3>
            <p>${esc(t("enter_pin_desc", "Enter the 4-digit PIN of this card"))}</p>
          </div>
          <div id="atm-pinpad"></div>
          <div class="atm-footer">
            ${state.atm.cards.length > 1 ? `<button class="ghost-btn" data-atm="back"><i class="fa-solid fa-arrow-left"></i>${esc(t("back", "Back"))}</button>` : ""}
            <button class="ghost-btn danger" data-atm="eject"><i class="fa-solid fa-eject"></i>${esc(t("eject", "Eject card"))}</button>
          </div>
        </div>`;
    }
    if (step === "reading") {
      return `
        <div class="view anim atm-view">
          <div class="atm-reading"><div class="spinner-ring"></div><span>${esc(t("loading", "Loading..."))}</span></div>
        </div>`;
    }
    return `
      <div class="view anim atm-view">
        <div class="atm-hero" id="atm-hero"></div>
        <div id="atm-actions"></div>
        <div>
          <div class="panel-head"><h4><i class="fa-solid fa-receipt"></i>${esc(t("recent_activity", "Recent activity"))}</h4></div>
          <div class="atm-mini-list" id="atm-list"></div>
        </div>
        <div class="atm-footer">
          <button class="ghost-btn danger" data-atm="eject"><i class="fa-solid fa-eject"></i>${esc(t("eject", "Eject card"))}</button>
        </div>
      </div>`;
  }

  function miniCard(card) {
    const color = CARD_COLORS.includes(card.color) ? card.color : "blue";
    return `<div class="mini-card color-${color}"><div class="mini-chip"></div><span>VISA</span></div>`;
  }

  function updateAtm() {
    const step = state.atm.step;
    if (step === "cards") {
      const err = document.getElementById("atm-error");
      err.classList.toggle("hidden", !state.atm.error);
      err.innerHTML = state.atm.error ? `<i class="fa-solid fa-circle-exclamation"></i>${esc(state.atm.error)}` : "";
      document.getElementById("atm-card-list").innerHTML = state.atm.cards
        .map(
          (c) => `
          <button class="atm-card-option" data-atm-card="${esc(c.slot)}">
            ${miniCard(c)}
            <div class="info"><b>${esc(c.holder || "—")}</b><span class="mono">${esc(maskIban(c.iban))}</span></div>
            <i class="fa-solid ${c.hasPin ? "fa-lock" : "fa-lock-open"}"></i>
          </button>`
        )
        .join("");
      return;
    }
    if (step === "pin") {
      const holder = document.getElementById("atm-pin-card");
      if (holder && state.atm.card) {
        ensure(holder, String(state.atm.card.slot), `<div class="atm-pin-card">${miniCard(state.atm.card)}<span class="mono">${esc(maskIban(state.atm.card.iban))}</span></div>`);
      }
      return;
    }
    if (step !== "main") return;

    const acc = state.accounts[0];
    if (!acc) return;
    document.getElementById("atm-hero").innerHTML = `
      <div class="atm-owner"><i class="fa-solid fa-user"></i>${esc(acc.name)} · <span class="mono">${esc(maskIban(acc.iban))}</span></div>
      <span class="balance-value" id="balance-value">${money(acc.amount)}</span>
      <div class="balance-label">${esc(t("balance", "Available Balance"))}</div>`;

    const actions = document.getElementById("atm-actions");
    if (acc.isFrozen) {
      actions.innerHTML = `<div class="frozen-banner"><i class="fa-solid fa-lock"></i>${esc(t("frozen", "This account is frozen - transactions are disabled"))}</div>`;
    } else {
      const quick = [100, 500, 1000, 2500, 5000];
      actions.innerHTML = `
        ${state.restricted ? `<div class="atm-notice"><i class="fa-solid fa-triangle-exclamation"></i>${esc(t("restricted", "No PIN on this card - withdraw only"))}</div>` : ""}
        <div class="atm-section-label">${esc(t("quick_withdraw", "Quick withdraw"))}</div>
        <div class="atm-quick">
          ${quick.map((v) => `<button class="quick-btn" data-atm-quick="${v}" ${v > acc.amount ? "disabled" : ""}>${money(v)}</button>`).join("")}
          <button class="quick-btn alt" data-money="withdraw" data-account="${esc(acc.id)}">${esc(t("other_amount", "Other amount"))}</button>
        </div>
        ${state.restricted ? "" : `<div class="atm-actions">${actionButtons(acc, ["deposit", "transfer"])}</div>`}`;
    }

    const recent = (acc.transactions || []).slice(0, 5);
    document.getElementById("atm-list").innerHTML = recent.length ? recent.map(txRow).join("") : emptyState("fa-inbox", t("no_transactions", "No transactions found"));
  }

  /* ---------------------------------------------------------------------
     PIN pad (used by the ATM and by the "Set PIN" modal)
  --------------------------------------------------------------------- */
  function createPinPad(el, opts) {
    el.innerHTML = `
      <div class="pinpad">
        ${opts.title ? `<div class="pin-title">${esc(opts.title)}</div>` : ""}
        <div class="pin-dots"><span></span><span></span><span></span><span></span></div>
        <div class="pin-msg"></div>
        <div class="pin-keys">
          ${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((k) => `<button type="button" data-key="${k}">${k}</button>`).join("")}
          <button type="button" class="fn" data-key="clear"><i class="fa-solid fa-xmark"></i></button>
          <button type="button" data-key="0">0</button>
          <button type="button" class="fn" data-key="back"><i class="fa-solid fa-delete-left"></i></button>
        </div>
      </div>`;
    const pad = el.querySelector(".pinpad");
    const dots = el.querySelectorAll(".pin-dots span");
    const msg = el.querySelector(".pin-msg");
    const titleEl = el.querySelector(".pin-title");
    let value = "";
    let locked = false;

    const paint = () => dots.forEach((d, i) => d.classList.toggle("filled", i < value.length));

    function press(k) {
      if (locked) return;
      if (k === "clear") value = "";
      else if (k === "back") value = value.slice(0, -1);
      else if (/^\d$/.test(k) && value.length < 4) value += k;
      paint();
      if (value.length === 4) {
        locked = true;
        const pin = value;
        setTimeout(() => opts.onComplete(pin), 90);
      }
    }

    const onClick = (e) => {
      const b = e.target.closest("[data-key]");
      if (!b) return;
      b.classList.remove("hit");
      void b.offsetWidth;
      b.classList.add("hit");
      press(b.dataset.key);
    };
    const onKey = (e) => {
      if (!document.body.contains(el)) return;
      if (e.target && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) return;
      if (/^\d$/.test(e.key)) {
        e.preventDefault();
        press(e.key);
      } else if (e.key === "Backspace") {
        e.preventDefault();
        press("back");
      }
    };
    el.addEventListener("click", onClick);
    window.addEventListener("keydown", onKey);

    return {
      reset(message, isError) {
        value = "";
        locked = false;
        paint();
        pad.classList.remove("disabled");
        msg.textContent = message || "";
        msg.classList.toggle("error", !!isError);
        if (isError) {
          pad.classList.remove("shake");
          void pad.offsetWidth;
          pad.classList.add("shake");
        }
      },
      setTitle(text) {
        if (titleEl) titleEl.textContent = text;
      },
      busy(message) {
        locked = true;
        pad.classList.add("disabled");
        msg.classList.remove("error");
        msg.textContent = message || "";
      },
      destroy() {
        window.removeEventListener("keydown", onKey);
        el.removeEventListener("click", onClick);
      },
    };
  }

  /* ---------------------------------------------------------------------
     In-NUI modals: form / confirm / choice / PIN
  --------------------------------------------------------------------- */
  const modal = { resolve: null, cleanup: null };
  const modalRoot = document.getElementById("modal-root");

  function showModal(html, onMount) {
    closeModal(null);
    return new Promise((resolve) => {
      modal.resolve = resolve;
      modalRoot.innerHTML = `<div class="popup-backdrop" data-modal-close></div><div class="popup-card">${html}</div>`;
      modalRoot.querySelector("[data-modal-close]").addEventListener("click", () => closeModal(null));
      modalRoot.querySelectorAll("[data-modal-cancel]").forEach((b) => b.addEventListener("click", () => closeModal(null)));
      modal.cleanup = onMount ? onMount(modalRoot.querySelector(".popup-card")) : null;
    });
  }

  function closeModal(result) {
    if (!modal.resolve) return;
    const resolve = modal.resolve;
    modal.resolve = null;
    if (typeof modal.cleanup === "function") modal.cleanup();
    modal.cleanup = null;
    modalRoot.innerHTML = "";
    resolve(result);
  }

  function modalHead(icon, title, accent) {
    return `<h2 class="${accent || ""}"><span class="modal-icon"><i class="fa-solid ${icon || "fa-circle-info"}"></i></span>${esc(title)}</h2>`;
  }

  function openForm(opts) {
    const fields = opts.fields
      .map((f) => {
        const input =
          f.type === "amount"
            ? `<div class="amount-input"><span>$</span><input type="number" name="${f.name}" min="1" step="1" inputmode="numeric" placeholder="0" value="${esc(f.value || "")}" /></div>`
            : `<input type="text" name="${f.name}" placeholder="${esc(f.placeholder || "")}" maxlength="${f.maxlength || 60}" value="${esc(f.value || "")}" autocomplete="off" />`;
        const quick = f.quick && f.quick.length
          ? `<div class="quick-row">${f.quick.map((q) => `<button type="button" class="chip" data-quick="${q.value}" data-field="${f.name}">${esc(q.label)}</button>`).join("")}</div>`
          : "";
        return `
          <div class="form-row">
            <label>${esc(f.label)}${f.hint ? `<span class="hint">${esc(f.hint)}</span>` : ""}</label>
            ${input}
            ${quick}
          </div>`;
      })
      .join("");

    return showModal(
      `
      ${modalHead(opts.icon, opts.title, opts.accent)}
      ${opts.desc ? `<p class="modal-desc">${esc(opts.desc)}</p>` : ""}
      <form id="modalForm" novalidate>
        ${fields}
        <div class="form-error hidden"></div>
        <div class="popup-btns">
          <button type="button" class="btn-cancel" data-modal-cancel>${esc(t("cancel", "Cancel"))}</button>
          <button type="submit" class="btn-confirm ${opts.danger ? "danger" : ""} ${opts.accent || ""}">${esc(opts.confirmLabel || t("confirm", "Confirm"))}</button>
        </div>
      </form>`,
      (card) => {
        const form = card.querySelector("#modalForm");
        const errorEl = card.querySelector(".form-error");
        const first = form.querySelector("input");
        if (first) setTimeout(() => first.focus(), 30);

        form.addEventListener("click", (e) => {
          const chip = e.target.closest("[data-quick]");
          if (!chip) return;
          const input = form.querySelector(`[name="${chip.dataset.field}"]`);
          input.value = chip.dataset.quick;
          input.focus();
        });

        form.addEventListener("submit", (e) => {
          e.preventDefault();
          const values = {};
          for (const f of opts.fields) {
            const raw = form.querySelector(`[name="${f.name}"]`).value.trim();
            if (f.type === "amount") {
              const n = Math.floor(Number(raw));
              if (!raw || !isFinite(n) || n < 1) return showError(t("amount", "Amount") + ": " + t("invalid", "invalid value"));
              if (f.max !== undefined && n > f.max) return showError(`${t("available", "Available")}: ${money(f.max)}`);
              values[f.name] = n;
            } else {
              if (f.required && !raw) return showError(`${f.label}?`);
              if (raw && f.pattern && !new RegExp(f.pattern).test(raw)) return showError(f.placeholder || f.label);
              values[f.name] = raw;
            }
          }
          closeModal(values);
        });

        function showError(msg) {
          errorEl.textContent = msg;
          errorEl.classList.remove("hidden");
          const c = card;
          c.classList.remove("shake");
          void c.offsetWidth;
          c.classList.add("shake");
        }
      }
    );
  }

  function openConfirm(opts) {
    return showModal(
      `
      ${modalHead(opts.icon, opts.title, opts.danger ? "danger" : "")}
      <p class="modal-desc">${esc(opts.message)}</p>
      <div class="popup-btns">
        <button type="button" class="btn-cancel" data-modal-cancel>${esc(t("cancel", "Cancel"))}</button>
        <button type="button" class="btn-confirm ${opts.danger ? "danger" : ""}" id="modalOk">${esc(opts.confirmLabel || t("confirm", "Confirm"))}</button>
      </div>`,
      (card) => {
        const ok = card.querySelector("#modalOk");
        ok.addEventListener("click", () => closeModal(true));
        setTimeout(() => ok.focus(), 30);
      }
    ).then((r) => r === true);
  }

  function openChoice(opts) {
    return showModal(
      `
      ${modalHead(opts.icon, opts.title)}
      <div class="choice-list">
        ${opts.options
          .map(
            (o) => `
          <button type="button" class="choice" data-choice="${esc(o.id)}" ${o.disabled ? "disabled" : ""}>
            <span class="choice-icon"><i class="fa-solid ${o.icon}"></i></span>
            <span class="choice-text"><b>${esc(o.label)}</b><span>${esc(o.desc || "")}</span></span>
            <i class="fa-solid fa-chevron-right"></i>
          </button>`
          )
          .join("")}
      </div>
      <div class="popup-btns"><button type="button" class="btn-cancel" data-modal-cancel>${esc(t("cancel", "Cancel"))}</button></div>`,
      (card) => {
        card.querySelectorAll("[data-choice]").forEach((b) => b.addEventListener("click", () => closeModal(b.dataset.choice)));
      }
    );
  }

  function openPinModal(opts) {
    return showModal(
      `
      ${modalHead("fa-key", opts.title)}
      ${opts.note ? `<p class="modal-desc">${esc(opts.note)}</p>` : ""}
      <div id="modal-pinpad"></div>
      <div class="popup-btns"><button type="button" class="btn-cancel" data-modal-cancel>${esc(t("cancel", "Cancel"))}</button></div>`,
      (card) => {
        let first = null;
        const pad = createPinPad(card.querySelector("#modal-pinpad"), {
          title: t("new_pin", "Choose a new 4-digit PIN"),
          onComplete(pin) {
            if (first === null) {
              first = pin;
              pad.setTitle(t("confirm_pin", "Enter the PIN again"));
              pad.reset("", false);
            } else if (pin === first) {
              closeModal(pin);
            } else {
              first = null;
              pad.setTitle(t("new_pin", "Choose a new 4-digit PIN"));
              pad.reset(t("pin_mismatch", "PINs don't match, try again"), true);
            }
          },
        });
        return () => pad.destroy();
      }
    );
  }

  /* ---------------------------------------------------------------------
     Charts (canvas, no library) + tooltip
  --------------------------------------------------------------------- */
  const tooltip = document.getElementById("chart-tooltip");

  function showTooltip(html, x, y) {
    tooltip.innerHTML = html;
    tooltip.classList.remove("hidden");
    const r = tooltip.getBoundingClientRect();
    let left = x + 14;
    let top = y - r.height - 10;
    if (left + r.width > window.innerWidth - 8) left = x - r.width - 14;
    if (top < 8) top = y + 16;
    tooltip.style.left = `${left}px`;
    tooltip.style.top = `${top}px`;
  }

  function hideTooltip() {
    if (tooltip) tooltip.classList.add("hidden");
  }

  function setupCanvas(canvas) {
    const rect = canvas.parentElement.getBoundingClientRect();
    const w = Math.floor(rect.width);
    const h = Math.floor(rect.height);
    if (w < 40 || h < 40) return null;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    return { ctx, w, h };
  }

  function niceMax(v) {
    if (v <= 0) return 100;
    const p = Math.pow(10, Math.floor(Math.log10(v)));
    const n = v / p;
    return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 2.5 ? 2.5 : n <= 5 ? 5 : 10) * p;
  }

  function roundRect(ctx, x, y, w, h, r) {
    h = Math.max(h, 0);
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.lineTo(x + w, y + h);
    ctx.lineTo(x, y + h);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function drawEmpty(ctx, w, h) {
    ctx.fillStyle = COLORS.label;
    ctx.font = "600 12px Roboto, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(t("no_data", "No data for this period yet"), w / 2, h / 2);
  }

  function drawYAxis(ctx, pad, w, chartH, min, max, formatter) {
    ctx.font = "10px Roboto, sans-serif";
    ctx.textAlign = "right";
    ctx.textBaseline = "middle";
    for (let g = 0; g <= 4; g++) {
      const y = pad.top + (chartH / 4) * g;
      ctx.strokeStyle = COLORS.grid;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(pad.left, Math.round(y) + 0.5);
      ctx.lineTo(w - pad.right, Math.round(y) + 0.5);
      ctx.stroke();
      ctx.fillStyle = COLORS.label;
      ctx.fillText(formatter(max - ((max - min) / 4) * g), pad.left - 8, y);
    }
  }

  function drawXLabels(ctx, labels, pad, h, groupW, maxLabels) {
    const step = Math.max(1, Math.ceil(labels.length / maxLabels));
    ctx.fillStyle = COLORS.label;
    ctx.font = "10px Roboto, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "alphabetic";
    labels.forEach((label, i) => {
      if ((labels.length - 1 - i) % step !== 0) return;
      ctx.fillText(label, pad.left + groupW * i + groupW / 2, h - 6);
    });
  }

  function drawFlowChart(canvas, buckets, hover) {
    const c = setupCanvas(canvas);
    if (!c) return;
    const { ctx, w, h } = c;
    const pad = { top: 12, right: 10, bottom: 24, left: 52 };
    const chartW = w - pad.left - pad.right;
    const chartH = h - pad.top - pad.bottom;
    const n = buckets.length;
    const groupW = chartW / n;
    const maxVal = niceMax(Math.max(0, ...buckets.map((b) => Math.max(b.in, b.out))));
    canvas._chart = { kind: "flow", buckets, left: pad.left, groupW, n };

    drawYAxis(ctx, pad, w, chartH, 0, maxVal, compactMoney);
    if (!buckets.some((b) => b.in || b.out)) {
      drawEmpty(ctx, w, h);
      return;
    }

    if (hover !== undefined && hover !== null) {
      ctx.fillStyle = "rgba(79,143,247,0.08)";
      roundRect(ctx, pad.left + groupW * hover + 1, pad.top, groupW - 2, chartH, 6);
      ctx.fill();
    }

    const barW = Math.max(2, Math.min(16, groupW * 0.3));
    const gap = Math.max(1, Math.min(4, groupW * 0.06));
    buckets.forEach((b, i) => {
      const cx = pad.left + groupW * i + groupW / 2;
      [
        [b.in, COLORS.in, cx - barW - gap / 2],
        [b.out, COLORS.out, cx + gap / 2],
      ].forEach(([val, color, x]) => {
        if (!val) return;
        const bh = Math.max(2, (val / maxVal) * chartH);
        const grad = ctx.createLinearGradient(0, pad.top + chartH - bh, 0, pad.top + chartH);
        grad.addColorStop(0, color);
        grad.addColorStop(1, color + "55");
        ctx.fillStyle = grad;
        roundRect(ctx, x, pad.top + chartH - bh, barW, bh, Math.min(4, barW / 2));
        ctx.fill();
      });
    });

    const labels = buckets.map((b) => (n <= 7 ? fmtWeekday(b.date) : fmtDay(b.date)));
    drawXLabels(ctx, labels, pad, h, groupW, Math.max(2, Math.floor(chartW / 54)));
  }

  function drawBalanceChart(canvas, buckets, hover) {
    const c = setupCanvas(canvas);
    if (!c) return;
    const { ctx, w, h } = c;
    const pad = { top: 14, right: 12, bottom: 24, left: 52 };
    const chartW = w - pad.left - pad.right;
    const chartH = h - pad.top - pad.bottom;
    const n = buckets.length;
    const groupW = chartW / n;
    canvas._chart = { kind: "balance", buckets, left: pad.left, groupW, n };

    const vals = buckets.map((b) => b.closing).filter((v) => typeof v === "number");
    if (!vals.length) {
      drawYAxis(ctx, pad, w, chartH, 0, 100, compactMoney);
      drawEmpty(ctx, w, h);
      return;
    }
    let min = Math.min(...vals);
    let max = Math.max(...vals);
    const span = max - min || Math.max(100, Math.abs(max) * 0.1);
    min = Math.max(min < 0 ? -Infinity : 0, min - span * 0.15);
    max = max + span * 0.15;
    drawYAxis(ctx, pad, w, chartH, min, max, compactMoney);

    const pts = buckets.map((b, i) => ({
      x: pad.left + groupW * i + groupW / 2,
      y: typeof b.closing === "number" ? pad.top + chartH - ((b.closing - min) / (max - min)) * chartH : null,
    }));
    const drawn = pts.filter((p) => p.y !== null);

    const grad = ctx.createLinearGradient(0, pad.top, 0, pad.top + chartH);
    grad.addColorStop(0, "rgba(79,143,247,0.35)");
    grad.addColorStop(1, "rgba(79,143,247,0)");
    ctx.beginPath();
    drawn.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
    ctx.lineTo(drawn[drawn.length - 1].x, pad.top + chartH);
    ctx.lineTo(drawn[0].x, pad.top + chartH);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();

    ctx.beginPath();
    drawn.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
    ctx.strokeStyle = COLORS.line;
    ctx.lineWidth = 2.2;
    ctx.lineJoin = "round";
    ctx.stroke();

    if (hover !== undefined && hover !== null && pts[hover] && pts[hover].y !== null) {
      const p = pts[hover];
      ctx.strokeStyle = "rgba(255,255,255,0.15)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(p.x + 0.5, pad.top);
      ctx.lineTo(p.x + 0.5, pad.top + chartH);
      ctx.stroke();
      ctx.fillStyle = "#0e1420";
      ctx.strokeStyle = COLORS.line;
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.arc(p.x, p.y, 4.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
    }

    const labels = buckets.map((b) => (n <= 7 ? fmtWeekday(b.date) : fmtDay(b.date)));
    drawXLabels(ctx, labels, pad, h, groupW, Math.max(2, Math.floor(chartW / 54)));
  }

  function chartBuckets() {
    if (!state.visible || state.mode !== "bank") return null;
    if (state.tab === "dashboard") return computeStats(activeAccount(), 7).buckets;
    if (state.tab === "stats") return computeStats(getAccount(state.statsAccountId) || activeAccount(), state.statsPeriod).buckets;
    return null;
  }

  function drawCharts() {
    const buckets = chartBuckets();
    if (!buckets) return;
    const dash = document.getElementById("dash-chart");
    if (dash) drawFlowChart(dash, buckets);
    const flow = document.getElementById("stats-flow");
    if (flow) drawFlowChart(flow, buckets);
    const bal = document.getElementById("stats-balance");
    if (bal) drawBalanceChart(bal, buckets);
  }

  function onChartMove(e) {
    const canvas = e.target;
    const chart = canvas._chart;
    if (!chart) return;
    const rect = canvas.getBoundingClientRect();
    const idx = Math.floor((e.clientX - rect.left - chart.left) / chart.groupW);
    if (idx < 0 || idx >= chart.n) return onChartLeave(e);
    if (canvas._hover !== idx) {
      canvas._hover = idx;
      (chart.kind === "flow" ? drawFlowChart : drawBalanceChart)(canvas, chart.buckets, idx);
    }
    const b = chart.buckets[idx];
    const date = `${fmtWeekday(b.date)} ${fmtDay(b.date)}`;
    const html =
      chart.kind === "flow"
        ? `<b>${esc(date)}</b>
           <div><i class="dot in"></i>${esc(t("money_in", "Money in"))}<span>${money(b.in)}</span></div>
           <div><i class="dot out"></i>${esc(t("money_out", "Money out"))}<span>${money(b.out)}</span></div>
           <div class="sep">${esc(t("net", "Net"))}<span class="${b.net >= 0 ? "pos" : "neg"}">${b.net >= 0 ? "+" : "-"}${money(Math.abs(b.net))}</span></div>`
        : `<b>${esc(date)}</b><div><i class="dot line"></i>${esc(t("closing", "Closing balance"))}<span>${b.closing === null ? "—" : money(b.closing)}</span></div>`;
    showTooltip(html, e.clientX, e.clientY);
  }

  function onChartLeave(e) {
    const canvas = e.target;
    hideTooltip();
    if (canvas._chart && canvas._hover !== null && canvas._hover !== undefined) {
      canvas._hover = null;
      (canvas._chart.kind === "flow" ? drawFlowChart : drawBalanceChart)(canvas, canvas._chart.buckets);
    }
  }

  /* ---------------------------------------------------------------------
     Event delegation (bound once)
  --------------------------------------------------------------------- */
  function bindEvents() {
    appRoot.addEventListener("click", (e) => {
      const el = (sel) => e.target.closest(sel);
      let b;

      if (el("#closeBtn")) return closeInterface();
      if ((b = el("[data-tab]"))) {
        if (state.tab !== b.dataset.tab) {
          state.tab = b.dataset.tab;
          state.txSearch = "";
          state.txFilter = "all";
          state.openTx = null;
          render();
        }
        return;
      }
      if ((b = el("[data-money]"))) return moneyAction(b.dataset.money, b.dataset.account);
      if ((b = el("[data-copy]"))) {
        setClipboard(b.dataset.copy);
        b.classList.add("copied");
        setTimeout(() => b.classList.remove("copied"), 1000);
        return toast(t("copied", "Copied to clipboard!"), "success");
      }
      if ((b = el("[data-filter]"))) {
        state.txFilter = b.dataset.filter;
        return render();
      }
      if ((b = el("[data-tx]"))) {
        state.openTx = state.openTx === b.dataset.tx ? null : b.dataset.tx;
        b.classList.toggle("open", state.openTx === b.dataset.tx);
        document.querySelectorAll(".tx-row.open").forEach((row) => {
          if (row !== b) row.classList.remove("open");
        });
        return;
      }
      if ((b = el("[data-select-account]"))) {
        if (state.accSelectedId !== b.dataset.selectAccount) {
          state.accSelectedId = b.dataset.selectAccount;
          state.txSearch = "";
          state.txFilter = "all";
          state.openTx = null;
          render();
        }
        return;
      }
      if ((b = el("[data-subtab]"))) {
        state.accSubtab = b.dataset.subtab;
        state.txSearch = "";
        return render();
      }
      if (el("#newAccountBtn")) return newAccountMenu();
      if ((b = el("[data-acc-action]"))) return accountAction(b.dataset.accAction, b.dataset.account, b.dataset.cid);
      if ((b = el("[data-card-action]"))) return cardAction(b.dataset.cardAction, b.dataset.account);
      if ((b = el("[data-period]"))) {
        state.statsPeriod = Number(b.dataset.period) || 0;
        return render();
      }
      if ((b = el("[data-export]"))) {
        const scope = b.dataset.export;
        if (scope === "stats") return exportStats();
        return exportTransactions(scope === "acc" ? getAccount(state.accSelectedId) : activeAccount());
      }
      if ((b = el("[data-atm-card]"))) return selectAtmCard(b.dataset.atmCard);
      if ((b = el("[data-atm-quick]"))) {
        const acc = state.accounts[0];
        if (acc) run("withdraw", { fromAccount: acc.id, amount: Number(b.dataset.atmQuick), comment: "" });
        return;
      }
      if ((b = el("[data-atm]"))) {
        if (b.dataset.atm === "eject") return closeInterface();
        if (b.dataset.atm === "back") {
          state.atm.step = "cards";
          state.atm.error = "";
          return render();
        }
      }
    });

    appRoot.addEventListener("input", (e) => {
      const kind = e.target.dataset && e.target.dataset.search;
      if (kind === "tx") {
        state.txSearch = e.target.value;
        if (state.tab === "dashboard") updateTxPanel("dash", activeAccount());
        else updateTxPanel("acc", getAccount(state.accSelectedId));
      } else if (kind === "acc") {
        state.accSearch = e.target.value;
        updateAccounts();
      }
    });

    appRoot.addEventListener("change", (e) => {
      if (e.target.id === "dash-account-select") {
        state.activeId = e.target.value;
        state.txSearch = "";
        state.openTx = null;
        const search = document.querySelector('[data-search="tx"]');
        if (search) search.value = "";
        render();
      } else if (e.target.id === "stats-account-select") {
        state.statsAccountId = e.target.value;
        render();
      }
    });

    appRoot.addEventListener("mousemove", (e) => {
      if (e.target.tagName === "CANVAS") onChartMove(e);
    });
    appRoot.addEventListener(
      "mouseleave",
      (e) => {
        if (e.target.tagName === "CANVAS") onChartLeave(e);
      },
      true
    );
  }

  /* ---------------------------------------------------------------------
     Browser preview mock (only used when index.html is opened outside FiveM)
  --------------------------------------------------------------------- */
  const mockDb = { accounts: [], cash: 4200 };

  function mockPayload() {
    return JSON.parse(
      JSON.stringify({
        accounts: mockDb.accounts,
        cash: mockDb.cash,
        costs: { pin: 5000, replace: 2500, shared: 0, personal: [2500, 5000], maxCard: 50000 },
      })
    );
  }

  function mockTx(acc, type, amount, title, other, message) {
    acc.amount += type === "withdraw" ? -amount : amount;
    acc.transactions.unshift({
      trans_id: Math.random().toString(16).slice(2, 10),
      title,
      trans_type: type,
      receiver: type === "withdraw" ? other : acc.name,
      issuer: type === "withdraw" ? acc.name : other,
      amount,
      message: message || "",
      time: "A few seconds ago",
      timestamp: Math.floor(Date.now() / 1000),
      balance: acc.amount,
    });
  }

  function mockFetchNui(eventName, data) {
    return new Promise((resolve) => {
      setTimeout(() => {
        const acc = mockDb.accounts.find((a) => a.id === (data.fromAccount || data.account));
        switch (eventName) {
          case "closeInterface":
            setTimeout(() => window.postMessage({ action: "open", tab: state.tab, data: mockPayload() }, "*"), 1200);
            return resolve("ok");
          case "deposit":
            if (data.amount > mockDb.cash) return resolve(toast("You don't have enough cash on you.", "error") || false);
            mockDb.cash -= data.amount;
            mockTx(acc, "deposit", data.amount, `Personal Account / ${acc.id}`, "John Doe", data.comment);
            toast(`Deposited ${money(data.amount)}.`, "success");
            return resolve(mockPayload());
          case "withdraw":
            if (data.amount > acc.amount) return resolve(toast("Account does not have enough funds!", "error") || false);
            mockDb.cash += data.amount;
            mockTx(acc, "withdraw", data.amount, `Personal Account / ${acc.id}`, "John Doe", data.comment);
            toast(`Withdrew ${money(data.amount)}.`, "success");
            return resolve(state.mode === "atm" ? { ...mockPayload(), accounts: [mockPayload().accounts[0]], atm: true } : mockPayload());
          case "transfer":
            if (data.amount > acc.amount) return resolve(toast("Account does not have enough funds!", "error") || false);
            mockTx(acc, "withdraw", data.amount, `Transfer / ${data.stateid}`, data.stateid, data.comment);
            toast(`Sent ${money(data.amount)} to ${data.stateid}.`, "success");
            return resolve(mockPayload());
          case "toggleFreeze":
            acc.isFrozen = !acc.isFrozen;
            return resolve(mockPayload());
          case "setCardPin":
            acc.cardPin = true;
            toast("The PIN of your card was updated.", "success");
            return resolve(mockPayload());
          case "loadCard":
            acc.cardBalance += data.amount;
            mockTx(acc, "withdraw", data.amount, "Card Top-Up", "CARD");
            return resolve(mockPayload());
          case "unloadCard":
            mockTx(acc, "deposit", acc.cardBalance, "Card Unload", "CARD");
            acc.cardBalance = 0;
            return resolve(mockPayload());
          case "requestCard":
            acc.cardPending = true;
            acc.cardReadyIn = 10;
            return resolve(mockPayload());
          case "replaceCard":
            acc.hasCard = false;
            acc.cardPending = true;
            acc.cardReadyIn = 10;
            acc.cardPin = false;
            return resolve(mockPayload());
          case "getMembers":
          case "addMember":
          case "removeMember":
            return resolve({
              members: [
                { cid: "ABC12345", name: "John Doe", creator: true },
                { cid: "XYZ98765", name: "Jane Smith", creator: false },
              ],
            });
          case "createShared":
            mockDb.accounts.push({ id: data.name.toLowerCase(), type: "Shared", name: data.name.toLowerCase(), amount: 0, iban: "S" + Math.floor(Math.random() * 1e9), shared: true, isCreator: true, transactions: [] });
            return resolve(mockPayload());
          case "atmInsertCard": {
            if (data.slot === 2 && data.pin !== "1234") {
              return resolve(data.pin ? { error: "Incorrect PIN.", attemptsLeft: 2, needPin: true } : { needPin: true });
            }
            const p = mockPayload();
            p.accounts = [p.accounts[0]];
            p.atm = true;
            p.restricted = data.slot !== 2;
            return resolve(p);
          }
          default:
            resolve(false);
        }
      }, 350);
    });
  }

  function loadMockData() {
    const now = Math.floor(Date.now() / 1000);
    let seed = 7;
    const rand = () => ((seed = (seed * 9301 + 49297) % 233280) / 233280);
    const makeTxs = (start, count, spanDays) => {
      let bal = start;
      const list = [];
      for (let i = 0; i < count; i++) {
        const ts = now - Math.floor(spanDays * 86400 * (1 - i / count)) + Math.floor(rand() * 3600);
        const out = rand() > 0.5;
        const amount = Math.floor(100 + rand() * (out ? 2400 : 3000));
        bal += out ? -amount : amount;
        list.unshift({
          trans_id: `${i}-${Math.floor(rand() * 1e6).toString(16)}`,
          title: out ? ["Withdrawal", "Transfer / Jane Doe", "Card Top-Up"][i % 3] : ["Paycheck", "Deposit", "Transfer / Mike Ross"][i % 3],
          trans_type: out ? "withdraw" : "deposit",
          receiver: out ? ["Cash", "Jane Doe", "CARD"][i % 3] : "John Doe",
          issuer: out ? "John Doe" : ["Los Santos PD", "John Doe", "Mike Ross"][i % 3],
          amount,
          message: i % 4 === 0 ? "Rent" : "",
          timestamp: ts,
          time: `${Math.max(1, Math.round((now - ts) / 86400))} days ago`,
          balance: bal,
        });
      }
      return { list, bal };
    };
    const main = makeTxs(15000, 60, 40);
    const police = makeTxs(80000, 18, 25);
    mockDb.accounts = [
      { id: "ABC12345", type: "Personal", name: "John Doe", amount: main.bal, iban: "B617521932", personal: true, isDefault: true, isCreator: true, canCard: true, hasCard: true, cardPin: true, cardOnYou: true, cardBalance: 1250, cardColor: "gold", transactions: main.list },
      { id: "ABC12345:2", type: "Personal", name: "Personal Account #2", amount: 3200, iban: "K552190113", personal: true, isCreator: true, canCard: true, hasCard: false, transactions: [] },
      { id: "police", type: "Organization", name: "Law Enforcement", amount: police.bal, iban: "B991244001", transactions: police.list },
      { id: "family_fund", type: "Shared", name: "family_fund", amount: 12750, iban: "S334412990", shared: true, isCreator: true, isFrozen: true, transactions: [] },
    ];
    state.translations = {};
    applyData(mockPayload());
    state.visible = true;
    state.mode = "bank";
  }

  /* ---------------------------------------------------------------------
     Boot
  --------------------------------------------------------------------- */
  document.addEventListener("DOMContentLoaded", () => {
    bindEvents();
    if (isEnvBrowser()) {
      loadMockData();
      // ?atm in the URL previews the ATM flow instead
      if (location.search.includes("atm")) {
        openAtm([
          { slot: 1, iban: "B617521932", holder: "John Doe", color: "gold", hasPin: false },
          { slot: 2, iban: "K552190113", holder: "John Doe", color: "purple", hasPin: true },
        ]);
        return;
      }
    }
    render();
  });
})();
