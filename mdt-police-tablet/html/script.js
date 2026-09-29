// ===========================================================================
// State
// ===========================================================================

const state = {
    opened: false,
    selfName: 'Officer',
    selfGrade: 'Officer',
    selfGradeLevel: 0,
    selfCitizenId: null,
    isCommandStaff: false,
    isBoss: false,
    minCommandGrade: 9,
    isLockdown: false,
    alertLevel: 'green',
    money: null,
    employees: [],
    applications: [],
    onDutyCount: 0,
    cameras: [],
    reports: null,      // null = not yet fetched
    directives: null,   // null = not yet fetched
    bolos: null,        // null = not yet fetched
    mapBounds: null,
    mapOfficers: [],
    mapMarkers: [],
    plateLookup: null,  // { plate, result } | null = nothing searched yet
    wanted: null,
    personnelHistory: null,
    citations: null,
    selfOnDuty: true,
    selfServerId: null,
    selfCallsign: 'NO TAG',
    selfStatus: 'active',
    canManageDispatch: false,
    dispatchCount: 0,
    shiftStartedAt: null,
    currentApp: null
};

// allowOffDuty: usable before clocking in (everything else unlocks after you
// clock in from the Command Hub app).
const APPS = [
    { id: 'hub',         label: 'Command Hub', glyph: '🛡️', tint: '#3b9dfb', dock: true, allowOffDuty: true },
    { id: 'dispatch',    label: 'Dispatch',    glyph: '📡', tint: '#f43f5e', dock: true, badge: 'calls' },
    { id: 'dashboard',   label: 'Dashboard',   glyph: '📊', tint: '#60a5fa', allowOffDuty: true },
    { id: 'map',         label: 'Map',         glyph: '🗺️', tint: '#06b6d4', dock: true },
    { id: 'wanted',      label: 'Most Wanted', glyph: '🎯', tint: '#b91c1c', dock: true },
    { id: 'citations',   label: 'Citations',   glyph: '🎫', tint: '#f97316' },
    { id: 'reports',     label: 'Reports',     glyph: '🗂️', tint: '#f59e0b' },
    { id: 'bolo',        label: 'BOLO',        glyph: '🚨', tint: '#dc2626', badge: 'bolos' },
    { id: 'directives',  label: 'Directives',  glyph: '📢', tint: '#ef4444' },
    { id: 'personnel',   label: 'Personnel',   glyph: '👮', tint: '#14b8a6' },
    { id: 'vehicles',    label: 'Vehicle Lookup', glyph: '🚓', tint: '#818cf8' },
    { id: 'recruitment', label: 'Recruitment', glyph: '📝', tint: '#22c55e', requiresCommand: true, badge: 'applications' },
    { id: 'finance',     label: 'Treasury',    glyph: '💰', tint: '#eab308', requiresCommand: true },
    { id: 'tactical',    label: 'Tactical Ops',glyph: '⚡', tint: '#f97316', requiresBoss: true },
    { id: 'cameras',     label: 'CCTV',        glyph: '🎥', tint: '#22c55e', requiresBoss: true, dock: true },
    { id: 'about',       label: 'About',       glyph: 'ℹ️', tint: '#9aa3b2', allowOffDuty: true }
];

const REPORT_TYPES = ['General', 'Arrest', 'Incident', 'Traffic Stop', 'Investigation', 'Use of Force', 'Other'];
const BOLO_PRIORITIES = ['low', 'normal', 'high'];

// ===========================================================================
// Small utilities
// ===========================================================================

function escapeHtml(str) {
    if (str === undefined || str === null) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function formatMoney(n) { return '$' + Number(n || 0).toLocaleString(); }

function loadingHtml(label) {
    return `
        <div class="loading-state">
            <div class="spinner"></div>
            <span>${escapeHtml(label || 'Loading…')}</span>
        </div>
    `;
}

function formatDate(value) {
    if (!value) return 'Unknown time';
    const d = new Date(value.replace ? value.replace(' ', 'T') : value);
    if (isNaN(d.getTime())) return String(value);
    return d.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function nuiPost(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {})
    }).catch(() => {});
}

function formatDuration(totalSeconds) {
    const secs = Math.max(0, Math.floor(totalSeconds || 0));
    const h = String(Math.floor(secs / 3600)).padStart(2, '0');
    const m = String(Math.floor((secs % 3600) / 60)).padStart(2, '0');
    const s = String(secs % 60).padStart(2, '0');
    return `${h}:${m}:${s}`;
}

function showToast(message, type) {
    let stack = document.getElementById('toast-stack');
    if (!stack) {
        stack = document.createElement('div');
        stack.id = 'toast-stack';
        document.getElementById('screen').appendChild(stack);
    }
    const toast = document.createElement('div');
    toast.className = 'toast' + (type ? ' toast-' + type : '');
    toast.textContent = message;
    stack.appendChild(toast);
    setTimeout(() => toast.remove(), 3000);
}

// ===========================================================================
// Clock (status bar + lock screen)
// ===========================================================================

function tickClock() {
    const now = new Date();
    const time = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const date = now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });

    const statusTime = document.getElementById('status-time');
    if (statusTime) statusTime.textContent = time;

    const lockTime = document.getElementById('lock-time');
    if (lockTime) lockTime.textContent = time;

    const lockDate = document.getElementById('lock-date');
    if (lockDate) lockDate.textContent = date;
}
setInterval(tickClock, 1000);
setInterval(() => {
    if (!state.shiftStartedAt || state.currentApp !== 'dashboard') return;
    const el = document.getElementById('shift-timer');
    if (!el) return;
    el.textContent = 'Shift time: ' + formatDuration((Date.now() - state.shiftStartedAt) / 1000);
}, 1000);
tickClock();

// ===========================================================================
// NUI message router
// ===========================================================================

window.addEventListener('message', function (event) {
    const data = event.data;
    const container = document.getElementById('boss-container');
    if (!container) return;

    if (data.action === 'openBossMenu') {
        applyBossData(data);
        if (!state.opened) {
            openDevice();
        } else {
            // Data refresh while already open (e.g. after an action) — just re-render.
            renderHomeMeta();
            if (state.currentApp) renderApp(state.currentApp);
        }
    } else if (data.action === 'close' || data.type === 'close') {
        closeDevice();
    } else if (data.action === 'openCameraView') {
        openCameraOverlay(data.name);
    } else if (data.action === 'closeCameraView') {
        closeCameraOverlay();
    } else if (data.action === 'reopenOnCameras') {
        container.classList.remove('hidden', 'closing');
        showHome(false);
        openApp('cameras');
    } else if (data.action === 'cameraPanUpdate') {
        updateCameraPanIndicator(data.sweep);
    } else if (data.action === 'receiveReports') {
        state.reports = data.reports || [];
        if (state.currentApp === 'reports') renderApp('reports');
        updateDockBadges();
    } else if (data.action === 'receiveDirectives') {
        state.directives = data.directives || [];
        if (state.currentApp === 'directives') renderApp('directives');
        updateDockBadges();
    } else if (data.action === 'receiveBolos') {
        state.bolos = data.bolos || [];
        if (state.currentApp === 'bolo') renderApp('bolo');
        updateDockBadges();
    } else if (data.action === 'mapOfficers') {
        state.mapOfficers = data.officers || [];
        if (state.currentApp === 'map') renderMapPins();
    } else if (data.action === 'mapMarkers') {
        state.mapMarkers = data.markers || [];
        if (state.currentApp === 'map') renderMapMarkers();
    } else if (data.action === 'plateLookupResult') {
        state.plateLookup = { plate: data.plate, result: data.result || null };
        if (state.currentApp === 'vehicles') renderApp('vehicles');
    } else if (data.action === 'receiveWanted') {
        state.wanted = data.wanted || [];
        if (state.currentApp === 'wanted') renderApp('wanted');
    } else if (data.action === 'receiveCitations') {
        state.citations = data.citations || [];
        if (state.currentApp === 'citations') renderApp('citations');
    } else if (data.action === 'personnelHistory') {
        state.personnelHistory = data.history || [];
        if (state.currentApp === 'personnel') renderApp('personnel');
    } else if (data.action === 'alertLevelChanged') {
        state.alertLevel = data.level || state.alertLevel;
        if (state.currentApp === 'dashboard' || state.currentApp === 'dispatch') renderApp(state.currentApp);
    } else if (data.action === 'forceClose') {
        closeDevice();
    } else if (data.action === 'dutyChanged') {
        setSelfDuty(data.onDuty === true);
    } else if (data.action === 'statusChanged') {
        state.selfStatus = data.status || 'active';
        if (state.currentApp === 'hub' && typeof hubRefresh === 'function') hubRefresh();
    } else if (data.action === 'dispatchCount') {
        state.dispatchCount = Number(data.count) || 0;
        updateDockBadges();
        renderStatusIndicators();
    }
});

// Duty flipped (from the Hub app, a duty board, or another script).
function setSelfDuty(onDuty) {
    const changed = state.selfOnDuty !== onDuty;
    state.selfOnDuty = onDuty;
    if (onDuty && !state.shiftStartedAt) state.shiftStartedAt = Date.now();
    if (!onDuty) { state.shiftStartedAt = null; state.selfStatus = 'off'; }
    else if (state.selfStatus === 'off') state.selfStatus = 'active';
    if (!state.opened) return;
    if (changed) { renderAppGrid(); renderDock(); }
    renderHomeMeta();
    const current = state.currentApp && APPS.find(a => a.id === state.currentApp);
    if (current && isAppLocked(current)) {
        showToast('You are off duty — clock in from the Command Hub.', 'error');
        goHome();
    } else if (state.currentApp) {
        if (state.currentApp === 'hub' && typeof hubRefresh === 'function') hubRefresh();
        else if (state.currentApp === 'dashboard') renderApp('dashboard');
    }
}

function applyBossData(data) {
    state.selfName = data.selfName || 'Officer';
    state.selfGrade = data.selfGrade || 'Officer';
    state.selfGradeLevel = data.selfGradeLevel || 0;
    state.selfCitizenId = data.selfCitizenId || null;
    state.selfOnDuty = data.selfOnDuty === true;
    if (state.selfOnDuty && !state.shiftStartedAt) state.shiftStartedAt = Date.now();
    if (!state.selfOnDuty) state.shiftStartedAt = null;
    state.selfServerId = data.selfServerId ?? state.selfServerId;
    state.selfCallsign = data.selfCallsign || state.selfCallsign;
    state.selfStatus = data.selfStatus || (state.selfOnDuty ? 'active' : 'off');
    state.canManageDispatch = !!data.canManageDispatch;
    state.isCommandStaff = !!data.isCommandStaff;
    state.isBoss = !!data.isBoss;
    state.minCommandGrade = data.minCommandGrade || 9;
    state.isLockdown = !!data.isLockdown;
    state.alertLevel = data.alertLevel || 'green';
    state.money = (data.money === undefined) ? null : data.money;
    state.employees = data.employees || [];
    state.applications = data.applications || [];
    state.onDutyCount = data.onDutyCount || 0;
    state.cameras = data.cameras || [];
    state.mapBounds = data.mapBounds || state.mapBounds;
}

// ===========================================================================
// Device open / close / lock screen
// ===========================================================================

function openDevice() {
    const container = document.getElementById('boss-container');
    container.classList.remove('hidden', 'closing');
    state.opened = true;

    document.getElementById('lock-screen').classList.remove('unlocking');
    document.getElementById('lock-screen').classList.remove('hidden');
    document.getElementById('home-screen').classList.remove('active');
    document.getElementById('app-view').classList.remove('active');

    renderAlertPill();
    renderAppGrid();
    renderDock();
    renderHomeMeta();
}

function unlockDevice() {
    const lock = document.getElementById('lock-screen');
    lock.classList.add('unlocking');
    setTimeout(() => {
        lock.classList.add('hidden');
        showHome(true);
    }, 480);
}
document.getElementById('lock-screen').addEventListener('click', unlockDevice);

function showHome(animated) {
    document.getElementById('app-view').classList.remove('active');
    document.getElementById('home-screen').classList.add('active');
    state.currentApp = null;
}

function goHome() {
    if (state.currentApp === 'map') teardownMapApp();
    showHome(true);
}
document.getElementById('app-home-btn').addEventListener('click', goHome);
document.getElementById('home-indicator').addEventListener('click', () => {
    if (state.currentApp) goHome();
});

// Explicit close control — previously Escape was the *only* way to close the
// tablet, with no visible affordance for it. This gives players an obvious
// button while keeping Escape working exactly as before.
document.getElementById('status-close-btn').addEventListener('click', (e) => {
    e.stopPropagation();
    if (state.opened) closeMenu();
});

function closeMenu() {
    if (state.currentApp === 'map') teardownMapApp();
    closeDevice();
    nuiPost('close');
}
function closeDevice() {
    if (typeof closeDialog === 'function') closeDialog(null);
    const container = document.getElementById('boss-container');
    container.classList.add('closing');
    setTimeout(() => {
        container.classList.add('hidden');
        container.classList.remove('closing');
        state.opened = false;
        state.currentApp = null;
    }, 220);
}

function renderAlertPill() {
    const pill = document.getElementById('alert-pill');
    if (!pill) return;
    pill.className = 'alert-pill alert-' + state.alertLevel;
    pill.textContent = 'CODE ' + state.alertLevel.toUpperCase();
}

function initials(name) {
    return (name || '')
        .trim()
        .split(/\s+/)
        .slice(0, 2)
        .map(p => p[0])
        .join('')
        .toUpperCase() || '?';
}

function renderHomeMeta() {
    document.getElementById('home-officer-name').textContent = state.selfName + ' — ' + state.selfGrade;
    document.getElementById('home-avatar').textContent = initials(state.selfName);
    document.getElementById('widget-onduty').textContent = state.onDutyCount;
    document.getElementById('widget-lockdown').textContent = state.isLockdown ? 'LOCKED DOWN' : 'Unlocked';
    const dutyEl = document.getElementById('widget-duty');
    if (dutyEl) {
        dutyEl.textContent = state.selfOnDuty ? 'ON DUTY' : 'OFF DUTY';
        dutyEl.className = state.selfOnDuty ? 'txt-ok' : 'txt-danger';
    }
    const greet = document.getElementById('home-greeting-text');
    if (greet) greet.textContent = state.selfOnDuty ? 'Welcome back' : 'Off duty — clock in from Command Hub';
    renderAlertPill();
    renderStatusIndicators();
    updateDockBadges();
}

// Status-bar pills: duty dot + active call count + mute bell.
function renderStatusIndicators() {
    const duty = document.getElementById('status-duty');
    if (duty) {
        duty.className = 'status-duty ' + (state.selfOnDuty ? 'on' : 'off');
        duty.title = state.selfOnDuty ? 'On duty' : 'Off duty';
    }
    const calls = document.getElementById('status-calls');
    if (calls) {
        calls.textContent = state.dispatchCount;
        calls.parentElement.classList.toggle('has-calls', state.dispatchCount > 0);
    }
    if (typeof renderMuteButton === 'function') renderMuteButton();
}

// ===========================================================================
// App grid + dock
// ===========================================================================

function isAppLocked(app) {
    if (!state.selfOnDuty && !app.allowOffDuty) return 'Clock in from the Command Hub first';
    if (app.requiresCommand && !state.isCommandStaff) return 'Command access required (Grade ' + state.minCommandGrade + '+)';
    if (app.requiresBoss && !state.isBoss) return 'Boss access required';
    return null;
}

function appBadgeCount(app) {
    if (app.badge === 'applications') {
        return state.applications.filter(a => a.status === 'Pending').length;
    }
    if (app.badge === 'bolos') {
        return (state.bolos || []).filter(b => b.active === undefined || b.active == 1).length;
    }
    if (app.badge === 'calls') return state.dispatchCount || 0;
    return 0;
}

function renderAppGrid() {
    const grid = document.getElementById('app-grid');
    grid.innerHTML = '';
    APPS.forEach(app => grid.appendChild(buildAppIcon(app)));
}

function renderDock() {
    const dock = document.getElementById('dock');
    dock.innerHTML = '';
    APPS.filter(a => a.dock).forEach(app => dock.appendChild(buildAppIcon(app, true)));
}

function buildAppIcon(app, small) {
    const wrap = document.createElement('div');
    const lockReason = isAppLocked(app);
    wrap.className = 'app-icon' + (lockReason ? ' locked' : '');
    wrap.title = lockReason || app.label;

    const badgeCount = appBadgeCount(app);
    wrap.innerHTML = `
        <div class="app-icon-tile" style="--tile-glow:${app.tint}55">
            <span class="glyph" style="color:${app.tint}">${app.glyph}</span>
            ${lockReason ? '<div class="app-icon-lock">🔒</div>' : ''}
            ${app.badge ? `<div class="app-badge" data-badge="${app.id}" style="display:${badgeCount > 0 ? 'flex' : 'none'}">${badgeCount}</div>` : ''}
        </div>
        ${small ? '' : `<div class="app-icon-label">${escapeHtml(app.label)}</div>`}
    `;

    wrap.addEventListener('click', () => {
        if (lockReason) {
            showToast(lockReason, 'error');
            return;
        }
        openApp(app.id);
    });

    return wrap;
}

function updateDockBadges() {
    document.querySelectorAll('[data-badge]').forEach(el => {
        const app = APPS.find(a => a.id === el.getAttribute('data-badge'));
        if (!app) return;
        const count = appBadgeCount(app);
        if (count > 0) {
            el.textContent = count;
            el.style.display = 'flex';
        } else {
            el.style.display = 'none';
        }
    });
}

// ===========================================================================
// App router
// ===========================================================================

const RENDERERS = {
    dashboard: renderDashboard,
    map: renderMap,
    // hub + dispatch renderers are registered by js/hub.js and js/dispatch.js
    wanted: renderWanted,
    citations: renderCitations,
    reports: renderReports,
    bolo: renderBolo,
    directives: renderDirectives,
    personnel: renderPersonnel,
    vehicles: renderVehicleLookup,
    recruitment: renderRecruitment,
    finance: renderFinance,
    tactical: renderTactical,
    cameras: renderCameras,
    about: renderAbout
};

// Apps that need to wire up event listeners / timers after their HTML lands
// in the DOM (innerHTML alone can't carry addEventListener-based behaviour).
const APP_INIT_HOOKS = { map: initMapApp };
// Apps that need to tear that down again when the officer navigates away.
const APP_TEARDOWN_HOOKS = { map: teardownMapApp };

function openApp(appId) {
    const app = APPS.find(a => a.id === appId);
    if (!app) return;

    if (state.currentApp && state.currentApp !== appId && APP_TEARDOWN_HOOKS[state.currentApp]) {
        APP_TEARDOWN_HOOKS[state.currentApp]();
    }

    state.currentApp = appId;
    document.getElementById('home-screen').classList.remove('active');
    document.getElementById('app-title').textContent = app.label;
    document.getElementById('app-view').classList.add('active');
    document.getElementById('app-body').classList.toggle('app-body-flush', appId === 'map');
    document.getElementById('app-body').classList.toggle('app-body-full', appId === 'dispatch' || appId === 'hub');
    renderApp(appId);
}

function renderApp(appId) {
    const body = document.getElementById('app-body');
    const fn = RENDERERS[appId];
    if (!fn) { body.innerHTML = ''; return; }
    body.innerHTML = fn();
    if (APP_INIT_HOOKS[appId]) APP_INIT_HOOKS[appId]();
}

// ===========================================================================
// Dashboard
// ===========================================================================

function renderDashboard() {
    const directivesLoading = state.directives === null;
    if (directivesLoading) nuiPost('getDirectives');
    const latestDirectives = (state.directives || []).slice(0, 3);

    return `
        <div class="section-title">Department Status</div>
        <div class="stat-row">
            <div class="card stat-card">
                <div class="stat-label">On-Duty Units</div>
                <div class="stat-value">${state.onDutyCount}</div>
            </div>
            <div class="card stat-card" style="border-left-color:${state.isLockdown ? 'var(--danger)' : 'var(--ok)'}">
                <div class="stat-label">Facility Status</div>
                <div class="stat-value" style="font-size:16px">${state.isLockdown ? '🔒 Locked Down' : '🔓 Open'}</div>
            </div>
        </div>
        <div class="stat-row">
            <div class="card stat-card" style="border-left-color:${state.alertLevel === 'red' ? 'var(--danger)' : state.alertLevel === 'yellow' ? 'var(--warn)' : 'var(--ok)'}">
                <div class="stat-label">Threat Condition</div>
                <div class="stat-value" style="font-size:16px">CODE ${state.alertLevel.toUpperCase()}</div>
            </div>
            <div class="card stat-card">
                <div class="stat-label">Your Assignment</div>
                <div class="stat-value" style="font-size:16px">${escapeHtml(state.selfGrade)}</div>
            </div>
        </div>

        <div class="section-title">Quick Access</div>
        <div class="field-row" style="flex-wrap:wrap; gap:10px;">
            <button class="btn btn-ghost" onclick="openApp('hub')">🛡️ Command Hub</button>
            <button class="btn btn-ghost" onclick="openApp('map')">🗺️ Tactical Map</button>
            <button class="btn btn-ghost" onclick="openApp('dispatch')">📡 Dispatch</button>
            <button class="btn btn-ghost" onclick="openApp('wanted')">🎯 Most Wanted</button>
            <button class="btn btn-ghost" onclick="openApp('bolo')">🚨 BOLO Board</button>
            <button class="btn btn-ghost" onclick="openApp('reports')">🗂️ File a Report</button>
            <button class="btn btn-ghost" onclick="openApp('personnel')">👮 View Roster</button>
            <button class="btn btn-ghost" onclick="doOpenRadio()">📻 Police Radio</button>
            ${state.isBoss ? `<button class="btn btn-ghost" onclick="openApp('cameras')">🎥 CCTV Feeds</button>` : ''}
            ${state.isCommandStaff ? `<button class="btn btn-ghost" onclick="openApp('finance')">💰 Treasury</button>` : ''}
        </div>

        <div class="section-title">Duty Status</div>
        <div class="card" style="display:flex; align-items:center; justify-content:space-between; gap:12px;">
            <div>
                <strong class="${state.selfOnDuty ? 'txt-ok' : 'txt-danger'}">${state.selfOnDuty ? 'On Duty' : 'Off Duty'}</strong>
                <span class="tag tag-normal" style="margin-left:6px;">${escapeHtml(state.selfCallsign)}</span>
                <div class="hint-text" id="shift-timer" style="margin-top:2px;">${state.selfOnDuty ? 'Shift time: 00:00:00' : 'Clock in to start your shift.'}</div>
            </div>
            <div style="display:flex; gap:8px;">
                ${state.selfOnDuty
                    ? `<button class="btn btn-danger btn-sm" onclick="doClockOut()">🔴 Clock Out</button>`
                    : `<button class="btn btn-ok btn-sm" onclick="doClockIn()">🟢 Clock In</button>`}
                <button class="btn btn-ghost btn-sm" onclick="openApp('hub'); hubSetTab('ops');">🚨 Panic / Status</button>
            </div>
        </div>

        <div class="section-title">Recent Directives</div>
        ${directivesLoading ? loadingHtml('Pulling latest directives…')
            : (latestDirectives.length ? latestDirectives.map(directiveItemHtml).join('') : `<div class="empty-state">No directives posted yet.</div>`)}
    `;
}

function doClockOut() {
    mdtConfirm({ title: 'Clock out?', message: 'You will go off duty and be removed from any calls you are attached to.', confirmText: 'Clock Out', danger: true })
        .then(ok => { if (ok) nuiPost('hubSetDuty', { onDuty: false }); });
}
function doClockIn() { nuiPost('hubSetDuty', { onDuty: true }); }
function doOpenRadio() { nuiPost('openRadio'); }

// ===========================================================================
// Most Wanted (Top 10 — Command staff post/remove, everyone views)
// ===========================================================================

const DANGER_LEVELS = ['Low', 'Medium', 'High', 'Extreme'];
const DANGER_TAG_CLASS = { Low: 'tag-normal', Medium: 'tag-important', High: 'tag-urgent', Extreme: 'tag-urgent' };

function wantedRowHtml(entry, rank) {
    const cls = DANGER_TAG_CLASS[entry.danger_level] || 'tag-normal';
    return `
        <div class="list-item" style="align-items:flex-start;">
            <div class="list-item-main">
                <strong>#${rank} — ${escapeHtml(entry.name)}</strong>
                <span class="tag ${cls}">${escapeHtml((entry.danger_level || 'Medium').toUpperCase())}</span>
                ${entry.reward ? `<span class="tag tag-normal">Reward: $${Number(entry.reward).toLocaleString()}</span>` : ''}
                <small>${escapeHtml(entry.charges)}</small>
                ${entry.last_seen ? `<small>Last seen: ${escapeHtml(entry.last_seen)}</small>` : ''}
                <small>Posted by ${escapeHtml(entry.posted_by)} · ${formatDate(entry.created_at)}</small>
            </div>
            ${state.isCommandStaff ? `<div class="list-item-actions"><button class="btn btn-danger btn-sm" onclick="doRemoveWanted(${entry.id})">Remove</button></div>` : ''}
        </div>
    `;
}

function renderWanted() {
    const loading = state.wanted === null;
    if (loading) nuiPost('getWanted');
    const list = state.wanted || [];
    const dangerOptions = DANGER_LEVELS.map(d => `<option value="${d}"${d === 'Medium' ? ' selected' : ''}>${d}</option>`).join('');

    const form = state.isCommandStaff ? `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Add to Most Wanted (${list.length}/10)</div>
            <div class="field-row">
                <div class="field"><label>Name</label><input id="wanted-name" type="text" maxlength="100" placeholder="Full name or alias"></div>
                <div class="field" style="max-width:150px;"><label>Danger</label><select id="wanted-danger">${dangerOptions}</select></div>
            </div>
            <div class="field"><label>Charges</label><input id="wanted-charges" type="text" maxlength="500" placeholder="e.g. Armed robbery"></div>
            <div class="field-row">
                <div class="field"><label>Last Seen</label><input id="wanted-lastseen" type="text" maxlength="150" placeholder="Area / vehicle (optional)"></div>
                <div class="field" style="max-width:150px;"><label>Reward $</label><input id="wanted-reward" type="number" min="0" placeholder="0"></div>
            </div>
            <button class="btn btn-danger btn-block" onclick="doAddWanted()" ${list.length >= 10 ? 'disabled' : ''}>🎯 Add To List</button>
            ${list.length >= 10 ? `<div class="hint-text" style="margin-top:6px;">List is full — remove an entry to add a new one.</div>` : ''}
        </div>
    ` : '';

    return form + `
        <div class="section-title" style="margin-top:${form ? '' : '0'};">Top 10 Most Wanted</div>
        ${loading ? loadingHtml('Pulling the Most Wanted list…')
            : (list.length ? list.map((e, i) => wantedRowHtml(e, i + 1)).join('') : `<div class="empty-state">No one is currently on the Most Wanted list.</div>`)}
    `;
}

function doAddWanted() {
    const name = document.getElementById('wanted-name').value.trim();
    const charges = document.getElementById('wanted-charges').value.trim();
    if (!name || !charges) { showToast('Name and charges are required.', 'error'); return; }
    nuiPost('addWanted', {
        name, charges,
        dangerLevel: document.getElementById('wanted-danger').value,
        lastSeen: document.getElementById('wanted-lastseen').value.trim(),
        reward: document.getElementById('wanted-reward').value
    });
}
function doRemoveWanted(id) { nuiPost('removeWanted', { id }); }

// ===========================================================================
// Citations (traffic tickets) — all employees issue/view; delete = author or Command
// ===========================================================================

function citationRowHtml(c) {
    const isAuthor = state.selfCitizenId && c.citizenid === state.selfCitizenId;
    const canDelete = isAuthor || state.isCommandStaff;
    return `
        <div class="list-item" style="align-items:flex-start;">
            <div class="list-item-main">
                <strong>${escapeHtml(c.target_name)}</strong>
                <span class="tag tag-important">$${Number(c.fine_amount).toLocaleString()}</span>
                ${c.plate ? `<span class="tag tag-normal">Plate: ${escapeHtml(c.plate)}</span>` : ''}
                <small>${escapeHtml(c.violation)}</small>
                ${c.notes ? `<small>${escapeHtml(c.notes)}</small>` : ''}
                <small>Issued by ${escapeHtml(c.officer_name)} · ${formatDate(c.created_at)}</small>
            </div>
            ${canDelete ? `<div class="list-item-actions"><button class="btn btn-danger btn-sm" onclick="doDeleteCitation(${c.id})">Void</button></div>` : ''}
        </div>
    `;
}

function renderCitations() {
    const loading = state.citations === null;
    if (loading) nuiPost('getCitations');
    const list = state.citations || [];

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Issue Citation</div>
            <div class="field-row">
                <div class="field"><label>Name</label><input id="citation-name" type="text" maxlength="100" placeholder="Full name"></div>
                <div class="field" style="max-width:130px;"><label>Fine $</label><input id="citation-fine" type="number" min="1" placeholder="250"></div>
            </div>
            <div class="field"><label>Violation</label><input id="citation-violation" type="text" maxlength="255" placeholder="e.g. Reckless driving"></div>
            <div class="field-row">
                <div class="field" style="max-width:150px;"><label>Plate (optional)</label><input id="citation-plate" type="text" maxlength="20" placeholder="ABC123"></div>
                <div class="field"><label>Notes (optional)</label><input id="citation-notes" type="text" maxlength="255"></div>
            </div>
            <button class="btn btn-accent btn-block" onclick="doIssueCitation()">🎫 Issue Citation</button>
        </div>
        <div class="section-title">Recent Citations (${list.length})</div>
        ${loading ? loadingHtml('Pulling citation log…') : (list.length ? list.map(citationRowHtml).join('') : `<div class="empty-state">No citations on record.</div>`)}
    `;
}

function doIssueCitation() {
    const targetName = document.getElementById('citation-name').value.trim();
    const violation = document.getElementById('citation-violation').value.trim();
    const fineAmount = document.getElementById('citation-fine').value;
    const plate = document.getElementById('citation-plate').value.trim();
    const notes = document.getElementById('citation-notes').value.trim();

    if (!targetName || !violation || !fineAmount || Number(fineAmount) <= 0) {
        showToast('Name, violation, and a fine amount are required.', 'error');
        return;
    }
    nuiPost('issueCitation', { targetName, violation, fineAmount, plate, notes });
    ['citation-name', 'citation-violation', 'citation-fine', 'citation-plate', 'citation-notes'].forEach(id => { document.getElementById(id).value = ''; });
}

function doDeleteCitation(id) { nuiPost('deleteCitation', { id }); }

// ===========================================================================
// Tactical Map app
// ===========================================================================

let mapZoomLevel = 1, mapPanX = 0, mapPanY = 0;
let mapDragging = false, mapDragStartX = 0, mapDragStartY = 0, mapPanStartX = 0, mapPanStartY = 0;
let selectedMapOfficer = null;

function worldToMapPercent(x, y) {
    const b = state.mapBounds || { minX: -4000, maxX: 4600, minY: -4300, maxY: 8100 };
    let left = (x - b.minX) / (b.maxX - b.minX);
    let top = 1 - (y - b.minY) / (b.maxY - b.minY); // image Y grows downward; world Y grows northward
    left = Math.min(1, Math.max(0, left));
    top = Math.min(1, Math.max(0, top));
    return { left: left * 100, top: top * 100 };
}

function renderMap() {
    return `
        <div class="map-wrap" id="map-wrap">
            <div class="map-canvas" id="map-canvas">
                <div class="map-calls-layer" id="map-calls-layer"></div>
                <div class="map-pins-layer" id="map-pins-layer"></div>
                <div class="map-markers-layer" id="map-markers-layer"></div>
            </div>
            <div class="map-toolbar">
                <button class="map-tool-btn active" id="map-tool-pan" onclick="setMapTool('pan')" title="Pan">🖐️</button>
                <button class="map-tool-btn" id="map-tool-pin" onclick="setMapTool('pin')" title="Drop a pin">📍</button>
                ${state.isCommandStaff ? `<button class="map-tool-btn" onclick="doClearAllMapMarkers()" title="Clear board">🗑️</button>` : ''}
                <span class="map-tool-sep"></span>
                <button class="map-tool-btn map-layer-btn" id="map-layer-units" onclick="toggleUnitsOnly()" title="On-duty units only (hide calls &amp; pins)">👥</button>
                <button class="map-tool-btn map-layer-btn" id="map-layer-calls" onclick="toggleMapLayer('calls')" title="Show / hide dispatch calls">📡</button>
                <button class="map-tool-btn map-layer-btn" id="map-layer-markers" onclick="toggleMapLayer('markers')" title="Show / hide map pins">📌</button>
            </div>
            <div class="map-controls">
                <button class="map-ctrl-btn" onclick="mapZoom(1)" title="Zoom in">＋</button>
                <button class="map-ctrl-btn" onclick="mapZoom(-1)" title="Zoom out">－</button>
                <button class="map-ctrl-btn" onclick="mapResetView()" title="Reset view">⤾</button>
            </div>
            <div class="map-legend">
                <span class="map-legend-dot"></span> Units: <strong id="map-legend-count">0</strong>
                <span class="map-legend-sep"></span>
                <span class="pri-dot pri-high"></span><span class="pri-dot pri-medium"></span><span class="pri-dot pri-low"></span>
                Calls: <strong id="map-legend-calls">0</strong>
            </div>
            <div class="map-info-panel hidden" id="map-info-panel"></div>
        </div>
    `;
}

let mapCanvasBaseSize = 0;
let mapTool = 'pan';

// Forces the canvas to a true square (min of the wrap's width/height,
// centered) with background-size 100% 100% against that exact square —
// this is the fix for "the map doesn't load fully": before, the image
// could be cropped by a non-square container. Now the whole map is always
// visible with zero letterboxing at zoom level 1.
function sizeMapCanvas() {
    const wrap = document.getElementById('map-wrap');
    const canvas = document.getElementById('map-canvas');
    if (!wrap || !canvas) return;
    const w = wrap.clientWidth, h = wrap.clientHeight;
    const size = Math.min(w, h);
    mapCanvasBaseSize = size;
    canvas.style.width = size + 'px';
    canvas.style.height = size + 'px';
    canvas.style.left = ((w - size) / 2) + 'px';
    canvas.style.top = ((h - size) / 2) + 'px';
}

// Fix for "I can drag past the map" — pan is clamped so you can never see
// empty space beyond the map's edge, at any zoom level.
function clampMapPan() {
    const wrap = document.getElementById('map-wrap');
    if (!wrap) return;
    const rect = wrap.getBoundingClientRect();
    const scaledSize = mapCanvasBaseSize * mapZoomLevel;
    const maxPanX = Math.max(0, (scaledSize - rect.width) / 2);
    const maxPanY = Math.max(0, (scaledSize - rect.height) / 2);
    mapPanX = Math.min(maxPanX, Math.max(-maxPanX, mapPanX));
    mapPanY = Math.min(maxPanY, Math.max(-maxPanY, mapPanY));
}

function applyMapTransform() {
    const canvas = document.getElementById('map-canvas');
    if (canvas) canvas.style.transform = `translate(${mapPanX}px, ${mapPanY}px) scale(${mapZoomLevel})`;
}

function mapZoom(direction) {
    mapZoomLevel = Math.min(4, Math.max(1, +(mapZoomLevel + direction * 0.5).toFixed(2)));
    if (mapZoomLevel === 1) { mapPanX = 0; mapPanY = 0; }
    clampMapPan();
    applyMapTransform();
}

function mapResetView() {
    mapZoomLevel = 1; mapPanX = 0; mapPanY = 0;
    applyMapTransform();
}

function onMapWheel(e) {
    e.preventDefault();
    mapZoom(e.deltaY > 0 ? -1 : 1);
}

// Map layers: dispatch calls / pins can be hidden so they don't cover the
// on-duty units ("units only" hides both). Remembered per player.
const MAP_LAYERS_KEY = 'mdt.map.layers.v1';
const mapLayers = { calls: true, markers: true };
try {
    const saved = JSON.parse(localStorage.getItem(MAP_LAYERS_KEY) || 'null');
    if (saved && typeof saved === 'object') {
        if (typeof saved.calls === 'boolean') mapLayers.calls = saved.calls;
        if (typeof saved.markers === 'boolean') mapLayers.markers = saved.markers;
    }
} catch (e) { /* storage blocked — defaults */ }

function applyMapLayers() {
    const wrap = document.getElementById('map-wrap');
    if (!wrap) return;
    const unitsOnly = !mapLayers.calls && !mapLayers.markers;
    wrap.classList.toggle('hide-calls', !mapLayers.calls);
    wrap.classList.toggle('hide-markers', !mapLayers.markers);
    document.getElementById('map-layer-units')?.classList.toggle('active', unitsOnly);
    document.getElementById('map-layer-calls')?.classList.toggle('active', mapLayers.calls);
    document.getElementById('map-layer-markers')?.classList.toggle('active', mapLayers.markers);
    // a hidden call / pin can't stay open in the info panel
    const panel = document.getElementById('map-info-panel');
    if (panel && !panel.classList.contains('hidden') && !selectedMapOfficer) closeMapInfoPanel();
}

function saveMapLayers() {
    try { localStorage.setItem(MAP_LAYERS_KEY, JSON.stringify(mapLayers)); } catch (e) {}
    applyMapLayers();
}

function toggleMapLayer(layer) {
    mapLayers[layer] = !mapLayers[layer];
    saveMapLayers();
}

function toggleUnitsOnly() {
    const unitsOnly = !mapLayers.calls && !mapLayers.markers;
    mapLayers.calls = unitsOnly;
    mapLayers.markers = unitsOnly;
    saveMapLayers();
    showToast(unitsOnly ? 'Showing units, calls and pins.' : 'Showing on-duty officers only.', 'primary');
}

function setMapTool(tool) {
    mapTool = tool;
    document.getElementById('map-tool-pan')?.classList.toggle('active', tool === 'pan');
    document.getElementById('map-tool-pin')?.classList.toggle('active', tool === 'pin');
}

function clientToNormalized(clientX, clientY) {
    const canvas = document.getElementById('map-canvas');
    const rect = canvas.getBoundingClientRect();
    const nx = (clientX - rect.left) / rect.width;
    const ny = (clientY - rect.top) / rect.height;
    return { x: Math.min(1, Math.max(0, nx)), y: Math.min(1, Math.max(0, ny)) };
}

const PIN_COLORS = ['#3b9dfb', '#ef4444', '#f59e0b', '#22c55e', '#a855f7', '#eef1f6'];
let lastPinColor = PIN_COLORS[0];

function onMapPointerDown(e) {
    if (e.target.closest('.map-pin') || e.target.closest('.map-marker-pin') || e.target.closest('.map-call')
        || e.target.closest('.map-controls') || e.target.closest('.map-toolbar') || e.target.closest('.map-info-panel')
        || e.target.closest('.map-legend')) return;

    if (mapTool === 'pin') {
        const pt = clientToNormalized(e.clientX, e.clientY);
        // The label is asked INSIDE the tablet (no browser prompt window).
        mdtPrompt({
            title: 'Drop a pin',
            icon: '📍',
            message: 'Shared live with every on-duty officer on the tactical map.',
            label: 'Pin label (optional)',
            placeholder: 'e.g. Roadblock, Staging area, Suspect last seen…',
            maxLength: 60,
            colors: PIN_COLORS,
            color: lastPinColor,
            confirmText: 'Drop Pin'
        }).then(res => {
            if (!res) return;
            lastPinColor = res.color || lastPinColor;
            nuiPost('mapAddMarker', { kind: 'pin', x: pt.x, y: pt.y, label: res.value || '', color: lastPinColor });
        });
        return;
    }

    mapDragging = true;
    mapDragStartX = e.clientX; mapDragStartY = e.clientY;
    mapPanStartX = mapPanX; mapPanStartY = mapPanY;
}

function onMapPointerMove(e) {
    if (!mapDragging) return;
    mapPanX = mapPanStartX + (e.clientX - mapDragStartX);
    mapPanY = mapPanStartY + (e.clientY - mapDragStartY);
    clampMapPan();
    applyMapTransform();
}

function onMapPointerUp() { mapDragging = false; }

let mapResizeHandlerBound = null;

function initMapApp() {
    mapZoomLevel = 1; mapPanX = 0; mapPanY = 0; selectedMapOfficer = null; mapTool = 'pan';
    nuiPost('mapSubscribe');
    sizeMapCanvas();
    applyMapTransform();
    renderMapPins();
    renderMapMarkers();
    renderMapCalls();
    applyMapLayers();
    if (mapFocusCallId) {
        // opened from a dispatch call: make sure calls are visible
        if (!mapLayers.calls) { mapLayers.calls = true; saveMapLayers(); }
        focusMapCall(mapFocusCallId); mapFocusCallId = null;
    }

    const wrap = document.getElementById('map-wrap');
    if (!wrap) return;
    wrap.addEventListener('wheel', onMapWheel, { passive: false });
    wrap.addEventListener('pointerdown', onMapPointerDown);
    window.addEventListener('pointermove', onMapPointerMove);
    window.addEventListener('pointerup', onMapPointerUp);
    mapResizeHandlerBound = () => { sizeMapCanvas(); clampMapPan(); applyMapTransform(); };
    window.addEventListener('resize', mapResizeHandlerBound);
}

function teardownMapApp() {
    nuiPost('mapUnsubscribe');
    const wrap = document.getElementById('map-wrap');
    if (wrap) {
        wrap.removeEventListener('wheel', onMapWheel);
        wrap.removeEventListener('pointerdown', onMapPointerDown);
    }
    window.removeEventListener('pointermove', onMapPointerMove);
    window.removeEventListener('pointerup', onMapPointerUp);
    if (mapResizeHandlerBound) { window.removeEventListener('resize', mapResizeHandlerBound); mapResizeHandlerBound = null; }
    state.mapOfficers = [];
    state.mapMarkers = [];
    selectedMapOfficer = null;
}

function safeColor(c) { return /^#[0-9a-fA-F]{6}$/.test(c || '') ? c : '#3b9dfb'; }

function renderMapMarkers() {
    const layer = document.getElementById('map-markers-layer');
    if (!layer) return;
    layer.innerHTML = (state.mapMarkers || []).map(m => {
        const color = safeColor(m.color);
        return `
            <div class="map-marker-pin" style="left:${m.x * 100}%; top:${m.y * 100}%; --pin:${color};" onclick="selectMapMarker(${Number(m.id)})">
                <span class="map-marker-pin-dot" title="${escapeHtml(m.label || 'Marker')} — ${escapeHtml(m.author)}"></span>
                ${m.label ? `<span class="map-marker-pin-label">${escapeHtml(m.label)}</span>` : ''}
            </div>
        `;
    }).join('');
}

// Normalized (0..1) map point → GTA world coords (inverse of worldToMapPercent).
function normalizedToWorld(nx, ny) {
    const b = state.mapBounds || { minX: -4000, maxX: 4600, minY: -4300, maxY: 8100 };
    return { x: b.minX + nx * (b.maxX - b.minX), y: b.maxY - ny * (b.maxY - b.minY) };
}

function selectMapMarker(id) {
    const m = (state.mapMarkers || []).find(x => Number(x.id) === Number(id));
    const panel = document.getElementById('map-info-panel');
    if (!m || !panel) return;
    selectedMapOfficer = null;
    const canClear = state.selfCitizenId && (m.citizenid === state.selfCitizenId || state.isCommandStaff);
    panel.classList.remove('hidden');
    panel.innerHTML = `
        <button class="map-info-close" onclick="closeMapInfoPanel()">✕</button>
        <strong><span class="pin-swatch" style="background:${safeColor(m.color)}"></span>${escapeHtml(m.label || 'Unlabeled pin')}</strong>
        <small>Dropped by ${escapeHtml(m.author)}</small>
        <div class="map-info-actions">
            <button class="btn btn-accent btn-sm" onclick="doGpsMapMarker(${Number(m.id)})">📍 Set GPS</button>
            ${canClear ? `<button class="btn btn-danger btn-sm" onclick="doClearMapMarker(${Number(m.id)})">Remove Pin</button>` : ''}
        </div>
    `;
}

function doGpsMapMarker(id) {
    const m = (state.mapMarkers || []).find(x => Number(x.id) === Number(id));
    if (!m) return;
    const w = normalizedToWorld(m.x, m.y);
    nuiPost('setWaypoint', { x: w.x, y: w.y, label: m.label || 'Map pin' });
}

function doClearMapMarker(id) { nuiPost('mapClearMarker', { id }); closeMapInfoPanel(); }
function doClearAllMapMarkers() {
    mdtConfirm({ title: 'Clear the tactical board?', message: 'Removes every pin for every officer.', confirmText: 'Clear All', danger: true })
        .then(ok => { if (ok) nuiPost('mapClearAllMarkers'); });
}

// ---- Dispatch calls on the tactical map (coloured by priority) ----
let mapFocusCallId = null;

function renderMapCalls() {
    const layer = document.getElementById('map-calls-layer');
    const calls = (typeof dsp !== 'undefined' && dsp.calls) ? dsp.calls : [];
    const countEl = document.getElementById('map-legend-calls');
    if (countEl) countEl.textContent = calls.length;
    if (!layer) return;
    layer.innerHTML = calls.filter(c => c.coords).map(c => {
        const pos = worldToMapPercent(c.coords.x, c.coords.y);
        return `
            <div class="map-call pri-${escapeHtml(c.priority)}" style="left:${pos.left}%; top:${pos.top}%;" onclick="selectMapCall('${escapeHtml(c.id)}')" title="${escapeHtml(c.code + ' ' + c.title)}">
                <span class="map-call-ring"></span>
                <span class="map-call-core">${escapeHtml(c.code)}</span>
            </div>
        `;
    }).join('');
}

function selectMapCall(callId) {
    const call = (dsp.calls || []).find(c => c.id === callId);
    const panel = document.getElementById('map-info-panel');
    if (!call || !panel) return;
    selectedMapOfficer = null;
    const attached = dspIsAttached(call);
    panel.classList.remove('hidden');
    panel.innerHTML = `
        <button class="map-info-close" onclick="closeMapInfoPanel()">✕</button>
        <span class="pri-badge pri-${escapeHtml(call.priority)}">${PRIORITY_META[call.priority].label}</span>
        <strong>${escapeHtml(call.code)} · ${escapeHtml(call.title)}</strong>
        <small>📍 ${escapeHtml(call.street)} · ${dspAgo(call.createdAt)} · ${call.units.length} unit(s)</small>
        <small>${escapeHtml(call.description)}</small>
        <div class="map-info-actions">
            ${attached ? `<button class="btn btn-ghost btn-sm" onclick="dspDetach('${escapeHtml(call.id)}')">Detach</button>`
                       : `<button class="btn btn-ok btn-sm" onclick="dspRespond('${escapeHtml(call.id)}')">🚓 Respond</button>`}
            <button class="btn btn-accent btn-sm" onclick="dspGps('${escapeHtml(call.id)}')">📍 GPS</button>
            <button class="btn btn-ghost btn-sm" onclick="dspOpenCall('${escapeHtml(call.id)}')">Open in Dispatch</button>
        </div>
    `;
}

function focusMapCall(callId) {
    const call = (dsp.calls || []).find(c => c.id === callId);
    if (!call || !call.coords) return;
    const pos = worldToMapPercent(call.coords.x, call.coords.y);
    mapZoomLevel = 2.5;
    mapPanX = (0.5 - pos.left / 100) * mapCanvasBaseSize * mapZoomLevel;
    mapPanY = (0.5 - pos.top / 100) * mapCanvasBaseSize * mapZoomLevel;
    clampMapPan();
    applyMapTransform();
    selectMapCall(callId);
}

function renderMapPins() {
    const layer = document.getElementById('map-pins-layer');
    const countEl = document.getElementById('map-legend-count');
    if (countEl) countEl.textContent = state.mapOfficers.length;
    if (!layer) return;

    layer.innerHTML = state.mapOfficers.map(o => {
        const pos = worldToMapPercent(o.coords.x, o.coords.y);
        const self = state.selfCitizenId && o.citizenid === state.selfCitizenId;
        return `
            <div class="map-pin${self ? ' map-pin-self' : ''}" style="left:${pos.left}%; top:${pos.top}%;"
                 onclick="selectMapOfficer('${o.citizenid}')" title="${escapeHtml(o.name)}">
                <span class="map-pin-dot"></span>
                <span class="map-pin-label">${escapeHtml(initials(o.name))}</span>
            </div>
        `;
    }).join('');

    if (selectedMapOfficer) {
        const fresh = state.mapOfficers.find(o => o.citizenid === selectedMapOfficer);
        if (fresh) renderMapInfoPanel(fresh); else closeMapInfoPanel();
    }
}

function selectMapOfficer(citizenid) {
    selectedMapOfficer = citizenid;
    const officer = state.mapOfficers.find(o => o.citizenid === citizenid);
    if (officer) renderMapInfoPanel(officer);
}

function closeMapInfoPanel() {
    if (typeof mapFocusCallId !== 'undefined') mapFocusCallId = null;
    selectedMapOfficer = null;
    const panel = document.getElementById('map-info-panel');
    if (panel) panel.classList.add('hidden');
}

function renderMapInfoPanel(o) {
    const panel = document.getElementById('map-info-panel');
    if (!panel) return;
    const self = state.selfCitizenId && o.citizenid === state.selfCitizenId;
    // Mirrors the exact server rule for personnel actions (grade9+ AND
    // strictly below your own rank) so this never shows a button that the
    // server would just reject anyway.
    const canAct = state.isCommandStaff && !self && o.gradeLevel < state.selfGradeLevel;

    panel.classList.remove('hidden');
    panel.innerHTML = `
        <button class="map-info-close" onclick="closeMapInfoPanel()">✕</button>
        <strong>${escapeHtml(o.name)}</strong>${self ? ' <span class="tag tag-normal">You</span>' : ''}
        <small>Rank: ${escapeHtml(o.gradeName)}</small>
        <div class="map-info-actions">
            <button class="btn btn-ghost btn-sm" onclick="doViewBodycam(${o.serverId})">🎥 Bodycam</button>
            ${canAct ? `
                <button class="btn btn-accent btn-sm" onclick="doUpdateGrade('${o.citizenid}','promote')">Promote</button>
                <button class="btn btn-warn btn-sm" onclick="doUpdateGrade('${o.citizenid}','demote')">Demote</button>
                <button class="btn btn-danger btn-sm" onclick="doFireEmployee('${o.citizenid}')">Terminate</button>
            ` : ''}
        </div>
    `;
}

function doViewBodycam(serverId) {
    nuiPost('viewBodycam', { serverId });
    showToast('Requesting bodycam feed…', 'primary');
}

// ===========================================================================
// Reports
// ===========================================================================

function reportItemHtml(r) {
    // Mirrors the server rule exactly (author OR command staff) so a low-rank
    // officer never sees a delete control that the server will just reject —
    // that mismatch used to render a dead-looking button on every report.
    const isAuthor = state.selfCitizenId && r.citizenid === state.selfCitizenId;
    const canDelete = isAuthor || state.isCommandStaff;

    return `
        <div class="list-item" style="align-items:flex-start;">
            <div class="list-item-main">
                <strong>${escapeHtml(r.title)}</strong>
                <span class="tag tag-normal">${escapeHtml(r.report_type)}</span>
                <small>Filed by ${escapeHtml(r.author_name)} (${escapeHtml(r.citizenid)}) · ${formatDate(r.created_at)}</small>
                ${r.involved ? `<small><strong>Involved:</strong> ${escapeHtml(r.involved)}</small>` : ''}
                <small style="white-space:pre-wrap;">${escapeHtml(r.details)}</small>
            </div>
            ${canDelete ? `
                <div class="list-item-actions">
                    <button class="btn btn-danger btn-sm" onclick="deleteReport(${r.id})" title="Delete report">✕</button>
                </div>` : ''}
        </div>
    `;
}

function renderReports() {
    const loading = state.reports === null;
    if (loading) nuiPost('getReports');
    const reports = state.reports || [];

    const typeOptions = REPORT_TYPES.map(t => `<option value="${t}">${t}</option>`).join('');

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">File New Report</div>
            <div class="field-row">
                <div class="field">
                    <label>Title</label>
                    <input id="report-title" type="text" maxlength="150" placeholder="e.g. Vehicle pursuit on Vinewood Blvd">
                </div>
                <div class="field" style="max-width:180px;">
                    <label>Type</label>
                    <select id="report-type">${typeOptions}</select>
                </div>
            </div>
            <div class="field">
                <label>Involved Persons / Citizen IDs</label>
                <input id="report-involved" type="text" maxlength="255" placeholder="Names or Citizen IDs, comma separated">
            </div>
            <div class="field">
                <label>Report Details</label>
                <textarea id="report-details" maxlength="2000" placeholder="Narrative, evidence, charges, notes..."></textarea>
            </div>
            <button class="btn btn-accent btn-block" id="report-submit-btn" onclick="submitReportForm()">File Report</button>
        </div>

        <div class="section-title">Filed Reports${loading ? '' : ` (${reports.length})`}</div>
        ${loading ? loadingHtml('Syncing report archive…')
            : (reports.length ? reports.map(reportItemHtml).join('') : `<div class="empty-state">No reports on file yet.</div>`)}
    `;
}

function submitReportForm() {
    const btn = document.getElementById('report-submit-btn');
    const title = document.getElementById('report-title').value.trim();
    const reportType = document.getElementById('report-type').value;
    const involved = document.getElementById('report-involved').value.trim();
    const details = document.getElementById('report-details').value.trim();

    if (!title || !details) {
        showToast('Title and report details are required.', 'error');
        return;
    }

    if (btn) { btn.disabled = true; setTimeout(() => { if (btn) btn.disabled = false; }, 2500); }
    nuiPost('submitReport', { title, reportType, involved, details });
    showToast('Report submitted.', 'success');
}

function deleteReport(id) {
    nuiPost('deleteReport', { id });
}

// ===========================================================================
// BOLO / Be-On-The-Lookout board
// ===========================================================================

function boloItemHtml(b) {
    const isAuthor = state.selfCitizenId && b.citizenid === state.selfCitizenId;
    const isActive = b.active === undefined || Number(b.active) === 1;
    const canClear = isActive && (isAuthor || state.isCommandStaff);
    const priorityTag = b.priority === 'high' ? 'urgent' : (b.priority === 'low' ? 'normal' : 'important');

    return `
        <div class="list-item priority-${priorityTag}" style="align-items:flex-start; ${isActive ? '' : 'opacity:0.55;'}">
            <div class="list-item-main">
                <strong>${escapeHtml(b.subject_name || 'Unidentified Subject')}</strong>
                ${b.vehicle_plate ? `<span class="tag tag-normal">Plate: ${escapeHtml(b.vehicle_plate)}</span>` : ''}
                <span class="tag tag-${priorityTag}">${escapeHtml((b.priority || 'normal').toUpperCase())}</span>
                <small>Issued by ${escapeHtml(b.author_name)} · ${formatDate(b.created_at)}${isActive ? '' : ' · CLEARED'}</small>
                ${b.subject_desc ? `<small><strong>Description:</strong> ${escapeHtml(b.subject_desc)}</small>` : ''}
                <small style="white-space:pre-wrap;">${escapeHtml(b.reason)}</small>
            </div>
            ${canClear ? `<div class="list-item-actions"><button class="btn btn-ok btn-sm" onclick="doClearBolo(${b.id})">Clear</button></div>` : ''}
        </div>
    `;
}

function renderBolo() {
    const loading = state.bolos === null;
    if (loading) nuiPost('getBolos');
    const bolos = state.bolos || [];
    const priorityOptions = BOLO_PRIORITIES
        .map(p => `<option value="${p}"${p === 'normal' ? ' selected' : ''}>${p.charAt(0).toUpperCase() + p.slice(1)}</option>`)
        .join('');

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Issue New BOLO</div>
            <div class="field-row">
                <div class="field">
                    <label>Subject Name</label>
                    <input id="bolo-subject" type="text" maxlength="150" placeholder="e.g. John Doe">
                </div>
                <div class="field" style="max-width:160px;">
                    <label>Vehicle Plate</label>
                    <input id="bolo-plate" type="text" maxlength="20" placeholder="ABC123">
                </div>
            </div>
            <div class="field">
                <label>Description</label>
                <input id="bolo-desc" type="text" maxlength="255" placeholder="Clothing, vehicle color, distinguishing features…">
            </div>
            <div class="field-row">
                <div class="field">
                    <label>Reason</label>
                    <input id="bolo-reason" type="text" maxlength="500" placeholder="Why is this person/vehicle being flagged?">
                </div>
                <div class="field" style="max-width:140px;">
                    <label>Priority</label>
                    <select id="bolo-priority">${priorityOptions}</select>
                </div>
            </div>
            <button class="btn btn-danger btn-block" onclick="doSubmitBolo()">Broadcast BOLO</button>
        </div>

        <div class="section-title">Active &amp; Recent BOLOs (${bolos.length})</div>
        ${loading ? loadingHtml('Pulling BOLO board…')
            : (bolos.length ? bolos.map(boloItemHtml).join('') : `<div class="empty-state">No BOLOs on record.</div>`)}
    `;
}

function doSubmitBolo() {
    const subjectName = document.getElementById('bolo-subject').value.trim();
    const vehiclePlate = document.getElementById('bolo-plate').value.trim();
    const subjectDesc = document.getElementById('bolo-desc').value.trim();
    const reason = document.getElementById('bolo-reason').value.trim();
    const priority = document.getElementById('bolo-priority').value;

    if (!reason || (!subjectName && !vehiclePlate)) {
        showToast('Enter a reason plus at least a subject name or plate.', 'error');
        return;
    }

    nuiPost('submitBolo', { subjectName, vehiclePlate, subjectDesc, reason, priority });
    ['bolo-subject', 'bolo-plate', 'bolo-desc', 'bolo-reason'].forEach(id => { document.getElementById(id).value = ''; });
}

function doClearBolo(id) { nuiPost('clearBolo', { id }); }

// ===========================================================================
// Directives / Circulars
// ===========================================================================

function directiveItemHtml(d) {
    return `
        <div class="list-item priority-${d.priority}" style="align-items:flex-start;">
            <div class="list-item-main">
                <span class="tag tag-${d.priority}">${d.priority}</span>
                <strong>${escapeHtml(d.title)}</strong>
                <small>Issued by ${escapeHtml(d.posted_by)} · ${formatDate(d.created_at)}</small>
                <small style="white-space:pre-wrap;">${escapeHtml(d.body)}</small>
            </div>
            ${state.isCommandStaff ? `
                <div class="list-item-actions">
                    <button class="btn btn-danger btn-sm" onclick="deleteDirective(${d.id})" title="Retract directive">✕</button>
                </div>` : ''}
        </div>
    `;
}

function renderDirectives() {
    const loading = state.directives === null;
    if (loading) nuiPost('getDirectives');
    const directives = state.directives || [];

    const composer = state.isCommandStaff ? `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Publish Directive</div>
            <div class="field-row">
                <div class="field" style="flex:2;">
                    <label>Title</label>
                    <input id="directive-title" type="text" maxlength="150" placeholder="e.g. Updated pursuit policy">
                </div>
                <div class="field">
                    <label>Priority</label>
                    <select id="directive-priority">
                        <option value="normal">Normal</option>
                        <option value="important">Important</option>
                        <option value="urgent">Urgent</option>
                    </select>
                </div>
            </div>
            <div class="field">
                <label>Body</label>
                <textarea id="directive-body" maxlength="2000" placeholder="Directive text sent to the whole department..."></textarea>
            </div>
            <button class="btn btn-accent btn-block" onclick="postDirectiveForm()">Publish to Department</button>
        </div>
    ` : '';

    return `
        ${composer}
        <div class="section-title">Department Directives${loading ? '' : ` (${directives.length})`}</div>
        ${loading ? loadingHtml('Pulling latest directives…')
            : (directives.length ? directives.map(directiveItemHtml).join('') : `<div class="empty-state">No directives have been issued.</div>`)}
    `;
}

function postDirectiveForm() {
    const title = document.getElementById('directive-title').value.trim();
    const priority = document.getElementById('directive-priority').value;
    const body = document.getElementById('directive-body').value.trim();

    if (!title || !body) {
        showToast('Title and directive body are required.', 'error');
        return;
    }

    nuiPost('postDirective', { title, priority, body });
    showToast('Directive published.', 'success');
}

function deleteDirective(id) {
    nuiPost('deleteDirective', { id });
}

// ===========================================================================
// Personnel
// ===========================================================================

function dutyTag(emp) {
    const isOut = (emp.onduty === 'out' || emp.onduty === false);
    if (isOut) return `<span class="tag tag-away">Offline</span>`;
    const isOn = emp.onduty === true || emp.onduty === 1 || emp.onduty === 'true' || emp.onduty === undefined;
    return isOn ? `<span class="tag tag-on">On-Duty</span>` : `<span class="tag tag-off">Off-Duty</span>`;
}

function renderPersonnel() {
    if (!state.employees.length) {
        return `<div class="empty-state">No registered personnel found.</div>`;
    }

    const historyBtn = state.isCommandStaff ? `<button class="btn btn-ghost btn-sm" onclick="togglePersonnelHistory()">${personnelHistoryOpen ? 'Roster' : '🕘 History'}</button>` : '';

    if (personnelHistoryOpen && state.isCommandStaff) {
        const loading = state.personnelHistory === null;
        const rows = state.personnelHistory || [];
        return `<div style="text-align:right; margin-bottom:8px;">${historyBtn}</div>` +
            (loading ? loadingHtml('Pulling personnel history…')
                : (rows.length ? rows.map(r => `
                    <div class="list-item"><div class="list-item-main">
                        <strong>${escapeHtml(r.action)}</strong>
                        <small>${escapeHtml(r.officer_name)}${r.details ? ' · ' + escapeHtml(r.details) : ''}</small>
                        <small>${formatDate(r.created_at)}</small>
                    </div></div>
                `).join('') : `<div class="empty-state">No personnel actions recorded yet.</div>`));
    }

    return `<div style="text-align:right; margin-bottom:8px;">${historyBtn}</div>` + state.employees.map(emp => {
        const gradeName = (emp.grade && (emp.grade.name || emp.grade.label)) || (typeof emp.grade === 'string' ? emp.grade : 'Officer');
        const cid = emp.citizenid || emp.cid || 'N/A';
        const suspended = !!emp.suspended;
        const actions = state.isCommandStaff ? `
            <div class="list-item-actions" style="flex-wrap:wrap;">
                <button class="btn btn-accent btn-sm" onclick="doUpdateGrade('${cid}','promote')">Promote</button>
                <button class="btn btn-warn btn-sm" onclick="doUpdateGrade('${cid}','demote')">Demote</button>
                <button class="btn ${suspended ? 'btn-ok' : 'btn-warn'} btn-sm" onclick="doToggleSuspension('${cid}', ${suspended})">${suspended ? 'Unsuspend' : 'Suspend'}</button>
                <button class="btn btn-danger btn-sm" onclick="doFireEmployee('${cid}')">Terminate</button>
            </div>` : '';

        return `
            <div class="list-item">
                <div class="list-item-main">
                    <strong>${escapeHtml(emp.name)}</strong> ${dutyTag(emp)} ${suspended ? '<span class="tag tag-away">Suspended</span>' : ''}
                    <small>Rank: ${escapeHtml(gradeName)} · CID: ${escapeHtml(cid)}</small>
                </div>
                ${actions}
            </div>
        `;
    }).join('');
}

let personnelHistoryOpen = false;
function togglePersonnelHistory() {
    personnelHistoryOpen = !personnelHistoryOpen;
    if (personnelHistoryOpen && state.personnelHistory === null) nuiPost('getPersonnelHistory');
    renderApp('personnel');
}

function doUpdateGrade(citizenid, type) {
    if (!citizenid) return;
    nuiPost('updateGrade', { citizenid, type });
}

function doFireEmployee(citizenid) {
    if (!citizenid) return;
    mdtConfirm({ title: 'Terminate officer?', message: 'Citizen ID ' + citizenid + ' will be removed from the department.', confirmText: 'Terminate', danger: true })
        .then(ok => { if (ok) nuiPost('fireEmployee', { citizenid }); });
}

function doToggleSuspension(citizenid, currentlySuspended) {
    if (!citizenid) return;
    if (currentlySuspended) {
        nuiPost('toggleSuspension', { citizenid, reason: '' });
        return;
    }
    mdtPrompt({
        title: 'Suspend MDT access',
        icon: '⛔',
        message: 'The officer keeps their job but cannot open the tablet or receive dispatch until lifted.',
        label: 'Reason (optional)',
        placeholder: 'e.g. Pending internal investigation',
        maxLength: 200,
        confirmText: 'Suspend',
        danger: true
    }).then(res => {
        if (res) nuiPost('toggleSuspension', { citizenid, reason: res.value || '' });
    });
}

// ===========================================================================
// Vehicle Lookup (read-only plate search)
// ===========================================================================

function renderPlateResult(lookup) {
    if (!lookup.result) {
        return `<div class="card"><div class="empty-state">No vehicle registered under plate "${escapeHtml(lookup.plate)}".</div></div>`;
    }
    const r = lookup.result;
    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Registration Found</div>
            <div class="list-item">
                <div class="list-item-main">
                    <strong>${escapeHtml(r.plate)}</strong>
                    <small>Vehicle: ${escapeHtml(r.vehicle)}</small>
                    <small>Registered Owner: ${escapeHtml(r.ownerName)} (${escapeHtml(r.citizenid)})</small>
                </div>
            </div>
        </div>
    `;
}

function renderVehicleLookup() {
    const lookup = state.plateLookup;
    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Plate Lookup</div>
            <div class="field-row">
                <div class="field">
                    <label>License Plate</label>
                    <input id="plate-input" type="text" maxlength="20" placeholder="e.g. ABC123"
                           onkeydown="if(event.key==='Enter') doLookupPlate();">
                </div>
            </div>
            <button class="btn btn-accent btn-block" onclick="doLookupPlate()">Search Registration</button>
        </div>
        ${lookup ? renderPlateResult(lookup) : ''}
        <div class="hint-text">Searches the department's vehicle registration database. Read-only — no ownership changes are possible from here.</div>
    `;
}

function doLookupPlate() {
    const input = document.getElementById('plate-input');
    const plate = input.value.trim();
    if (!plate) { showToast('Enter a plate to search.', 'error'); return; }
    nuiPost('lookupPlate', { plate });
}

// ===========================================================================
// Recruitment (Command staff only — grade gate enforced server-side too)
// ===========================================================================

function applicationItemHtml(app) {
    const actions = app.status === 'Pending' ? `
        <div class="list-item-actions">
            <button class="btn btn-ok btn-sm" onclick="doHandleApplication(${app.id},'accept')">Accept</button>
            <button class="btn btn-danger btn-sm" onclick="doHandleApplication(${app.id},'reject')">Reject</button>
        </div>` : `<span class="tag tag-away">Reviewed</span>`;

    return `
        <div class="list-item priority-${app.status === 'Accepted' ? 'normal' : app.status === 'Rejected' ? 'urgent' : 'important'}">
            <div class="list-item-main">
                <strong>${escapeHtml(app.applicant_name)} (Age ${escapeHtml(String(app.applicant_age))})</strong>
                <small>Experience: ${escapeHtml(app.experience)}</small>
                <small>Status: ${escapeHtml(app.status)} · CID: ${escapeHtml(app.citizenid)} · ${formatDate(app.created_at)}</small>
            </div>
            ${actions}
        </div>
    `;
}

function renderRecruitment() {
    if (!state.isCommandStaff) {
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Command Access Required</strong>Recruitment is restricted to Grade ${state.minCommandGrade}+ (Captain and above).</div>`;
    }

    // Matches the server rule exactly: you can only assign a rank strictly
    // below your own (gradeLevel >= bossGrade is rejected server-side), so
    // offering anything else here would just be a dead option that fails.
    const gradeOptions = Array.from({ length: Math.max(state.selfGradeLevel, 1) }, (_, i) => i)
        .map(g => `<option value="${g}">Grade ${g}</option>`).join('');

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Direct Recruitment</div>
            <button class="btn btn-ok btn-block" onclick="doHireNearby()">Recruit Nearest Civilian</button>
            <div class="hint-text">Recruits nearby the requesting officer at the base rank.</div>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Manual Identifier Hiring</div>
            <div class="field-row">
                <div class="field">
                    <label>Citizen ID</label>
                    <input id="hire-cid" type="text" placeholder="e.g. ABC12345">
                </div>
                <div class="field" style="max-width:160px;">
                    <label>Rank</label>
                    <select id="hire-grade">${gradeOptions}</select>
                </div>
            </div>
            <button class="btn btn-accent btn-block" onclick="doHireByCid()">Authorize Hire</button>
        </div>

        <div class="section-title">Recruitment Applications (${state.applications.length})</div>
        ${state.applications.length ? state.applications.map(applicationItemHtml).join('') : `<div class="empty-state">No active applications pending review.</div>`}
    `;
}

function doHireNearby() { nuiPost('hireNearby'); }

function doHireByCid() {
    const citizenid = document.getElementById('hire-cid').value.trim();
    const grade = parseInt(document.getElementById('hire-grade').value, 10);
    if (!citizenid) { showToast('Enter a Citizen ID.', 'error'); return; }
    nuiPost('hireByCitizenId', { citizenid, grade });
    document.getElementById('hire-cid').value = '';
}

function doHandleApplication(appId, actionType) {
    nuiPost('handleApplication', { appId, actionType });
}

// ===========================================================================
// Finance / Treasury (Command staff only)
// ===========================================================================

function renderFinance() {
    if (!state.isCommandStaff) {
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Command Access Required</strong>Treasury access is restricted to Grade ${state.minCommandGrade}+ (Captain and above).</div>`;
    }

    return `
        <div class="card stat-card">
            <div class="stat-label">Treasury Balance</div>
            <div class="stat-value">${formatMoney(state.money)}</div>
        </div>
        <div class="card">
            <div class="section-title" style="margin-top:0;">Financial Operations</div>
            <div class="field">
                <label>Amount</label>
                <input id="finance-amount" type="number" min="1" placeholder="Enter amount...">
            </div>
            <div class="field-row">
                <button class="btn btn-accent btn-block" onclick="doDeposit()">Deposit</button>
                <button class="btn btn-warn btn-block" onclick="doWithdraw()">Withdraw</button>
            </div>
            <div class="hint-text">Both deposits and withdrawals are restricted to Grade ${state.minCommandGrade}+.</div>
        </div>
    `;
}

function doDeposit() {
    const val = Number(document.getElementById('finance-amount').value);
    if (!val || val <= 0) return;
    nuiPost('depositMoney', { amount: val });
    document.getElementById('finance-amount').value = '';
}

function doWithdraw() {
    const val = Number(document.getElementById('finance-amount').value);
    if (!val || val <= 0) return;
    nuiPost('withdrawMoney', { amount: val });
    document.getElementById('finance-amount').value = '';
}

// ===========================================================================
// Tactical Ops (Boss only, unchanged permissions)
// ===========================================================================

function renderTactical() {
    if (!state.isBoss) {
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Boss Access Required</strong>Tactical Operations are restricted to department leadership.</div>`;
    }

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Broadcast Department Directive</div>
            <textarea id="dept-message" placeholder="Type encrypted priority broadcast for all units..."></textarea>
            <button class="btn btn-accent btn-block" style="margin-top:10px;" onclick="sendDepartmentAlert()">Transmit Broadcast</button>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Threat Condition Level</div>
            <div class="alert-buttons">
                <button class="btn btn-ok" onclick="setAlertLevel('green')">Code Green</button>
                <button class="btn btn-warn" onclick="setAlertLevel('yellow')">Code Yellow</button>
                <button class="btn btn-danger" onclick="setAlertLevel('red')">Code Red</button>
            </div>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Advanced Command Operations</div>
            <div class="field-row" style="flex-wrap:wrap;">
                <button class="btn btn-accent" onclick="triggerBossAction('toggleOnDutyGPS')">Toggle On-Duty Tracking</button>
                <button class="btn btn-warn" onclick="triggerBossAction('lockdownDept')">Toggle Facility Lockdown</button>
                <button class="btn btn-ok" onclick="triggerBossAction('requestBackupAll')">Global Code 99 Backup</button>
                <button class="btn btn-danger" onclick="triggerBossAction('clearDepartmentBlips')">Purge Tactical Blips</button>
            </div>
            <div class="hint-text">On-Duty Tracking shows live GPS blips for on-duty officers only — never off-duty or offline personnel.</div>
        </div>
    `;
}

function sendDepartmentAlert() {
    const input = document.getElementById('dept-message');
    if (input && input.value.trim() !== '') {
        nuiPost('sendAlertMessage', { message: input.value.trim() });
        showToast('Broadcast transmitted.', 'success');
        input.value = '';
    }
}

function setAlertLevel(level) {
    state.alertLevel = level;
    renderAlertPill();
    nuiPost('setAlertLevel', { level });
    showToast('Threat condition set to CODE ' + level.toUpperCase(), level === 'red' ? 'error' : 'success');
}

function triggerBossAction(actionName) {
    nuiPost('triggerBossAction', { action: actionName });
}

// ===========================================================================
// Cameras (Boss only, unchanged permissions)
// ===========================================================================

function renderCameras() {
    if (!state.isBoss) {
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Boss Access Required</strong>CCTV access is restricted to department leadership.</div>`;
    }
    if (!state.cameras.length) {
        return `<div class="empty-state">No cameras configured.</div><div class="hint-text" style="text-align:center;">Select a feed to switch your view to that camera. While viewing: A / D to pan (slow, limited sweep), Backspace to return here.</div>`;
    }

    return `
        <div class="hint-text" style="margin-bottom:14px;">Select a feed to switch your view to that camera. While viewing: A / D to pan (slow, limited sweep), Backspace to return here.</div>
        ${state.cameras.map(cam => `
            <div class="list-item">
                <div class="list-item-main">
                    <strong>🎥 ${escapeHtml(cam.name)}</strong>
                    <small>Feed #${cam.id}</small>
                </div>
                <div class="list-item-actions">
                    <button class="btn btn-ok btn-sm" onclick="viewCamera(${cam.id})">View Feed</button>
                </div>
            </div>
        `).join('')}
    `;
}

function viewCamera(id) { nuiPost('viewCamera', { id }); }

// ===========================================================================
// About
// ===========================================================================

function renderAbout() {
    return `
        <div class="card" style="text-align:center; padding: 30px 20px;">
            <span class="dept-logo dept-logo-md" style="display:flex; margin:0 auto 10px;">
                <img src="img/logo.png" alt="" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';">
                <span class="dept-logo-fallback">🛡️</span>
            </span>
            <div style="font-family:'Orbitron',sans-serif; font-weight:800; font-size:16px;">Los Santos Police Department</div>
            <div class="hint-text">Mobile Data Terminal · Unit-Issued Tablet</div>
        </div>
        <div class="card">
            <div class="stat-row" style="grid-template-columns:1fr;">
                <div>
                    <div class="section-title" style="margin-top:0;">Signed In As</div>
                    <div>${escapeHtml(state.selfName)} — ${escapeHtml(state.selfGrade)}</div>
                </div>
            </div>
        </div>
        <div class="card">
            <div class="section-title" style="margin-top:0;">System</div>
            <div class="hint-text">MDT Software v8.0.0 · Command clearance: Grade ${state.minCommandGrade}+ · Session encrypted end-to-end.</div>
        </div>
        <div class="card">
            <div class="section-title" style="margin-top:0;">What's New</div>
            <div class="hint-text">The Command Hub (roster, duty, callsign, status, panic, comms) and a full Dispatch CAD now live inside this tablet. Calls are ranked Blue (low) · Yellow (medium) · Red (high), each with its own alert tone — and they reach you even with the tablet closed, as long as it's in your inventory.</div>
        </div>
    `;
}

// ===========================================================================
// CCTV overlay (unchanged behaviour)
// ===========================================================================

let cameraClockInterval = null;

function openCameraOverlay(name) {
    const overlay = document.getElementById('camera-overlay');
    const nameEl = document.getElementById('camera-name');
    const container = document.getElementById('boss-container');

    if (container) container.classList.add('hidden');
    if (nameEl) nameEl.innerText = name || 'Camera';
    if (overlay) overlay.classList.remove('hidden');

    updateCameraPanIndicator(0);
    updateCameraTimestamp();
    if (cameraClockInterval) clearInterval(cameraClockInterval);
    cameraClockInterval = setInterval(updateCameraTimestamp, 1000);
}

function closeCameraOverlay() {
    const overlay = document.getElementById('camera-overlay');
    if (overlay) overlay.classList.add('hidden');
    if (cameraClockInterval) {
        clearInterval(cameraClockInterval);
        cameraClockInterval = null;
    }
}

function updateCameraTimestamp() {
    const el = document.getElementById('camera-timestamp');
    if (!el) return;
    el.innerText = new Date().toLocaleTimeString('en-GB');
}

// sweep is -1..1 (fully left .. fully right); 0 is centered
function updateCameraPanIndicator(sweep) {
    const fill = document.getElementById('camera-pan-fill');
    if (!fill) return;
    const clamped = Math.max(-1, Math.min(1, sweep || 0));
    const percent = 50 + (clamped * 50);
    fill.style.left = percent + '%';
}

// ===========================================================================
// Admin activity log console (/mdtlog — admin permission enforced server-side)
// ===========================================================================

// NOTE: /mdtlog admin console removed — important actions now go to Discord (server-side).

// ===========================================================================
// Misc wiring
// ===========================================================================

// Small tactile "ripple" on tap for icons/buttons — pure visual polish.
document.getElementById('screen').addEventListener('click', (e) => {
    const target = e.target.closest('.app-icon-tile, .btn');
    if (!target) return;
    const rect = target.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height) * 1.4;
    const span = document.createElement('span');
    span.className = 'ripple';
    span.style.width = span.style.height = size + 'px';
    span.style.left = (e.clientX - rect.left - size / 2) + 'px';
    span.style.top = (e.clientY - rect.top - size / 2) + 'px';
    target.appendChild(span);
    setTimeout(() => span.remove(), 520);
});

// Allow Escape as a shortcut back to the pause-menu-style close, matching
// the original resource's UX for anyone used to the old boss menu.
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && state.opened) closeMenu();
});
