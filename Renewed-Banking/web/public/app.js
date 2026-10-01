/* =========================================================================
   Renewed-Banking NUI — hand-built, dependency-free (no build step needed)
   ========================================================================= */

(function () {
  "use strict";

  /* ---------------------------------------------------------------------
     Helpers
  --------------------------------------------------------------------- */
  const isEnvBrowser = () => !window.invokeNative;

  function getResourceName() {
    try {
      return window.GetParentResourceName ? window.GetParentResourceName() : "Renewed-Banking";
    } catch (e) {
      return "Renewed-Banking";
    }
  }

  async function fetchNui(eventName, data) {
    data = data || {};
    if (isEnvBrowser()) {
      return mockFetchNui(eventName, data);
    }
    try {
      const resp = await fetch(`https://${getResourceName()}/${eventName}`, {
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

  function formatMoney(number) {
    number = Number(number) || 0;
    return number.toLocaleString("en-US", { style: "currency", currency: "USD" });
  }

  function escapeHtml(str) {
    if (str === null || str === undefined) return "";
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function maskTail(id, keep) {
    id = String(id || "");
    keep = keep || 4;
    if (id.length <= keep) return id;
    return "•••• " + id.slice(-keep);
  }

  function t(key, fallback) {
    const parts = key.split(".");
    let cur = state.translations;
    for (const p of parts) {
      if (cur && typeof cur === "object" && p in cur) cur = cur[p];
      else return fallback;
    }
    return typeof cur === "string" ? cur : fallback;
  }

  function setClipboard(text) {
    function fallback() {
      const el = document.createElement("textarea");
      el.value = text;
      document.body.appendChild(el);
      el.select();
      try { document.execCommand("copy"); } catch (e2) { /* nothing more we can do */ }
      document.body.removeChild(el);
    }
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).catch(fallback);
      } else {
        fallback();
      }
    } catch (e) {
      fallback();
    }
  }

  function convertToCSV(transactions) {
    if (!transactions || !transactions.length) return "";
    const header = ["trans_id", "title", "trans_type", "receiver", "amount", "time", "issuer", "message"];
    const rows = transactions.map((tItem) => header.map((h) => JSON.stringify(tItem[h] ?? "")).join(","));
    return [header.join(","), ...rows].join("\n");
  }

  /* ---------------------------------------------------------------------
     State
  --------------------------------------------------------------------- */
  const state = {
    visible: false,
    loading: false,
    isAtm: false,
    accounts: [],
    activeAccountId: null,
    tab: "dashboard", // dashboard | accounts | cards
    translations: {},
    notifications: [],
    popup: null, // { actionType, account }
    accSearch: "",
    txSearch: "",
    accountsTabSelectedId: null,
    busyCardId: null,
  };

  function getAccount(id) {
    return state.accounts.find((a) => a.id === id) || null;
  }

  // Remembers each account's previous balance so we can play a little
  // pulse animation on the number whenever it changes after an action.
  const lastKnownBalances = {};

  function activeAccount() {
    return getAccount(state.activeAccountId) || state.accounts[0] || null;
  }

  /* ---------------------------------------------------------------------
     NUI message handling
  --------------------------------------------------------------------- */
  window.addEventListener("message", (event) => {
    const data = event.data || {};
    switch (data.action) {
      case "setLoading": {
        state.loading = !!data.status;
        render();
        break;
      }
      case "setVisible": {
        state.accounts = data.accounts || [];
        state.loading = !!data.loading;
        state.isAtm = !!data.atm;
        state.visible = !!data.status;
        state.activeAccountId = (data.focusAccount && getAccount(data.focusAccount) && data.focusAccount) ||
          (state.accounts[0] && state.accounts[0].id) || null;
        state.accountsTabSelectedId = state.activeAccountId;
        state.tab = data.focusTab || "dashboard";
        render();
        break;
      }
      case "notify": {
        pushNotification(data.status);
        break;
      }
      case "updateLocale": {
        state.translations = data.translations || {};
        render();
        break;
      }
    }
  });

  window.addEventListener("keydown", (e) => {
    if (state.visible && e.code === "Escape") {
      closeInterface();
    }
  });

  function closeInterface() {
    fetchNui("closeInterface");
    state.visible = false;
    state.popup = null;
    render();
  }

  function pushNotification(msg) {
    if (!msg) return;
    const id = Date.now() + Math.random();
    state.notifications.push({ id, msg });
    renderNotifications();
    setTimeout(() => {
      const el = document.querySelector(`[data-notify-id="${id}"]`);
      if (el) el.classList.add("leaving");
      setTimeout(() => {
        state.notifications = state.notifications.filter((n) => n.id !== id);
        renderNotifications();
      }, 220);
    }, 3500);
  }

  /* ---------------------------------------------------------------------
     Actions
  --------------------------------------------------------------------- */
  function openPopup(accountId, actionType) {
    const account = getAccount(accountId);
    if (!account) return;
    if (account.isFrozen) {
      pushNotification("This account is frozen.");
      return;
    }
    state.popup = { actionType, account };
    render();
  }

  function closePopup() {
    state.popup = null;
    render();
  }

  async function submitPopup(formEl) {
    if (!state.popup) return;
    const amount = Number(formEl.querySelector('[name="amount"]').value) || 0;
    const comment = formEl.querySelector('[name="comment"]').value || "";
    const stateidEl = formEl.querySelector('[name="stateId"]');
    const stateid = stateidEl ? stateidEl.value || "" : "";
    const actionType = state.popup.actionType;
    const fromAccount = state.popup.account.id;

    closePopup();
    state.loading = true;
    render();

    const result = await fetchNui(actionType, { fromAccount, amount, comment, stateid });

    state.loading = false;
    if (result) {
      state.accounts = result;
      if (!getAccount(state.activeAccountId)) {
        state.activeAccountId = state.accounts[0] && state.accounts[0].id;
      }
    }
    render();
  }

  async function toggleFreeze(accountId) {
    state.busyCardId = accountId;
    render();
    const result = await fetchNui("toggleFreeze", { account: accountId });
    state.busyCardId = null;
    if (result) {
      state.accounts = result;
    }
    render();
  }

  async function requestCard() {
    state.loading = true;
    render();
    const result = await fetchNui("requestCard", {});
    state.loading = false;
    if (result) {
      state.accounts = result;
      pushNotification("A new bank card has been issued to your inventory.");
    }
    render();
  }

  async function openNewAccount() {
    state.loading = true;
    render();
    const result = await fetchNui("openAccount", {});
    state.loading = false;
    if (result) {
      state.accounts = result;
      pushNotification("New account opened.");
    }
    render();
  }

  async function closeAccountTab(accountId) {
    state.busyCardId = accountId;
    render();
    const result = await fetchNui("closeAccount", { fromAccount: accountId });
    state.busyCardId = null;
    if (result) {
      state.accounts = result;
      state.accountsTabSelectedId = result[0] && result[0].id;
      pushNotification("Account closed.");
    }
    render();
  }

  async function requestCardForAccount(accountId) {
    state.busyCardId = accountId;
    render();
    const result = await fetchNui("requestCardForAccount", { fromAccount: accountId });
    state.busyCardId = null;
    if (result) {
      state.accounts = result;
      pushNotification("Card issued.");
    }
    render();
  }

  async function setCardPinTab(accountId) {
    const pin = window.prompt("Enter a new 4-digit PIN for this card:");
    if (!pin) return;
    state.busyCardId = accountId;
    render();
    const result = await fetchNui("setCardPinTab", { fromAccount: accountId, pin });
    state.busyCardId = null;
    if (result) {
      state.accounts = result;
      pushNotification("PIN set on your card.");
    }
    render();
  }

  async function replaceCardTab(accountId) {
    if (!window.confirm("Report this card lost/stolen and pay $2,500 for a replacement? The old card will stop working.")) return;
    state.busyCardId = accountId;
    render();
    const result = await fetchNui("replaceCardTab", { fromAccount: accountId });
    state.busyCardId = null;
    if (result) {
      state.accounts = result;
      pushNotification("Old card deactivated, new one issued.");
    }
    render();
  }

  async function unloadCardTab(accountId) {
    state.busyCardId = accountId;
    render();
    const result = await fetchNui("unloadCardTab", { fromAccount: accountId });
    state.busyCardId = null;
    if (result) {
      state.accounts = result;
      pushNotification("Card balance unloaded into the account.");
    }
    render();
  }

  function copyToClipboard(text, btnEl) {
    setClipboard(text);
    if (btnEl) {
      btnEl.classList.add("copied");
      const icon = btnEl.querySelector("i");
      const original = icon ? icon.className : null;
      if (icon) icon.className = "fa-solid fa-check";
      setTimeout(() => {
        btnEl.classList.remove("copied");
        if (icon && original) icon.className = original;
      }, 1200);
    }
    pushNotification("Copied to clipboard!");
  }

  function handleExport(account) {
    if (!account || !account.transactions || !account.transactions.length) {
      pushNotification("No transactions to export!");
      return;
    }
    setClipboard(convertToCSV(account.transactions));
    pushNotification("Data copied to clipboard!");
  }

  /* ---------------------------------------------------------------------
     Rendering
     ---------------------------------------------------------------------
     The panel/backdrop/header are built ONCE and kept alive across
     re-renders (a persistent "shell"), so the pop-in animation only plays
     when the interface actually opens or switches bank<->atm mode - not
     on every click. Within a tab, list rows (transactions/accounts/cards)
     are reconciled by id instead of being torn down and rebuilt, so their
     staggered fade-in only plays for rows that are genuinely new, not on
     every keystroke while searching.
  --------------------------------------------------------------------- */
  const root = document.getElementById("app");

  let mounted = false;
  let currentMode = null; // "bank" | "atm" - drives the persistent shell
  let headerMode = null; // last mode the header HTML was built for
  let mainKey = null; // "mode:tab" - last structural key #bank-main was built for

  function render() {
    if (!state.visible) {
      if (mounted) {
        root.innerHTML = "";
        mounted = false;
        currentMode = null;
        headerMode = null;
        mainKey = null;
      }
      renderNotifications();
      renderLoadingStandalone();
      return;
    }

    const mode = state.isAtm ? "atm" : "bank";

    if (!mounted || mode !== currentMode) {
      root.innerHTML = `
        <div id="bank-overlay">
          <div class="backdrop"></div>
          <div class="bank-panel" data-mode="${mode}">
            <header class="bank-header" id="bank-header"></header>
            ${mode === "bank" ? '<div class="breadcrumb" id="bank-breadcrumb"></div>' : ""}
            <main id="bank-main"></main>
          </div>
        </div>
      `;
      mounted = true;
      currentMode = mode;
      headerMode = null;
      mainKey = null;
    }

    updateHeader(mode);
    if (mode === "bank") updateBreadcrumb();
    updateMain(mode);

    renderNotifications();
    renderPopup();
    renderLoadingStandalone();
    flashBalanceIfChanged();

    if (!state.isAtm && state.tab === "dashboard") {
      drawChart();
    }
  }

  // Plays a quick green/red pulse on the visible balance number whenever
  // the underlying account balance has actually changed since last render.
  function flashBalanceIfChanged() {
    const acc = activeAccount();
    const el = document.getElementById("balance-value");
    if (!acc || !el) return;
    const prev = lastKnownBalances[acc.id];
    if (prev !== undefined && prev !== acc.amount) {
      el.classList.remove("bump-up", "bump-down");
      // force reflow so the animation restarts if triggered twice quickly
      void el.offsetWidth;
      el.classList.add(acc.amount > prev ? "bump-up" : "bump-down");
    }
    lastKnownBalances[acc.id] = acc.amount;
  }

  /* ---- Header (persistent - rebuilt only when bank<->atm mode changes) ---- */
  function updateHeader(mode) {
    const header = document.getElementById("bank-header");
    if (!header) return;
    if (mode !== headerMode) {
      header.innerHTML = renderHeader(mode);
      headerMode = mode;
    }
    if (mode === "bank") {
      header.querySelectorAll(".tab").forEach((btn) => {
        // toggling the class (rather than rebuilding the button) is what
        // lets the tabPop animation play only when a tab actually becomes
        // active, instead of on every unrelated re-render.
        btn.classList.toggle("active", btn.dataset.tab === state.tab);
      });
    }
  }

  function renderHeader(mode) {
    const bankName = t("ui.bank_name", "City Banking");
    if (mode === "atm") {
      return `
        <div class="brand"><i class="fa-solid fa-building-columns"></i><span>ATM</span></div>
        <div class="header-spacer"></div>
        <button class="close-btn" id="closeBtn"><i class="fa-solid fa-xmark"></i></button>
      `;
    }
    const tabs = [
      { id: "dashboard", label: t("ui.dashboard", "Dashboard"), icon: "fa-table-columns" },
      { id: "accounts", label: t("ui.accounts", "Accounts"), icon: "fa-user" },
      { id: "cards", label: "Cards", icon: "fa-credit-card" },
    ];
    return `
      <div class="brand"><i class="fa-solid fa-building-columns"></i><span>${escapeHtml(bankName)}</span></div>
      <nav class="tabs">
        ${tabs
          .map(
            (tab) => `
          <button class="tab ${state.tab === tab.id ? "active" : ""}" data-tab="${tab.id}">
            <i class="fa-solid ${tab.icon}"></i>${escapeHtml(tab.label)}
          </button>
        `
          )
          .join("")}
      </nav>
      <div class="header-spacer"></div>
      <button class="close-btn" id="closeBtn"><i class="fa-solid fa-xmark"></i></button>
    `;
  }

  /* ---- Breadcrumb (cheap - no entrance animation, safe to refresh) ---- */
  function updateBreadcrumb() {
    const el = document.getElementById("bank-breadcrumb");
    if (el) el.innerHTML = renderBreadcrumb();
  }

  function renderBreadcrumb() {
    const acc = activeAccount();
    const tabLabels = { dashboard: "Dashboard", accounts: "Accounts", cards: "Cards" };
    return `
      <span>${escapeHtml(t("ui.bank_name", "City Banking"))}</span>
      <i class="fa-solid fa-chevron-right"></i>
      <span>${tabLabels[state.tab]}</span>
      ${
        acc && state.tab !== "cards"
          ? `<i class="fa-solid fa-chevron-right"></i><span class="crumb-current">${escapeHtml(acc.name)}</span>`
          : ""
      }
    `;
  }

  /* ---- Main content ----
     A full rebuild (with the .view pop/fade entrance) only happens when
     the mode or tab actually changes. Everything else - searching,
     switching the selected account, a balance changing, freezing a card -
     goes through the matching refresh*() function below, which patches
     text in place and reconciles list rows by id instead of recreating
     the whole view. */
  function updateMain(mode) {
    const main = document.getElementById("bank-main");
    if (!main) return;

    const key = mode === "atm" ? "atm" : `bank:${state.tab}`;
    if (key !== mainKey) {
      main.innerHTML = mode === "atm" ? renderAtmView() : renderTabView();
      mainKey = key;
    }

    if (mode === "atm") {
      refreshAtm();
    } else if (state.tab === "accounts") {
      refreshAccountsView();
    } else if (state.tab === "cards") {
      refreshCardsView();
    } else {
      refreshDashboard();
    }
  }

  function renderTabView() {
    if (state.tab === "accounts") return renderAccountsView();
    if (state.tab === "cards") return renderCardsView();
    return renderDashboardView();
  }

  /* ---------------------------------------------------------------------
     Keyed list reconciliation
     Diffs `items` against the container's existing children (matched by
     data-key) instead of rebuilding it, so unchanged rows are never
     removed/recreated and never replay their entrance animation. Only
     rows that are genuinely new get `renderRowHTML` (and its animation);
     rows that already exist are patched in place via `updateNode`.
  --------------------------------------------------------------------- */
  function reconcileList(container, items, keyFn, renderRowHTML, updateNode, emptyHTML) {
    if (!container) return;

    if (!items.length) {
      if (container.dataset.state !== "empty") {
        container.innerHTML = emptyHTML;
        container.dataset.state = "empty";
      }
      return;
    }
    if (container.dataset.state === "empty") {
      container.innerHTML = "";
    }
    container.dataset.state = "list";

    const existing = new Map();
    Array.from(container.children).forEach((el) => existing.set(el.dataset.key, el));

    let anchor = container.firstChild;
    items.forEach((item, i) => {
      const key = String(keyFn(item));
      let el = existing.get(key);
      if (el) {
        existing.delete(key);
        updateNode(el, item, i);
        if (el !== anchor) container.insertBefore(el, anchor);
      } else {
        const tmp = document.createElement("div");
        tmp.innerHTML = renderRowHTML(item, i).trim();
        el = tmp.firstElementChild;
        el.dataset.key = key;
        container.insertBefore(el, anchor);
      }
      anchor = el.nextSibling;
    });

    existing.forEach((el) => el.remove());
  }

  /* ---- Dashboard tab ---- */
  function renderDashboardView() {
    const acc = activeAccount();
    if (!acc) {
      return `<div class="view empty-state"><i class="fa-solid fa-building-columns"></i><span>No accounts found</span></div>`;
    }

    return `
      <div class="view">
        ${renderAccountInfoCard(acc)}
        <div class="dash-grid">
          ${renderChartPanel(acc)}
          ${renderTransactionsPanel("dash", true)}
        </div>
      </div>
    `;
  }

  function refreshDashboard() {
    const acc = activeAccount();
    const infoCard = document.getElementById("acc-info-card");
    if (infoCard && acc) infoCard.outerHTML = renderAccountInfoCard(acc);
    if (acc) updateTransactionsList("dash", acc);
  }

  function renderAccountInfoCard(acc) {
    return `
      <section class="acc-info-card" id="acc-info-card">
        <div class="acc-info-top">
          <h3>${escapeHtml(t("ui.account_title_label", "Account information"))}</h3>
          <div class="balance-block">
            <div class="balance-label">${escapeHtml(t("ui.balance", "Current balance"))}</div>
            <div class="balance-value" id="balance-value">${formatMoney(acc.amount)}</div>
          </div>
        </div>
        <div class="acc-info-row">
          <div class="acc-select-wrap">
            <select id="accountSelect">
              ${state.accounts
                .map(
                  (a) =>
                    `<option value="${escapeHtml(a.id)}" ${a.id === acc.id ? "selected" : ""}>${escapeHtml(
                      a.name
                    )} ${maskTail(a.id)}</option>`
                )
                .join("")}
            </select>
            <i class="fa-solid fa-chevron-down"></i>
          </div>
          <div class="iban-box">
            <div>
              <span class="iban-label">IBAN</span>
              <span class="iban-value">${escapeHtml(acc.iban || acc.id)}</span>
            </div>
            <button class="icon-btn" data-copy="${escapeHtml(acc.iban || acc.id)}" title="Copy IBAN"><i class="fa-solid fa-copy"></i></button>
          </div>
          <div class="acc-actions">
            <button class="act-btn deposit" data-act="deposit" data-account="${escapeHtml(acc.id)}" ${
      acc.isFrozen ? "disabled" : ""
    }><i class="fa-solid fa-arrow-down-to-bracket"></i>${escapeHtml(t("ui.deposit_but", "Deposit"))}</button>
            <button class="act-btn transfer" data-act="transfer" data-account="${escapeHtml(acc.id)}" ${
      acc.isFrozen ? "disabled" : ""
    }><i class="fa-solid fa-right-left"></i>${escapeHtml(t("ui.transfer_but", "Transfer"))}</button>
            <button class="act-btn withdraw" data-act="withdraw" data-account="${escapeHtml(acc.id)}" ${
      acc.isFrozen ? "disabled" : ""
    }><i class="fa-solid fa-arrow-up-from-bracket"></i>${escapeHtml(t("ui.withdraw_but", "Withdraw"))}</button>
          </div>
        </div>
        ${
          acc.isFrozen
            ? `<div class="frozen-banner"><i class="fa-solid fa-lock"></i>${escapeHtml(
                t("ui.frozen", "This account is frozen — transactions are disabled")
              )}</div>`
            : ""
        }
      </section>
    `;
  }

  function renderChartPanel(acc) {
    const hasTx = acc.transactions && acc.transactions.length;
    return `
      <section class="panel">
        <div class="panel-head">
          <h4><i class="fa-solid fa-chart-simple"></i>${escapeHtml(t("ui.latest_transactions", "Latest Transactions"))}</h4>
          <span class="panel-sub">Last ${Math.min(7, (acc.transactions || []).length)} transactions</span>
        </div>
        <div class="legend">
          <span class="dep"><i></i>Deposits</span>
          <span class="wd"><i></i>Withdrawals</span>
        </div>
        <div class="chart-wrap">
          ${
            hasTx
              ? '<canvas id="txChart"></canvas>'
              : `<div class="chart-empty"><i class="fa-solid fa-chart-simple"></i><span>No transaction data yet</span></div>`
          }
        </div>
      </section>
    `;
  }

  // `scope` namespaces the DOM ids so the dashboard's transactions panel
  // and the accounts tab's transactions panel never collide (only one of
  // the two is ever mounted at a time, but this keeps things unambiguous).
  function renderTransactionsPanel(scope, withExport) {
    return `
      <section class="panel">
        <div class="panel-head">
          <h4><i class="fa-solid fa-receipt"></i>${escapeHtml(t("ui.recent_transactions", "Recent Transactions"))}</h4>
        </div>
        <div class="search-row">
          <div class="search-input-wrap">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="text" id="txSearchInput" placeholder="Search transactions..." value="${escapeHtml(state.txSearch)}" />
          </div>
        </div>
        <div class="result-count" id="tx-result-count"></div>
        <div class="tx-scroll" id="tx-scroll" data-scope="${scope}"></div>
        ${
          withExport && !state.isAtm
            ? `<div class="export-row"><button class="act-btn transfer" id="exportBtn"><i class="fa-solid fa-file-export"></i>${escapeHtml(
                t("ui.export_data", "Export Transaction Data")
              )}</button></div>`
            : ""
        }
      </section>
    `;
  }

  function updateTransactionsList(scope, acc) {
    const container = document.getElementById("tx-scroll");
    if (!container || container.dataset.scope !== scope) return;

    const query = state.txSearch.toLowerCase();
    const all = acc.transactions || [];
    const filtered = all.filter((tItem) => {
      const hay = `${tItem.message || ""} ${tItem.trans_id || ""} ${tItem.receiver || ""} ${tItem.title || ""}`.toLowerCase();
      return hay.includes(query);
    });

    const countEl = document.getElementById("tx-result-count");
    if (countEl) countEl.textContent = `Showing ${filtered.length} of ${all.length} transactions`;

    reconcileList(
      container,
      filtered,
      (tItem) => tItem.trans_id,
      (tItem, i) => renderTxRow(tItem, i),
      (el, tItem) => updateTxRow(el, tItem),
      `<div class="empty-state"><i class="fa-solid fa-inbox"></i><span>No transactions found</span></div>`
    );
  }

  function renderTxRow(tItem, i) {
    const isWithdraw = tItem.trans_type === "withdraw";
    const icon = isWithdraw ? "fa-arrow-up" : "fa-arrow-down";
    const cls = isWithdraw ? "withdraw" : "deposit";
    return `
      <div class="tx-row" data-key="${escapeHtml(String(tItem.trans_id))}" style="animation-delay:${Math.min(i * 0.03, 0.4)}s">
        <div class="tx-icon ${cls}"><i class="fa-solid ${icon}"></i></div>
        <div class="tx-mid">
          <div class="tx-title">${escapeHtml(tItem.title)}</div>
          <div class="tx-sub">${escapeHtml(tItem.time)} • ${escapeHtml(tItem.receiver)}</div>
        </div>
        <div class="tx-amount ${cls}">${isWithdraw ? "-" : "+"}${formatMoney(tItem.amount)}</div>
      </div>
    `;
  }

  function updateTxRow(el, tItem) {
    const isWithdraw = tItem.trans_type === "withdraw";
    const icon = isWithdraw ? "fa-arrow-up" : "fa-arrow-down";
    const cls = isWithdraw ? "withdraw" : "deposit";
    el.querySelector(".tx-icon").className = `tx-icon ${cls}`;
    el.querySelector(".tx-icon i").className = `fa-solid ${icon}`;
    el.querySelector(".tx-title").textContent = tItem.title;
    el.querySelector(".tx-sub").textContent = `${tItem.time} • ${tItem.receiver}`;
    const amountEl = el.querySelector(".tx-amount");
    amountEl.className = `tx-amount ${cls}`;
    amountEl.textContent = `${isWithdraw ? "-" : "+"}${formatMoney(tItem.amount)}`;
  }

  /* ---- Accounts tab ---- */
  function renderAccountsView() {
    return `
      <div class="view accounts-view-grid">
        <div class="accounts-col">
          <div class="search-row">
            <div class="search-input-wrap">
              <i class="fa-solid fa-magnifying-glass"></i>
              <input type="text" id="accSearchInput" placeholder="Account search..." value="${escapeHtml(state.accSearch)}" />
            </div>
            <button id="newAccountBtn" class="icon-btn" title="Open New Account"><i class="fa-solid fa-plus"></i></button>
          </div>
          <div class="acc-list" id="acc-list"></div>
        </div>
        <div class="accounts-col" id="accounts-tx-col"></div>
      </div>
    `;
  }

  function refreshAccountsView() {
    const accSearch = state.accSearch.toLowerCase();
    const list = state.accounts.filter((a) => a.name.toLowerCase().includes(accSearch));
    const selectedId = state.accountsTabSelectedId || (state.accounts[0] && state.accounts[0].id);
    const selected = getAccount(selectedId);

    const listEl = document.getElementById("acc-list");
    reconcileList(
      listEl,
      list,
      (a) => a.id,
      (a, i) => renderAccCard(a, i, selectedId),
      (el, a) => updateAccCard(el, a, selectedId),
      `<div class="empty-state"><i class="fa-solid fa-magnifying-glass"></i><span>No accounts found</span></div>`
    );

    const txCol = document.getElementById("accounts-tx-col");
    if (!txCol) return;
    if (!selected) {
      if (txCol.dataset.key !== "empty") {
        txCol.innerHTML = `<div class="empty-state"><i class="fa-solid fa-hand-pointer"></i><span>Select an account</span></div>`;
        txCol.dataset.key = "empty";
      }
      return;
    }
    if (txCol.dataset.key !== selected.id) {
      txCol.innerHTML = renderTransactionsPanel("accounts", true);
      txCol.dataset.key = selected.id;
    }
    updateTransactionsList("accounts", selected);
  }

  function renderAccCard(a, i, selectedId) {
    return `
      <div class="acc-card ${a.id === selectedId ? "active" : ""} ${a.isFrozen ? "frozen" : ""}" data-key="${escapeHtml(
      a.id
    )}" data-select-account="${escapeHtml(a.id)}" style="animation-delay:${Math.min(i * 0.04, 0.4)}s">
        <div class="acc-card-top">
          <span class="acc-card-type">${escapeHtml(a.type)} ${maskTail(a.id)}</span>
          ${a.isFrozen ? '<span class="frozen-tag">Frozen</span>' : ""}
          ${
            a.personal
              ? `<button class="icon-btn acc-close-btn" data-close-account="${escapeHtml(a.id)}" title="Close Account"><i class="fa-solid fa-xmark"></i></button>`
              : ""
          }
        </div>
        <div class="acc-card-name">${escapeHtml(a.name)}</div>
        <div class="acc-card-amt">${formatMoney(a.amount)}</div>
      </div>
    `;
  }

  function updateAccCard(el, a, selectedId) {
    const isActive = a.id === selectedId;
    // only add the class (and its cardSelect pop) when it's newly selected
    if (isActive && !el.classList.contains("active")) el.classList.add("active");
    else if (!isActive) el.classList.remove("active");
    el.classList.toggle("frozen", !!a.isFrozen);
    el.querySelector(".acc-card-name").textContent = a.name;
    el.querySelector(".acc-card-amt").textContent = formatMoney(a.amount);
    const frozenTag = el.querySelector(".frozen-tag");
    if (a.isFrozen && !frozenTag) {
      el.querySelector(".acc-card-top").insertAdjacentHTML("beforeend", '<span class="frozen-tag">Frozen</span>');
    } else if (!a.isFrozen && frozenTag) {
      frozenTag.remove();
    }
  }

  /* ---- Cards tab ---- */
  function renderCardsView() {
    return `<div class="view"><div class="cards-grid" id="cards-grid"></div></div>`;
  }

  function refreshCardsView() {
    const grid = document.getElementById("cards-grid");
    if (!grid) return;
    const withCard = state.accounts.filter((a) => a.hasCard);
    const withoutCard = state.isAtm ? [] : state.accounts.filter((a) => !a.hasCard);

    reconcileList(grid, withCard, (a) => a.id, (a, i) => renderCardTile(a, i), (el, a) => updateCardTile(el, a), "");

    // "request a card" tiles for any account that doesn't have one yet
    grid.querySelectorAll(".request-card-tile").forEach((el) => {
      if (!withoutCard.find((a) => a.id === el.dataset.key)) el.remove();
    });
    withoutCard.forEach((a) => {
      if (grid.querySelector(`.request-card-tile[data-key="${a.id}"]`)) return;
      grid.insertAdjacentHTML(
        "beforeend",
        `<div class="request-card-tile" data-key="${escapeHtml(a.id)}">
          <i class="fa-solid fa-credit-card"></i>
          <b>${escapeHtml(a.name)}</b>
          <span>No card issued for this account yet.</span>
          <button class="act-btn" data-request-card="${escapeHtml(a.id)}">Request Card</button>
        </div>`
      );
    });
    if (!withCard.length && !withoutCard.length) {
      grid.innerHTML = `<div class="empty-state"><i class="fa-solid fa-credit-card"></i><span>No accounts yet</span></div>`;
    }
  }

  function renderCardTile(acc, i) {
    const isOrg = acc.type !== t("ui.personal", "Personal");
    const frozen = !!acc.isFrozen;
    const isBusy = state.busyCardId === acc.id;
    const iban = acc.iban || acc.id;
    const masked = iban.length > 4 ? `•••• •••• •••• ${iban.slice(-4)}` : iban;

    return `
      <div class="card-tile" data-key="${escapeHtml(acc.id)}">
        <div class="credit-card ${isOrg ? "org" : ""} ${frozen ? "frozen-card" : ""}" style="animation-delay:${Math.min(
      i * 0.05,
      0.4
    )}s">
          <div class="card-glow"></div>
          <div class="card-top-row">
            <div class="card-chip"></div>
            <div class="card-issuer">
              <span class="card-brand">${escapeHtml(t("ui.bank_name", "City Banking"))}</span>
              <span class="card-network">VISA</span>
            </div>
          </div>
          <div class="card-number">${escapeHtml(masked)}</div>
          <div class="card-bottom-row">
            <div>
              <div class="card-holder-label">Card Holder</div>
              <div class="card-holder">${escapeHtml(acc.name)}</div>
            </div>
            <div>
              <div class="card-type-label">IBAN</div>
              <div class="card-type">${escapeHtml(iban)}</div>
            </div>
          </div>
        </div>
        ${
          !state.isAtm
            ? `<div class="card-actions">
                <button class="card-freeze-btn ${frozen ? "is-frozen" : ""}" data-toggle-freeze="${escapeHtml(acc.id)}" ${
                isBusy ? "disabled" : ""
              }>
                  <i class="fa-solid ${isBusy ? "fa-spinner fa-spin" : frozen ? "fa-lock" : "fa-lock-open"}"></i>
                  ${frozen ? "Unfreeze" : "Freeze"}
                </button>
                <button class="card-copy-btn" data-copy="${escapeHtml(iban)}" title="Copy IBAN"><i class="fa-solid fa-copy"></i></button>
              </div>
              <div class="card-actions card-actions-secondary">
                <button class="card-mini-btn" data-set-pin="${escapeHtml(acc.id)}" title="Set PIN ($5,000)"><i class="fa-solid fa-key"></i> PIN</button>
                <button class="card-mini-btn" data-unload-card="${escapeHtml(acc.id)}" title="Move card balance into this account"><i class="fa-solid fa-arrow-right-to-bracket"></i> Unload</button>
                <button class="card-mini-btn danger" data-replace-card="${escapeHtml(acc.id)}" title="Report lost/stolen ($2,500)"><i class="fa-solid fa-triangle-exclamation"></i> Lost/Stolen</button>
              </div>`
            : ""
        }
      </div>
    `;
  }

  function updateCardTile(el, acc) {
    const frozen = !!acc.isFrozen;
    const isBusy = state.busyCardId === acc.id;
    const card = el.querySelector(".credit-card");
    card.classList.toggle("frozen-card", frozen);
    const iban = acc.iban || acc.id;
    const masked = iban.length > 4 ? `•••• •••• •••• ${iban.slice(-4)}` : iban;
    el.querySelector(".card-number").textContent = masked;
    el.querySelector(".card-holder").textContent = acc.name;
    el.querySelector(".card-type").textContent = iban;

    const freezeBtn = el.querySelector(".card-freeze-btn");
    if (freezeBtn) {
      freezeBtn.classList.toggle("is-frozen", frozen);
      freezeBtn.disabled = isBusy;
      freezeBtn.dataset.toggleFreeze = acc.id;
      freezeBtn.querySelector("i").className = `fa-solid ${isBusy ? "fa-spinner fa-spin" : frozen ? "fa-lock" : "fa-lock-open"}`;
      freezeBtn.lastChild.textContent = frozen ? "Unfreeze" : "Freeze";
    }
    const copyBtn = el.querySelector(".card-copy-btn");
    if (copyBtn) copyBtn.dataset.copy = iban;
  }

  /* ---- ATM mode ---- */
  function renderAtmView() {
    const acc = state.accounts[0];
    if (!acc) {
      return `<div class="view empty-state"><i class="fa-solid fa-triangle-exclamation"></i><span>Unable to load account</span></div>`;
    }
    return `
      <div class="view atm-view">
        <div class="atm-hero">
          <i class="fa-solid fa-money-check-dollar"></i>
          <span class="balance-value" id="balance-value">${formatMoney(acc.amount)}</span>
          <div class="balance-label">${escapeHtml(t("ui.balance", "Available Balance"))}</div>
        </div>
        <div id="atm-status-block" style="display:flex;flex-direction:column;gap:1.1rem;"></div>
        <div>
          <div class="panel-head" style="margin-bottom:0.5rem;"><h4><i class="fa-solid fa-receipt"></i>Recent Activity</h4></div>
          <div class="atm-mini-list" id="atm-mini-list"></div>
        </div>
      </div>
    `;
  }

  function refreshAtm() {
    const acc = state.accounts[0];
    if (!acc) return;

    const statusBlock = document.getElementById("atm-status-block");
    if (statusBlock) {
      statusBlock.innerHTML = acc.isFrozen
        ? `<div class="frozen-banner"><i class="fa-solid fa-lock"></i>Your account is frozen</div>`
        : `<div class="atm-actions">
            <button class="act-btn deposit" data-act="deposit" data-account="${escapeHtml(acc.id)}"><i class="fa-solid fa-arrow-down-to-bracket"></i>${escapeHtml(
            t("ui.deposit_but", "Deposit")
          )}</button>
            <button class="act-btn withdraw" data-act="withdraw" data-account="${escapeHtml(acc.id)}"><i class="fa-solid fa-arrow-up-from-bracket"></i>${escapeHtml(
            t("ui.withdraw_but", "Withdraw")
          )}</button>
          </div>` +
          (acc.hasCard
            ? `<div class="atm-card-status"><i class="fa-solid fa-circle-check"></i>Bank card already issued</div>`
            : `<div class="atm-card-cta" id="requestCardBtn">
                <i class="fa-solid fa-credit-card"></i>
                <div><b>Request a bank card</b><span>Get a physical card linked to your account</span></div>
              </div>`);
    }

    const miniList = document.getElementById("atm-mini-list");
    const recent = (acc.transactions || []).slice(0, 5);
    reconcileList(
      miniList,
      recent,
      (tItem) => tItem.trans_id,
      (tItem, i) => renderTxRow(tItem, i),
      (el, tItem) => updateTxRow(el, tItem),
      `<div class="empty-state"><i class="fa-solid fa-inbox"></i><span>No recent activity</span></div>`
    );
  }

  /* ---- Popup ---- */
  function renderPopup() {
    const popupRoot = document.getElementById("popup-root");
    if (!state.popup) {
      popupRoot.innerHTML = "";
      return;
    }
    const { actionType, account } = state.popup;
    const titleMap = {
      deposit: { icon: "fa-arrow-down-to-bracket", label: t("ui.deposit_but", "Deposit") },
      withdraw: { icon: "fa-arrow-up-from-bracket", label: t("ui.withdraw_but", "Withdraw") },
      transfer: { icon: "fa-right-left", label: t("ui.transfer_but", "Transfer") },
    };
    const info = titleMap[actionType] || { icon: "fa-money-bill", label: actionType };

    popupRoot.innerHTML = `
      <div class="popup-backdrop" id="popupBackdrop"></div>
      <div class="popup-card">
        <h2><i class="fa-solid ${info.icon}"></i>${escapeHtml(info.label)} — ${escapeHtml(account.name)}</h2>
        <form id="popupForm">
          <div class="form-row">
            <label>${escapeHtml(t("ui.amount", "Amount"))}</label>
            <input type="number" name="amount" min="1" placeholder="$0.00" required autofocus />
          </div>
          <div class="form-row">
            <label>${escapeHtml(t("ui.comment", "Comment"))}</label>
            <input type="text" name="comment" placeholder="Optional note" />
          </div>
          ${
            actionType === "transfer"
              ? `<div class="form-row">
                  <label>${escapeHtml(t("ui.transfer", "Business or Citizen ID"))}</label>
                  <input type="text" name="stateId" placeholder="Recipient ID" required />
                </div>`
              : ""
          }
          <div class="popup-btns">
            <button type="button" class="btn-cancel" id="popupCancel">${escapeHtml(t("ui.cancel", "Cancel"))}</button>
            <button type="submit" class="btn-confirm">${escapeHtml(t("ui.confirm", "Confirm"))}</button>
          </div>
        </form>
      </div>
    `;

    document.getElementById("popupBackdrop").addEventListener("click", closePopup);
    document.getElementById("popupCancel").addEventListener("click", closePopup);
    document.getElementById("popupForm").addEventListener("submit", (e) => {
      e.preventDefault();
      submitPopup(e.target);
    });
  }

  /* ---- Notifications ---- */
  function renderNotifications() {
    const notifRoot = document.getElementById("notification-root");
    notifRoot.innerHTML = state.notifications
      .map(
        (n) => `
        <div class="notify-toast" data-notify-id="${n.id}">
          <i class="fa-solid fa-circle-info"></i>
          <span>${escapeHtml(n.msg)}</span>
        </div>
      `
      )
      .join("");
  }

  /* ---- Loading overlay ---- */
  function renderLoadingStandalone() {
    const loadingRoot = document.getElementById("loading-overlay");
    if (!state.loading) {
      loadingRoot.classList.add("hidden");
      loadingRoot.innerHTML = "";
      return;
    }
    loadingRoot.classList.remove("hidden");
    loadingRoot.innerHTML = `
      <div class="loading-card">
        <div class="spinner-ring"></div>
        <div class="loading-text" id="loadingText">${escapeHtml(loadingMessages[0])}</div>
        <div class="loading-bar"><div></div></div>
      </div>
    `;
    cycleLoadingText();
  }

  const loadingMessages = [
    "Connecting securely...",
    "Verifying credentials...",
    "Fetching account data...",
    "Almost there...",
  ];
  let loadingCycleTimer = null;
  function cycleLoadingText() {
    clearInterval(loadingCycleTimer);
    let idx = 0;
    loadingCycleTimer = setInterval(() => {
      idx = (idx + 1) % loadingMessages.length;
      const el = document.getElementById("loadingText");
      if (!el) {
        clearInterval(loadingCycleTimer);
        return;
      }
      el.style.opacity = 0;
      setTimeout(() => {
        el.textContent = loadingMessages[idx];
        el.style.opacity = 1;
      }, 150);
    }, 1400);
  }

  /* ---------------------------------------------------------------------
     Chart (canvas bar chart: deposits vs withdrawals)
  --------------------------------------------------------------------- */
  function drawChart() {
    const canvas = document.getElementById("txChart");
    if (!canvas) return;
    const acc = activeAccount();
    if (!acc) return;

    const txs = (acc.transactions || []).slice(0, 7).slice().reverse();
    if (!txs.length) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.parentElement.getBoundingClientRect();
    const width = Math.max(rect.width, 200);
    const height = Math.max(rect.height, 140);
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    const ctx = canvas.getContext("2d");
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, width, height);

    const maxVal = Math.max(1, ...txs.map((tx) => Number(tx.amount) || 0));
    const padding = { top: 10, right: 10, bottom: 26, left: 10 };
    const chartW = width - padding.left - padding.right;
    const chartH = height - padding.top - padding.bottom;
    const groupW = chartW / txs.length;
    const barW = Math.min(18, groupW * 0.28);

    // gridlines
    ctx.strokeStyle = "rgba(255,255,255,0.06)";
    ctx.lineWidth = 1;
    for (let g = 0; g <= 3; g++) {
      const y = padding.top + (chartH / 3) * g;
      ctx.beginPath();
      ctx.moveTo(padding.left, y);
      ctx.lineTo(width - padding.right, y);
      ctx.stroke();
    }

    txs.forEach((tx, i) => {
      const cx = padding.left + groupW * i + groupW / 2;
      const isWithdraw = tx.trans_type === "withdraw";
      const val = Number(tx.amount) || 0;
      const barH = (val / maxVal) * chartH;
      const y = padding.top + chartH - barH;

      ctx.fillStyle = isWithdraw ? "#f2554c" : "#4f8ff7";
      const barX = isWithdraw ? cx + 4 : cx - barW - 4;
      roundRect(ctx, barX, y, barW, barH, 4);
      ctx.fill();

      // label - split on words rather than a fixed char-slice, so distinct
      // time strings never collide into the same truncated label
      ctx.fillStyle = "rgba(255,255,255,0.35)";
      ctx.font = "10px Roboto, sans-serif";
      ctx.textAlign = "center";
      const words = String(tx.time || "").split(" ");
      const label = words.slice(0, 2).join(" ");
      ctx.fillText(label, cx, height - 8);
    });
  }

  function roundRect(ctx, x, y, w, h, r) {
    if (h < 0) { y += h; h = Math.abs(h); }
    h = Math.max(h, 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  /* ---------------------------------------------------------------------
     Event delegation
     All interaction is bound ONCE on the root container (rather than
     re-attaching listeners on every render) since the shell and list rows
     now persist across renders instead of being recreated.
  --------------------------------------------------------------------- */
  function bindDelegatedEvents() {
    root.addEventListener("click", (e) => {
      if (e.target.closest("#closeBtn")) return closeInterface();

      const tabBtn = e.target.closest(".tab");
      if (tabBtn) {
        state.tab = tabBtn.dataset.tab;
        render();
        return;
      }

      const actBtn = e.target.closest("[data-act]");
      if (actBtn) return openPopup(actBtn.dataset.account, actBtn.dataset.act);

      const copyBtn = e.target.closest("[data-copy]");
      if (copyBtn) return copyToClipboard(copyBtn.dataset.copy, copyBtn);

      const freezeBtn = e.target.closest("[data-toggle-freeze]");
      if (freezeBtn) return toggleFreeze(freezeBtn.dataset.toggleFreeze);

      const accCard = e.target.closest("[data-select-account]");
      if (accCard) {
        state.accountsTabSelectedId = accCard.dataset.selectAccount;
        state.txSearch = "";
        render();
        return;
      }

      if (e.target.closest("#requestCardBtn")) return requestCard();

      if (e.target.closest("#newAccountBtn")) return openNewAccount();

      const closeAccBtn = e.target.closest("[data-close-account]");
      if (closeAccBtn) {
        e.stopPropagation();
        return closeAccountTab(closeAccBtn.dataset.closeAccount);
      }

      const reqCardBtn = e.target.closest("[data-request-card]");
      if (reqCardBtn) return requestCardForAccount(reqCardBtn.dataset.requestCard);

      const pinBtn = e.target.closest("[data-set-pin]");
      if (pinBtn) return setCardPinTab(pinBtn.dataset.setPin);

      const replaceBtn = e.target.closest("[data-replace-card]");
      if (replaceBtn) return replaceCardTab(replaceBtn.dataset.replaceCard);

      const unloadBtn = e.target.closest("[data-unload-card]");
      if (unloadBtn) return unloadCardTab(unloadBtn.dataset.unloadCard);

      const exportBtn = e.target.closest("#exportBtn");
      if (exportBtn) {
        const acc = state.tab === "accounts" ? getAccount(state.accountsTabSelectedId) : activeAccount();
        return handleExport(acc);
      }
    });

    root.addEventListener("input", (e) => {
      if (e.target.id === "txSearchInput") {
        state.txSearch = e.target.value;
        render();
      } else if (e.target.id === "accSearchInput") {
        state.accSearch = e.target.value;
        render();
      }
    });

    root.addEventListener("change", (e) => {
      if (e.target.id === "accountSelect") {
        state.activeAccountId = e.target.value;
        state.txSearch = "";
        render();
      }
    });
  }

  /* ---------------------------------------------------------------------
     Browser preview mock (only used when opened outside FiveM)
  --------------------------------------------------------------------- */
  function mockFetchNui(eventName, data) {
    return new Promise((resolve) => {
      setTimeout(() => {
        if (eventName === "closeInterface") return resolve("ok");
        if (eventName === "toggleFreeze") {
          const acc = getAccount(data.account);
          if (acc) acc.isFrozen = !acc.isFrozen;
          return resolve(JSON.parse(JSON.stringify(state.accounts)));
        }
        if (eventName === "requestCard") {
          const acc = state.accounts[0];
          if (acc) acc.hasCard = true;
          return resolve(JSON.parse(JSON.stringify(state.accounts)));
        }
        if (["deposit", "withdraw", "transfer"].includes(eventName)) {
          const acc = getAccount(data.fromAccount);
          if (acc) {
            const amount = Number(data.amount) || 0;
            const isWithdraw = eventName === "withdraw" || eventName === "transfer";
            acc.amount += isWithdraw ? -amount : amount;
            acc.transactions.unshift({
              trans_id: Math.random().toString(16).slice(2, 10),
              title: eventName === "transfer" ? `Transfer / ${data.stateid || "?"}` : `Personal Account / ${acc.id}`,
              trans_type: isWithdraw ? "withdraw" : "deposit",
              receiver: data.stateid || acc.id,
              amount: amount,
              time: "Just now",
              issuer: acc.name,
              message: data.comment || "",
            });
          }
          return resolve(JSON.parse(JSON.stringify(state.accounts)));
        }
        resolve(false);
      }, 400);
    });
  }

  function loadMockData() {
    state.translations = {
      ui: {
        bank_name: "City Banking",
        dashboard: "Dashboard",
        accounts: "Accounts",
        personal: "Personal",
        balance: "Current balance",
        deposit_but: "Deposit",
        withdraw_but: "Withdraw",
        transfer_but: "Transfer",
        amount: "Amount",
        comment: "Comment",
        transfer: "Business or Citizen ID",
        cancel: "Cancel",
        confirm: "Confirm",
        export_data: "Export Transaction Data",
        latest_transactions: "Latest Transactions",
        recent_transactions: "Recent Transactions",
      },
    };
    state.accounts = [
      {
        id: "ABC12345",
        type: "Personal",
        name: "Main Account",
        amount: 19875,
        cash: 4200,
        iban: "B617521932",
        isFrozen: false,
        hasCard: true,
        transactions: [
          { trans_id: "1", title: "Transfer", trans_type: "withdraw", receiver: "police", amount: 126, time: "2025-10-26", issuer: "bank", message: "" },
          { trans_id: "2", title: "Withdrawal", trans_type: "withdraw", receiver: "cash", amount: 2337, time: "2025-10-26", issuer: "bank", message: "Rent" },
          { trans_id: "3", title: "Deposit", trans_type: "deposit", receiver: "bank", amount: 2602, time: "2025-10-26", issuer: "job", message: "Paycheck" },
          { trans_id: "4", title: "Deposit", trans_type: "deposit", receiver: "bank", amount: 1503, time: "2025-10-25", issuer: "job", message: "" },
          { trans_id: "5", title: "Withdrawal", trans_type: "withdraw", receiver: "cash", amount: 473, time: "2025-10-25", issuer: "bank", message: "" },
          { trans_id: "6", title: "Transfer", trans_type: "withdraw", receiver: "Jon Doe", amount: 862, time: "2025-10-25", issuer: "bank", message: "" },
          { trans_id: "7", title: "Transfer", trans_type: "withdraw", receiver: "Jane Doe", amount: 423, time: "2025-10-24", issuer: "bank", message: "" },
        ],
      },
      {
        id: "police",
        type: "Organization",
        name: "Law Enforcement",
        amount: 84250,
        iban: "B991244001",
        isFrozen: false,
        transactions: [
          { trans_id: "8", title: "Deposit", trans_type: "deposit", receiver: "police", amount: 5000, time: "2025-10-20", issuer: "city", message: "Budget" },
        ],
      },
      {
        id: "mechanic",
        type: "Organization",
        name: "Bennys Mechanics",
        amount: 12750,
        iban: "B334412990",
        isFrozen: true,
        transactions: [],
      },
    ];
    state.activeAccountId = state.accounts[0].id;
    state.accountsTabSelectedId = state.activeAccountId;
    state.visible = true;
    state.loading = false;
    state.isAtm = false;
  }

  /* ---------------------------------------------------------------------
     Boot
  --------------------------------------------------------------------- */
  document.addEventListener("DOMContentLoaded", () => {
    if (isEnvBrowser()) {
      loadMockData();
    }
    bindDelegatedEvents();
    render();
  });
})();
