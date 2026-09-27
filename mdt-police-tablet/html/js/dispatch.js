// ===========================================================================
// Dispatch app — full CAD inside the tablet.
//   Calls          : live list (sorted RED → YELLOW → BLUE, newest first) + detail
//   New Call       : dispatchers create calls with a priority
//   Command        : alert level / emergency broadcast / all-units alert
//   Sound & Alerts : mute, volume, per-priority sound + pop-up, position
// Managing calls (assign units, roles, status, priority, close) needs the
// Dispatch or Commander status from the Command Hub (or senior command).
// ===========================================================================

const dsp = {
    calls: [],
    history: [],
    serverOffset: 0, // client seconds - server seconds
    canManage: false,
    roles: [],
    tab: 'calls',
    view: 'active',
    pri: 'all',
    selected: null,
    draftPriority: 'medium'
};

const CALL_STATUSES = ['pending', 'active', 'contained', 'closed'];
const PRIORITY_HINT = { high: 'Hard — shots, panic, robbery', medium: 'Medium — standard response', low: 'Easy — info / low risk' };

function dspNow() { return Date.now() / 1000 - dsp.serverOffset; }

function dspAgo(ts) {
    const secs = Math.max(0, Math.floor(dspNow() - Number(ts || 0)));
    if (secs < 45) return 'just now';
    if (secs < 3600) return Math.floor(secs / 60) + 'm ago';
    return Math.floor(secs / 3600) + 'h ' + Math.floor((secs % 3600) / 60) + 'm ago';
}

function agoSpan(ts) { return `<span class="js-ago" data-ts="${Number(ts) || 0}">${dspAgo(ts)}</span>`; }

function dspMyId() { return Number(hub.selfId ?? state.selfServerId); }
function dspIsAttached(call) { return (call.units || []).some(u => Number(u.source) === dspMyId()); }
function dspFind(id) { return dsp.calls.find(c => c.id === id) || dsp.history.find(c => c.id === id); }
function dspCanManage() { return dsp.canManage || state.canManageDispatch; }

function sortCalls(list) {
    const rank = { high: 3, medium: 2, low: 1 };
    return list.slice().sort((a, b) => (rank[b.priority] || 0) - (rank[a.priority] || 0) || b.createdAt - a.createdAt);
}

// A notification can arrive before the next full sync — keep the list in step.
function dspIngestCall(call, serverTime) {
    if (!call || !call.id) return;
    if (serverTime) dsp.serverOffset = Date.now() / 1000 - Number(serverTime);
    const idx = dsp.calls.findIndex(c => c.id === call.id);
    if (idx >= 0) dsp.calls[idx] = call; else dsp.calls.push(call);
    dsp.calls = sortCalls(dsp.calls);
    state.dispatchCount = dsp.calls.length;
    updateDockBadges();
    renderStatusIndicators();
    dspLiveRefresh();
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function dspRespond(id) {
    const call = dspFind(id);
    if (!call) return;
    nuiPost('dispatchRespond', { callId: id, coords: call.coords || null });
    showToast('Responding to ' + call.code + ' — GPS set.', 'success');
}
function dspDetach(id) { nuiPost('dispatchDetach', { callId: id }); }
function dspGps(id) {
    const call = dspFind(id);
    if (call && call.coords) nuiPost('dispatchGps', { coords: call.coords });
}
function dspUpdate(callId, field, value, extra) {
    nuiPost('dispatchUpdate', Object.assign({ callId, field, value }, extra || {}));
}
function dspOpenCall(id) {
    dsp.tab = 'calls';
    dsp.selected = id;
    const call = dspFind(id);
    if (call && call.status === 'closed') dsp.view = 'history';
    else if (dsp.view === 'history') dsp.view = 'active';
    if (state.currentApp === 'dispatch') renderApp('dispatch'); else openApp('dispatch');
}
function dspShowOnMap(id) {
    mapFocusCallId = id;
    openApp('map');
}

function dspCloseCall(id) {
    const call = dspFind(id);
    if (!call) return;
    mdtConfirm({ title: 'Close ' + call.code + '?', message: 'The call moves to history and all units are released.', confirmText: 'Close Call', danger: true })
        .then(ok => { if (ok) { dspUpdate(id, 'status', 'closed'); if (dsp.selected === id) dsp.selected = null; } });
}

function dspSetChannel(id) {
    const call = dspFind(id);
    if (!call) return;
    mdtPrompt({ title: 'Radio channel', icon: '📻', label: 'Channel number', placeholder: 'e.g. 3', value: call.channel ? String(call.channel) : '', maxLength: 3, confirmText: 'Set' })
        .then(res => { if (res) dspUpdate(id, 'channel', Number(res.value) || null); });
}

function dspAssignUnits(id) {
    const call = dspFind(id);
    if (!call) return;
    const onDuty = hub.roster.filter(m => m.duty);
    if (!onDuty.length) { showToast('No on-duty units found.', 'error'); return; }
    const selected = new Set((call.units || []).map(u => Number(u.source)));

    const busyIn = (memberId) => dsp.calls.find(c => c.id !== id && (c.units || []).some(u => Number(u.source) === Number(memberId)));

    const grid = onDuty.map(m => {
        const busy = busyIn(m.id);
        return `
            <label class="assign-card${selected.has(Number(m.id)) ? ' selected' : ''}${busy ? ' busy' : ''}">
                <input type="checkbox" value="${Number(m.id)}" ${selected.has(Number(m.id)) ? 'checked' : ''}>
                <span class="assign-top"><b>${escapeHtml(m.callsign)}</b> ${hubStatusPill(m.status)}</span>
                <span class="assign-name">${escapeHtml(m.name)}</span>
                <small>${escapeHtml(m.rank)} · ${escapeHtml(m.location)}</small>
                ${busy ? `<small class="txt-warn"><i class="fa-solid fa-triangle-exclamation"></i> On ${escapeHtml(busy.code)}</small>` : ''}
            </label>`;
    }).join('');

    mdtDialog({
        title: 'Assign units',
        icon: '👮',
        message: `${call.code} · ${call.title} — ${call.street}`,
        bodyHtml: `<div class="assign-grid" onchange="this.querySelectorAll('.assign-card').forEach(c => c.classList.toggle('selected', c.querySelector('input').checked))">${grid}</div>`,
        confirmText: 'Send',
        collect: (layer) => Array.from(layer.querySelectorAll('.assign-grid input:checked')).map(i => Number(i.value))
    }).then(res => { if (res) dspUpdate(id, 'units', res.data || []); });
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

function renderDispatch() {
    const counts = { high: 0, medium: 0, low: 0 };
    dsp.calls.forEach(c => { counts[c.priority] = (counts[c.priority] || 0) + 1; });
    const manage = dspCanManage();

    return `
        <div class="dsp-app">
            <div class="dsp-top">
                <div class="seg-tabs">
                    <button class="seg-tab${dsp.tab === 'calls' ? ' active' : ''}" onclick="dspSetTab('calls')"><i class="fa-solid fa-tower-broadcast"></i> Calls <span class="seg-count">${dsp.calls.length}</span></button>
                    <button class="seg-tab${dsp.tab === 'create' ? ' active' : ''}" onclick="dspSetTab('create')"><i class="fa-solid fa-plus"></i> New Call</button>
                    <button class="seg-tab${dsp.tab === 'command' ? ' active' : ''}" onclick="dspSetTab('command')"><i class="fa-solid fa-bullhorn"></i> Command</button>
                    <button class="seg-tab${dsp.tab === 'sound' ? ' active' : ''}" onclick="dspSetTab('sound')"><i class="fa-solid ${notifySettings.muted ? 'fa-volume-xmark' : 'fa-volume-high'}"></i> Sound &amp; Alerts</button>
                </div>
                <div class="dsp-counters">
                    <span class="pri-count pri-high" title="High / Red">${counts.high}</span>
                    <span class="pri-count pri-medium" title="Medium / Yellow">${counts.medium}</span>
                    <span class="pri-count pri-low" title="Low / Blue">${counts.low}</span>
                    <span class="role-pill ${manage ? 'on' : ''}">${manage ? '<i class="fa-solid fa-headset"></i> Dispatcher' : '<i class="fa-solid fa-eye"></i> Unit view'}</span>
                </div>
            </div>
            <div id="dsp-pane" class="dsp-pane">${dspPaneHtml()}</div>
        </div>
    `;
}

function dspSetTab(tab) {
    dsp.tab = tab;
    renderApp('dispatch');
}

function dspRenderPane() {
    const pane = document.getElementById('dsp-pane');
    if (pane) pane.innerHTML = dspPaneHtml();
}

function dspPaneHtml() {
    if (dsp.tab === 'create') return dspCreateHtml();
    if (dsp.tab === 'command') return dspCommandHtml();
    if (dsp.tab === 'sound') return dspSoundHtml();
    return `
        <div class="dsp-split">
            <div class="dsp-list-col">
                <div class="chip-row">
                    <button class="chip${dsp.view === 'active' ? ' active' : ''}" onclick="dspSetView('active')">Active</button>
                    <button class="chip${dsp.view === 'mine' ? ' active' : ''}" onclick="dspSetView('mine')">My calls</button>
                    <button class="chip${dsp.view === 'history' ? ' active' : ''}" onclick="dspSetView('history')">History</button>
                </div>
                <div class="chip-row">
                    <button class="chip chip-sm${dsp.pri === 'all' ? ' active' : ''}" onclick="dspSetPri('all')">All</button>
                    ${PRIORITY_ORDER.map(p => `<button class="chip chip-sm pri-chip pri-${p}${dsp.pri === p ? ' active' : ''}" onclick="dspSetPri('${p}')"><span class="pri-dot pri-${p}"></span>${PRIORITY_META[p].label}</button>`).join('')}
                </div>
                <div id="dsp-list" class="dsp-list">${dspListHtml()}</div>
            </div>
            <div id="dsp-detail" class="dsp-detail">${dspDetailHtml()}</div>
        </div>
    `;
}

function dspSetView(v) { dsp.view = v; dspRenderPane(); }
function dspSetPri(p) { dsp.pri = p; dspRenderPane(); }
function dspSelect(id) {
    dsp.selected = id;
    const list = document.getElementById('dsp-list');
    if (list) list.innerHTML = dspListHtml();
    const detail = document.getElementById('dsp-detail');
    if (detail) detail.innerHTML = dspDetailHtml();
}

function dspVisibleCalls() {
    let list = dsp.view === 'history' ? dsp.history : dsp.calls;
    if (dsp.view === 'mine') list = list.filter(dspIsAttached);
    if (dsp.pri !== 'all') list = list.filter(c => c.priority === dsp.pri);
    return list;
}

function dspListHtml() {
    const list = dspVisibleCalls();
    if (!list.length) {
        return `<div class="empty-state"><div style="font-size:26px;margin-bottom:6px;">📭</div>${dsp.view === 'history' ? 'No closed calls yet.' : 'No active calls — all quiet.'}</div>`;
    }
    return list.map(c => {
        const mine = dspIsAttached(c);
        return `
            <div class="call-item pri-${c.priority}${dsp.selected === c.id ? ' selected' : ''}" onclick="dspSelect('${escapeHtml(c.id)}')">
                <div class="call-item-top">
                    <span class="call-code">${escapeHtml(c.code)}</span>
                    <span class="call-title">${escapeHtml(c.title)}</span>
                    ${mine ? '<span class="mine-tag">YOU</span>' : ''}
                </div>
                <div class="call-item-bottom">
                    <span><i class="fa-solid fa-location-dot"></i> ${escapeHtml(c.street)}</span>
                    <span class="call-meta"><i class="fa-regular fa-clock"></i> ${agoSpan(c.createdAt)} · <i class="fa-solid fa-user-group"></i> ${(c.units || []).length} · <span class="status-tag s-${escapeHtml(c.status)}">${escapeHtml(c.status)}</span></span>
                </div>
            </div>`;
    }).join('');
}

function dspDetailHtml() {
    const call = dsp.selected && dspFind(dsp.selected);
    if (!call) {
        return `
            <div class="dsp-empty-detail">
                <div class="dsp-legend">
                    ${PRIORITY_ORDER.map(p => `<div class="legend-row"><span class="pri-dot pri-${p}"></span><b>${PRIORITY_META[p].name}</b><small>${PRIORITY_HINT[p]}</small></div>`).join('')}
                </div>
                <div class="hint-text" style="text-align:center;">Select a call to see details, respond, or manage units.</div>
            </div>`;
    }

    const closed = call.status === 'closed';
    const manage = dspCanManage() && !closed;
    const mine = dspIsAttached(call);
    const isSupervisor = Number(call.supervisor) === dspMyId();
    const roles = (dsp.roles && dsp.roles.length) ? dsp.roles : (mdtCfg.roles || []);
    const meta = PRIORITY_META[call.priority] || PRIORITY_META.medium;

    const unitsHtml = (call.units || []).length ? call.units.map((u, i) => `
        <div class="call-unit">
            <span class="call-unit-num">${i + 1}</span>
            <div class="call-unit-id">
                <b>${escapeHtml(u.callsign)}</b> ${Number(call.supervisor) === Number(u.source) ? '<i class="fa-solid fa-star txt-warn" title="Scene supervisor"></i>' : ''}
                <small>${escapeHtml(u.name)}</small>
            </div>
            ${manage
                ? `<select onchange="dspUpdate('${escapeHtml(call.id)}','role',this.value,{unit:${Number(u.source)}})">
                        ${roles.map(r => `<option value="${escapeHtml(r)}"${r === u.role ? ' selected' : ''}>${escapeHtml(r)}</option>`).join('')}
                        ${roles.includes(u.role) ? '' : `<option selected>${escapeHtml(u.role)}</option>`}
                   </select>`
                : `<span class="call-unit-role">${escapeHtml(u.role)}</span>`}
        </div>`).join('') : `<div class="hint-text">No units attached yet.</div>`;

    return `
        <div class="call-detail pri-${call.priority}">
            <div class="call-detail-head">
                <span class="pri-badge pri-${call.priority}">${meta.label}</span>
                <span class="call-code big">${escapeHtml(call.code)}</span>
                <span class="status-tag s-${escapeHtml(call.status)}">${escapeHtml(call.status)}</span>
                <span class="call-case">${escapeHtml(call.caseNumber || '')}</span>
            </div>
            <div class="call-detail-title">${escapeHtml(call.title)}</div>
            <div class="call-detail-sub">
                <span><i class="fa-solid fa-location-dot"></i> ${escapeHtml(call.street)}</span>
                <span><i class="fa-regular fa-clock"></i> ${agoSpan(call.createdAt)}</span>
                ${call.channel ? `<span><i class="fa-solid fa-walkie-talkie"></i> CH ${Number(call.channel)}</span>` : ''}
                ${call.createdBy ? `<span><i class="fa-solid fa-headset"></i> ${escapeHtml(call.createdBy)}</span>` : ''}
            </div>
            <div class="call-detail-desc">${escapeHtml(call.description)}</div>
            ${(call.tags || []).length ? `<div class="call-tags">${callTagsHtml(call)}</div>` : ''}

            ${!closed ? `
            <div class="call-actions">
                ${mine ? `<button class="btn btn-ghost btn-sm" onclick="dspDetach('${escapeHtml(call.id)}')"><i class="fa-solid fa-right-from-bracket"></i> Detach</button>`
                       : `<button class="btn btn-ok btn-sm" onclick="dspRespond('${escapeHtml(call.id)}')"><i class="fa-solid fa-car-on"></i> Respond</button>`}
                <button class="btn btn-accent btn-sm" onclick="dspGps('${escapeHtml(call.id)}')" ${call.coords ? '' : 'disabled'}><i class="fa-solid fa-location-crosshairs"></i> GPS</button>
                <button class="btn btn-ghost btn-sm" onclick="dspShowOnMap('${escapeHtml(call.id)}')" ${call.coords ? '' : 'disabled'}><i class="fa-solid fa-map"></i> Map</button>
                ${manage ? `<button class="btn btn-ghost btn-sm" onclick="dspSetChannel('${escapeHtml(call.id)}')"><i class="fa-solid fa-walkie-talkie"></i> Channel</button>` : ''}
            </div>` : `<div class="hint-text">Closed ${call.closedBy ? 'by ' + escapeHtml(call.closedBy) : ''} ${call.closedAt ? agoSpan(call.closedAt) : ''}</div>`}

            ${manage ? `
            <div class="section-title">Manage</div>
            <div class="manage-row">
                <div class="field"><label>Priority</label>
                    <div class="pri-picker">
                        ${PRIORITY_ORDER.map(p => `<button class="pri-opt pri-${p}${call.priority === p ? ' active' : ''}" onclick="dspUpdate('${escapeHtml(call.id)}','priority','${p}')">${PRIORITY_META[p].label}</button>`).join('')}
                    </div>
                </div>
                <div class="field"><label>Status</label>
                    <select onchange="if(this.value==='closed'){this.value='${escapeHtml(call.status)}';dspCloseCall('${escapeHtml(call.id)}')}else dspUpdate('${escapeHtml(call.id)}','status',this.value)">
                        ${CALL_STATUSES.map(s => `<option value="${s}"${s === call.status ? ' selected' : ''}>${s.toUpperCase()}</option>`).join('')}
                    </select>
                </div>
                <div class="field"><label>Scene supervisor</label>
                    <select onchange="dspUpdate('${escapeHtml(call.id)}','supervisor',this.value)">
                        <option value="">— none —</option>
                        ${(call.units || []).map(u => `<option value="${Number(u.source)}"${Number(call.supervisor) === Number(u.source) ? ' selected' : ''}>${escapeHtml(u.callsign)} · ${escapeHtml(u.name)}</option>`).join('')}
                    </select>
                </div>
            </div>` : (isSupervisor && !closed ? `
            <div class="section-title">Scene supervisor</div>
            <div class="field"><label>Status</label>
                <select onchange="if(this.value==='closed'){this.value='${escapeHtml(call.status)}';dspCloseCall('${escapeHtml(call.id)}')}else dspUpdate('${escapeHtml(call.id)}','status',this.value)">
                    ${CALL_STATUSES.map(s => `<option value="${s}"${s === call.status ? ' selected' : ''}>${s.toUpperCase()}</option>`).join('')}
                </select>
            </div>` : '')}

            <div class="section-title units-head">
                <span>Response plan · ${(call.units || []).length} unit(s)</span>
                ${manage ? `<button class="btn btn-ghost btn-sm" onclick="dspAssignUnits('${escapeHtml(call.id)}')"><i class="fa-solid fa-user-plus"></i> Assign units</button>` : ''}
            </div>
            <div class="call-units">${unitsHtml}</div>

            ${manage ? `<button class="btn btn-danger btn-block" style="margin-top:12px;" onclick="dspCloseCall('${escapeHtml(call.id)}')"><i class="fa-solid fa-circle-check"></i> Close Call</button>` : ''}
            ${!dspCanManage() && !closed ? `<div class="hint-text">Want to assign units or change priority? Take <b>Dispatch</b> in the Command Hub → Operations.</div>` : ''}
        </div>
    `;
}

function dspCreateHtml() {
    if (!dspCanManage()) {
        return `<div class="locked-panel"><div class="lock-icon">🎧</div><strong>Dispatcher only</strong>Take <b>Dispatch</b> or <b>Commander</b> status in the Command Hub (Operations tab) to create calls.
            <button class="btn btn-accent btn-sm" style="margin-top:14px;" onclick="openApp('hub'); hubSetTab('ops');">Open Command Hub</button></div>`;
    }
    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Create Dispatch Call</div>
            <div class="field"><label>Priority</label>
                <div class="pri-picker big">
                    ${PRIORITY_ORDER.map(p => `<button type="button" class="pri-opt pri-${p}${dsp.draftPriority === p ? ' active' : ''}" onclick="dspDraftPriority('${p}')">${PRIORITY_META[p].name}<small>${PRIORITY_HINT[p]}</small></button>`).join('')}
                </div>
            </div>
            <div class="field-row">
                <div class="field" style="max-width:140px;"><label>Code</label><input id="dc-code" type="text" maxlength="20" placeholder="10-XX"></div>
                <div class="field"><label>Title</label><input id="dc-title" type="text" maxlength="90" placeholder="e.g. Suspicious vehicle"></div>
            </div>
            <div class="field"><label>Street / Area (optional)</label><input id="dc-street" type="text" maxlength="80" placeholder="Filled automatically from the location if empty"></div>
            <div class="field"><label>Details</label><textarea id="dc-desc" maxlength="400" placeholder="What happened, suspects, vehicles…"></textarea></div>
            <div class="field-row">
                <button class="btn btn-accent btn-block" onclick="dspSubmitCall(false)"><i class="fa-solid fa-location-dot"></i> Create at my location</button>
                <button class="btn btn-ghost btn-block" onclick="dspSubmitCall(true)"><i class="fa-solid fa-map-pin"></i> Create at my waypoint</button>
            </div>
        </div>
    `;
}

function dspDraftPriority(p) {
    dsp.draftPriority = p;
    document.querySelectorAll('.pri-picker.big .pri-opt').forEach(b => b.classList.toggle('active', b.classList.contains('pri-' + p)));
}

function dspSubmitCall(useWaypoint) {
    const title = document.getElementById('dc-title').value.trim();
    if (!title) { showToast('A title is required.', 'error'); return; }
    nuiPost('dispatchCreate', {
        code: document.getElementById('dc-code').value.trim() || '10-00',
        title,
        street: document.getElementById('dc-street').value.trim(),
        description: document.getElementById('dc-desc').value.trim(),
        priority: dsp.draftPriority,
        useMyLocation: !useWaypoint,
        useWaypoint: !!useWaypoint
    });
    ['dc-code', 'dc-title', 'dc-street', 'dc-desc'].forEach(id => { document.getElementById(id).value = ''; });
    showToast('Call created.', 'success');
}

function dspCommandHtml() {
    const levels = [['green', 'CODE GREEN', 'btn-ok'], ['yellow', 'CODE YELLOW', 'btn-warn'], ['red', 'CODE RED', 'btn-danger']];
    return `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Department Alert Level</div>
            <div class="hint-text">Current: <strong>CODE ${state.alertLevel.toUpperCase()}</strong>${state.isLockdown ? ' · Facility Locked' : ''}</div>
            <div class="alert-buttons" style="margin-top:10px;">
                ${levels.map(([id, label, cls]) => `<button class="btn ${state.alertLevel === id ? cls : 'btn-ghost'} btn-sm" onclick="doSetAlertLevel('${id}')" ${state.isBoss ? '' : 'disabled'}>${label}</button>`).join('')}
            </div>
            ${!state.isBoss ? `<div class="hint-text">Boss-level command only.</div>` : ''}
        </div>
        ${state.isBoss ? `
        <div class="card">
            <div class="section-title" style="margin-top:0;">Emergency Broadcast <span class="pri-badge pri-high">RED</span></div>
            <div class="field"><input id="dispatch-911-input" type="text" maxlength="250" placeholder="What's happening and where?"></div>
            <button class="btn btn-danger btn-block" onclick="doSendEmergencyAlert()">📡 Broadcast to All Police</button>
        </div>` : ''}
        <div class="card">
            <div class="section-title" style="margin-top:0;">All-Units Alert <span class="pri-badge pri-low">BLUE</span></div>
            <div class="hint-text">Short call-out to every on-duty officer — e.g. "stand down". Limited to one every 20 seconds.</div>
            <div class="field" style="margin-top:8px;"><input id="dispatch-units-input" type="text" maxlength="200" placeholder="e.g. All units, stand down"></div>
            <button class="btn btn-accent btn-block" onclick="doSendUnitsAlert()">📢 Send to All Units</button>
        </div>
    `;
}

function doSetAlertLevel(level) { nuiPost('setAlertLevel', { level }); }
function doSendEmergencyAlert() {
    const input = document.getElementById('dispatch-911-input');
    if (!input.value.trim()) { showToast('Enter a message.', 'error'); return; }
    nuiPost('sendAlertMessage', { message: input.value.trim() });
    input.value = '';
    showToast('Emergency broadcast sent.', 'success');
}
function doSendUnitsAlert() {
    const input = document.getElementById('dispatch-units-input');
    if (!input.value.trim()) { showToast('Enter a message.', 'error'); return; }
    nuiPost('sendUnitsAlert', { message: input.value.trim() });
    input.value = '';
    showToast('All-units alert sent.', 'success');
}

function dspSoundHtml() {
    const s = notifySettings;
    const positions = [['top-right', 'Top right'], ['top-left', 'Top left'], ['top-center', 'Top center'], ['bottom-right', 'Bottom right'], ['bottom-left', 'Bottom left']];
    return `
        <div class="card">
            <div class="sound-master">
                <div>
                    <strong>${s.muted ? '🔕 All dispatch sounds muted' : '🔔 Dispatch sounds on'}</strong>
                    <div class="hint-text" style="margin-top:2px;">Quick toggle: the bell in the status bar, or <b>/mdtmute</b> (bindable in GTA key settings).</div>
                </div>
                <button class="switch big${s.muted ? '' : ' on'}" onclick="toggleMute(); dspRenderPane();"><span></span></button>
            </div>
            <div class="field" style="margin-top:14px;">
                <label>Volume · <span id="vol-label">${Math.round(s.volume * 100)}%</span></label>
                <input type="range" min="0" max="100" value="${Math.round(s.volume * 100)}" class="range"
                    oninput="dspSetVolume(this.value)" onchange="playPrioritySound('medium', { force: true })">
            </div>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Per priority</div>
            <div class="sound-table">
                <div class="sound-row head"><span>Priority</span><span>Sound</span><span>Pop-up</span><span>Test</span></div>
                ${PRIORITY_ORDER.map(p => `
                    <div class="sound-row">
                        <span class="sound-name"><span class="pri-dot pri-${p}"></span><b>${PRIORITY_META[p].name}</b><small>${PRIORITY_HINT[p]}</small></span>
                        <span><button class="switch${s.sound[p] ? ' on' : ''}" onclick="dspToggleSetting('sound','${p}')"><span></span></button></span>
                        <span><button class="switch${s.popup[p] ? ' on' : ''}" onclick="dspToggleSetting('popup','${p}')"><span></span></button></span>
                        <span><button class="btn btn-ghost btn-sm" onclick="dspTest('${p}')">▶ Test</button></span>
                    </div>`).join('')}
            </div>
        </div>

        <div class="card">
            <div class="section-title" style="margin-top:0;">Pop-up position (tablet closed)</div>
            <div class="chip-row">
                ${positions.map(([id, label]) => `<button class="chip${s.position === id ? ' active' : ''}" onclick="dspSetPosition('${id}')">${label}</button>`).join('')}
            </div>
            <div class="hint-text">
                Notifications reach you while the MDT is in your inventory and you're on duty — even with the tablet closed.
                <br>Respond: <kbd>${escapeHtml(mdtCfg.respondKey || 'G')}</kbd> · Dismiss: <kbd>${escapeHtml(mdtCfg.dismissKey || 'DELETE')}</kbd> · Panic: <b>/panic</b> — all rebindable in GTA Settings → Key Bindings → FiveM.
            </div>
        </div>
    `;
}

function dspSetVolume(v) {
    notifySettings.volume = Math.min(1, Math.max(0, Number(v) / 100));
    const l = document.getElementById('vol-label');
    if (l) l.textContent = Math.round(notifySettings.volume * 100) + '%';
    saveNotifySettings();
}
function dspToggleSetting(group, p) {
    notifySettings[group][p] = !notifySettings[group][p];
    saveNotifySettings();
    dspRenderPane();
}
function dspSetPosition(pos) {
    notifySettings.position = pos;
    saveNotifySettings();
    dspRenderPane();
    // Preview where the card will appear.
    pushHudCard({ id: 'preview', code: 'TEST', title: 'Pop-up position preview', street: 'Mission Row', description: 'This is where dispatch pop-ups appear while the tablet is closed.', priority: 'low', tags: [] }, 'new');
}
function dspTest(p) {
    playPrioritySound(p, { force: true });
    pushBanner({ id: 'test-' + p, code: 'TEST', title: PRIORITY_META[p].name + ' notification', street: 'Mission Row PD', description: PRIORITY_HINT[p], priority: p, tags: [] }, 'new');
}

// ---------------------------------------------------------------------------
// Live refresh (sync pushes)
// ---------------------------------------------------------------------------

function dspLiveRefresh() {
    if (state.currentApp === 'dispatch') {
        if (dsp.tab === 'calls') {
            const list = document.getElementById('dsp-list');
            if (list) list.innerHTML = dspListHtml();
            // Don't rebuild the detail pane while the user has a dropdown open.
            const detail = document.getElementById('dsp-detail');
            const active = document.activeElement;
            if (detail && !(active && active.tagName === 'SELECT' && detail.contains(active))) detail.innerHTML = dspDetailHtml();
        }
        const tabs = document.querySelector('.dsp-app');
        if (tabs) {
            const counts = { high: 0, medium: 0, low: 0 };
            dsp.calls.forEach(c => { counts[c.priority] = (counts[c.priority] || 0) + 1; });
            tabs.querySelectorAll('.dsp-counters .pri-count').forEach(el => {
                const p = PRIORITY_ORDER.find(k => el.classList.contains('pri-' + k));
                if (p) el.textContent = counts[p];
            });
            const callsCount = tabs.querySelector('.seg-tab .seg-count');
            if (callsCount) callsCount.textContent = dsp.calls.length;
        }
    }
    if (state.currentApp === 'map' && typeof renderMapCalls === 'function') renderMapCalls();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action !== 'dispatchSync' || !data.payload) return;
    const p = data.payload;
    if (p.serverTime) dsp.serverOffset = Date.now() / 1000 - Number(p.serverTime);
    dsp.calls = sortCalls(p.calls || []);
    dsp.history = p.history || [];
    const managedBefore = dspCanManage();
    dsp.canManage = !!p.canManage;
    state.canManageDispatch = dsp.canManage;
    if (Array.isArray(p.roles)) dsp.roles = p.roles;
    state.dispatchCount = dsp.calls.length;
    updateDockBadges();
    renderStatusIndicators();

    if (state.currentApp === 'dispatch' && managedBefore !== dsp.canManage) renderApp('dispatch');
    else dspLiveRefresh();
});

setInterval(() => {
    document.querySelectorAll('.js-ago').forEach(el => { el.textContent = dspAgo(el.getAttribute('data-ts')); });
}, 10000);

RENDERERS.dispatch = renderDispatch;
