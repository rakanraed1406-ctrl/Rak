'use strict';
/* ============================================================================
   Command UI — qb-ui
   DrawText, notifications, info overlay (DrawBlackUi) and the lockpick circle,
   in the same identity and with the same sound palette as qb-radialmenu,
   qb-menu and qb-input. No libraries (no Vue / Quasar / jQuery).
   Messages from the client (unchanged):
     { type: 'open' | 'close', text, icon }          DrawText / HideText
     { action: 'KEY_PRESSED' }                        KeyPressed
     { action: 'show' | 'hide', text }               DrawBlackUi / HideBlackUi
     { action: 'start', value, time }                 StartLockPickCircle
     { action: 'notify', text, type, length, caption, icon }   Notify (new)
   ============================================================================ */

// ---------------------------------------------------------------------------
// Sound identity (same D-minor pentatonic "glass" set as the other menus)
// ---------------------------------------------------------------------------
var UiSfx = {
    enabled: true,
    volume: 0.35,
    parts: { drawtext: true, notify: true, lockpick: true, info: true },
    ctx: null,
    master: null,
    notes: [293.66, 349.23, 392.0, 440.0, 523.25], // D4 F4 G4 A4 C5
    lastTick: 0,
    idleTimer: null,

    // the audio thread costs CPU while running, so it sleeps when idle
    sleepSoon: function () {
        var self = this;
        clearTimeout(self.idleTimer);
        self.idleTimer = setTimeout(function () {
            if (self.ctx && self.ctx.state === 'running') self.ctx.suspend();
        }, 2000);
    },

    init: function () {
        if (this.ctx) {
            if (this.ctx.state === 'suspended') this.ctx.resume();
            this.master.gain.value = this.volume;
            return this.ctx;
        }
        var Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return null;
        this.ctx = new Ctx();
        var comp = this.ctx.createDynamicsCompressor();
        comp.threshold.value = -18;
        comp.ratio.value = 4;
        var lp = this.ctx.createBiquadFilter();
        lp.type = 'lowpass';
        lp.frequency.value = 6500;
        this.master = this.ctx.createGain();
        this.master.gain.value = this.volume;
        this.master.connect(lp).connect(comp).connect(this.ctx.destination);
        return this.ctx;
    },

    tone: function (freq, when, dur, type, gain, glideTo) {
        var ctx = this.ctx;
        var o = ctx.createOscillator();
        var g = ctx.createGain();
        o.type = type || 'sine';
        o.frequency.setValueAtTime(freq, when);
        if (glideTo) o.frequency.exponentialRampToValueAtTime(glideTo, when + dur);
        g.gain.setValueAtTime(0.0001, when);
        g.gain.exponentialRampToValueAtTime(gain || 0.2, when + 0.008);
        g.gain.exponentialRampToValueAtTime(0.0001, when + dur);
        o.connect(g).connect(this.master);
        o.start(when);
        o.stop(when + dur + 0.03);
        if (type !== 'square') {
            var o2 = ctx.createOscillator();
            var g2 = ctx.createGain();
            o2.type = 'sine';
            o2.frequency.setValueAtTime(freq * 2.01, when);
            if (glideTo) o2.frequency.exponentialRampToValueAtTime(glideTo * 2.01, when + dur);
            g2.gain.setValueAtTime(0.0001, when);
            g2.gain.exponentialRampToValueAtTime((gain || 0.2) * 0.22, when + 0.006);
            g2.gain.exponentialRampToValueAtTime(0.0001, when + dur * 0.7);
            o2.connect(g2).connect(this.master);
            o2.start(when);
            o2.stop(when + dur + 0.03);
        }
    },

    play: function (part, name, index) {
        if (!this.enabled || this.volume <= 0 || (this.parts && this.parts[part] === false)) return;
        var ctx = this.init();
        if (!ctx) return;
        var t = ctx.currentTime + 0.005;
        var n = this.notes;
        switch (name) {
            case 'appear':      // DrawText shows: one soft glass note
                this.tone(n[3] * 2, t, 0.09, 'sine', 0.05);
                break;
            case 'press':       // DrawText key pressed
                this.tone(n[0] * 2, t, 0.06, 'triangle', 0.1);
                this.tone(n[3] * 2, t + 0.05, 0.1, 'triangle', 0.09);
                break;
            case 'tick': {
                var now = performance.now();
                if (now - this.lastTick < 30) return;
                this.lastTick = now;
                this.tone(n[(index || 0) % n.length] * 2, t, 0.06, 'triangle', 0.08);
                break;
            }
            case 'note':        // neutral notification
                this.tone(n[2] * 2, t, 0.08, 'sine', 0.08);
                this.tone(n[4] * 2, t + 0.07, 0.12, 'sine', 0.07);
                break;
            case 'success':
                this.tone(n[0] * 2, t, 0.07, 'triangle', 0.1);
                this.tone(n[3] * 2, t + 0.06, 0.1, 'triangle', 0.1);
                this.tone(n[4] * 2, t + 0.12, 0.16, 'triangle', 0.09);
                break;
            case 'warn':
                this.tone(n[3] * 2, t, 0.08, 'triangle', 0.09);
                this.tone(n[3] * 2, t + 0.1, 0.08, 'triangle', 0.09);
                break;
            case 'deny':
                this.tone(150, t, 0.09, 'square', 0.05, 110);
                this.tone(n[0], t + 0.02, 0.14, 'sine', 0.08, n[0] * 0.7);
                break;
            case 'open':
                this.tone(78, t, 0.13, 'sine', 0.28, 52);
                this.tone(n[0], t, 0.2, 'sine', 0.09, n[4]);
                this.tone(n[3] * 2, t + 0.08, 0.13, 'triangle', 0.07);
                break;
            case 'close':
                this.tone(n[4], t, 0.16, 'sine', 0.09, n[0] * 0.75);
                this.tone(60, t + 0.02, 0.1, 'sine', 0.2, 40);
                break;
        }
        this.sleepSoon();
    }
};

// ---------------------------------------------------------------------------
// Settings (index.html can override these)
// ---------------------------------------------------------------------------
var UiConfig = {
    notifyPosition: 'top-right',   // top-right | top-left | bottom-right | bottom-left | top-center
    notifyMax: 5
};

// GTA color codes -> spans in the muted palette (~r~ red, ~g~ green, ~b~ blue,
// ~y~ yellow, ~o~ orange, ~p~ purple, ~c~ cyan, ~m~ grey, ~w~ white, ~h~ bold,
// ~s~ reset). Text without codes is returned untouched.
function uiColors(html) {
    html = String(html == null ? '' : html);
    if (html.indexOf('~') === -1) return html;
    var open = 0;
    var out = html.replace(/~([rgbyopcmwhsn])~/g, function (_, c) {
        if (c === 'n') return '<br>';
        var close = '';
        while (open > 0) { close += '</span>'; open--; }
        if (c === 's') return close;
        open++;
        return close + '<span class="gc-' + c + '">';
    });
    while (open > 0) { out += '</span>'; open--; }
    return out;
}

function uiResource() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-ui';
}
function uiPost(name, data) {
    return fetch('https://' + uiResource() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).catch(function () {});
}
function uiAttr(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
function uiEsc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
function $(id) { return document.getElementById(id); }

// ---------------------------------------------------------------------------
// DrawText
// ---------------------------------------------------------------------------
var DT = { visible: false, hideTimer: null };

function dtOpen(text, icon, position) {
    var el = $('dt'), key = $('dtKey'), body = $('dtText');
    text = text == null ? '' : String(text);
    var pos = { left: 1, right: 1, top: 1, bottom: 1 }[position] ? position : 'bottom';
    el.classList.remove('pos-left', 'pos-right', 'pos-top', 'pos-bottom');
    el.classList.add('pos-' + pos);

    // "[E] Open door" / "[E] - Open door" -> keycap "E" + "Open door"
    var m = text.match(/^\s*\[([^\]]{1,8})\]\s*[-:]?\s*/);
    if (m) {
        key.className = 'key';
        key.textContent = m[1];
        text = text.slice(m[0].length);
    } else {
        key.className = '';
        key.innerHTML = '<i class="' + uiAttr(icon || 'fa-solid fa-bells') + '"></i>';
    }

    text = uiColors(text);
    var changed = body.innerHTML !== text;
    body.innerHTML = text; // HTML on purpose, same as the original
    body.classList.toggle('multi', /<br|\n/i.test(text));

    if (DT.hideTimer) { clearTimeout(DT.hideTimer); DT.hideTimer = null; }
    el.classList.remove('pressed');
    if (DT.visible) {
        if (changed) {
            body.classList.remove('swap');
            void body.offsetWidth;
            body.classList.add('swap');
        }
        el.classList.remove('off');
        el.classList.add('on');
        return;
    }
    DT.visible = true;
    el.classList.remove('off');
    void el.offsetWidth;
    el.classList.add('on');
    UiSfx.play('drawtext', 'appear');
}

function dtClose() {
    var el = $('dt');
    if (!DT.visible) return;
    DT.visible = false;
    el.classList.remove('on');
    el.classList.add('off');
    DT.hideTimer = setTimeout(function () {
        DT.hideTimer = null;
        el.classList.remove('off', 'pressed');
    }, 200);
}

function dtPressed() {
    var el = $('dt');
    if (!DT.visible) return;
    el.classList.remove('pressed');
    void el.offsetWidth;
    el.classList.add('pressed');
    UiSfx.play('drawtext', 'press');
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------
var NOTE_TYPES = {
    primary:   { color: '#3b9dfb', icon: 'fa-solid fa-circle-info',          label: 'INFO',      sound: 'note' },
    inform:    { color: '#3b9dfb', icon: 'fa-solid fa-circle-info',          label: 'INFO',      sound: 'note' },
    info:      { color: '#3b9dfb', icon: 'fa-solid fa-circle-info',          label: 'INFO',      sound: 'note' },
    success:   { color: '#22c55e', icon: 'fa-solid fa-circle-check',         label: 'SUCCESS',   sound: 'success' },
    error:     { color: '#ef4444', icon: 'fa-solid fa-circle-xmark',         label: 'ERROR',     sound: 'deny' },
    warning:   { color: '#f59e0b', icon: 'fa-solid fa-triangle-exclamation', label: 'WARNING',   sound: 'warn' },
    police:    { color: '#3b9dfb', icon: 'fa-solid fa-shield-halved',        label: 'POLICE',    sound: 'warn' },
    ambulance: { color: '#ef4444', icon: 'fa-solid fa-truck-medical',        label: 'EMS',       sound: 'warn' }
};

function hexToRgba(hex, a) {
    var h = hex.replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
}

function noteRemove(node) {
    if (!node || node.classList.contains('out')) return;
    clearTimeout(node._timer);
    node.classList.add('out');
    setTimeout(function () { node.remove(); }, 230);
}

function noteStartTimer(node, length) {
    clearTimeout(node._timer);
    var bar = node.querySelector('.note-bar i');
    bar.style.animation = 'none';
    void bar.offsetWidth;
    bar.style.animation = '';
    bar.style.animationDuration = length + 'ms';
    node._timer = setTimeout(function () { noteRemove(node); }, length);
}

function notify(data) {
    var text = data.text == null ? '' : String(data.text);
    if (!text) return;
    var type = NOTE_TYPES[data.type] ? data.type : 'primary';
    var def = NOTE_TYPES[type];
    var length = Math.max(1000, Number(data.length) || 5000);
    var box = $('notes');
    if (box.className !== UiConfig.notifyPosition) box.className = UiConfig.notifyPosition;

    // same message again while it is still on screen -> count it instead of stacking
    var key = type + '|' + text + '|' + (data.caption || '');
    var existing = Array.prototype.find.call(box.children, function (n) { return n._key === key && !n.classList.contains('out'); });
    if (existing) {
        existing._count = (existing._count || 1) + 1;
        var c = existing.querySelector('.note-count');
        c.textContent = '×' + existing._count;
        c.style.display = '';
        existing.classList.remove('bump');
        void existing.offsetWidth;
        existing.classList.add('bump');
        noteStartTimer(existing, length);
        UiSfx.play('notify', def.sound);
        return;
    }

    var node = document.createElement('div');
    node.className = 'note';
    node._key = key;
    node.style.setProperty('--c', def.color);
    node.style.setProperty('--c-soft', hexToRgba(def.color, 0.35));
    node.innerHTML =
        '<div class="note-icon"><i class="' + uiAttr(data.icon || def.icon) + '"></i></div>' +
        '<div class="note-body">' +
            '<div class="note-kicker">' + def.label + '</div>' +
            '<div class="note-text">' + uiColors(uiEsc(text)) + '</div>' +
            (data.caption ? '<div class="note-caption">' + uiColors(uiEsc(data.caption)) + '</div>' : '') +
        '</div>' +
        '<span class="note-count" style="display:none"></span>' +
        '<div class="note-bar"><i></i></div>';
    box.appendChild(node);

    var live = Array.prototype.filter.call(box.children, function (n) { return !n.classList.contains('out'); });
    if (live.length > UiConfig.notifyMax) noteRemove(live[0]);

    noteStartTimer(node, length);
    UiSfx.play('notify', def.sound);
}

// ---------------------------------------------------------------------------
// Info overlay (DrawBlackUi / HideBlackUi)
// ---------------------------------------------------------------------------
var INFO = { visible: false, timer: null };

function infoShow(text) {
    var el = $('info'), box = $('infoText');
    text = text == null ? '' : String(text);
    var prevNum = box.querySelector('.num');
    prevNum = prevNum ? prevNum.textContent : null;
    // numbers in plain text (e.g. "RESPAWN IN: 12 SECONDS") get their own tick animation
    var html = text.indexOf('<') === -1 ? uiColors(text).replace(/(\d+)/, '<span class="num">$1</span>') : uiColors(text);
    box.innerHTML = html; // HTML, same as the original
    var num = box.querySelector('.num');
    if (num && prevNum !== null && prevNum !== num.textContent) num.classList.add('tick');
    if (INFO.visible) return; // just a text update (countdowns etc.)
    INFO.visible = true;
    clearTimeout(INFO.timer);
    el.classList.add('on');
    void el.offsetWidth;
    el.classList.add('show');
    UiSfx.play('info', 'open');
}

function infoHide() {
    var el = $('info');
    if (!INFO.visible) return;
    INFO.visible = false;
    el.classList.remove('show');
    UiSfx.play('info', 'close');
    clearTimeout(INFO.timer);
    INFO.timer = setTimeout(function () { el.classList.remove('on'); }, 620);
}

// ---------------------------------------------------------------------------
// Lockpick circle
// Same rules as the original: a random zone on the ring, a key 1-4 in the
// middle, press that key while the needle is inside the zone. The needle moves
// 2 degrees every `time` ms (same speed as before). Wrong key, early/late
// press or a full turn = fail. `value` hits in a row = success.
// ---------------------------------------------------------------------------
var LP = {
    running: false,
    needed: 4,
    streak: 0,
    stepMs: 2,
    key: '1',
    zoneStart: 0, zoneEnd: 0,   // degrees
    t0: 0,
    raf: 0,
    flashUntil: 0,
    failed: false,
    ctx: null,
    size: 240
};

function lpRand(min, max) { return Math.floor(Math.random() * (max - min + 1) + min); }

function lpSetupCanvas() {
    var c = $('lpCanvas');
    var dpr = window.devicePixelRatio || 1;
    c.width = LP.size * dpr;
    c.height = LP.size * dpr;
    LP.ctx = c.getContext('2d');
    LP.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function lpDots() {
    var html = '';
    for (var i = 0; i < LP.needed; i++) html += '<i class="' + (i < LP.streak ? 'done' : '') + '"></i>';
    $('lpDots').innerHTML = html;
}

function lpRound() {
    // original zone: start 2.0–4.0 rad, width 0.5–1.0 rad
    var gs = lpRand(20, 40) / 10;
    var ge = gs + lpRand(5, 10) / 10;
    LP.zoneStart = gs * 180 / Math.PI;
    LP.zoneEnd = ge * 180 / Math.PI;
    LP.key = String(lpRand(1, 4));
    LP.t0 = performance.now();
}

function lpDegrees(now) {
    return ((now - LP.t0) / LP.stepMs) * 2;
}

function lpDraw(now) {
    var ctx = LP.ctx, S = LP.size, cx = S / 2, cy = S / 2, R = 96;
    var deg = lpDegrees(now);
    var rad = function (d) { return (d - 90) * Math.PI / 180; };
    ctx.clearRect(0, 0, S, S);

    // track
    ctx.lineCap = 'butt';
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(255,255,255,0.07)';
    ctx.lineWidth = 16;
    ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.stroke();

    // ticks
    ctx.strokeStyle = 'rgba(255,255,255,0.14)';
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    for (var i = 0; i < 60; i++) {
        var a = i * 6 * Math.PI / 180;
        var r0 = R + 11, r1 = R + (i % 5 === 0 ? 17 : 14);
        ctx.moveTo(cx + r0 * Math.sin(a), cy - r0 * Math.cos(a));
        ctx.lineTo(cx + r1 * Math.sin(a), cy - r1 * Math.cos(a));
    }
    ctx.stroke();

    // zone
    var flash = now < LP.flashUntil;
    ctx.beginPath();
    ctx.strokeStyle = LP.failed ? '#ef4444' : (flash ? '#eef1f6' : '#3b9dfb');
    ctx.lineWidth = 16;
    ctx.shadowColor = LP.failed ? 'rgba(239,68,68,0.45)' : 'rgba(59,157,251,0.45)';
    ctx.shadowBlur = 8;
    ctx.arc(cx, cy, R, rad(LP.zoneStart), rad(LP.zoneEnd));
    ctx.stroke();
    ctx.shadowBlur = 0;

    // needle trail + head
    var inZone = deg >= LP.zoneStart && deg <= LP.zoneEnd;
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(238,241,246,0.12)';
    ctx.lineWidth = 16;
    ctx.arc(cx, cy, R, rad(Math.max(0, deg - 26)), rad(deg));
    ctx.stroke();
    ctx.beginPath();
    ctx.strokeStyle = inZone ? '#ffffff' : '#c4cbd9';
    ctx.lineWidth = 28;
    ctx.arc(cx, cy, R - 2, rad(deg - 5), rad(deg));
    ctx.stroke();

    // core
    ctx.beginPath();
    ctx.fillStyle = 'rgba(17,20,27,0.92)';
    ctx.arc(cx, cy, 58, 0, Math.PI * 2);
    ctx.fill();
    ctx.lineWidth = 1.2;
    ctx.strokeStyle = inZone ? 'rgba(59,157,251,0.6)' : 'rgba(255,255,255,0.1)';
    ctx.stroke();

    // time left in this turn (thin inner ring that empties)
    var left = Math.max(0, 1 - deg / 360);
    ctx.beginPath();
    ctx.strokeStyle = left < 0.25 ? 'rgba(239,68,68,0.75)' : 'rgba(59,157,251,0.45)';
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.arc(cx, cy, 66, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * left);
    ctx.stroke();
    ctx.lineCap = 'butt';

    // key
    ctx.fillStyle = '#eef1f6';
    ctx.font = '800 58px Oxanium, "Segoe UI", sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(LP.key, cx, cy + 3);
    ctx.font = '700 10px Oxanium, "Segoe UI", sans-serif';
    ctx.fillStyle = '#9aa3b2';
    ctx.fillText(LP.streak + ' / ' + LP.needed, cx, cy + 38);
}

function lpLoop(now) {
    if (!LP.running) return;
    if (lpDegrees(now) >= 360) { lpEnd(false); return; }
    lpDraw(now);
    LP.raf = requestAnimationFrame(lpLoop);
}

function lpStart(value, time) {
    LP.needed = value != null ? Math.max(1, Number(value) || 4) : 4;
    LP.stepMs = time != null ? Math.max(1, Number(time) || 2) : 2;
    LP.streak = 0;
    LP.failed = false;
    LP.running = true;
    if (!LP.ctx) lpSetupCanvas();
    lpDots();
    lpRound();
    var el = $('lp');
    el.classList.remove('off', 'fail');
    void el.offsetWidth;
    el.classList.add('on');
    UiSfx.play('lockpick', 'open');
    cancelAnimationFrame(LP.raf);
    LP.raf = requestAnimationFrame(lpLoop);
}

function lpEnd(success) {
    if (!LP.running) return;
    LP.running = false;
    cancelAnimationFrame(LP.raf);
    var el = $('lp');
    if (!success) {
        LP.failed = true;
        lpDraw(performance.now());
        el.classList.add('fail');
        UiSfx.play('lockpick', 'deny');
    } else {
        UiSfx.play('lockpick', 'success');
    }
    uiPost(success ? 'success' : 'fail');
    setTimeout(function () {
        el.classList.remove('on');
        el.classList.add('off');
        setTimeout(function () { el.classList.remove('off', 'fail'); }, 260);
    }, success ? 180 : 380);
}

function lpKey(key) {
    if (!LP.running) return;
    if (key === 'Escape') { lpEnd(false); return; }
    if (['1', '2', '3', '4'].indexOf(key) === -1) return;
    var deg = lpDegrees(performance.now());
    if (key !== LP.key || deg < LP.zoneStart || deg > LP.zoneEnd) { lpEnd(false); return; }

    LP.streak++;
    lpDots();
    if (LP.streak >= LP.needed) { lpEnd(true); return; }
    UiSfx.play('lockpick', 'tick', LP.streak);
    LP.flashUntil = performance.now() + 140;
    lpRound();
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------
window.addEventListener('message', function (event) {
    var d = event.data || {};
    if (d.type === 'open') return dtOpen(d.text, d.icon, d.position);
    if (d.type === 'close') return dtClose();
    switch (d.action) {
        case 'KEY_PRESSED': return dtPressed();
        case 'notify': return notify(d);
        case 'show': return infoShow(d.text);
        case 'hide': return infoHide();
        case 'start': return lpStart(d.value, d.time);
        case 'pause': return document.body.classList.toggle('paused', !!d.state);
    }
});

document.addEventListener('keydown', function (e) {
    if (e.repeat) return;
    lpKey(e.key);
});
