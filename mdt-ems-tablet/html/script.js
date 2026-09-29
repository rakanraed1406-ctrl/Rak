// ===========================================================================
// State
// ===========================================================================

const state = {
    opened: false,
    selfName: 'Paramedic',
    selfGrade: 'Paramedic',
    selfGradeLevel: 0,
    selfCitizenId: null,
    selfPoints: null,
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
    ward: null,         // null = not yet fetched
    bills: null,
    mapBounds: null,
    mapOfficers: [],
    mapMarkers: [],
    patientSearch: null,   // { query, results } | null = nothing searched yet
    patientProfile: null,  // full profile of the selected patient
    nearbyPatients: null,  // players next to you (billing / quick lookup)
    personnelHistory: null,
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
// clock in from the EMS Hub app).
const APPS = [
    { id: 'hub',         label: 'EMS Hub',        glyph: '🚑', tint: '#19c3b1', dock: true, allowOffDuty: true },
    { id: 'dispatch',    label: 'Dispatch',       glyph: '📡', tint: '#f43f5e', dock: true, badge: 'calls' },
    { id: 'dashboard',   label: 'Dashboard',      glyph: '📊', tint: '#60a5fa', allowOffDuty: true },
    { id: 'map',         label: 'Live Map',       glyph: '🗺️', tint: '#06b6d4', dock: true },
    { id: 'patients',    label: 'Patient Records',glyph: '🩺', tint: '#ef4444', dock: true },
    { id: 'ward',        label: 'Ward Board',     glyph: '🛏️', tint: '#a855f7', dock: true, badge: 'ward' },
    { id: 'reports',     label: 'Medical Reports',glyph: '📋', tint: '#f59e0b' },
    { id: 'billing',     label: 'Billing',        glyph: '🧾', tint: '#f97316' },
    { id: 'directives',  label: 'Directives',     glyph: '📢', tint: '#ef4444' },
    { id: 'protocols',   label: 'Protocols',      glyph: '📖', tint: '#818cf8', allowOffDuty: true },
    { id: 'personnel',   label: 'Personnel',      glyph: '👨‍⚕️', tint: '#14b8a6' },
    { id: 'recruitment', label: 'Recruitment',    glyph: '📝', tint: '#22c55e', requiresCommand: true, badge: 'applications' },
    { id: 'finance',     label: 'Treasury',       glyph: '💰', tint: '#eab308', requiresCommand: true },
    { id: 'tactical',    label: 'Command Ops',    glyph: '⚡', tint: '#f97316', requiresBoss: true },
    { id: 'cameras',     label: 'CCTV',           glyph: '🎥', tint: '#22c55e', requiresBoss: true },
    { id: 'about',       label: 'About',          glyph: 'ℹ️', tint: '#9aa3b2', allowOffDuty: true }
];

const REPORT_TYPES = ['Treatment', 'Revive', 'Transport', 'Surgery', 'Check-up', 'Death', 'Mass Casualty', 'Other'];
const WARD_SEVERITY = {
    critical: { label: 'Critical', tag: 'tag-urgent' },
    serious:  { label: 'Serious',  tag: 'tag-important' },
    stable:   { label: 'Stable',   tag: 'tag-on' }
};
const WARD_ORDER = ['critical', 'serious', 'stable'];

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

// Safe JS string literal for inline onclick="" handlers (names are player-controlled).
function jsStr(value) {
    return escapeHtml(JSON.stringify(String(value === undefined || value === null ? '' : value)));
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
    } else if (data.action === 'receiveDirectives') {
        state.directives = data.directives || [];
        if (state.currentApp === 'directives' || state.currentApp === 'dashboard') renderApp(state.currentApp);
    } else if (data.action === 'receiveWard') {
        state.ward = data.entries || [];
        // Only swap the board, so a medic typing in the admit form doesn't lose it.
        if (state.currentApp === 'ward') { if (!refreshWardBoard()) renderApp('ward'); }
        else if (state.currentApp === 'dashboard') renderApp('dashboard');
        updateDockBadges();
    } else if (data.action === 'receiveBills') {
        state.bills = data.bills || [];
        if (state.currentApp === 'billing') renderApp('billing');
    } else if (data.action === 'patientSearchResults') {
        state.patientSearch = { query: data.query, results: data.results || [] };
        if (state.currentApp === 'patients') renderApp('patients');
    } else if (data.action === 'patientProfile') {
        state.patientProfile = data.profile || null;
        patientTab = 'profile';
        if (state.currentApp === 'patients') renderApp('patients');
    } else if (data.action === 'nearbyPatients') {
        state.nearbyPatients = data.list || [];
        if (state.currentApp === 'billing' || state.currentApp === 'patients') renderApp(state.currentApp);
    } else if (data.action === 'mapOfficers') {
        state.mapOfficers = data.officers || [];
        if (state.currentApp === 'map') renderMapPins();
    } else if (data.action === 'mapMarkers') {
        state.mapMarkers = data.markers || [];
        if (state.currentApp === 'map') renderMapMarkers();
    } else if (data.action === 'personnelHistory') {
        state.personnelHistory = data.history || [];
        if (state.currentApp === 'personnel') renderApp('personnel');
    } else if (data.action === 'alertLevelChanged') {
        state.alertLevel = data.level || state.alertLevel;
        renderAlertPill();
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
    } else if (data.action === 'mdtConfig') {
        setTimeout(applyDepartmentBranding, 0); // after js/notify.js stored the config
    }
});

// Department name / logo text from Config.Department (lock screen, status bar, About).
function applyDepartmentBranding() {
    const d = (typeof mdtCfg !== 'undefined' && mdtCfg.department) || {};
    const set = (id, text) => { const el = document.getElementById(id); if (el && text) el.textContent = text; };
    set('status-dept-name', (d.Short || 'EMS') + ' MDT');
    set('lock-dept-title', d.Name);
    set('lock-dept-sub', d.Sub);
}

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
        showToast('You are off duty — clock in from the EMS Hub.', 'error');
        goHome();
    } else if (state.currentApp) {
        if (state.currentApp === 'hub' && typeof hubRefresh === 'function') hubRefresh();
        else if (state.currentApp === 'dashboard') renderApp('dashboard');
    }
}

function applyBossData(data) {
    state.selfName = data.selfName || 'Paramedic';
    state.selfGrade = data.selfGrade || 'Paramedic';
    state.selfPoints = (data.selfPoints === undefined) ? null : data.selfPoints;
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
    document.getElementById('widget-lockdown').textContent = state.isLockdown ? 'LOCKED DOWN' : 'Open';
    const dutyEl = document.getElementById('widget-duty');
    if (dutyEl) {
        dutyEl.textContent = state.selfOnDuty ? 'ON DUTY' : 'OFF DUTY';
        dutyEl.className = state.selfOnDuty ? 'txt-ok' : 'txt-danger';
    }
    const greet = document.getElementById('home-greeting-text');
    if (greet) greet.textContent = state.selfOnDuty ? 'Welcome back' : 'Off duty — clock in from the EMS Hub';
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
    if (!state.selfOnDuty && !app.allowOffDuty) return 'Clock in from the EMS Hub first';
    if (app.requiresCommand && !state.isCommandStaff) return 'Command access required (Grade ' + state.minCommandGrade + '+)';
    if (app.requiresBoss && !state.isBoss) return 'Boss access required';
    return null;
}

function appBadgeCount(app) {
    if (app.badge === 'applications') {
        return state.applications.filter(a => a.status === 'Pending').length;
    }
    if (app.badge === 'ward') {
        return (state.ward || []).filter(w => Number(w.active) === 1).length;
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
    patients: renderPatients,
    billing: renderBilling,
    reports: renderReports,
    ward: renderWard,
    directives: renderDirectives,
    personnel: renderPersonnel,
    protocols: renderProtocols,
    recruitment: renderRecruitment,
    finance: renderFinance,
    tactical: renderTactical,
    cameras: renderCameras,
    about: renderAbout
};

// Apps that need to wire up event listeners / timers after their HTML lands
// in the DOM (innerHTML alone can't carry addEventListener-based behaviour).
const APP_INIT_HOOKS = {
    map: initMapApp,
    reports: () => applyPrefill('reports'),
    ward: () => applyPrefill('ward'),
    billing: () => applyPrefill('billing')
};
// Apps that need to tear that down again when the medic navigates away.
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

const ALERT_LEVEL_TEXT = {
    green: 'Normal operations',
    yellow: 'High patient load',
    red: 'Mass casualty / at capacity'
};

function renderDashboard() {
    const directivesLoading = state.directives === null;
    if (directivesLoading) nuiPost('getDirectives');
    if (state.ward === null && state.selfOnDuty) nuiPost('getWard');
    const latestDirectives = (state.directives || []).slice(0, 3);
    const admitted = (state.ward || []).filter(w => Number(w.active) === 1);
    const critical = admitted.filter(w => w.severity === 'critical').length;

    return `
        <div class="section-title">Department Status</div>
        <div class="stat-row">
            <div class="card stat-card">
                <div class="stat-label">On-Duty Medics</div>
                <div class="stat-value">${state.onDutyCount}</div>
            </div>
            <div class="card stat-card" style="border-left-color:${critical ? 'var(--danger)' : 'var(--ok)'}">
                <div class="stat-label">Admitted Patients</div>
                <div class="stat-value" style="font-size:16px">${admitted.length} <small class="hint-text">${critical ? '· ' + critical + ' critical' : ''}</small></div>
            </div>
        </div>
        <div class="stat-row">
            <div class="card stat-card" style="border-left-color:${state.alertLevel === 'red' ? 'var(--danger)' : state.alertLevel === 'yellow' ? 'var(--warn)' : 'var(--ok)'}">
                <div class="stat-label">Hospital Alert Level</div>
                <div class="stat-value" style="font-size:16px">CODE ${state.alertLevel.toUpperCase()} <small class="hint-text">${escapeHtml(ALERT_LEVEL_TEXT[state.alertLevel] || '')}</small></div>
            </div>
            <div class="card stat-card" style="border-left-color:${state.isLockdown ? 'var(--danger)' : 'var(--ok)'}">
                <div class="stat-label">Hospital Access</div>
                <div class="stat-value" style="font-size:16px">${state.isLockdown ? '🔒 Locked Down' : '🔓 Open'}</div>
            </div>
        </div>

        <div class="section-title">Quick Access</div>
        <div class="field-row" style="flex-wrap:wrap; gap:10px;">
            <button class="btn btn-ghost" onclick="openApp('hub')">🚑 EMS Hub</button>
            <button class="btn btn-ghost" onclick="openApp('dispatch')">📡 Dispatch</button>
            <button class="btn btn-ghost" onclick="openApp('map')">🗺️ Live Map</button>
            <button class="btn btn-ghost" onclick="openApp('patients')">🩺 Patient Records</button>
            <button class="btn btn-ghost" onclick="openApp('ward')">🛏️ Ward Board</button>
            <button class="btn btn-ghost" onclick="openApp('reports')">📋 Medical Report</button>
            <button class="btn btn-ghost" onclick="openApp('billing')">🧾 Bill a Patient</button>
            <button class="btn btn-ghost" onclick="openApp('protocols')">📖 Protocols</button>
            <button class="btn btn-ghost" onclick="doOpenRadio()">📻 EMS Radio</button>
            ${state.isBoss ? `<button class="btn btn-ghost" onclick="openApp('cameras')">🎥 CCTV Feeds</button>` : ''}
            ${state.isCommandStaff ? `<button class="btn btn-ghost" onclick="openApp('finance')">💰 Treasury</button>` : ''}
        </div>

        <div class="section-title">Duty Status</div>
        <div class="card" style="display:flex; align-items:center; justify-content:space-between; gap:12px;">
            <div>
                <strong class="${state.selfOnDuty ? 'txt-ok' : 'txt-danger'}">${state.selfOnDuty ? 'On Duty' : 'Off Duty'}</strong>
                <span class="tag tag-normal" style="margin-left:6px;">${escapeHtml(state.selfCallsign)}</span>
                ${state.selfPoints !== null && state.selfPoints !== undefined ? `<span class="tag tag-important" style="margin-left:4px;">⭐ ${Number(state.selfPoints)} pts</span>` : ''}
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
// Patient Records — search, identity, blood type, insurance, live condition,
// medical notes (allergies / conditions / medications) and history.
// ===========================================================================

let patientTab = 'search'; // 'search' | 'profile'

function patientStatusTag(live) {
    if (!live) return `<span class="tag tag-away">Not in city</span>`;
    if (live.dead) return `<span class="tag tag-urgent">❤️‍🩹 No pulse</span>`;
    if (live.laststand) return `<span class="tag tag-important">🩸 Bleeding out</span>`;
    return `<span class="tag tag-on">Conscious</span>`;
}

function renderPatients() {
    if (patientTab === 'profile' && state.patientProfile) return renderPatientProfile(state.patientProfile);

    const search = state.patientSearch;
    const nearby = state.nearbyPatients;
    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Find a Patient</div>
            <div class="field-row">
                <div class="field">
                    <label>Name, Citizen ID or phone</label>
                    <input id="patient-query" type="text" maxlength="40" placeholder="e.g. John Smith · ABC12345 · 555…"
                           value="${escapeHtml(search ? search.query : '')}" onkeydown="if(event.key==='Enter') doSearchPatients();">
                </div>
            </div>
            <div class="field-row">
                <button class="btn btn-accent btn-block" onclick="doSearchPatients()"><i class="fa-solid fa-magnifying-glass"></i> Search Records</button>
                <button class="btn btn-ghost btn-block" onclick="nuiPost('nearbyPatients')"><i class="fa-solid fa-person-walking"></i> Who is next to me?</button>
            </div>
        </div>

        ${nearby ? `
        <div class="section-title">Next to you (${nearby.length})</div>
        ${nearby.length ? nearby.map(p => `
            <div class="list-item">
                <div class="list-item-main">
                    <strong>${escapeHtml(p.name)}</strong> ${patientStatusTag({ dead: p.dead, laststand: p.laststand })}
                    <small>ID ${Number(p.serverId)} · CID ${escapeHtml(p.citizenid)}</small>
                </div>
                <div class="list-item-actions"><button class="btn btn-accent btn-sm" onclick="doOpenPatient(${jsStr(p.citizenid)})">Open Record</button></div>
            </div>`).join('') : `<div class="empty-state">Nobody is standing next to you.</div>`}` : ''}

        ${search ? `
        <div class="section-title">Results for "${escapeHtml(search.query)}" (${search.results.length})</div>
        ${search.results.length ? search.results.map(p => `
            <div class="list-item">
                <div class="list-item-main">
                    <strong>${escapeHtml(p.name)}</strong> ${p.online ? '<span class="tag tag-on">In city</span>' : ''}
                    ${p.bloodtype ? `<span class="tag tag-urgent">🩸 ${escapeHtml(p.bloodtype)}</span>` : ''}
                    <small>CID ${escapeHtml(p.citizenid)} · ${escapeHtml(p.gender)}${p.dob ? ' · DOB ' + escapeHtml(p.dob) : ''}</small>
                </div>
                <div class="list-item-actions"><button class="btn btn-accent btn-sm" onclick="doOpenPatient(${jsStr(p.citizenid)})">Open Record</button></div>
            </div>`).join('') : `<div class="empty-state">No citizens match that search.</div>`}` : ''}

        ${state.patientProfile ? `<div class="hint-text" style="margin-top:10px;"><a href="#" onclick="patientTab='profile'; renderApp('patients'); return false;">↩ Back to ${escapeHtml(state.patientProfile.name)}</a></div>` : ''}
    `;
}

function renderPatientProfile(p) {
    const med = p.medical || {};
    const live = p.live;
    const ins = p.insurance || {};
    const injuries = (live && live.injuries) || null;

    const injuryHtml = !live ? '<div class="hint-text">The patient is not in the city — live condition unavailable.</div>'
        : (!injuries ? '<div class="hint-text">No injury data (qb-hospital export not available).</div>'
        : `
            ${injuries.bleeding ? `<span class="tag tag-urgent">🩸 ${escapeHtml(injuries.bleeding)}</span>` : ''}
            ${(injuries.limbs || []).length ? injuries.limbs.map(l => `<span class="tag tag-important">${escapeHtml(l.label)} · ${escapeHtml(l.state || '')}</span>`).join(' ') : '<span class="tag tag-on">No limb injuries</span>'}
            ${(injuries.weapons || []).length ? `<div class="hint-text" style="margin-top:6px;">Wound causes: ${injuries.weapons.map(escapeHtml).join(', ')}</div>` : ''}
        `);

    const history = []
        .concat((p.reports || []).map(r => ({ at: r.created_at, icon: '📋', text: `${r.report_type}: ${r.title}`, by: r.author_name })))
        .concat((p.bills || []).map(b => ({ at: b.created_at, icon: '🧾', text: `Bill $${Number(b.amount).toLocaleString()} — ${b.treatment}${Number(b.paid) === 1 ? ' (paid)' : ' (unpaid)'}`, by: b.medic_name })))
        .concat((p.ward || []).map(w => ({ at: w.created_at, icon: '🛏️', text: `Ward${w.bed ? ' bed ' + w.bed : ''}: ${w.diagnosis} [${w.severity}]${Number(w.active) === 1 ? ' — admitted' : ''}`, by: w.author_name })))
        .sort((a, b) => String(b.at).localeCompare(String(a.at)));

    return `
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
            <button class="btn btn-ghost btn-sm" onclick="patientTab='search'; renderApp('patients');">◂ Search</button>
            <button class="btn btn-ghost btn-sm" onclick="doOpenPatient(${jsStr(p.citizenid)})"><i class="fa-solid fa-rotate"></i> Refresh</button>
        </div>
        <div class="card">
            <div style="display:flex; align-items:center; gap:12px;">
                <div class="home-avatar">${escapeHtml(initials(p.name))}</div>
                <div style="flex:1;">
                    <strong style="font-size:16px;">${escapeHtml(p.name)}</strong> ${patientStatusTag(live)}
                    <div class="hint-text">CID ${escapeHtml(p.citizenid)} · ${escapeHtml(p.gender)}${p.dob ? ' · DOB ' + escapeHtml(p.dob) : ''}${p.nationality ? ' · ' + escapeHtml(p.nationality) : ''}${p.phone ? ' · ☎ ' + escapeHtml(p.phone) : ''}${live ? ' · ID ' + Number(live.serverId) : ''}</div>
                </div>
            </div>
            <div class="stat-row" style="margin-top:12px;">
                <div class="card stat-card" style="border-left-color:var(--danger)"><div class="stat-label">Blood Type</div><div class="stat-value" style="font-size:18px">${escapeHtml(p.bloodtype || '—')}</div></div>
                <div class="card stat-card" style="border-left-color:${ins.active ? 'var(--ok)' : 'var(--warn)'}"><div class="stat-label">Insurance</div><div class="stat-value" style="font-size:14px">${ins.active ? '✅ Active' : '❌ None'}${ins.expires ? `<small class="hint-text"> until ${escapeHtml(ins.expires)}</small>` : ''}</div></div>
            </div>
        </div>

        <div class="section-title">Current Condition</div>
        <div class="card">${injuryHtml}</div>

        <div class="section-title">Medical Record</div>
        <div class="card">
            <div class="field-row">
                <div class="field"><label>Allergies</label><input id="pt-allergies" type="text" maxlength="500" value="${escapeHtml(med.allergies || '')}" placeholder="e.g. Penicillin"></div>
                <div class="field"><label>Chronic conditions</label><input id="pt-conditions" type="text" maxlength="500" value="${escapeHtml(med.conditions || '')}" placeholder="e.g. Asthma, diabetes"></div>
            </div>
            <div class="field"><label>Medications</label><input id="pt-medications" type="text" maxlength="500" value="${escapeHtml(med.medications || '')}" placeholder="e.g. Insulin"></div>
            <div class="field"><label>Notes</label><textarea id="pt-notes" maxlength="2000" placeholder="Anything the next medic should know…">${escapeHtml(med.notes || '')}</textarea></div>
            <button class="btn btn-accent btn-block" onclick="doSavePatientNotes(${jsStr(p.citizenid)})"><i class="fa-solid fa-floppy-disk"></i> Save Medical Record</button>
            ${med.updated_by ? `<div class="hint-text" style="margin-top:6px;">Last updated by ${escapeHtml(med.updated_by)} · ${formatDate(med.updated_at)}</div>` : ''}
        </div>

        <div class="section-title">Quick Actions</div>
        <div class="field-row" style="flex-wrap:wrap;">
            <button class="btn btn-ghost btn-sm" onclick="startReportFor(${jsStr(p.citizenid)}, ${jsStr(p.name)})">📋 Write report</button>
            <button class="btn btn-ghost btn-sm" onclick="startAdmitFor(${jsStr(p.citizenid)}, ${jsStr(p.name)})">🛏️ Admit to ward</button>
            ${live ? `<button class="btn btn-ghost btn-sm" onclick="startBillFor(${Number(live.serverId)}, ${jsStr(p.name)})">🧾 Bill patient</button>` : ''}
        </div>

        <div class="section-title">History (${history.length})</div>
        ${history.length ? history.map(h => `
            <div class="list-item"><div class="list-item-main">
                <strong>${h.icon} ${escapeHtml(h.text)}</strong>
                <small>${escapeHtml(h.by || '')} · ${formatDate(h.at)}</small>
            </div></div>`).join('') : `<div class="empty-state">No treatments on record yet.</div>`}
    `;
}

function doSearchPatients() {
    const q = (document.getElementById('patient-query').value || '').trim();
    if (q.length < 2) { showToast('Type at least 2 characters.', 'error'); return; }
    nuiPost('searchPatients', { query: q });
}

function doOpenPatient(citizenid) {
    if (!citizenid) return;
    nuiPost('getPatientProfile', { citizenid });
    showToast('Loading record…', 'primary');
}

function doSavePatientNotes(citizenid) {
    nuiPost('savePatientNotes', {
        citizenid,
        allergies: document.getElementById('pt-allergies').value.trim(),
        conditions: document.getElementById('pt-conditions').value.trim(),
        medications: document.getElementById('pt-medications').value.trim(),
        notes: document.getElementById('pt-notes').value.trim()
    });
}

// Pre-fill other apps from a patient record.
let pendingPrefill = null;
function startReportFor(cid, name) { pendingPrefill = { app: 'reports', cid, name }; openApp('reports'); }
function startAdmitFor(cid, name) { pendingPrefill = { app: 'ward', cid, name }; openApp('ward'); }
function startBillFor(serverId, name) { pendingPrefill = { app: 'billing', serverId, name }; openApp('billing'); }

function applyPrefill(appId) {
    if (!pendingPrefill || pendingPrefill.app !== appId) return;
    const p = pendingPrefill;
    pendingPrefill = null;
    const set = (id, v) => { const el = document.getElementById(id); if (el && v !== undefined && v !== null) el.value = v; };
    if (appId === 'reports') { set('report-patient', p.name); set('report-patient-cid', p.cid); }
    if (appId === 'ward') { set('ward-patient', p.name); set('ward-patient-cid', p.cid); }
    if (appId === 'billing') { billTarget = { serverId: p.serverId, name: p.name }; renderApp('billing'); }
}

// ===========================================================================
// Billing — medical bills. Charging happens server-side (patient must be next
// to you) when Config.Billing.ChargePatient is on; otherwise it's a record.
// ===========================================================================

let billTarget = null; // { serverId, name } picked from "next to me"

function billRowHtml(b) {
    const isAuthor = state.selfCitizenId && b.citizenid === state.selfCitizenId;
    const paid = Number(b.paid) === 1;
    const canVoid = (isAuthor && !paid) || state.isCommandStaff;
    return `
        <div class="list-item" style="align-items:flex-start;">
            <div class="list-item-main">
                <strong>${escapeHtml(b.patient_name)}</strong>
                <span class="tag tag-important">$${Number(b.amount).toLocaleString()}</span>
                <span class="tag ${paid ? 'tag-on' : 'tag-away'}">${paid ? 'Paid' : 'Unpaid'}</span>
                <small>${escapeHtml(b.treatment)}</small>
                ${b.notes ? `<small>${escapeHtml(b.notes)}</small>` : ''}
                <small>By ${escapeHtml(b.medic_name)} · ${formatDate(b.created_at)}${b.patient_cid ? ' · CID ' + escapeHtml(b.patient_cid) : ''}</small>
            </div>
            ${canVoid ? `<div class="list-item-actions"><button class="btn btn-danger btn-sm" onclick="doVoidBill(${Number(b.id)})">Void</button></div>` : ''}
        </div>
    `;
}

function renderBilling() {
    const loading = state.bills === null;
    if (loading) nuiPost('getBills');
    const list = state.bills || [];
    const presets = (mdtCfg.billingPresets || []);
    const nearby = state.nearbyPatients;

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Bill a Patient</div>
            <div class="field">
                <label>Patient</label>
                ${billTarget ? `
                    <div class="list-item" style="margin:0;">
                        <div class="list-item-main"><strong>${escapeHtml(billTarget.name)}</strong><small>ID ${Number(billTarget.serverId)} — next to you</small></div>
                        <div class="list-item-actions"><button class="btn btn-ghost btn-sm" onclick="billTarget=null; renderApp('billing');">Change</button></div>
                    </div>` : `
                    <div class="field-row">
                        <button class="btn btn-ghost btn-block" onclick="nuiPost('nearbyPatients')"><i class="fa-solid fa-person-walking"></i> Pick someone next to me</button>
                    </div>
                    ${nearby ? (nearby.length ? `<div class="chip-row" style="margin-top:6px;">${nearby.map((p, i) => `<button class="chip" onclick="pickBillTarget(${i})">${escapeHtml(p.name)} · ${Number(p.serverId)}</button>`).join('')}</div>` : `<div class="hint-text">Nobody is standing next to you.</div>`) : ''}
                    <div class="field-row" style="margin-top:6px;">
                        <div class="field"><input id="bill-name" type="text" maxlength="100" placeholder="…or type the patient name (record only)"></div>
                        <div class="field" style="max-width:150px;"><input id="bill-cid" type="text" maxlength="50" placeholder="CID (optional)"></div>
                    </div>`}
            </div>
            ${presets.length ? `<div class="chip-row">${presets.map((p, i) => `<button class="chip chip-sm" onclick="applyBillPreset(${i})">${escapeHtml(p.label)} · $${Number(p.amount).toLocaleString()}</button>`).join('')}</div>` : ''}
            <div class="field-row">
                <div class="field"><label>Treatment</label><input id="bill-treatment" type="text" maxlength="255" placeholder="e.g. Field revive + transport"></div>
                <div class="field" style="max-width:140px;"><label>Amount $</label><input id="bill-amount" type="number" min="1" max="${Number(mdtCfg.billingMax) || 50000}" placeholder="250"></div>
            </div>
            <div class="field"><label>Notes (optional)</label><input id="bill-notes" type="text" maxlength="255"></div>
            <button class="btn btn-accent btn-block" onclick="doIssueBill()">🧾 Issue Bill</button>
            <div class="hint-text" style="margin-top:6px;">${mdtCfg.billingCharges ? 'Bills for a patient next to you are charged from their bank straight away and go to the EMS treasury.' : 'Bills are recorded only — no money is moved.'}</div>
        </div>
        <div class="section-title">Recent Bills (${list.length})</div>
        ${loading ? loadingHtml('Pulling billing log…') : (list.length ? list.map(billRowHtml).join('') : `<div class="empty-state">No bills on record.</div>`)}
    `;
}

function pickBillTarget(i) {
    const p = (state.nearbyPatients || [])[i];
    if (!p) return;
    billTarget = { serverId: p.serverId, name: p.name };
    renderApp('billing');
}

function applyBillPreset(i) {
    const p = (mdtCfg.billingPresets || [])[i];
    if (!p) return;
    document.getElementById('bill-treatment').value = p.label;
    document.getElementById('bill-amount').value = p.amount;
}

function doIssueBill() {
    const treatment = document.getElementById('bill-treatment').value.trim();
    const amount = Number(document.getElementById('bill-amount').value);
    const notes = document.getElementById('bill-notes').value.trim();
    if (!treatment || !amount || amount <= 0) { showToast('Treatment and an amount are required.', 'error'); return; }

    const payload = { treatment, amount, notes };
    if (billTarget) {
        payload.serverId = billTarget.serverId;
    } else {
        payload.patientName = (document.getElementById('bill-name') || {}).value?.trim() || '';
        payload.patientCid = (document.getElementById('bill-cid') || {}).value?.trim() || '';
        if (!payload.patientName) { showToast('Pick a patient next to you or type a name.', 'error'); return; }
    }
    nuiPost('issueBill', payload);
    billTarget = null;
    ['bill-treatment', 'bill-amount', 'bill-notes', 'bill-name', 'bill-cid'].forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
}

function doVoidBill(id) {
    mdtConfirm({ title: 'Void this bill?', message: 'The bill is removed from the log (money already paid is not refunded).', confirmText: 'Void', danger: true })
        .then(ok => { if (ok) nuiPost('voidBill', { id }); });
}

// ===========================================================================
// Live Map app
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

const PIN_COLORS = ['#19c3b1', '#ef4444', '#f59e0b', '#3b9dfb', '#a855f7', '#eef1f6'];
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
            message: 'Shared live with every on-duty medic on the map.',
            label: 'Pin label (optional)',
            placeholder: 'e.g. Triage point, Landing zone, Staging area…',
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
    if (mapFocusCallId) { focusMapCall(mapFocusCallId); mapFocusCallId = null; }

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

function safeColor(c) { return /^#[0-9a-fA-F]{6}$/.test(c || '') ? c : '#19c3b1'; }

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
    mdtConfirm({ title: 'Clear the map board?', message: 'Removes every pin for every medic.', confirmText: 'Clear All', danger: true })
        .then(ok => { if (ok) nuiPost('mapClearAllMarkers'); });
}

// ---- Dispatch calls on the live map (coloured by priority) ----
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
                       : `<button class="btn btn-ok btn-sm" onclick="dspRespond('${escapeHtml(call.id)}')">🚑 Respond</button>`}
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
                 onclick="selectMapOfficer(${jsStr(o.citizenid)})" title="${escapeHtml(o.name)}">
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
        <strong>${o.callsign ? '[' + escapeHtml(o.callsign) + '] ' : ''}${escapeHtml(o.name)}</strong>${self ? ' <span class="tag tag-normal">You</span>' : ''}
        <small>Rank: ${escapeHtml(o.gradeName)}</small>
        <div class="map-info-actions">
            ${!self ? `<button class="btn btn-accent btn-sm" onclick="hubGpsUnit(${Number(o.serverId)})">📍 GPS to medic</button>` : ''}
            ${canAct ? `
                <button class="btn btn-ghost btn-sm" onclick="doUpdateGrade(${jsStr(o.citizenid)},'promote')">Promote</button>
                <button class="btn btn-warn btn-sm" onclick="doUpdateGrade(${jsStr(o.citizenid)},'demote')">Demote</button>
                <button class="btn btn-danger btn-sm" onclick="doFireEmployee(${jsStr(o.citizenid)})">Terminate</button>
            ` : ''}
        </div>
    `;
}

// ===========================================================================
// Medical Reports (patient care reports)
// ===========================================================================

function reportItemHtml(r) {
    // Mirrors the server rule exactly (author OR command staff).
    const isAuthor = state.selfCitizenId && r.citizenid === state.selfCitizenId;
    const canDelete = isAuthor || state.isCommandStaff;

    return `
        <div class="list-item" style="align-items:flex-start;">
            <div class="list-item-main">
                <strong>${escapeHtml(r.title)}</strong>
                <span class="tag tag-normal">${escapeHtml(r.report_type)}</span>
                ${r.patient_name ? `<span class="tag tag-important">🧑 ${escapeHtml(r.patient_name)}${r.patient_cid ? ' · ' + escapeHtml(r.patient_cid) : ''}</span>` : ''}
                <small>Filed by ${escapeHtml(r.author_name)} · ${formatDate(r.created_at)}</small>
                ${r.involved ? `<small><strong>Units / others:</strong> ${escapeHtml(r.involved)}</small>` : ''}
                <small style="white-space:pre-wrap;">${escapeHtml(r.details)}</small>
            </div>
            ${(canDelete || r.patient_cid) ? `
                <div class="list-item-actions">
                    ${r.patient_cid ? `<button class="btn btn-ghost btn-sm" onclick="doOpenPatient(${jsStr(r.patient_cid)}); openApp('patients');" title="Open patient">🩺</button>` : ''}
                    ${canDelete ? `<button class="btn btn-danger btn-sm" onclick="deleteReport(${Number(r.id)})" title="Delete report">✕</button>` : ''}
                </div>` : ''}
        </div>
    `;
}

let reportFilter = '';

function renderReports() {
    const loading = state.reports === null;
    if (loading) nuiPost('getReports');
    const q = reportFilter.trim().toLowerCase();
    const reports = (state.reports || []).filter(r => !q ||
        [r.title, r.patient_name, r.patient_cid, r.author_name, r.report_type].some(v => String(v || '').toLowerCase().includes(q)));

    const typeOptions = REPORT_TYPES.map(t => `<option value="${t}">${t}</option>`).join('');

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">New Medical Report</div>
            <div class="field-row">
                <div class="field">
                    <label>Title</label>
                    <input id="report-title" type="text" maxlength="150" placeholder="e.g. GSW to left leg — field treatment & transport">
                </div>
                <div class="field" style="max-width:180px;">
                    <label>Type</label>
                    <select id="report-type">${typeOptions}</select>
                </div>
            </div>
            <div class="field-row">
                <div class="field"><label>Patient name</label><input id="report-patient" type="text" maxlength="100" placeholder="Full name"></div>
                <div class="field" style="max-width:180px;"><label>Patient CID (optional)</label><input id="report-patient-cid" type="text" maxlength="50" placeholder="ABC12345"></div>
            </div>
            <div class="field">
                <label>Units / others involved</label>
                <input id="report-involved" type="text" maxlength="255" placeholder="Callsigns, police units, witnesses…">
            </div>
            <div class="field">
                <label>Assessment &amp; treatment</label>
                <textarea id="report-details" maxlength="2000" placeholder="Chief complaint, injuries, vitals, treatment given, outcome…"></textarea>
            </div>
            <button class="btn btn-accent btn-block" id="report-submit-btn" onclick="submitReportForm()">File Report</button>
        </div>

        <div class="section-title units-head">
            <span>Filed Reports${loading ? '' : ` (${reports.length})`}</span>
            <input class="mini-search" type="text" placeholder="Filter…" value="${escapeHtml(reportFilter)}" oninput="reportFilter=this.value; refreshReportList()">
        </div>
        <div id="report-list">
        ${loading ? loadingHtml('Syncing report archive…')
            : (reports.length ? reports.map(reportItemHtml).join('') : `<div class="empty-state">No reports on file.</div>`)}
        </div>
    `;
}

function refreshReportList() {
    const q = reportFilter.trim().toLowerCase();
    const list = document.getElementById('report-list');
    if (!list) return;
    const reports = (state.reports || []).filter(r => !q ||
        [r.title, r.patient_name, r.patient_cid, r.author_name, r.report_type].some(v => String(v || '').toLowerCase().includes(q)));
    list.innerHTML = reports.length ? reports.map(reportItemHtml).join('') : `<div class="empty-state">No reports match.</div>`;
}

function submitReportForm() {
    const btn = document.getElementById('report-submit-btn');
    const title = document.getElementById('report-title').value.trim();
    const reportType = document.getElementById('report-type').value;
    const patientName = document.getElementById('report-patient').value.trim();
    const patientCid = document.getElementById('report-patient-cid').value.trim();
    const involved = document.getElementById('report-involved').value.trim();
    const details = document.getElementById('report-details').value.trim();

    if (!title || !details) {
        showToast('Title and report details are required.', 'error');
        return;
    }

    if (btn) { btn.disabled = true; setTimeout(() => { if (btn) btn.disabled = false; }, 2500); }
    nuiPost('submitReport', { title, reportType, patientName, patientCid, involved, details });
}

function deleteReport(id) {
    mdtConfirm({ title: 'Delete report?', message: 'This medical report will be removed permanently.', confirmText: 'Delete', danger: true })
        .then(ok => { if (ok) nuiPost('deleteReport', { id }); });
}

// ===========================================================================
// Ward Board — patients currently admitted / under care
// ===========================================================================

function wardItemHtml(w) {
    const isAuthor = state.selfCitizenId && w.citizenid === state.selfCitizenId;
    const active = Number(w.active) === 1;
    const canDischarge = active && (isAuthor || state.isCommandStaff);
    const sev = WARD_SEVERITY[w.severity] || WARD_SEVERITY.stable;
    const priorityClass = w.severity === 'critical' ? 'urgent' : (w.severity === 'serious' ? 'important' : 'normal');

    return `
        <div class="list-item priority-${priorityClass}" style="align-items:flex-start; ${active ? '' : 'opacity:0.55;'}">
            <div class="list-item-main">
                <strong>${escapeHtml(w.patient_name)}</strong>
                ${w.bed ? `<span class="tag tag-normal">🛏️ ${escapeHtml(w.bed)}</span>` : ''}
                <span class="tag ${sev.tag}">${sev.label.toUpperCase()}</span>
                <small style="white-space:pre-wrap;">${escapeHtml(w.diagnosis)}</small>
                <small>Admitted by ${escapeHtml(w.author_name)} · ${formatDate(w.created_at)}${active ? '' : ' · DISCHARGED' + (w.discharged_by ? ' by ' + escapeHtml(w.discharged_by) : '')}</small>
            </div>
            <div class="list-item-actions" style="flex-direction:column; align-items:flex-end;">
                ${active ? `
                    <select onchange="doUpdateWardSeverity(${Number(w.id)}, this.value)">
                        ${WARD_ORDER.map(s => `<option value="${s}"${s === w.severity ? ' selected' : ''}>${WARD_SEVERITY[s].label}</option>`).join('')}
                    </select>` : ''}
                <div style="display:flex; gap:6px;">
                    ${w.patient_cid ? `<button class="btn btn-ghost btn-sm" onclick="doOpenPatient(${jsStr(w.patient_cid)}); openApp('patients');" title="Open patient record">🩺</button>` : ''}
                    ${canDischarge ? `<button class="btn btn-ok btn-sm" onclick="doDischargePatient(${Number(w.id)})">Discharge</button>` : ''}
                </div>
            </div>
        </div>
    `;
}

let wardShowHistory = false;

function renderWard() {
    const loading = state.ward === null;
    if (loading) nuiPost('getWard');
    const severityOptions = WARD_ORDER.map(s => `<option value="${s}"${s === 'stable' ? ' selected' : ''}>${WARD_SEVERITY[s].label}</option>`).join('');

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Admit a Patient</div>
            <div class="field-row">
                <div class="field"><label>Patient name</label><input id="ward-patient" type="text" maxlength="150" placeholder="Full name"></div>
                <div class="field" style="max-width:170px;"><label>CID (optional)</label><input id="ward-patient-cid" type="text" maxlength="50" placeholder="ABC12345"></div>
                <div class="field" style="max-width:110px;"><label>Bed / Room</label><input id="ward-bed" type="text" maxlength="30" placeholder="ICU-2"></div>
            </div>
            <div class="field-row">
                <div class="field"><label>Diagnosis / reason</label><input id="ward-diagnosis" type="text" maxlength="500" placeholder="e.g. Multiple GSW, post-surgery observation"></div>
                <div class="field" style="max-width:150px;"><label>Condition</label><select id="ward-severity">${severityOptions}</select></div>
            </div>
            <button class="btn btn-accent btn-block" onclick="doAdmitPatient()">🛏️ Admit to Ward</button>
            <div class="hint-text" style="margin-top:6px;">A <b class="txt-danger">Critical</b> admission sends a red call so staff come to the hospital.</div>
        </div>
        <div id="ward-board">${loading ? loadingHtml('Pulling ward board…') : wardBoardHtml()}</div>
    `;
}

// Header counts + list — refreshed on its own so the admit form keeps what you typed.
function wardBoardHtml() {
    const all = state.ward || [];
    const active = all.filter(w => Number(w.active) === 1);
    const shown = wardShowHistory ? all : active;
    const counts = { critical: 0, serious: 0, stable: 0 };
    active.forEach(w => { counts[w.severity] = (counts[w.severity] || 0) + 1; });
    return `
        <div class="section-title units-head">
            <span>${wardShowHistory ? 'All admissions' : 'Currently admitted'} (${shown.length})
                <span class="tag tag-urgent">${counts.critical} critical</span>
                <span class="tag tag-important">${counts.serious} serious</span>
                <span class="tag tag-on">${counts.stable} stable</span>
            </span>
            <button class="btn btn-ghost btn-sm" onclick="wardShowHistory=!wardShowHistory; refreshWardBoard();">${wardShowHistory ? 'Admitted only' : '🕘 History'}</button>
        </div>
        ${shown.length ? shown.map(wardItemHtml).join('') : `<div class="empty-state">No patients ${wardShowHistory ? 'on record' : 'currently admitted'}.</div>`}
    `;
}

function refreshWardBoard() {
    const el = document.getElementById('ward-board');
    if (!el) return false;
    const active = document.activeElement;
    if (active && active.tagName === 'SELECT' && el.contains(active)) return true; // don't close an open dropdown
    el.innerHTML = wardBoardHtml();
    return true;
}

function doAdmitPatient() {
    const patientName = document.getElementById('ward-patient').value.trim();
    const patientCid = document.getElementById('ward-patient-cid').value.trim();
    const bed = document.getElementById('ward-bed').value.trim();
    const diagnosis = document.getElementById('ward-diagnosis').value.trim();
    const severity = document.getElementById('ward-severity').value;
    if (!patientName || !diagnosis) { showToast('Patient name and diagnosis are required.', 'error'); return; }
    nuiPost('admitPatient', { patientName, patientCid, bed, diagnosis, severity });
    ['ward-patient', 'ward-patient-cid', 'ward-bed', 'ward-diagnosis'].forEach(id => { document.getElementById(id).value = ''; });
}

function doUpdateWardSeverity(id, severity) { nuiPost('updateWardSeverity', { id, severity }); }
function doDischargePatient(id) {
    mdtConfirm({ title: 'Discharge patient?', message: 'The patient leaves the ward board (kept in history).', confirmText: 'Discharge' })
        .then(ok => { if (ok) nuiPost('dischargePatient', { id }); });
}

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
                    <input id="directive-title" type="text" maxlength="150" placeholder="e.g. Updated triage protocol">
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
// Personnel (+ EMS points)
// ===========================================================================

function dutyTag(emp) {
    const isOut = (emp.onduty === 'out' || emp.onduty === false);
    if (isOut) return `<span class="tag tag-away">Offline</span>`;
    const isOn = emp.onduty === true || emp.onduty === 1 || emp.onduty === 'true' || emp.onduty === undefined;
    return isOn ? `<span class="tag tag-on">On-Duty</span>` : `<span class="tag tag-off">Off-Duty</span>`;
}

let personnelHistoryOpen = false;
let personnelSort = 'rank';

function renderPersonnel() {
    if (!state.employees.length) {
        return `<div class="empty-state">No registered personnel found.</div>`;
    }

    const pointsOn = !!mdtCfg.pointsEnabled;
    const historyBtn = state.isCommandStaff ? `<button class="btn btn-ghost btn-sm" onclick="togglePersonnelHistory()">${personnelHistoryOpen ? 'Roster' : '🕘 History'}</button>` : '';
    const sortBtns = pointsOn && !personnelHistoryOpen ? `
        <div class="chip-row" style="margin:0;">
            <button class="chip chip-sm${personnelSort === 'rank' ? ' active' : ''}" onclick="personnelSort='rank'; renderApp('personnel');">By rank</button>
            <button class="chip chip-sm${personnelSort === 'points' ? ' active' : ''}" onclick="personnelSort='points'; renderApp('personnel');">⭐ By points</button>
        </div>` : '<span></span>';
    const toolbar = `<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">${sortBtns}${historyBtn}</div>`;

    if (personnelHistoryOpen && state.isCommandStaff) {
        const loading = state.personnelHistory === null;
        const rows = state.personnelHistory || [];
        return toolbar +
            (loading ? loadingHtml('Pulling personnel history…')
                : (rows.length ? rows.map(r => `
                    <div class="list-item"><div class="list-item-main">
                        <strong>${escapeHtml(r.action)}</strong>
                        <small>${escapeHtml(r.medic_name)}${r.details ? ' · ' + escapeHtml(r.details) : ''}</small>
                        <small>${formatDate(r.created_at)}</small>
                    </div></div>
                `).join('') : `<div class="empty-state">No personnel actions recorded yet.</div>`));
    }

    const gradeLevel = e => Number(e.grade && e.grade.level) || 0;
    const list = state.employees.slice().sort((a, b) =>
        personnelSort === 'points' ? (Number(b.points) || 0) - (Number(a.points) || 0) : gradeLevel(b) - gradeLevel(a));

    return toolbar + list.map(emp => {
        const gradeName = (emp.grade && (emp.grade.name || emp.grade.label)) || (typeof emp.grade === 'string' ? emp.grade : 'Paramedic');
        const cid = emp.citizenid || emp.cid || 'N/A';
        const suspended = !!emp.suspended;
        const hasPoints = pointsOn && emp.points !== null && emp.points !== undefined;
        const actions = state.isCommandStaff ? `
            <div class="list-item-actions" style="flex-wrap:wrap;">
                <button class="btn btn-accent btn-sm" onclick="doUpdateGrade(${jsStr(cid)},'promote')">Promote</button>
                <button class="btn btn-warn btn-sm" onclick="doUpdateGrade(${jsStr(cid)},'demote')">Demote</button>
                ${pointsOn ? `<button class="btn btn-ghost btn-sm" onclick="doChangePoints(${jsStr(cid)}, ${jsStr(emp.name)}, ${Number(emp.points) || 0})">⭐ Points</button>` : ''}
                <button class="btn ${suspended ? 'btn-ok' : 'btn-warn'} btn-sm" onclick="doToggleSuspension(${jsStr(cid)}, ${suspended})">${suspended ? 'Unsuspend' : 'Suspend'}</button>
                <button class="btn btn-danger btn-sm" onclick="doFireEmployee(${jsStr(cid)})">Terminate</button>
            </div>` : '';

        return `
            <div class="list-item">
                <div class="list-item-main">
                    <strong>${escapeHtml(emp.name)}</strong> ${dutyTag(emp)} ${suspended ? '<span class="tag tag-away">Suspended</span>' : ''}
                    ${hasPoints ? `<span class="tag tag-important">⭐ ${Number(emp.points)}</span>` : ''}
                    <small>Rank: ${escapeHtml(gradeName)} · CID: ${escapeHtml(cid)}</small>
                </div>
                ${actions}
            </div>
        `;
    }).join('');
}

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
    mdtConfirm({ title: 'Terminate medic?', message: 'Citizen ID ' + citizenid + ' will be removed from EMS.', confirmText: 'Terminate', danger: true })
        .then(ok => { if (ok) nuiPost('fireEmployee', { citizenid }); });
}

function doToggleSuspension(citizenid, currentlySuspended) {
    if (!citizenid) return;
    if (currentlySuspended) {
        nuiPost('toggleSuspension', { citizenid, reason: '' });
        return;
    }
    mdtPrompt({
        title: 'Suspend tablet access',
        icon: '⛔',
        message: 'The medic keeps their job but cannot open the tablet or receive dispatch until lifted.',
        label: 'Reason (optional)',
        placeholder: 'e.g. Pending review',
        maxLength: 200,
        confirmText: 'Suspend',
        danger: true
    }).then(res => {
        if (res) nuiPost('toggleSuspension', { citizenid, reason: res.value || '' });
    });
}

function doChangePoints(citizenid, name, current) {
    const max = Number(mdtCfg.pointsMax) || 100;
    mdtDialog({
        title: 'EMS points — ' + name,
        icon: '⭐',
        message: 'Current points: ' + current,
        bodyHtml: `
            <div class="field-row">
                <div class="field"><label>Action</label>
                    <select id="pts-mode">
                        <option value="add">Give points</option>
                        <option value="remove">Remove points</option>
                        <option value="reset">Reset to 0</option>
                    </select>
                </div>
                <div class="field" style="max-width:130px;"><label>Amount (1-${max})</label><input id="pts-amount" type="number" min="1" max="${max}" value="1"></div>
            </div>`,
        confirmText: 'Apply',
        collect: (layer) => {
            const mode = layer.querySelector('#pts-mode').value;
            const amount = Number(layer.querySelector('#pts-amount').value);
            if (mode !== 'reset' && (!amount || amount < 1 || amount > max)) { showToast('Amount must be 1-' + max + '.', 'error'); return false; }
            return { mode, amount };
        }
    }).then(res => {
        if (res && res.data) nuiPost('changePoints', { citizenid, mode: res.data.mode, amount: res.data.amount });
    });
}

// ===========================================================================
// Protocols — quick medical reference (Config.Protocols / Config.RadioCodes)
// ===========================================================================

function renderProtocols() {
    const protocols = mdtCfg.protocols || [];
    const codes = mdtCfg.radioCodes || [];
    const levelTag = { high: 'tag-urgent', medium: 'tag-important', low: 'tag-normal' };
    return `
        <div class="hint-text" style="margin-bottom:10px;">Quick reference for field treatment. Items listed are what the hospital script uses.</div>
        ${protocols.map(p => `
            <div class="card protocol-card">
                <div class="protocol-head">
                    <i class="fa-solid ${safeIcon(p.icon)}"></i>
                    <strong>${escapeHtml(p.title)}</strong>
                    ${p.level ? `<span class="tag ${levelTag[p.level] || 'tag-normal'}">${escapeHtml(String(p.level).toUpperCase())}</span>` : ''}
                </div>
                <ol class="protocol-steps">${(p.steps || []).map(s => `<li>${escapeHtml(s)}</li>`).join('')}</ol>
                ${(p.items || []).length ? `<div class="protocol-items">${p.items.map(i => `<span class="call-tag"><i class="fa-solid fa-kit-medical"></i> ${escapeHtml(i)}</span>`).join('')}</div>` : ''}
            </div>`).join('') || '<div class="empty-state">No protocols configured.</div>'}

        <div class="section-title">EMS Radio Codes</div>
        <div class="card">
            <div class="code-grid">
                ${codes.map(c => `<div class="code-row"><b>${escapeHtml(c.code)}</b><span>${escapeHtml(c.label)}</span></div>`).join('') || '<div class="hint-text">No codes configured.</div>'}
            </div>
        </div>

        <div class="section-title">Citizen Commands</div>
        <div class="card hint-text">
            Citizens call EMS with <b>/997 message</b> (anonymous: <b>/997a</b>). Reply with <b>/${escapeHtml(mdtCfg.replyCommand || '997r')} E1001 message</b> or <b>/${escapeHtml(mdtCfg.replyCommand || '997r')} [player id] message</b>.
            Downed players press <b>G</b> on the death screen — the call lands in Dispatch with their injuries.
        </div>
    `;
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
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Command Access Required</strong>Recruitment is restricted to Grade ${state.minCommandGrade}+ (EMS Command).</div>`;
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
            <div class="hint-text">Recruits the civilian standing next to you at the base rank.</div>
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
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Command Access Required</strong>Treasury access is restricted to Grade ${state.minCommandGrade}+ (EMS Command).</div>`;
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
// Command Ops (Boss only)
// ===========================================================================

function renderTactical() {
    if (!state.isBoss) {
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Boss Access Required</strong>Command Ops are restricted to EMS leadership.</div>`;
    }

    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Broadcast to All EMS <span class="pri-badge pri-high">RED</span></div>
            <textarea id="dept-message" maxlength="250" placeholder="Priority broadcast for every on-duty medic…"></textarea>
            <button class="btn btn-accent btn-block" style="margin-top:10px;" onclick="sendDepartmentAlert()">Transmit Broadcast</button>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Hospital Alert Level</div>
            <div class="alert-buttons">
                <button class="btn btn-ok" onclick="setAlertLevel('green')">Code Green<small>Normal</small></button>
                <button class="btn btn-warn" onclick="setAlertLevel('yellow')">Code Yellow<small>High load</small></button>
                <button class="btn btn-danger" onclick="setAlertLevel('red')">Code Red<small>MCI / capacity</small></button>
            </div>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Command Operations</div>
            <div class="field-row" style="flex-wrap:wrap;">
                <button class="btn btn-accent" onclick="triggerBossAction('toggleOnDutyGPS')">Toggle Medic Tracking</button>
                <button class="btn btn-warn" onclick="confirmBossAction('lockdownDept', 'Toggle hospital lockdown?', 'Every player is notified that the hospital is locked down / open again.')">Toggle Hospital Lockdown</button>
                <button class="btn btn-danger" onclick="confirmBossAction('requestBackupAll', 'Declare a mass casualty incident?', 'Every on-duty medic gets a flashing blip at your position and a RED call.')">Declare MCI (All Units)</button>
                <button class="btn btn-ghost" onclick="triggerBossAction('clearDepartmentBlips')">Clear Tracking Blips</button>
            </div>
            <div class="hint-text">Medic Tracking shows live GPS blips for on-duty medics only — never off-duty or offline personnel.</div>
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
    showToast('Hospital alert level set to CODE ' + level.toUpperCase(), level === 'red' ? 'error' : 'success');
}

function triggerBossAction(actionName) {
    nuiPost('triggerBossAction', { action: actionName });
}

function confirmBossAction(actionName, title, message) {
    mdtConfirm({ title, message, confirmText: 'Confirm', danger: true })
        .then(ok => { if (ok) triggerBossAction(actionName); });
}

// ===========================================================================
// Cameras (Boss only, unchanged permissions)
// ===========================================================================

function renderCameras() {
    if (!state.isBoss) {
        return `<div class="locked-panel"><div class="lock-icon">🔒</div><strong>Boss Access Required</strong>CCTV access is restricted to EMS leadership.</div>`;
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
    const d = mdtCfg.department || {};
    return `
        <div class="card" style="text-align:center; padding: 30px 20px;">
            <span class="dept-logo dept-logo-md" style="display:flex; margin:0 auto 10px;">
                <img src="img/logo.svg" alt="" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';">
                <span class="dept-logo-fallback">🚑</span>
            </span>
            <div style="font-family:'Orbitron',sans-serif; font-weight:800; font-size:16px;">${escapeHtml(d.Name || 'Los Santos Medical Services')}</div>
            <div class="hint-text">${escapeHtml(d.Sub || 'Medical Data Terminal')} · Unit-Issued Tablet</div>
        </div>
        <div class="card">
            <div class="section-title" style="margin-top:0;">Signed In As</div>
            <div>${escapeHtml(state.selfName)} — ${escapeHtml(state.selfGrade)}</div>
        </div>
        <div class="card">
            <div class="section-title" style="margin-top:0;">System</div>
            <div class="hint-text">EMS MDT v1.0.0 · Command clearance: Grade ${state.minCommandGrade}+ · Session encrypted end-to-end.</div>
        </div>
        <div class="card">
            <div class="section-title" style="margin-top:0;">How alerts reach you</div>
            <div class="hint-text">Downed patients (G on the death screen), /997 calls, check-in requests and crashes land in Dispatch.
            Calls are ranked Blue (low) · Yellow (medium) · Red (high), each with its own tone — and they reach you even with the tablet closed, as long as it's in your inventory and you're on duty.</div>
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

