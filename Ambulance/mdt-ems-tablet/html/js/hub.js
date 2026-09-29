// ===========================================================================
// EMS Hub app — the medics' menu inside the tablet.
//   Roster      : every online medic, status, location, duty timer, panic flag
//   Operations  : clock in/out, callsign, status (Available/Transporting/At Hospital/
//                 Dispatch/Supervisor/Break), PANIC
//   Comms       : department chat channels
// Only small containers are re-rendered on the 3s roster push, so inputs keep focus.
// ===========================================================================

const hub = {
    roster: [],
    selfId: null,
    tab: 'roster',
    filter: 'duty',
    search: '',
    expanded: null,
    chat: {},
    channel: 'all',
    unread: {},
    panicHolding: false
};

const STATUS_META = {
    active:    { label: 'Available',    icon: 'fa-star-of-life',   cls: 'st-active',    desc: 'Available for calls',                       go: 'Go Available' },
    transport: { label: 'Transporting', icon: 'fa-truck-medical',  cls: 'st-transport', desc: 'Taking a patient to the hospital',          go: 'Transporting' },
    hospital:  { label: 'At Hospital',  icon: 'fa-hospital',       cls: 'st-hospital',  desc: 'Treating patients at the hospital',         go: 'At Hospital' },
    dispatch:  { label: 'Dispatch',     icon: 'fa-headset',        cls: 'st-dispatch',  desc: 'Runs the CAD — assign units & manage calls', go: 'Take Dispatch' },
    commander: { label: 'Supervisor',   icon: 'fa-user-doctor',    cls: 'st-commander', desc: 'Shift / scene supervisor — can manage calls', go: 'Take Supervisor' },
    break:     { label: 'Break',        icon: 'fa-mug-hot',        cls: 'st-break',     desc: 'Temporarily unavailable',                   go: 'Take a Break' },
    off:       { label: 'Off Duty',     icon: 'fa-power-off',      cls: 'st-off',       desc: '' }
};
const STATUS_ORDER = ['active', 'transport', 'hospital', 'dispatch', 'commander', 'break'];

const VEHICLE_ICON = { car: 'fa-truck-medical', bike: 'fa-motorcycle', helicopter: 'fa-helicopter', plane: 'fa-plane', boat: 'fa-ship', person: 'fa-person-walking' };
const QUICK_CODES = ['10-4 Copy', '10-8 Available', '10-97 On scene', '10-52 En route', 'Code 3 — transporting', 'Arrived at hospital', '10-20 Location?'];

function hubSelf() {
    return hub.roster.find(m => Number(m.id) === Number(hub.selfId ?? state.selfServerId));
}

function hubStatusPill(status) {
    const s = STATUS_META[status] || STATUS_META.active;
    return `<span class="st-pill ${s.cls}"><i class="fa-solid ${s.icon}"></i> ${s.label}</span>`;
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

function renderHub() {
    const onDutyCount = hub.roster.filter(m => m.duty).length;
    const unread = Object.values(hub.unread).reduce((a, b) => a + b, 0);
    return `
        <div class="hub-app">
            <div class="seg-tabs">
                <button class="seg-tab${hub.tab === 'roster' ? ' active' : ''}" onclick="hubSetTab('roster')"><i class="fa-solid fa-list-ul"></i> Roster <span class="seg-count" id="hub-onduty-count">${onDutyCount}</span></button>
                <button class="seg-tab${hub.tab === 'ops' ? ' active' : ''}" onclick="hubSetTab('ops')"><i class="fa-solid fa-bolt"></i> Operations</button>
                <button class="seg-tab${hub.tab === 'comms' ? ' active' : ''}" onclick="hubSetTab('comms')"><i class="fa-solid fa-comments"></i> Comms ${unread ? `<span class="seg-count hot">${unread}</span>` : ''}</button>
            </div>
            <div id="hub-pane" class="hub-pane">${hubPaneHtml()}</div>
        </div>
    `;
}

function hubPaneHtml() {
    if (hub.tab === 'ops') return `<div id="hub-ops">${hubOpsHtml()}</div>`;
    if (hub.tab === 'comms') return hubCommsHtml();
    return `
        <div class="hub-toolbar">
            <div class="hub-search"><i class="fa-solid fa-magnifying-glass"></i>
                <input id="hub-search" type="text" placeholder="Search name, callsign, rank…" value="${escapeHtml(hub.search)}" oninput="hubSearch(this.value)">
            </div>
            <div class="chip-row">
                <button class="chip${hub.filter === 'duty' ? ' active' : ''}" onclick="hubSetFilter('duty')">On duty</button>
                <button class="chip${hub.filter === 'all' ? ' active' : ''}" onclick="hubSetFilter('all')">All online</button>
            </div>
        </div>
        <div id="hub-roster-list">${hubRosterHtml()}</div>
    `;
}

function hubSetTab(tab) {
    hub.tab = tab;
    if (tab === 'comms') hub.unread[hub.channel] = 0;
    if (state.currentApp === 'hub') renderApp('hub');
    if (tab === 'comms') hubScrollChat();
}

function hubSetFilter(f) { hub.filter = f; renderApp('hub'); }
function hubSearch(v) { hub.search = v || ''; hubRefreshRoster(); }

// Called on roster push / duty / status change — only touches live containers.
function hubRefresh() {
    if (state.currentApp !== 'hub') return;
    const count = document.getElementById('hub-onduty-count');
    if (count) count.textContent = hub.roster.filter(m => m.duty).length;
    hubRefreshRoster();
    const ops = document.getElementById('hub-ops');
    if (ops && !hub.panicHolding) ops.innerHTML = hubOpsHtml();
}

function hubRefreshRoster() {
    const list = document.getElementById('hub-roster-list');
    if (list) list.innerHTML = hubRosterHtml();
}

// ---------------------------------------------------------------------------
// Roster
// ---------------------------------------------------------------------------

function hubRosterHtml() {
    const q = hub.search.trim().toLowerCase();
    const rows = hub.roster.filter(m => {
        if (hub.filter === 'duty' && !m.duty) return false;
        if (!q) return true;
        return [m.name, m.callsign, m.rank, m.location].some(v => String(v || '').toLowerCase().includes(q));
    });
    if (!rows.length) {
        return `<div class="empty-state">${hub.roster.length ? 'No medics match.' : 'Loading roster…'}</div>`;
    }

    return rows.map(m => {
        const isSelf = Number(m.id) === Number(hub.selfId);
        const open = Number(hub.expanded) === Number(m.id);
        const st = m.duty ? m.status : 'off';
        return `
            <div class="unit-row${m.duty ? '' : ' off'}${m.isPanic ? ' panic' : ''}${isSelf ? ' self' : ''}${open ? ' open' : ''}${m.isCadet ? ' cadet' : ''}">
                <div class="unit-main" onclick="hubToggleUnit(${Number(m.id)})">
                    <div class="unit-badge ${(STATUS_META[st] || STATUS_META.active).cls}"><i class="fa-solid ${m.isCadet ? 'fa-graduation-cap' : 'fa-star-of-life'}"></i></div>
                    <div class="unit-callsign">${escapeHtml(m.callsign)}</div>
                    <div class="unit-id">
                        <div class="unit-name">${escapeHtml(m.name)} ${isSelf ? '<span class="you">YOU</span>' : ''} ${m.isPanic ? '<span class="panic-tag">10-99</span>' : ''}</div>
                        <div class="unit-sub">${escapeHtml(m.rank)} · <i class="fa-solid fa-location-dot"></i> ${escapeHtml(m.duty ? m.location : 'Off duty')}</div>
                    </div>
                    <i class="unit-veh fa-solid ${VEHICLE_ICON[m.vehicleType] || VEHICLE_ICON.person}" title="${escapeHtml(m.transport)}"></i>
                    ${hubStatusPill(st)}
                    <div class="unit-radio" title="Radio">${m.duty ? (m.radio ? '📻 ' + escapeHtml(m.radio) : '📻 —') : ''}</div>
                </div>
                ${open ? `
                <div class="unit-drawer">
                    <div class="mini-stat"><small>On duty</small><b>${m.duty ? formatDuration(m.dutySeconds) : 'N/A'}</b></div>
                    <div class="mini-stat"><small>Grade</small><b>Lvl ${Number(m.rankLevel) || 0}</b></div>
                    <div class="mini-stat"><small>Transport</small><b>${escapeHtml(m.transport)}</b></div>
                    <div class="mini-stat"><small>Radio</small><b>${m.radio ? escapeHtml(m.radio) : '—'}</b></div>
                    <div class="unit-actions">
                        ${m.coords && !isSelf ? `<button class="btn btn-accent btn-sm" onclick="hubGpsUnit(${Number(m.id)})">📍 GPS to unit</button>` : ''}
                        ${isSelf ? `<button class="btn btn-ghost btn-sm" onclick="hubEditCallsign()">✏️ Change callsign</button>` : ''}
                    </div>
                </div>` : ''}
            </div>
        `;
    }).join('');
}

function hubToggleUnit(id) {
    hub.expanded = Number(hub.expanded) === Number(id) ? null : Number(id);
    hubRefreshRoster();
}

function hubGpsUnit(id) {
    const m = hub.roster.find(x => Number(x.id) === Number(id));
    if (!m || !m.coords) return;
    nuiPost('setWaypoint', { x: m.coords.x, y: m.coords.y, label: `[${m.callsign}] ${m.name}` });
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

function hubOpsHtml() {
    const me = hubSelf();
    const onDuty = state.selfOnDuty;
    const status = onDuty ? (state.selfStatus || 'active') : 'off';
    const callsign = (me && me.callsign) || state.selfCallsign || 'NO TAG';
    const dutySecs = me && me.duty ? me.dutySeconds : 0;
    const holders = (s) => hub.roster.filter(m => m.duty && m.status === s).map(m => m.callsign).join(', ');

    const allowed = (mdtCfg.statuses && mdtCfg.statuses.length) ? mdtCfg.statuses : STATUS_ORDER;
    const statusButtons = STATUS_ORDER.filter(s => allowed.includes(s)).map(s => {
        const meta = STATUS_META[s];
        const who = (s === 'dispatch' || s === 'commander') ? holders(s) : '';
        return `
            <button class="ops-status ${meta.cls}${status === s ? ' active' : ''}" ${onDuty ? '' : 'disabled'} onclick="hubSetStatus('${s}')">
                <i class="fa-solid ${meta.icon}"></i>
                <div><b>${escapeHtml(meta.go || meta.label)}</b>
                <small>${status === s ? 'Current status' : (who ? 'Held by ' + escapeHtml(who) : meta.desc)}</small></div>
            </button>`;
    }).join('');

    return `
        <div class="ops-grid-2">
            <div class="card ops-self">
                <div class="ops-self-top">
                    <span class="ops-callsign" onclick="hubEditCallsign()" title="Change callsign">${escapeHtml(callsign)} <i class="fa-solid fa-pen"></i></span>
                    <div>
                        <strong>${escapeHtml(state.selfName)}</strong>
                        <small>${escapeHtml(state.selfGrade)}</small>
                    </div>
                    ${hubStatusPill(status)}
                </div>
                <div class="duty-switch${onDuty ? ' on' : ''}" onclick="hubToggleDuty()">
                    <div class="duty-switch-icon"><i class="fa-solid fa-power-off"></i></div>
                    <div class="duty-switch-text">
                        <b>${onDuty ? 'Clock Out' : 'Clock In'}</b>
                        <small>${onDuty ? 'On duty · ' + formatDuration(dutySecs) : 'You are off duty — apps are locked'}</small>
                    </div>
                    <div class="switch${onDuty ? ' on' : ''}"><span></span></div>
                </div>
            </div>

            <div class="card panic-card${onDuty ? '' : ' disabled'}">
                <div class="panic-title"><i class="fa-solid fa-triangle-exclamation"></i> Medic in Distress — 10-99</div>
                <small>Hold the button for 1 second. Sends a <b class="txt-danger">RED</b> call with your location to every medic${mdtCfg.panicPolice === false ? '' : ' and the police'}.</small>
                <button id="panic-btn" class="panic-btn" ${onDuty ? '' : 'disabled'}
                    onpointerdown="hubPanicStart(event)" onpointerup="hubPanicCancel()" onpointerleave="hubPanicCancel()">
                    <span class="panic-fill"></span>
                    <span class="panic-label">HOLD FOR PANIC</span>
                </button>
            </div>
        </div>

        <div class="section-title">Unit Status</div>
        <div class="ops-status-grid">${statusButtons}</div>
        ${!onDuty ? `<div class="hint-text">Clock in to change your status or use the panic button.</div>` : ''}
    `;
}

function hubToggleDuty() {
    if (state.selfOnDuty) {
        mdtConfirm({ title: 'Clock out?', message: 'You will go off duty and be detached from any calls.', confirmText: 'Clock Out', danger: true })
            .then(ok => { if (ok) nuiPost('hubSetDuty', { onDuty: false }); });
    } else {
        nuiPost('hubSetDuty', { onDuty: true });
    }
}

function hubSetStatus(status) {
    if (!state.selfOnDuty) return;
    state.selfStatus = status;
    nuiPost('hubSetStatus', { status });
    const ops = document.getElementById('hub-ops');
    if (ops) ops.innerHTML = hubOpsHtml();
}

function hubEditCallsign() {
    const me = hubSelf();
    mdtPrompt({
        title: 'Unit callsign',
        icon: '#️⃣',
        label: 'Callsign',
        placeholder: 'e.g. M-12, Medic 4, Air-1',
        value: (me && me.callsign !== 'NO TAG') ? me.callsign : (state.selfCallsign !== 'NO TAG' ? state.selfCallsign : ''),
        maxLength: 12,
        confirmText: 'Save'
    }).then(res => {
        if (!res) return;
        const v = (res.value || '').trim();
        if (!v) { showToast('Callsign cannot be empty.', 'error'); return; }
        if (/[<>"']|https?:|www\./i.test(v)) { showToast('Links / HTML are not allowed.', 'error'); return; }
        state.selfCallsign = v;
        nuiPost('hubSetCallsign', { callsign: v });
    });
}

// Press-and-hold panic (1s) so it can't be triggered by a stray click.
let panicTimer = null, panicStartedAt = 0, panicRaf = null;

function hubPanicStart(e) {
    if (!state.selfOnDuty) return;
    e.preventDefault();
    hub.panicHolding = true;
    panicStartedAt = performance.now();
    const btn = document.getElementById('panic-btn');
    const fill = btn && btn.querySelector('.panic-fill');
    const step = () => {
        const pct = Math.min(1, (performance.now() - panicStartedAt) / 1000);
        if (fill) fill.style.width = (pct * 100) + '%';
        if (pct < 1 && hub.panicHolding) panicRaf = requestAnimationFrame(step);
    };
    panicRaf = requestAnimationFrame(step);
    panicTimer = setTimeout(() => {
        hub.panicHolding = false;
        nuiPost('hubPanic');
        if (btn) { btn.classList.add('sent'); btn.querySelector('.panic-label').textContent = 'PANIC SENT'; }
        setTimeout(() => { const ops = document.getElementById('hub-ops'); if (ops) ops.innerHTML = hubOpsHtml(); }, 2500);
    }, 1000);
}

function hubPanicCancel() {
    if (!hub.panicHolding) return;
    hub.panicHolding = false;
    clearTimeout(panicTimer);
    cancelAnimationFrame(panicRaf);
    const fill = document.querySelector('#panic-btn .panic-fill');
    if (fill) fill.style.width = '0%';
}

// ---------------------------------------------------------------------------
// Comms
// ---------------------------------------------------------------------------

function hubChannels() {
    return (mdtCfg.chatChannels && mdtCfg.chatChannels.length) ? mdtCfg.chatChannels : [{ id: 'all', label: '#All-Units' }];
}

function hubCommsHtml() {
    const channels = hubChannels();
    if (!channels.some(c => c.id === hub.channel)) hub.channel = channels[0].id;
    return `
        <div class="comms">
            <div class="chip-row">
                ${channels.map(c => `
                    <button class="chip${c.id === hub.channel ? ' active' : ''}" onclick="hubSetChannel('${escapeHtml(c.id)}')">
                        ${escapeHtml(c.label)} ${hub.unread[c.id] ? `<span class="seg-count hot">${hub.unread[c.id]}</span>` : ''}
                    </button>`).join('')}
            </div>
            <div id="hub-chat-list" class="chat-list">${hubChatListHtml()}</div>
            <div class="chip-row quick-codes">
                ${QUICK_CODES.map(q => `<button class="chip chip-sm" onclick="hubQuickCode('${escapeHtml(q)}')">${escapeHtml(q)}</button>`).join('')}
            </div>
            <form class="chat-input" onsubmit="hubSendChat(event)">
                <input id="hub-chat-input" type="text" maxlength="250" placeholder="${state.selfOnDuty ? 'Transmit to ' + escapeHtml((channels.find(c => c.id === hub.channel) || {}).label || '') + '…' : 'Clock in to transmit'}" ${state.selfOnDuty ? '' : 'disabled'} autocomplete="off">
                <button class="btn btn-accent" type="submit" ${state.selfOnDuty ? '' : 'disabled'}><i class="fa-solid fa-paper-plane"></i></button>
            </form>
        </div>
    `;
}

function hubChatListHtml() {
    const list = hub.chat[hub.channel] || [];
    if (!list.length) return `<div class="empty-state">No transmissions on this channel yet.</div>`;
    return list.map(msg => {
        const mine = state.selfCitizenId && msg.citizenid === state.selfCitizenId;
        const text = escapeHtml(msg.text).replace(/\b(10-\d{1,3}[A-Z]?)\b/g, '<span class="ten-code">$1</span>');
        return `
            <div class="chat-msg${mine ? ' mine' : ''}">
                <div class="chat-meta"><b>[${escapeHtml(msg.callsign)}]</b> ${escapeHtml(msg.sender)} <span>${escapeHtml(msg.rank)}</span> <time>${escapeHtml(msg.time)}</time></div>
                <div class="chat-text">${text}</div>
            </div>`;
    }).join('');
}

function hubScrollChat() {
    const el = document.getElementById('hub-chat-list');
    if (el) el.scrollTop = el.scrollHeight;
}

function hubSetChannel(id) {
    hub.channel = id;
    hub.unread[id] = 0;
    renderApp('hub');
    hubScrollChat();
}

function hubQuickCode(text) {
    const input = document.getElementById('hub-chat-input');
    if (input && !input.disabled) { input.value = text; input.focus(); }
}

function hubSendChat(e) {
    e.preventDefault();
    const input = document.getElementById('hub-chat-input');
    const text = input ? input.value.trim() : '';
    if (!text) return;
    nuiPost('hubChat', { channel: hub.channel, text });
    input.value = '';
}

// ---------------------------------------------------------------------------
// NUI messages
// ---------------------------------------------------------------------------

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'hubRoster') {
        hub.roster = Array.isArray(data.roster) ? data.roster : [];
        if (data.selfId !== undefined) { hub.selfId = data.selfId; state.selfServerId = data.selfId; }
        const me = hubSelf();
        if (me) {
            state.selfCallsign = me.callsign;
            if (me.duty) {
                state.selfStatus = me.status;
                state.shiftStartedAt = Date.now() - (Number(me.dutySeconds) || 0) * 1000;
            }
            if (me.duty !== state.selfOnDuty) setSelfDuty(me.duty);
        }
        state.onDutyCount = hub.roster.filter(m => m.duty).length;
        const w = document.getElementById('widget-onduty');
        if (w) w.textContent = state.onDutyCount;
        hubRefresh();
    } else if (data.action === 'hubChatHistory') {
        hub.chat = data.history || {};
        if (state.currentApp === 'hub' && hub.tab === 'comms') {
            const list = document.getElementById('hub-chat-list');
            if (list) { list.innerHTML = hubChatListHtml(); hubScrollChat(); }
        }
    } else if (data.action === 'hubChatMessage') {
        const ch = data.channel || 'all';
        if (!hub.chat[ch]) hub.chat[ch] = [];
        hub.chat[ch].push(data.message);
        if (hub.chat[ch].length > 80) hub.chat[ch].shift();
        const viewing = state.opened && state.currentApp === 'hub' && hub.tab === 'comms' && hub.channel === ch;
        if (viewing) {
            const list = document.getElementById('hub-chat-list');
            if (list) { list.innerHTML = hubChatListHtml(); hubScrollChat(); }
        } else {
            hub.unread[ch] = (hub.unread[ch] || 0) + 1;
        }
    }
});

RENDERERS.hub = renderHub;
APP_INIT_HOOKS.hub = () => { if (hub.tab === 'comms') hubScrollChat(); };
