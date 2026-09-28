(function () {
  'use strict';

  var RES = 'emotes';
  var CDN = 'https://assets.cylexdev.com/cylex_animmenuv2/animations/';

  var GAP = 11;          // grid gutter, keep in sync with .grid layout math
  var MIN_COL = 116;     // minimum tile width (tile height is measured from it)
  var OVERSCAN = 2;      // rows rendered above/below the viewport
  var SLOTS = 7;         // quick slots (LSHIFT + NUMPAD 1-7)
  var RECENT_MAX = 24;
  var SEARCH_DELAY = 120;
  var HIDE_IN_ALL = { expressions: true, walks: true };

  /* ============================================================
     ICONS - inline SVG, no Font Awesome / CDN needed
     ============================================================ */

  var PATHS = {
    home: '<path d="M3 10.2 12 3l9 7.2V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    star: '<path d="M12 3.6l2.6 5.3 5.9.8-4.3 4.1 1 5.8-5.2-2.8-5.2 2.8 1-5.8L3.5 9.7l5.9-.8z"/>',
    timer: '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 10v3.7l2.2 2M9.2 2.6h5.6M12 2.6v3.4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7.2V12l3.4 2"/>',
    person: '<circle cx="12" cy="5" r="2.6"/><path d="M12 7.8v7m0 0-2.6 6.2m2.6-6.2 2.6 6.2M7.8 11h8.4"/>',
    running: '<circle cx="15" cy="4.6" r="2.1"/><path d="m13.4 7.6-3.9 2.7 2.4 2.9-1.2 3.6-3.3 2.9M11.9 13.2l3.9 1.1 1.1 4.6M9.5 10.3 5.6 9.6"/>',
    walking: '<circle cx="13" cy="4.6" r="2.1"/><path d="m12.4 7.4-1.9 4.2 2.6 2.2.9 6.6M10.5 11.6 7.6 15l-.6 4.4M13 9.8l3.4 2.2 2.3-.6"/>',
    sparkles: '<path d="M9 3.5l1.5 4 4 1.5-4 1.5L9 14.5l-1.5-4-4-1.5 4-1.5z"/><path d="M17.5 13.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>',
    smile: '<circle cx="12" cy="12" r="9"/><path d="M8 14.4s1.5 2 4 2 4-2 4-2M8.6 9.6c.6-.7 1.4-.7 2 0M13.4 9.6c.6-.7 1.4-.7 2 0"/>',
    shield: '<path d="M12 3l7 2.4v6c0 4.2-2.9 8-7 9.6-4.1-1.6-7-5.4-7-9.6v-6z"/><path d="m12 8.4 1.1 2.3 2.5.4-1.8 1.7.4 2.5-2.2-1.2-2.2 1.2.4-2.5-1.8-1.7 2.5-.4z"/>',
    cube: '<path d="M12 2.8 20 7v10l-8 4.2L4 17V7z"/><path d="M4 7l8 4.2L20 7M12 11.2V21"/>',
    users: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-1.2C3 16.7 5.7 15 9 15s6 1.7 6 3.8V20M16 8.2a3 3 0 0 1 0 5.6M17.5 15.4c2 .5 3.5 1.8 3.5 3.4V20"/>',
    search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m20 20-4.9-4.9"/>',
    move: '<path d="M12 3v18M3 12h18"/><path d="m9 6 3-3 3 3M9 18l3 3 3-3M6 9l-3 3 3 3M18 9l3 3-3 3"/>',
    cursor: '<path d="M5.5 3.2 19 12.4l-5.9.6-2.3 5.4z"/>',
    ban: '<circle cx="12" cy="12" r="9"/><path d="m6.4 17.6 11.2-11.2"/>',
    chevrons: '<path d="m11 6-6 6 6 6M18 6l-6 6 6 6"/>',
    xmark: '<path d="M6 6l12 12M18 6 6 18"/>',
    flag: '<path d="M5 21V4M5 4.6h11l-1.6 3.6L16 12H5"/>',
    heart: '<path d="M12 20.2 4.9 13a4.5 4.5 0 0 1 7.1-5.4A4.5 4.5 0 0 1 19.1 13z"/>',
    music: '<circle cx="7" cy="18" r="2.6"/><circle cx="17.4" cy="15.6" r="2.6"/><path d="M9.6 18V7.6L20 5.3v10.3"/>',
    paw: '<circle cx="8" cy="9" r="1.8"/><circle cx="12" cy="7.2" r="1.8"/><circle cx="16" cy="9" r="1.8"/><path d="M12 11.6c2.6 0 4.6 1.9 4.6 4.1 0 1.7-1.4 3-3.1 3h-3c-1.7 0-3.1-1.3-3.1-3 0-2.2 2-4.1 4.6-4.1z"/>',
    sliders: '<path d="M3.5 8h10M18.5 8h2M3.5 16h2M10.5 16h10"/><circle cx="16" cy="8" r="2.3"/><circle cx="8" cy="16" r="2.3"/>',
    dot: '<circle cx="12" cy="12" r="3.4"/>'
  };

  // Config.Categories reuses the same Font Awesome icon for different categories
  // (fa-running for both Dances and Walks, fa-male for both General and Custom),
  // which makes them indistinguishable once the sidebar is collapsed to icons.
  // These per-id overrides win; unknown ids still fall back to the FA mapping.
  var CAT_ICON = {
    all: 'home', favorites: 'star', recent: 'clock',
    emotes: 'person', dances: 'running', walks: 'walking',
    newemote: 'sparkles', expressions: 'smile', custom: 'sliders',
    police: 'shield', propemotes: 'cube', shared: 'users'
  };

  // Font Awesome names used by Config.Categories -> local icon
  var FA_MAP = {
    house: 'home', home: 'home', star: 'star', stopwatch: 'timer', clock: 'clock',
    'clock-rotate-left': 'clock', history: 'clock',
    male: 'person', person: 'person', user: 'person', child: 'person',
    running: 'running', 'person-running': 'running',
    'person-walking': 'walking', walking: 'walking',
    sparkles: 'sparkles', star_shooting: 'sparkles', wand: 'sparkles',
    'laugh-beam': 'smile', 'face-smile': 'smile', smile: 'smile', 'face-laugh': 'smile',
    'user-police': 'shield', 'shield-halved': 'shield', shield: 'shield', handcuffs: 'shield',
    hands: 'cube', 'hands-holding': 'cube', box: 'cube', cube: 'cube', 'box-open': 'cube',
    'user-group': 'users', users: 'users', 'people-group': 'users', 'user-friends': 'users',
    flag: 'flag', heart: 'heart', music: 'music', dog: 'paw', cat: 'paw', paw: 'paw'
  };
  var FA_STYLES = {
    fas: 1, far: 1, fal: 1, fat: 1, fab: 1, fad: 1, fa: 1,
    solid: 1, regular: 1, light: 1, thin: 1, duotone: 1, brands: 1,
    sharp: 1, 'sharp-solid': 1, 'sharp-duotone': 1, 'sharp-regular': 1, 'sharp-light': 1
  };

  function ico(name, extra) {
    var d = PATHS[name] || PATHS.dot;
    return '<svg class="ic' + (extra ? ' ' + extra : '') + '" viewBox="0 0 24 24" fill="none" ' +
      'stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" ' +
      'aria-hidden="true">' + d + '</svg>';
  }

  // Resolves an arbitrary "fas fa-user-group" style class to a local icon.
  function faIco(cls, extra) {
    var name = null;
    var parts = String(cls || '').split(/\s+/);
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i].replace(/^fa-/, '');
      if (!p || FA_STYLES[p] || FA_STYLES[parts[i]]) continue;
      name = p;
    }
    return ico((name && FA_MAP[name]) || 'dot', extra);
  }

  /* ============================================================
     HELPERS
     ============================================================ */

  // Mirrors the old $.post semantics: the callback only fires when the
  // response body is valid JSON (a non-JSON/empty reply is ignored).
  function post(name, data, cb) {
    fetch('https://' + RES + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    })
      .then(function (r) { return r.text(); })
      .then(function (txt) {
        if (!cb) return;
        var v;
        try { v = JSON.parse(txt); } catch (e) { return; }
        cb(v);
      })
      .catch(function () { /* resource unavailable - ignore */ });
  }

  function lsJSON(k, d) {
    try { var v = localStorage.getItem(k); return v == null ? d : JSON.parse(v); }
    catch (e) { return d; }
  }
  function lsSet(k, v) {
    try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* full/blocked */ }
  }
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function debounce(fn, ms) {
    var t = null;
    return function () {
      var self = this, a = arguments;
      if (t) clearTimeout(t);
      t = setTimeout(function () { t = null; fn.apply(self, a); }, ms);
    };
  }

  /* ============================================================
     STATE
     ============================================================ */

  var state = {
    active: false,
    visible: false,      // gifs mounted? false while the menu is hidden
    categories: [],
    animations: [],
    locales: {},
    counts: {},
    query: '',
    selectedCategory: 'all',
    shortcuts: lsJSON('shortcutAnims', []),
    favorites: lsJSON('favoriteAnims', {}),
    recent: lsJSON('recentAnims', []),
    navCollapsed: lsJSON('navCollapsed', false) === true,
    sel: -1,             // keyboard selection index in the current list
    inputMode: true
  };

  function L(k) { return state.locales[k] || ''; }
  function T(k, fallback) { return L(k) || fallback; }

  /* ============================================================
     DERIVED DATA
     ============================================================ */

  var baseCache = {};   // category id -> sorted array
  var resultCache = { key: null, list: null };

  function invalidate(cat) {
    if (cat) delete baseCache[cat]; else baseCache = {};
    resultCache.key = null;
    resultCache.list = null;
  }

  function byLabel(a, b) {
    return a._l < b._l ? -1 : (a._l > b._l ? 1 : 0);
  }

  function recentAnims() {
    var byId = {}, out = [];
    for (var i = 0; i < state.animations.length; i++) byId[state.animations[i].id] = state.animations[i];
    for (var j = 0; j < state.recent.length; j++) {
      var a = byId[state.recent[j]];
      if (a) out.push(a);
    }
    return out;
  }

  function baseList(cat) {
    if (baseCache[cat]) return baseCache[cat];
    var all = state.animations, t;
    if (cat === 'all') {
      t = all.filter(function (a) { return !HIDE_IN_ALL[a.category]; });
    } else if (cat === 'favorites') {
      t = all.filter(function (a) { return state.favorites[a.id] === true; });
    } else if (cat === 'recent') {
      t = recentAnims();
    } else if (cat === 'shared') {
      t = all.filter(function (a) { return a.targetAnim != null; });
    } else {
      t = all.filter(function (a) { return a.category === cat; });
    }
    if (cat !== 'recent') t.sort(byLabel);   // recent keeps its own order
    baseCache[cat] = t;
    return t;
  }

  function wordStart(s, t) {
    var p = s.indexOf(t);
    while (p > 0) {
      var c = s.charAt(p - 1);
      if (c === ' ' || c === '-' || c === '_' || c === '(') return true;
      p = s.indexOf(t, p + 1);
    }
    return false;
  }

  // Every token must hit somewhere; better hits (exact > prefix > word start)
  // rank higher, so "air g" finds "Air Guitar" and puts it on top.
  function score(a, toks, q) {
    var l = a._l, id = a._i, total = 0;
    for (var k = 0; k < toks.length; k++) {
      var t = toks[k], best = 0;
      if (l === t) best = 1000;
      else if (l.indexOf(t) === 0) best = 220;
      else if (wordStart(l, t)) best = 140;
      else if (l.indexOf(t) !== -1) best = 60;
      if (id === t) best = Math.max(best, 900);
      else if (id.indexOf(t) === 0) best = Math.max(best, 180);
      else if (id.indexOf(t) !== -1) best = Math.max(best, 40);
      if (best === 0) return 0;
      total += best;
    }
    if (l === q || id === q) total += 800;
    return total;
  }

  function resultList() {
    var cat = state.selectedCategory;
    var q = state.query.trim().toLowerCase();
    var key = cat + '\u0000' + q;
    if (resultCache.key === key) return resultCache.list;

    var base = baseList(cat), out;
    if (!q) {
      out = base;
    } else {
      var toks = q.split(/\s+/);
      var scored = [];
      for (var i = 0; i < base.length; i++) {
        var s = score(base[i], toks, q);
        if (s > 0) scored.push([s, i, base[i]]);
      }
      scored.sort(function (x, y) { return (y[0] - x[0]) || (x[1] - y[1]); });
      out = scored.map(function (e) { return e[2]; });
    }
    resultCache.key = key;
    resultCache.list = out;
    return out;
  }

  function getCount(id) {
    if (id === 'favorites') {
      var t = 0;
      for (var k in state.favorites) if (state.favorites[k]) t++;
      return t;
    }
    if (id === 'recent') return baseList('recent').length;
    if (state.counts[id] != null) return state.counts[id];
    return baseList(id).length;
  }

  function getCategories() {
    var r = [];
    var favN = getCount('favorites');
    var recN = state.animations.length ? getCount('recent') : 0;
    for (var i = 0; i < state.categories.length; i++) {
      var c = state.categories[i];
      if (c.id === 'sequences') continue;                  // feature removed
      if (c.id === 'favorites' && favN === 0) continue;
      r.push(c);
      if (c.id === 'favorites' && recN > 0) {
        r.push({ id: 'recent', label: T('recent_animations', 'Recent'), icon: 'fa-clock' });
      }
    }
    // no favorites row to anchor to -> park Recent right after All
    if (recN > 0 && favN === 0) {
      for (var j = 0; j < r.length; j++) {
        if (r[j].id === 'all') {
          r.splice(j + 1, 0, { id: 'recent', label: T('recent_animations', 'Recent'), icon: 'fa-clock' });
          break;
        }
      }
    }
    return r;
  }

  function hasFavorite(id) { return state.favorites[id] === true; }

  function gifUrl(a) {
    if (!a || !a.gif) return null;
    return a.custom ? CDN + 'customs/' + a.gif : CDN + a.gif;
  }

  /* ============================================================
     SKELETON
     ============================================================ */

  var app = document.getElementById('app');
  var els = {};

  function buildSkeleton() {
    app.innerHTML =
      '<div class="stage" id="stage">' +
        '<div class="overlay"></div>' +
        '<div class="panel">' +
          '<div class="glow glow-a"></div><div class="glow glow-b"></div><div class="dots"></div>' +
          '<header class="topbar">' +
            '<div class="brand"><h1>Emotes</h1></div>' +
            '<div class="tools">' +
              '<div class="search" id="searchWrap">' + ico('search') +
                '<input id="searchInput" type="text" spellcheck="false" autocomplete="off" placeholder="Search..." />' +
                '<button class="search-clear" id="searchClear" type="button" title="Clear">' + ico('xmark') + '</button>' +
              '</div>' +
              '<button class="btn stop" id="btnStop" type="button">' + ico('ban') +
                '<span id="stopLabel">Stop</span><b class="k">X</b>' +
              '</button>' +
              '<div class="esc-hint"><span class="k">ESC</span><span class="t" id="escLabel">Close</span></div>' +
            '</div>' +
          '</header>' +
          '<div class="body">' +
            '<aside class="sidebar" id="sidebar">' +
              '<button class="nav-toggle" id="navToggle" type="button">' + ico('chevrons') + '</button>' +
              '<div class="nav" id="nav"></div>' +
            '</aside>' +
            '<main class="content">' +
              '<div class="content-head">' +
                '<div class="ch-left">' +
                  '<span class="ch-title" id="catTitle">All</span>' +
                  '<span class="ch-count" id="catCount"></span>' +
                '</div>' +
                '<div class="ch-hints">' +
                  '<span class="hint">' + ico('cursor') + '<span id="hintPlay">Click to play</span></span>' +
                  '<span class="hint"><b>RMB</b><span id="hintInvite">Invite a player</span></span>' +
                  // No MMB hint: middle-click posts animPos, but Config.AnimPos.EnableAnimPos
                  // is false on this server, so the feature does nothing. Re-add the hint
                  // (and the hint_place locale key) if AnimPos is ever turned on.
                '</div>' +
              '</div>' +
              '<div class="grid-scroll" id="gridScroll">' +
                '<div class="grid" id="grid"></div>' +
                '<div class="empty" id="empty">' + ico('search') +
                  '<h4 id="emptyTitle">No animations found</h4>' +
                  '<p id="emptyText">Try a different search or pick another category.</p>' +
                '</div>' +
              '</div>' +
              '<div class="quick">' +
                '<div class="quick-head">' +
                  '<span id="quickLabel">Quick Animations</span>' +
                  '<span class="quick-hint">' +
                    '<span class="hint">' + ico('move') + '<span id="hintDrag">Drag an emote onto a slot</span></span>' +
                    '<span class="hint"><b>RMB</b><span id="hintRemove">Clear a slot</span></span>' +
                    '<span class="hint"><b>SHIFT</b><b>NUM 1-7</b><span id="hintKeys">to play</span></span>' +
                  '</span>' +
                '</div>' +
                '<div class="quick-slots" id="quickSlots"></div>' +
              '</div>' +
            '</main>' +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div class="toasts" id="toasts"></div>';

    // No clickable close button: this escrowed resource only releases NUI focus
    // via the ESC key, not via a callback, so a click could not free the cursor.

    els.stage = document.getElementById('stage');
    els.nav = document.getElementById('nav');
    els.sidebar = document.getElementById('sidebar');
    els.navToggle = document.getElementById('navToggle');
    els.grid = document.getElementById('grid');
    els.scroll = document.getElementById('gridScroll');
    els.empty = document.getElementById('empty');
    els.quick = document.getElementById('quickSlots');
    els.toasts = document.getElementById('toasts');
    els.input = document.getElementById('searchInput');
    els.searchWrap = document.getElementById('searchWrap');
    els.catTitle = document.getElementById('catTitle');
    els.catCount = document.getElementById('catCount');

    var onSearch = debounce(function () {
      applyQuery(els.input.value);
    }, SEARCH_DELAY);

    els.input.addEventListener('input', function () {
      els.searchWrap.classList.toggle('has-text', this.value.length > 0);
      keepInput();
      onSearch();
    });
    els.input.addEventListener('focus', keepInput);
    els.input.addEventListener('mousedown', keepInput);
    els.input.addEventListener('blur', releaseInput);

    document.getElementById('searchClear').addEventListener('click', function () {
      els.input.value = '';
      els.searchWrap.classList.remove('has-text');
      applyQuery('');
    });

    document.getElementById('btnStop').addEventListener('click', function () {
      post('stopAnim', {});
    });

    els.navToggle.addEventListener('click', function () {
      state.navCollapsed = !state.navCollapsed;
      lsSet('navCollapsed', state.navCollapsed);
      applyNavCollapsed();
      renderNav();
      // Re-layout on every frame of the 220ms width transition. Doing it here
      // rather than leaning on the ResizeObserver keeps the columns correct even
      // where RO is missing (the window-resize fallback never fires for this).
      reflowFor(300);
    });
    applyNavCollapsed();

    bindGridEvents();
    setupVirtualScroll();
    setupNavTip();
  }

  function applyQuery(v) {
    if (state.query === v) return;
    state.query = v;
    state.sel = -1;
    renderGrid();
    renderNav();
  }

  function keepInput() {
    if (state.inputMode) { state.inputMode = false; post('toggleKeepInput', { toggle: false }); }
  }
  function releaseInput() {
    if (!state.inputMode) { state.inputMode = true; post('toggleKeepInput', { toggle: true }); }
  }

  /* ============================================================
     SIDEBAR
     ============================================================ */

  function renderNav() {
    if (!els.nav) return;
    var cats = getCategories();
    var suffix = T('animations', 'Animations');
    var html = '';
    for (var i = 0; i < cats.length; i++) {
      var c = cats[i];
      var label = c.label || c.id;
      var count = getCount(c.id);
      // the sidebar scrolls, so a CSS tooltip would be clipped - the native
      // title carries the label + count while the rail is collapsed
      var tip = label + '  -  ' + count + ' ' + suffix;
      html +=
        '<div class="nav-item' + (state.selectedCategory === c.id ? ' active' : '') + '"' +
             ' data-id="' + esc(c.id) + '" data-tip="' + esc(tip) + '"' +
             // collapsed uses the styled .nav-tip instead, so no double tooltip
             (state.navCollapsed ? '' : ' title="' + esc(tip) + '"') + '>' +
          '<div class="nav-bar"></div>' +
          (CAT_ICON[c.id] ? ico(CAT_ICON[c.id]) : faIco(c.icon)) +
          '<div class="nav-text">' +
            '<span class="nav-label">' + esc(label) + '</span>' +
            '<span class="nav-count">' + count + ' ' + esc(suffix) + '</span>' +
          '</div>' +
        '</div>';
    }
    els.nav.innerHTML = html;
  }

  function applyNavCollapsed() {
    if (!els.sidebar) return;
    els.sidebar.classList.toggle('collapsed', state.navCollapsed);
    els.navToggle.title = state.navCollapsed
      ? T('expand_menu', 'Expand menu')
      : T('collapse_menu', 'Collapse menu');
    hideNavTip();
  }

  /* ---- collapsed-rail tooltip ----------------------------------------------
     The sidebar scrolls, so a ::after tooltip would be clipped at its edge.
     Instead one fixed-position node lives on <body> and is moved to the hovered
     item, which also keeps it above the panel and the toasts.
  ------------------------------------------------------------------------- */

  var navTipFor = null;

  function setupNavTip() {
    els.navTip = document.createElement('div');
    els.navTip.className = 'nav-tip';
    document.body.appendChild(els.navTip);

    els.nav.addEventListener('mousemove', function (ev) {
      if (!state.navCollapsed) return;
      var item = ev.target.closest('.nav-item');
      if (!item) { hideNavTip(); return; }
      if (item !== navTipFor) showNavTip(item);
    });
    els.nav.addEventListener('mouseleave', hideNavTip);
    els.sidebar.addEventListener('scroll', hideNavTip);
  }

  function showNavTip(item) {
    navTipFor = item;
    els.navTip.textContent = item.getAttribute('data-tip') || '';
    var r = item.getBoundingClientRect();
    els.navTip.style.left = (r.right + 10) + 'px';
    els.navTip.style.top = (r.top + r.height / 2) + 'px';
    els.navTip.classList.add('show');
  }

  function hideNavTip() {
    navTipFor = null;
    if (els.navTip) els.navTip.classList.remove('show');
  }

  function selectCategory(id) {
    if (state.selectedCategory === id) return;
    state.selectedCategory = id;
    state.sel = -1;
    renderNav();
    renderGrid();
  }

  function categoryLabel(id) {
    if (id === 'recent') return T('recent_animations', 'Recent');
    for (var i = 0; i < state.categories.length; i++) {
      if (state.categories[i].id === id) return state.categories[i].label || id;
    }
    return id;
  }

  /* ============================================================
     GRID - windowed rendering (only visible rows exist in the DOM)
     ============================================================ */

  var badGif = {};   // gif url -> true once it has failed to load

  var G = {
    list: [],
    cols: 0,
    colW: MIN_COL,
    tileH: MIN_COL + 35,
    mounted: {},        // index -> element
    probe: {},          // colW -> measured height
    raf: 0,
    dirty: false
  };

  function tileInner(a, forProbe) {
    var cmd = '/e ' + (a ? a.id : '');
    var url = a ? gifUrl(a) : null;
    var media;
    // "no gif configured" and "gif failed to load" mean the same thing to a
    // player, so both get the same quiet mark. badGif keeps a url that already
    // 404'd from being requested again on every re-mount while scrolling.
    if (forProbe || !url || badGif[url]) {
      media = '<div class="tile-media placeholder">' + ico('person') + '</div>';
    } else {
      media = '<div class="tile-shim"></div>' +
        '<img class="tile-media" src="' + esc(url) + '" alt="" draggable="false" decoding="async" />';
    }
    var star = a
      ? '<button class="tile-star' + (hasFavorite(a.id) ? ' on' : '') + '" type="button" ' +
        'data-fav="' + esc(a.id) + '" title="' + esc(T('favorite', 'Favorite')) + '">' + ico('star') + '</button>'
      : '';
    // the probe needs real text in the name row, otherwise it has no line box
    // and the measured tile height comes out ~15px short
    var name = a ? esc(a.label) : 'X';
    return '<div class="tile-top">' + star + '<span class="tile-cmd">' + esc(cmd) + '</span></div>' +
      media +
      '<div class="tile-name">' + name + '</div>';
  }

  function makeTile(a, i) {
    var el = document.createElement('div');
    el.className = 'tile' + (state.sel === i ? ' sel' : '');
    el.title = a.label || a.id || '';
    el.innerHTML = tileInner(a, false);
    el._anim = a;
    el._i = i;
    var img = el.querySelector('img.tile-media');
    if (img) {
      var shim = el.querySelector('.tile-shim');
      img.onload = function () {
        img.classList.add('loaded');
        if (shim) shim.classList.add('done');
      };
      img.onerror = function () {
        img.onerror = null;
        var src = img.getAttribute('src');
        if (src) badGif[src] = true;
        // swap the broken image for an inline placeholder instead of loading a
        // fallback png - no extra request, and it matches the rest of the UI
        var ph = document.createElement('div');
        ph.className = 'tile-media placeholder';
        ph.innerHTML = ico('person');
        if (img.parentNode) img.parentNode.replaceChild(ph, img);
        if (shim) shim.classList.add('done');
      };
      if (img.complete && img.naturalWidth) img.onload();
    }
    return el;
  }

  function unmount(i) {
    var el = G.mounted[i];
    if (!el) return;
    var img = el.querySelector('img.tile-media');
    if (img) { img.onload = img.onerror = null; img.removeAttribute('src'); }
    if (el.parentNode) el.parentNode.removeChild(el);
    delete G.mounted[i];
  }

  function unmountAll() {
    for (var k in G.mounted) unmount(k);
    G.mounted = {};
  }

  function place(el, i) {
    var r = Math.floor(i / G.cols), c = i % G.cols;
    el.style.width = G.colW + 'px';
    el.style.left = (c * (G.colW + GAP)) + 'px';
    el.style.top = (r * (G.tileH + GAP)) + 'px';
  }

  // Tile height depends on the column width (square media + name row), so it is
  // measured once per width with an off-screen probe instead of hard-coded.
  function measureTileH(colW) {
    var key = Math.round(colW);
    if (G.probe[key]) return G.probe[key];
    var p = document.createElement('div');
    p.className = 'tile';
    p.style.cssText = 'visibility:hidden;left:-9999px;top:0;width:' + colW + 'px';
    p.innerHTML = tileInner(null, true);
    els.grid.appendChild(p);
    var h = p.offsetHeight || (colW + 35);
    els.grid.removeChild(p);
    G.probe[key] = h;
    return h;
  }

  // returns true when the geometry changed
  function measure() {
    var W = els.grid.clientWidth;
    if (W <= 0) return false;
    var cols = Math.max(1, Math.floor((W + GAP) / (MIN_COL + GAP)));
    // whole pixels only: fractional widths give blurry text and make the
    // measured tile height wobble by a pixel between renders
    var colW = Math.floor((W - GAP * (cols - 1)) / cols);
    if (cols === G.cols && colW === G.colW) return false;
    G.cols = cols;
    G.colW = colW;
    G.tileH = measureTileH(colW);
    return true;
  }

  function totalRows() { return Math.ceil(G.list.length / G.cols); }

  function syncHeight() {
    var rows = totalRows();
    els.grid.style.height = rows > 0 ? (rows * G.tileH + (rows - 1) * GAP) + 'px' : '0px';
  }

  function renderWindow(force) {
    if (!state.visible || !G.cols) return;
    var n = G.list.length;
    if (!n) { unmountAll(); return; }

    var st = els.scroll.scrollTop, vh = els.scroll.clientHeight;
    var rowH = G.tileH + GAP;
    var firstRow = Math.max(0, Math.floor(st / rowH) - OVERSCAN);
    var lastRow = Math.min(totalRows() - 1, Math.ceil((st + vh) / rowH) + OVERSCAN);
    var from = firstRow * G.cols;
    var to = Math.min(n - 1, (lastRow + 1) * G.cols - 1);

    for (var k in G.mounted) {
      var idx = +k;
      if (idx < from || idx > to) unmount(k);
    }
    for (var i = from; i <= to; i++) {
      var el = G.mounted[i];
      if (!el) {
        el = makeTile(G.list[i], i);
        G.mounted[i] = el;
        place(el, i);
        els.grid.appendChild(el);
      } else if (force) {
        place(el, i);
      }
    }
  }

  function scheduleWindow(force) {
    if (force) G.dirty = true;
    if (G.raf) return;
    G.raf = requestAnimationFrame(function () {
      G.raf = 0;
      var f = G.dirty;
      G.dirty = false;
      renderWindow(f);
    });
  }

  function renderGrid(keepScroll) {
    if (!els.grid) return;
    G.list = resultList();
    unmountAll();
    if (!keepScroll) els.scroll.scrollTop = 0;
    measure();
    if (!G.cols) { G.cols = 1; G.colW = els.grid.clientWidth || MIN_COL; G.tileH = measureTileH(G.colW); }
    syncHeight();
    renderWindow(true);

    els.empty.classList.toggle('show', G.list.length === 0);
    els.catTitle.textContent = categoryLabel(state.selectedCategory);
    els.catCount.textContent = G.list.length + ' ' + T('results', 'RESULTS');
  }

  // keeps the grid geometry in step with an animating container width
  function reflowFor(ms) {
    var start = null;
    function step(ts) {
      if (start === null) start = ts;
      if (measure()) syncHeight();
      renderWindow(true);
      if (ts - start < ms) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  function setupVirtualScroll() {
    els.scroll.addEventListener('scroll', function () { scheduleWindow(false); }, { passive: true });
    if (typeof ResizeObserver !== 'undefined') {
      new ResizeObserver(function () {
        if (!state.visible) return;
        if (measure()) { syncHeight(); scheduleWindow(true); }
      }).observe(els.scroll);
    } else {
      window.addEventListener('resize', function () {
        if (measure()) { syncHeight(); scheduleWindow(true); }
      });
    }
  }

  /* ============================================================
     TILE INTERACTIONS
     ============================================================ */

  var justDragged = false;

  function bindGridEvents() {
    var grid = els.grid;

    grid.addEventListener('click', function (ev) {
      if (justDragged) { justDragged = false; return; }
      var favBtn = ev.target.closest('.tile-star');
      if (favBtn) {
        ev.stopPropagation();
        toggleFavorite(favBtn.getAttribute('data-fav'), favBtn);
        return;
      }
      var tile = ev.target.closest('.tile');
      if (!tile || !tile._anim) return;
      setSel(tile._i);
      onAnimClicked(tile._anim);
    });

    grid.addEventListener('contextmenu', function (ev) {
      var tile = ev.target.closest('.tile');
      if (!tile || !tile._anim) return;
      ev.preventDefault();
      post('sendAnimationInvite', { animation: tile._anim });
    });

    grid.addEventListener('mousedown', function (ev) {
      if (ev.button !== 1) return;
      var tile = ev.target.closest('.tile');
      if (!tile || !tile._anim) return;
      ev.preventDefault();
      post('animPos', { animation: tile._anim });
    });

    grid.addEventListener('pointerdown', onDragStart);

    els.nav.addEventListener('click', function (ev) {
      var item = ev.target.closest('.nav-item');
      if (item) selectCategory(item.getAttribute('data-id'));
    });
  }

  function onAnimClicked(a) {
    pushRecent(a.id);
    post('onAnimClicked', { animation: a }, function (resp) {
      if (resp !== 'animClickedData') post('animPos', { animation: a });
    });
  }

  function pushRecent(id) {
    if (id == null) return;
    var r = state.recent.filter(function (x) { return x !== id; });
    r.unshift(id);
    if (r.length > RECENT_MAX) r.length = RECENT_MAX;
    state.recent = r;
    lsSet('recentAnims', r);
    invalidate('recent');
    // don't reshuffle the grid under the cursor while browsing Recent
    if (state.selectedCategory !== 'recent') renderNav();
  }

  function toggleFavorite(id, btn) {
    if (id == null || id === 'undefined') return;
    if (state.favorites[id]) delete state.favorites[id]; else state.favorites[id] = true;
    lsSet('favoriteAnims', state.favorites);
    invalidate('favorites');
    if (btn) btn.classList.toggle('on', hasFavorite(id));
    // mirror the change onto any other mounted tile for the same animation
    for (var k in G.mounted) {
      var el = G.mounted[k];
      if (el._anim && el._anim.id === id) {
        var b = el.querySelector('.tile-star');
        if (b) b.classList.toggle('on', hasFavorite(id));
      }
    }
    renderNav();
    // only rebuild the list when the change actually removes/adds a row
    if (state.selectedCategory === 'favorites') renderGrid(true);
  }

  /* ============================================================
     DRAG & DROP - native pointer events (no jQuery UI)
     ============================================================ */

  var drag = null;

  function onDragStart(ev) {
    if (drag || ev.button !== 0) return;
    if (ev.target.closest('.tile-star')) return;
    var tile = ev.target.closest('.tile');
    if (!tile || !tile._anim) return;
    drag = { tile: tile, sx: ev.clientX, sy: ev.clientY, on: false, ghost: null, slot: null, rects: null };
    window.addEventListener('pointermove', onDragMove);
    window.addEventListener('pointerup', onDragEnd);
    window.addEventListener('pointercancel', onDragEnd);
  }

  function onDragMove(ev) {
    if (!drag) return;
    if (!drag.on) {
      if (Math.abs(ev.clientX - drag.sx) < 6 && Math.abs(ev.clientY - drag.sy) < 6) return;
      beginGhost(ev);
    }
    var g = drag.ghost;
    g.style.left = (ev.clientX - drag.ox) + 'px';
    g.style.top = (ev.clientY - drag.oy) + 'px';

    var hit = null;
    for (var i = 0; i < drag.rects.length; i++) {
      var r = drag.rects[i];
      if (ev.clientX >= r.left && ev.clientX <= r.right && ev.clientY >= r.top && ev.clientY <= r.bottom) {
        hit = r.el;
        break;
      }
    }
    if (hit !== drag.slot) {
      if (drag.slot) drag.slot.classList.remove('drop-hover');
      if (hit) hit.classList.add('drop-hover');
      drag.slot = hit;
    }
  }

  function beginGhost(ev) {
    drag.on = true;
    tiltFreeze(true);
    var r = drag.tile.getBoundingClientRect();
    drag.ox = drag.sx - r.left;
    drag.oy = drag.sy - r.top;

    var g = drag.tile.cloneNode(true);
    g.classList.add('drag-ghost');
    g.classList.remove('sel');
    g.style.width = r.width + 'px';
    g.style.left = (ev.clientX - drag.ox) + 'px';
    g.style.top = (ev.clientY - drag.oy) + 'px';
    document.body.appendChild(g);
    drag.ghost = g;
    drag.tile.classList.add('drag-src');
    document.body.style.cursor = 'grabbing';

    drag.rects = [];
    var slots = els.quick.querySelectorAll('.slot');
    for (var i = 0; i < slots.length; i++) {
      var b = slots[i].getBoundingClientRect();
      drag.rects.push({ el: slots[i], left: b.left, right: b.right, top: b.top, bottom: b.bottom });
    }
  }

  function onDragEnd() {
    window.removeEventListener('pointermove', onDragMove);
    window.removeEventListener('pointerup', onDragEnd);
    window.removeEventListener('pointercancel', onDragEnd);
    if (!drag) return;
    var d = drag;
    drag = null;

    if (d.on) {
      if (d.ghost && d.ghost.parentNode) d.ghost.parentNode.removeChild(d.ghost);
      d.tile.classList.remove('drag-src');
      document.body.style.cursor = '';
      if (d.slot) {
        d.slot.classList.remove('drop-hover');
        setShortcut(parseInt(d.slot.getAttribute('data-slot'), 10), d.tile._anim);
      }
      tiltFreeze(false);
      justDragged = true;                                // swallow the trailing click
      setTimeout(function () { justDragged = false; }, 0);
    }
  }

  /* ============================================================
     QUICK SLOTS
     ============================================================ */

  function renderQuick() {
    if (!els.quick) return;
    var html = '';
    for (var i = 0; i < SLOTS; i++) {
      var s = state.shortcuts[i];
      var filled = !!(s && s.id);
      var inner;
      if (filled) {
        var url = state.visible ? gifUrl(s) : null;
        if (url && badGif[url]) url = null;
        // the key number stays on screen so you know which bind plays this slot
        inner = '<span class="slot-key">' + (i + 1) + '</span>';
        inner += url
          ? '<img src="' + esc(url) + '" alt="" draggable="false" />'
          : ico('person');
        inner += '<span class="slot-name">' + esc(s.label) + '</span>';
      } else {
        inner = '<span class="slot-empty">' + (i + 1) + '</span>';
      }
      var tip = filled
        ? esc(s.label) + '  -  ' + T('hint_remove', 'Right-click to clear')
        : T('hint_drag', 'Drag an emote here');
      html += '<div class="slot' + (filled ? ' filled' : '') + '" data-slot="' + i + '" title="' + esc(tip) + '">' +
        inner + '</div>';
    }
    els.quick.innerHTML = html;

    // a missing gif falls back to the icon, never to a broken-image png
    var imgs = els.quick.querySelectorAll('img');
    for (var n = 0; n < imgs.length; n++) {
      imgs[n].onerror = function () {
        this.onerror = null;
        var src = this.getAttribute('src');
        if (src) badGif[src] = true;
        var svg = document.createElement('span');
        svg.innerHTML = ico('person');
        if (this.parentNode) this.parentNode.replaceChild(svg.firstChild, this);
      };
    }
  }

  function setShortcut(i, anim) {
    if (!anim || i < 0 || i >= SLOTS) return;
    var copy = {};
    for (var k in anim) if (k.charAt(0) !== '_') copy[k] = anim[k];
    copy.index = i;
    state.shortcuts[i] = copy;
    lsSet('shortcutAnims', state.shortcuts);
    post('getShortcuts', { shortcuts: state.shortcuts });
    renderQuick();
  }

  function removeShortcut(i) {
    if (state.shortcuts[i] === false || state.shortcuts[i] == null) return;
    state.shortcuts[i] = false;
    lsSet('shortcutAnims', state.shortcuts);
    post('getShortcuts', { shortcuts: state.shortcuts });
    renderQuick();
  }

  /* ============================================================
     TOASTS - built once, then only the timer bar is updated
     ============================================================ */

  var toasts = [];   // { data, el, bar, left, total }
  var toastTimer = null;

  function buildToast(n) {
    var el = document.createElement('div');
    el.className = 'toast ' + (n.type === 'invite' ? 'invite' : 'basic');
    var media = '';
    var nurl = n.type === 'invite' && n.anim ? gifUrl(n.anim) : null;
    if (nurl && !badGif[nurl]) {
      media = '<img class="toast-img" src="' + esc(nurl) + '" alt="" />';
    }
    var buttons = (n.type === 'invite' && n.buttons)
      ? '<div class="toast-buttons">' +
          '<span class="tb accept">' + esc(T('accept_shared_anim', 'Accept')) + '</span>' +
          '<span class="tb decline">' + esc(T('decline_shared_anim', 'Decline')) + '</span>' +
        '</div>'
      : '';
    el.innerHTML = media +
      '<div class="toast-body">' +
        (n.title ? '<p class="toast-title">' + esc(n.title) + '</p>' : '') +
        (n.text ? '<p class="toast-text">' + esc(n.text) + '</p>' : '') +
        (n.description ? '<p class="toast-desc">' + esc(n.description) + '</p>' : '') +
        buttons +
      '</div>' +
      '<div class="toast-bar"><span></span></div>';
    var tImg = el.querySelector('.toast-img');
    if (tImg) {
      tImg.onerror = function () {
        this.onerror = null;
        var src = this.getAttribute('src');
        if (src) badGif[src] = true;
        if (this.parentNode) this.parentNode.removeChild(this);   // text-only toast
      };
    }
    return el;
  }

  function addToast(n) {
    var total = n.timeout == null ? 5 : n.timeout;
    var el = buildToast(n);
    els.toasts.appendChild(el);
    toasts.push({ el: el, bar: el.querySelector('.toast-bar span'), left: total, total: total || 1 });
    if (!toastTimer) toastTimer = setInterval(tickToasts, 1000);
  }

  function tickToasts() {
    for (var i = toasts.length - 1; i >= 0; i--) {
      var t = toasts[i];
      t.left -= 1;
      if (t.left <= 0) {
        toasts.splice(i, 1);
        t.el.classList.add('out');
        (function (el) { setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 260); })(t.el);
      } else {
        t.bar.style.width = Math.max(0, Math.min(100, (t.left / t.total) * 100)) + '%';
      }
    }
    if (!toasts.length && toastTimer) { clearInterval(toastTimer); toastTimer = null; }
  }

  /* ============================================================
     PARALLAX TILT - rAF only runs while the panel is still settling
     ============================================================ */

  var tilt = { x: 0, y: 0, tx: 0, ty: 0, raf: 0, active: false, frozen: false, timer: null, panel: null };

  function tiltApply() {
    if (!tilt.panel) return;
    tilt.panel.style.transform = 'perspective(1200px) rotateX(' + tilt.x.toFixed(3) +
      'deg) rotateY(' + tilt.y.toFixed(3) + 'deg)';
  }
  function tiltStep() {
    tilt.x += (tilt.tx - tilt.x) * 0.08;
    tilt.y += (tilt.ty - tilt.y) * 0.08;
    var dx = tilt.tx - tilt.x, dy = tilt.ty - tilt.y;
    if (Math.abs(dx) < 0.004 && Math.abs(dy) < 0.004) {
      tilt.x = tilt.tx; tilt.y = tilt.ty;
      tiltApply();
      tilt.raf = 0;                       // settled: stop burning frames
      return;
    }
    tiltApply();
    tilt.raf = requestAnimationFrame(tiltStep);
  }
  function tiltWake() {
    if (!tilt.active || tilt.raf) return;
    tilt.raf = requestAnimationFrame(tiltStep);
  }
  function tiltMove(e) {
    if (tilt.frozen || !tilt.panel) return;
    var r = tilt.panel.getBoundingClientRect();
    if (!r.width || !r.height) return;
    var x = (e.clientX - r.left) / r.width;
    var y = (e.clientY - r.top) / r.height;
    tilt.tx = (y - 0.5) * -2.5;
    tilt.ty = (x - 0.5) * 3.0;
    tiltWake();
  }
  function tiltLeave() { tilt.tx = 0; tilt.ty = 0; tiltWake(); }
  function tiltFreeze(v) {
    tilt.frozen = v;
    if (v) { tilt.tx = 0; tilt.ty = 0; tiltWake(); }
  }
  function startTilt() {
    if (tilt.timer) clearTimeout(tilt.timer);
    // small delay so the fade-in settles first
    tilt.timer = setTimeout(function () {
      if (!state.active || tilt.active) return;
      tilt.panel = document.querySelector('.panel');
      if (!tilt.panel) return;
      tilt.active = true;
      tilt.x = tilt.y = tilt.tx = tilt.ty = 0;
      tilt.panel.addEventListener('mousemove', tiltMove);
      tilt.panel.addEventListener('mouseleave', tiltLeave);
    }, 360);
  }
  function stopTilt() {
    if (tilt.timer) { clearTimeout(tilt.timer); tilt.timer = null; }
    tilt.active = false;
    if (tilt.raf) { cancelAnimationFrame(tilt.raf); tilt.raf = 0; }
    if (tilt.panel) {
      tilt.panel.removeEventListener('mousemove', tiltMove);
      tilt.panel.removeEventListener('mouseleave', tiltLeave);
      tilt.panel.style.transform = '';
    }
  }

  /* ============================================================
     OPEN / CLOSE
     ============================================================ */

  function setVisible(v) {
    state.visible = v;
    if (v) {
      renderGrid(true);
      renderQuick();
    } else {
      unmountAll();      // stops every gif decoding while the menu is hidden
      renderQuick();
    }
  }

  function applyActive() {
    if (!els.stage) return;
    els.stage.classList.toggle('open', state.active);
    document.body.classList.toggle('menu-open', state.active);
    if (!state.active) hideNavTip();
  }

  function closeMenu() {
    // Set inputMode true FIRST so any resulting blur makes releaseInput a no-op
    // (no toggleKeepInput post) - otherwise it races Lua's focus release and the
    // cursor stays on screen. Then blur cleanly and close.
    state.inputMode = true;
    if (els.input) els.input.blur();
    post('forceClose', {});
    state.active = false;
    stopTilt();
    applyActive();
  }

  /* ============================================================
     KEYBOARD
     ============================================================ */

  function setSel(i) {
    if (state.sel === i) return;
    var old = G.mounted[state.sel];
    if (old) old.classList.remove('sel');
    state.sel = i;
    var el = G.mounted[i];
    if (el) el.classList.add('sel');
  }

  function ensureVisible(i) {
    var rowH = G.tileH + GAP;
    var top = Math.floor(i / G.cols) * rowH;
    var st = els.scroll.scrollTop, vh = els.scroll.clientHeight;
    if (top < st) els.scroll.scrollTop = top;
    else if (top + G.tileH > st + vh) els.scroll.scrollTop = top + G.tileH - vh;
  }

  function moveSel(delta) {
    var n = G.list.length;
    if (!n) return;
    var next;
    if (state.sel < 0) {
      next = Math.floor(els.scroll.scrollTop / (G.tileH + GAP)) * G.cols;
    } else {
      next = state.sel + delta;
    }
    next = Math.max(0, Math.min(n - 1, next));
    ensureVisible(next);
    renderWindow(false);      // mount the row now so .sel lands on a real node
    setSel(next);
  }

  document.addEventListener('keydown', function (ev) {
    var k = ev.keyCode;

    if (k === 27) {                       // ESC - the only way to close
      if (state.active) closeMenu();
      return;
    }
    if (!state.active) return;

    var typing = ev.target === els.input;

    if (k === 38 || k === 40 || k === 37 || k === 39) {
      if (typing && (k === 37 || k === 39)) return;   // keep caret movement
      ev.preventDefault();
      moveSel(k === 38 ? -G.cols : k === 40 ? G.cols : k === 37 ? -1 : 1);
      return;
    }
    if (k === 13) {                       // Enter - play selection
      if (state.sel >= 0 && G.list[state.sel]) {
        ev.preventDefault();
        onAnimClicked(G.list[state.sel]);
      }
      return;
    }
    if (typing) return;                   // never react to typed letters

    if (k === 36 || k === 35) {           // Home / End
      ev.preventDefault();
      moveSel(k === 36 ? -1e9 : 1e9);
      return;
    }
    if (k === 88) post('stopAnim', {});   // X
  });

  // right-click a quick slot to clear it
  document.addEventListener('contextmenu', function (ev) {
    var slot = ev.target.closest('.slot');
    if (!slot) return;
    ev.preventDefault();
    removeShortcut(parseInt(slot.getAttribute('data-slot'), 10));
  });

  /* ============================================================
     MESSAGES
     ============================================================ */

  window.addEventListener('message', function (ev) {
    var d = ev.data || {};

    if (d.action === 'load') {
      state.categories = d.categories || [];
      state.animations = d.animations || [];
      state.locales = d.locales || {};

      // pre-lowercase once: the search runs over 6k+ entries per keystroke
      for (var i = 0; i < state.animations.length; i++) {
        var a = state.animations[i];
        a._l = String(a.label == null ? '' : a.label).toLowerCase();
        a._i = String(a.id == null ? '' : a.id).toLowerCase();
      }

      invalidate();
      state.counts = {};
      state.categories.forEach(function (c) {
        if (c.id === 'all' || c.id === 'favorites' || c.id === 'sequences') return;
        state.counts[c.id] = baseList(c.id).length;
      });
      state.counts.all = baseList('all').length;   // All hides expressions + walks

      applyStaticText();
      renderNav();
      renderQuick();
      if (state.visible) renderGrid();
    }

    if (d.action === 'open') {
      state.active = d.state !== false;
      if (state.active) {
        setVisible(true);
        applyActive();
        startTilt();
      } else {
        stopTilt();
        applyActive();
        setTimeout(function () { if (!state.active) setVisible(false); }, 400);
      }
    }

    if (d.action === 'notification') {
      var n = d.data || {};
      if (n.buttons === undefined) n.buttons = false;
      if (n.timeout == null) n.timeout = 5;
      addToast(n);
    }
  });

  function setText(id, v) {
    var el = document.getElementById(id);
    if (el) el.textContent = v;
  }

  function applyStaticText() {
    setText('quickLabel', T('quick_animations', 'Quick Animations'));
    setText('stopLabel', T('stop_animation', 'Stop'));
    setText('escLabel', T('close', 'Close'));
    setText('hintPlay', T('hint_play', 'Click to play'));
    setText('hintInvite', T('hint_invite', 'Invite a player'));
    setText('hintDrag', T('hint_drag', 'Drag an emote onto a slot'));
    setText('hintRemove', T('hint_remove', 'Clear a slot'));
    setText('hintKeys', T('hint_keys', 'to play'));
    setText('emptyTitle', T('no_results_title', 'No animations found'));
    setText('emptyText', T('no_results_text', 'Try a different search or pick another category.'));
    if (els.input) els.input.setAttribute('placeholder', T('search_placeholder', 'Search...'));
  }

  /* ============================================================
     BOOT
     ============================================================ */

  function boot() {
    buildSkeleton();
    applyStaticText();
    renderNav();
    renderQuick();

    if (!Array.isArray(state.shortcuts) || localStorage.getItem('shortcutAnims') == null) {
      var arr = [];
      for (var i = 0; i < SLOTS; i++) arr[i] = false;
      lsSet('shortcutAnims', arr);
      state.shortcuts = arr;
      renderQuick();
    }
    if (!Array.isArray(state.recent)) state.recent = [];
    if (!state.favorites || typeof state.favorites !== 'object') state.favorites = {};

    post('jsLoaded', {});
    post('getShortcuts', { shortcuts: lsJSON('shortcutAnims', []) });
    post('getSequences', { sequences: [] });   // sequences feature removed
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
