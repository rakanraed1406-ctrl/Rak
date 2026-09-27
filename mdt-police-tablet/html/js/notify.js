// ===========================================================================
// Dispatch notifications + sounds
//   low    → BLUE   (سهل)    soft two-note chime
//   medium → YELLOW (متوسط)  triple beep
//   high   → RED    (صعب)    alarm sweep
// Tablet closed → HUD cards on screen (no NUI focus needed, keybinds via Lua).
// Tablet open   → banner inside the tablet screen.
// Every officer controls mute / volume / per-priority sound & pop-up in
// Dispatch → Sound & Alerts. Saved in the NUI's localStorage.
// ===========================================================================

const PRIORITY_META = {
    high:   { label: 'HIGH',   name: 'Red — High',      color: '#ef4444' },
    medium: { label: 'MEDIUM', name: 'Yellow — Medium', color: '#f5b400' },
    low:    { label: 'LOW',    name: 'Blue — Low',      color: '#3b9dfb' }
};
const PRIORITY_ORDER = ['high', 'medium', 'low'];

const mdtCfg = {
    toastDuration: { low: 8000, medium: 11000, high: 16000 },
    sounds: { low: '', medium: '', high: '' },
    defaultVolume: 0.7,
    respondKey: 'G',
    dismissKey: 'DELETE',
    roles: [],
    chatChannels: [{ id: 'all', label: '#All-Units' }],
    autoClockIn: false
};

const NOTIFY_KEY = 'mdt.notify.settings.v1';
const notifySettings = {
    muted: false,
    volume: 0.7,
    sound: { low: true, medium: true, high: true },
    popup: { low: true, medium: true, high: true },
    position: 'top-right'
};
let notifySettingsLoaded = false;

function loadNotifySettings() {
    try {
        const saved = JSON.parse(localStorage.getItem(NOTIFY_KEY) || 'null');
        if (saved && typeof saved === 'object') {
            notifySettings.muted = !!saved.muted;
            if (typeof saved.volume === 'number') notifySettings.volume = Math.min(1, Math.max(0, saved.volume));
            ['sound', 'popup'].forEach(k => {
                if (saved[k]) PRIORITY_ORDER.forEach(p => { if (typeof saved[k][p] === 'boolean') notifySettings[k][p] = saved[k][p]; });
            });
            if (['top-right', 'top-left', 'bottom-right', 'bottom-left', 'top-center'].includes(saved.position)) notifySettings.position = saved.position;
            notifySettingsLoaded = true;
        }
    } catch (e) { /* storage blocked — defaults are fine */ }
    applyHudPosition();
}

function saveNotifySettings() {
    try { localStorage.setItem(NOTIFY_KEY, JSON.stringify(notifySettings)); } catch (e) {}
    renderMuteButton();
    applyHudPosition();
}

function applyHudPosition() {
    const hud = document.getElementById('hud-dispatch');
    if (hud) hud.className = 'hud-dispatch pos-' + notifySettings.position;
}

function renderMuteButton() {
    const btn = document.getElementById('status-mute-btn');
    if (!btn) return;
    btn.textContent = notifySettings.muted ? '🔕' : '🔔';
    btn.classList.toggle('muted', notifySettings.muted);
    btn.title = notifySettings.muted ? 'Dispatch sounds muted — click to unmute' : 'Mute dispatch sounds';
}

function toggleMute(forceValue) {
    notifySettings.muted = typeof forceValue === 'boolean' ? forceValue : !notifySettings.muted;
    saveNotifySettings();
    if (state.currentApp === 'dispatch' && typeof dspRenderPane === 'function' && dsp.tab === 'sound') dspRenderPane();
    return notifySettings.muted;
}

// ---------------------------------------------------------------------------
// Sound engine (Web Audio synth, or a custom file per priority)
// ---------------------------------------------------------------------------

let audioCtx = null;

function getAudioCtx() {
    if (!audioCtx) {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return null;
        audioCtx = new Ctx();
    }
    if (audioCtx.state === 'suspended') audioCtx.resume().catch(() => {});
    return audioCtx;
}

function synthTone(ctx, dest, freq, start, dur, type, peak, slideTo) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq, start);
    if (slideTo) osc.frequency.linearRampToValueAtTime(slideTo, start + dur);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(peak || 0.3, start + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + dur);
    osc.connect(gain).connect(dest);
    osc.start(start);
    osc.stop(start + dur + 0.05);
}

const SOUND_PATTERNS = {
    // Blue — calm two-note chime
    low(ctx, out, t) {
        synthTone(ctx, out, 880, t, 0.22, 'sine', 0.35);
        synthTone(ctx, out, 1318.5, t + 0.16, 0.4, 'sine', 0.3);
    },
    // Yellow — three quick attention beeps + rising tail
    medium(ctx, out, t) {
        [0, 0.17, 0.34].forEach(o => synthTone(ctx, out, 760, t + o, 0.13, 'triangle', 0.4));
        synthTone(ctx, out, 1020, t + 0.55, 0.28, 'triangle', 0.35);
    },
    // Red — urgent two-tone alarm sweep (~1.1s)
    high(ctx, out, t) {
        for (let i = 0; i < 6; i++) {
            const hi = i % 2 === 0;
            synthTone(ctx, out, hi ? 980 : 700, t + i * 0.18, 0.17, 'sawtooth', 0.22, hi ? 1100 : 640);
        }
    }
};

function playPrioritySound(priority, { force = false } = {}) {
    if (!PRIORITY_META[priority]) priority = 'medium';
    if (!force && (notifySettings.muted || !notifySettings.sound[priority])) return;
    const volume = notifySettings.volume;
    if (volume <= 0) return;

    const file = mdtCfg.sounds && mdtCfg.sounds[priority];
    if (file) {
        try {
            const audio = new Audio(file);
            audio.volume = volume;
            audio.play().catch(() => playSynth(priority, volume));
            return;
        } catch (e) { /* fall through to synth */ }
    }
    playSynth(priority, volume);
}

function playSynth(priority, volume) {
    const ctx = getAudioCtx();
    if (!ctx) return;
    const master = ctx.createGain();
    master.gain.value = volume;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = priority === 'high' ? 3200 : 5000;
    master.connect(filter).connect(ctx.destination);
    SOUND_PATTERNS[priority](ctx, master, ctx.currentTime + 0.02);
}

// ---------------------------------------------------------------------------
// Shared card markup
// ---------------------------------------------------------------------------

function safeIcon(icon) {
    return String(icon || 'fa-circle-info').replace(/[^a-z0-9-]/gi, '') || 'fa-circle-info';
}

function callTagsHtml(call, max) {
    return (call.tags || []).slice(0, max || 8).map(t =>
        `<span class="call-tag${t.danger ? ' danger' : ''}"><i class="fa-solid ${safeIcon(t.icon)}"></i> ${escapeHtml(t.label)}</span>`
    ).join('');
}

// ---------------------------------------------------------------------------
// HUD cards (tablet closed)
// ---------------------------------------------------------------------------

const hudCards = []; // newest first: { call, kind, timer, expires }
const HUD_MAX = 3;

function reportTopToast() {
    const top = hudCards[0];
    nuiPost('toastState', top ? { callId: top.call.id, coords: top.call.coords || null } : {});
}

function renderHud() {
    const hud = document.getElementById('hud-dispatch');
    if (!hud) return;
    hud.innerHTML = hudCards.map((c, i) => {
        const call = c.call;
        const meta = PRIORITY_META[call.priority] || PRIORITY_META.medium;
        const duration = c.duration;
        const isTop = i === 0;
        return `
            <div class="hud-card pri-${call.priority}${isTop ? ' top' : ''}" data-hud-id="${escapeHtml(call.id)}">
                <div class="hud-card-stripe"></div>
                <div class="hud-card-body">
                    <div class="hud-card-head">
                        <span class="pri-badge pri-${call.priority}">${c.kind === 'assigned' ? 'ASSIGNED · ' : ''}${meta.label}</span>
                        <span class="hud-card-code">${escapeHtml(call.code)}</span>
                        <span class="hud-card-time">${hudCards.length > 1 ? `${i + 1}/${hudCards.length}` : 'now'}</span>
                    </div>
                    <div class="hud-card-title">${escapeHtml(call.title)}</div>
                    <div class="hud-card-street"><i class="fa-solid fa-location-dot"></i> ${escapeHtml(call.street)}</div>
                    ${isTop ? `<div class="hud-card-desc">${escapeHtml(call.description)}</div>
                    <div class="hud-card-tags">${callTagsHtml(call, 4)}</div>
                    <div class="hud-card-keys">
                        <span><kbd>${escapeHtml(mdtCfg.respondKey || 'G')}</kbd> Respond</span>
                        <span><kbd>${escapeHtml(mdtCfg.dismissKey || 'DEL')}</kbd> Dismiss</span>
                    </div>` : ''}
                </div>
                <div class="hud-card-progress"><div style="animation-duration:${duration}ms; animation-delay:-${Math.max(0, Date.now() - c.start)}ms"></div></div>
            </div>
        `;
    }).join('');
}

function removeHudCard(callId) {
    const idx = hudCards.findIndex(c => c.call.id === callId);
    if (idx < 0) return;
    clearTimeout(hudCards[idx].timer);
    hudCards.splice(idx, 1);
    renderHud();
    reportTopToast();
}

function pushHudCard(call, kind) {
    removeHudCard(call.id);
    const duration = Number((mdtCfg.toastDuration || {})[call.priority]) || 10000;
    const card = { call, kind, duration, start: Date.now() };
    card.timer = setTimeout(() => removeHudCard(call.id), duration);
    hudCards.unshift(card);
    while (hudCards.length > HUD_MAX) {
        const old = hudCards.pop();
        clearTimeout(old.timer);
    }
    renderHud();
    reportTopToast();
}

function clearHud() {
    hudCards.forEach(c => clearTimeout(c.timer));
    hudCards.length = 0;
    renderHud();
    reportTopToast();
}

// ---------------------------------------------------------------------------
// In-tablet banner (tablet open)
// ---------------------------------------------------------------------------

function pushBanner(call, kind) {
    const stack = document.getElementById('device-banner-stack');
    if (!stack) return;
    stack.querySelectorAll(`[data-banner-id="${CSS.escape(call.id)}"]`).forEach(el => el.remove());
    const meta = PRIORITY_META[call.priority] || PRIORITY_META.medium;
    const el = document.createElement('div');
    el.className = 'device-banner pri-' + call.priority;
    el.setAttribute('data-banner-id', call.id);
    el.innerHTML = `
        <div class="device-banner-icon">📡</div>
        <div class="device-banner-main">
            <div class="device-banner-head">
                <span class="pri-badge pri-${call.priority}">${kind === 'assigned' ? 'ASSIGNED · ' : ''}${meta.label}</span>
                <strong>${escapeHtml(call.code)} · ${escapeHtml(call.title)}</strong>
            </div>
            <small><i class="fa-solid fa-location-dot"></i> ${escapeHtml(call.street)} — ${escapeHtml(call.description)}</small>
        </div>
        <div class="device-banner-actions">
            <button class="btn btn-ok btn-sm" data-banner-act="respond">Respond</button>
            <button class="btn btn-ghost btn-sm" data-banner-act="view">View</button>
            <button class="device-banner-x" data-banner-act="close">✕</button>
        </div>
    `;
    el.addEventListener('click', (e) => {
        const act = e.target.closest('[data-banner-act]');
        if (!act) return;
        const a = act.getAttribute('data-banner-act');
        if (a === 'respond') dspRespond(call.id);
        if (a === 'view') dspOpenCall(call.id);
        el.remove();
    });
    stack.prepend(el);
    while (stack.children.length > 2) stack.lastElementChild.remove();
    const duration = Number((mdtCfg.toastDuration || {})[call.priority]) || 10000;
    setTimeout(() => el.remove(), Math.min(duration, 12000));
}

// ---------------------------------------------------------------------------
// Entry point for every incoming call
// ---------------------------------------------------------------------------

function notifyDispatch(call, kind) {
    if (!call || !call.id) return;
    if (!PRIORITY_META[call.priority]) call.priority = 'medium';

    playPrioritySound(call.priority);
    if (!notifySettings.popup[call.priority] && kind !== 'assigned') return;

    const tabletVisible = state.opened && !document.getElementById('boss-container').classList.contains('hidden');
    if (tabletVisible) pushBanner(call, kind);
    else pushHudCard(call, kind);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    switch (data.action) {
        case 'mdtConfig':
            Object.assign(mdtCfg, data.config || {});
            if (!notifySettingsLoaded && typeof mdtCfg.defaultVolume === 'number') notifySettings.volume = mdtCfg.defaultVolume;
            renderHud();
            break;
        case 'dispatchNotify':
            if (typeof dspIngestCall === 'function') dspIngestCall(data.call, data.serverTime);
            notifyDispatch(data.call, 'new');
            break;
        case 'dispatchAssigned':
            notifyDispatch(data.call, 'assigned');
            break;
        case 'toastResponded':
            removeHudCard(data.callId);
            break;
        case 'toastDismiss':
            if (hudCards[0]) removeHudCard(hudCards[0].call.id);
            break;
        case 'toggleMute': {
            const muted = toggleMute();
            nuiPost('notifyMuteState', { muted });
            break;
        }
        case 'openBossMenu':
            // Tablet opened → HUD cards move out of the way.
            clearHud();
            break;
    }
});

loadNotifySettings();
renderMuteButton();
