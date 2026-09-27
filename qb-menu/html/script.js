'use strict';
/* ============================================================================
   Command Panel — NUI for qb-menu
   Identity shared with the qb-radialmenu Command Wheel: deep navy glass,
   royal-blue signal light, one sound palette.
   Same messages from client/main.lua as the original:
     OPEN_MENU / SHOW_HEADER { data: [...] }, CLOSE_MENU
   and the same callbacks back: clickedButton (index + 1), closeMenu.
   Item format is unchanged:
     { header, txt | text, icon, image, isMenuHeader, disabled, hidden,
       ProgressBar = { Value, MaxValue }, params = {...} }
   ============================================================================ */

// ---------------------------------------------------------------------------
// Sound identity: the same D-minor pentatonic set and the same soft "glass"
// timbre as WheelSfx in qb-radialmenu, so both menus sound like one system.
// ---------------------------------------------------------------------------
var MenuSfx = {
    enabled: true,
    volume: 0.35,
    ctx: null,
    master: null,
    notes: [293.66, 349.23, 392.0, 440.0, 523.25], // D4 F4 G4 A4 C5
    lastTick: 0,
    idleTimer: null,

    // the audio thread costs CPU while running, so it sleeps when the panel is closed
    sleep: function () {
        var self = this;
        clearTimeout(self.idleTimer);
        self.idleTimer = setTimeout(function () {
            if (self.ctx && self.ctx.state === 'running') self.ctx.suspend();
        }, 1500);
    },

    init: function () {
        clearTimeout(this.idleTimer);
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
        // soft upper partial = the "glass" in the timbre
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

    play: function (name, index) {
        if (!this.enabled || this.volume <= 0) return;
        var ctx = this.init();
        if (!ctx) return;
        var t = ctx.currentTime + 0.005;
        var n = this.notes;
        switch (name) {
            case 'open':
                // the panel slides in from the side: a shorter body than the wheel, same sweep
                this.tone(78, t, 0.13, 'sine', 0.28, 52);
                this.tone(n[0], t, 0.2, 'sine', 0.09, n[4]);
                this.tone(n[3] * 2, t + 0.08, 0.13, 'triangle', 0.07);
                break;
            case 'close':
                this.tone(n[4], t, 0.16, 'sine', 0.09, n[0] * 0.75);
                this.tone(60, t + 0.02, 0.1, 'sine', 0.2, 40);
                break;
            case 'tick': {
                var now = performance.now();
                if (now - this.lastTick < 30) return; // no machine-gun ticks on fast sweeps
                this.lastTick = now;
                this.tone(n[(index || 0) % n.length] * 2, t, 0.05, 'triangle', 0.06);
                break;
            }
            case 'select':
                this.tone(n[0] * 2, t, 0.07, 'triangle', 0.1);
                this.tone(n[3] * 2, t + 0.06, 0.12, 'triangle', 0.1);
                break;
            case 'enter': // a new menu replaced the current one
                this.tone(n[0] * 2, t, 0.06, 'triangle', 0.08);
                this.tone(n[1] * 2, t + 0.05, 0.06, 'triangle', 0.08);
                this.tone(n[3] * 2, t + 0.1, 0.12, 'triangle', 0.09);
                break;
            case 'deny':
                this.tone(150, t, 0.09, 'square', 0.05, 110);
                break;
        }
    }
};

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------
var QM = {
    visible: false,
    focus: true,
    data: [],
    order: [],          // data indexes of selectable rows, in display order
    selected: -1,       // data index
    closeTimer: null,
    pendingClose: null, // short grace window after a click (next menu may arrive)
    swapTimer: null,
    el: {}
};

function qmResource() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-menu';
}

function qmPost(name, data) {
    return fetch('https://' + qmResource() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data === undefined ? {} : data)
    }).catch(function () {});
}

function qmAttr(s) {
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function qmIsImage(icon) {
    return /^(https?:|nui:|data:|\.{0,2}\/)/i.test(icon) || /\.(png|jpe?g|webp|gif|svg)(\?.*)?$/i.test(icon);
}

function qmIcon(icon) {
    if (icon === undefined || icon === null || icon === '' || icon === false) return '';
    icon = String(icon);
    var inner = qmIsImage(icon)
        ? '<img src="' + qmAttr(icon) + '" onerror="this.remove()">'
        : '<i class="' + qmAttr(icon) + '"></i>';
    return '<div class="qm-icon">' + inner + '</div>';
}

function qmProgress(pb) {
    if (!pb || !pb.MaxValue) return '';
    var pct = Math.max(0, Math.min(100, (pb.Value / pb.MaxValue) * 100));
    return '<div class="qm-progress"><div class="qm-bar"><i data-w="' + pct + '"></i></div>' +
        '<div class="qm-bar-info">' + pb.Value + '/' + pb.MaxValue + '</div></div>';
}

// header / txt are rendered as HTML on purpose: other resources send <br>, <b>, etc.
function qmRow(item, index, num, delay) {
    var message = item.txt || item.text;
    var isTitle = !!item.isMenuHeader;
    var cls = 'qm-item' + (isTitle ? ' qm-title-row' : '') + (item.disabled ? ' disabled' : '');
    return '<div class="' + cls + '" data-index="' + index + '" style="animation-delay:' + delay + 'ms">' +
        (isTitle ? '' : '<div class="qm-num">' + (num > 0 && num < 10 ? num : '') + '</div>') +
        qmIcon(item.icon) +
        '<div class="qm-body">' +
            '<div class="qm-header">' + (item.header || '') + '</div>' +
            (message ? '<div class="qm-text">' + message + '</div>' : '') +
            qmProgress(item.ProgressBar) +
        '</div>' +
        (isTitle ? '' : '<div class="qm-arrow">›</div>') +
    '</div>';
}

function qmRender(data) {
    var el = QM.el;
    QM.data = data || [];
    QM.order = [];
    QM.selected = -1;

    // A leading isMenuHeader becomes the panel title; the rest go in the list.
    var first = -1;
    for (var i = 0; i < QM.data.length; i++) { if (QM.data[i] && !QM.data[i].hidden) { first = i; break; } }
    var head = first >= 0 && QM.data[first].isMenuHeader ? QM.data[first] : null;

    if (head) {
        var sub = head.txt || head.text;
        el.titleWrap.innerHTML = qmIcon(head.icon) +
            '<div><div class="qm-title">' + (head.header || '') + '</div>' +
            (sub ? '<div class="qm-sub">' + sub + '</div>' : '') +
            qmProgress(head.ProgressBar) + '</div>';
    } else {
        el.titleWrap.innerHTML = '';
    }

    var html = '';
    var num = 0;
    var delay = 0;
    QM.data.forEach(function (item, index) {
        if (!item || item.hidden || item === head) return;
        if (!item.isMenuHeader) { num++; QM.order.push(index); }
        html += qmRow(item, index, item.isMenuHeader ? 0 : num, delay);
        delay = Math.min(delay + 32, 380);
    });
    el.list.innerHTML = html;
    el.list.scrollTop = 0;
    el.kicker.textContent = QM.order.length ? 'MENU · ' + QM.order.length + (QM.order.length === 1 ? ' OPTION' : ' OPTIONS') : 'MENU';

    // animate progress bars from zero
    requestAnimationFrame(function () {
        requestAnimationFrame(function () {
            el.list.querySelectorAll('.qm-bar i').forEach(function (b) { b.style.transform = 'scaleX(' + (b.getAttribute('data-w') / 100) + ')'; });
            el.titleWrap.querySelectorAll('.qm-bar i').forEach(function (b) { b.style.transform = 'scaleX(' + (b.getAttribute('data-w') / 100) + ')'; });
        });
    });

    el.indicator.classList.remove('on');
    el.preview.classList.remove('on');
    if (QM.order.length) qmSelect(QM.order[0], true);
}

function qmRowEl(index) {
    return QM.el.list.querySelector('.qm-item[data-index="' + index + '"]');
}

function qmPlaceIndicator() {
    var el = QM.el;
    var row = QM.selected >= 0 ? qmRowEl(QM.selected) : null;
    if (!row) { el.indicator.classList.remove('on'); return; }
    var y = el.list.offsetTop + row.offsetTop - el.list.scrollTop;
    var h = row.offsetHeight;
    var inView = y + h > el.list.offsetTop && y < el.list.offsetTop + el.list.clientHeight;
    el.indicator.style.height = (h * 0.62) + 'px';
    el.indicator.style.transform = 'translateY(' + (y + h * 0.19) + 'px)';
    el.indicator.classList.toggle('on', inView);
}

function qmSelect(index, silent) {
    if (index === QM.selected) return;
    var prev = QM.selected >= 0 ? qmRowEl(QM.selected) : null;
    if (prev) prev.classList.remove('selected');
    var row = qmRowEl(index);
    if (!row) return;
    row.classList.add('selected');
    QM.selected = index;

    var pos = QM.order.indexOf(index);
    if (!silent) {
        row.scrollIntoView({ block: 'nearest' });
        MenuSfx.play('tick', pos);
    }
    qmPlaceIndicator();

    var item = QM.data[index];
    if (item && item.image) {
        QM.el.previewImg.src = item.image;
        QM.el.preview.classList.add('on');
    } else {
        QM.el.preview.classList.remove('on');
    }
}

function qmSelectDelta(delta) {
    var n = QM.order.length;
    if (!n) return;
    var pos = QM.order.indexOf(QM.selected);
    pos = pos < 0 ? 0 : ((pos + delta) % n + n) % n;
    qmSelect(QM.order[pos]);
}

function qmRipple(row, x, y) {
    var r = row.getBoundingClientRect();
    var ring = document.createElement('span');
    ring.className = 'qm-ripple';
    ring.style.left = (x !== undefined ? x - r.left : r.width / 2) + 'px';
    ring.style.top = (y !== undefined ? y - r.top : r.height / 2) + 'px';
    row.appendChild(ring);
    setTimeout(function () { ring.remove(); }, 520);
}

function qmActivate(index, x, y) {
    if (!QM.visible || QM.pendingClose) return;
    var item = QM.data[index];
    var row = qmRowEl(index);
    if (!item || !row || item.isMenuHeader) return;

    if (item.disabled) {
        row.classList.remove('qm-deny');
        void row.offsetWidth;
        row.classList.add('qm-deny');
        MenuSfx.play('deny');
        return;
    }

    qmSelect(index, true);
    row.classList.remove('qm-flash');
    void row.offsetWidth;
    row.classList.add('qm-flash');
    qmRipple(row, x, y);
    MenuSfx.play('select');

    qmPost('clickedButton', index + 1);

    // Most menus open the next menu straight from the clicked event. Give it a
    // moment to arrive so it swaps in place instead of close + reopen.
    QM.pendingClose = setTimeout(function () {
        QM.pendingClose = null;
        qmHide(false);
    }, 140);
}

function qmShow(data, focus) {
    var body = document.body;
    QM.focus = focus;
    body.classList.toggle('qm-nofocus', !focus);

    if (QM.pendingClose) { clearTimeout(QM.pendingClose); QM.pendingClose = null; }
    if (QM.swapTimer) { clearTimeout(QM.swapTimer); QM.swapTimer = null; }

    var wasVisible = QM.visible;
    var wasClosing = !!QM.closeTimer;
    if (QM.closeTimer) { clearTimeout(QM.closeTimer); QM.closeTimer = null; }

    QM.visible = true;
    body.classList.remove('qm-closing');

    if (wasVisible) {
        // swap the content: current list slides out, new one staggers in
        MenuSfx.play('enter');
        QM.el.list.classList.add('qm-swap-out');
        QM.swapTimer = setTimeout(function () {
            QM.swapTimer = null;
            QM.el.list.classList.remove('qm-swap-out');
            QM.el.head.classList.remove('qm-swap-in');
            void QM.el.head.offsetWidth;
            QM.el.head.classList.add('qm-swap-in');
            qmRender(data);
        }, 150);
        return;
    }

    if (wasClosing) body.classList.remove('qm-visible');
    void body.offsetWidth; // restart the entry animation
    body.classList.add('qm-visible');
    qmRender(data); // after the panel is displayed, so the indicator can measure rows
    MenuSfx.play('open');
}

function qmHide(withSound) {
    var body = document.body;
    if (QM.pendingClose) { clearTimeout(QM.pendingClose); QM.pendingClose = null; }
    if (QM.swapTimer) { clearTimeout(QM.swapTimer); QM.swapTimer = null; }
    if (!QM.visible) return;
    QM.visible = false;
    if (withSound) MenuSfx.play('close');

    QM.el.preview.classList.remove('on');
    body.classList.add('qm-closing');
    MenuSfx.sleep();
    QM.closeTimer = setTimeout(function () {
        QM.closeTimer = null;
        body.classList.remove('qm-visible', 'qm-closing');
        QM.el.list.innerHTML = '';
        QM.el.titleWrap.innerHTML = '';
        QM.el.list.classList.remove('qm-swap-out');
        QM.data = [];
        QM.order = [];
        QM.selected = -1;
    }, 230);
}

function qmCancel() {
    if (!QM.visible || QM.pendingClose) return;
    qmPost('closeMenu');
    qmHide(true);
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', function () {
    ['list', 'kicker', 'titleWrap', 'indicator', 'preview', 'previewImg', 'head'].forEach(function (id) {
        QM.el[id] = document.getElementById(id);
    });

    QM.el.list.addEventListener('mouseover', function (e) {
        var row = e.target.closest('.qm-item');
        if (!row || row.classList.contains('qm-title-row') || !QM.visible) return;
        qmSelect(parseInt(row.getAttribute('data-index'), 10));
    });

    QM.el.list.addEventListener('click', function (e) {
        var row = e.target.closest('.qm-item');
        if (!row || row.classList.contains('qm-title-row')) return;
        qmActivate(parseInt(row.getAttribute('data-index'), 10), e.clientX, e.clientY);
    });

    QM.el.previewImg.addEventListener('error', function () { QM.el.preview.classList.remove('on'); });
    QM.el.list.addEventListener('scroll', qmPlaceIndicator, { passive: true });
    window.addEventListener('resize', qmPlaceIndicator);
});

window.addEventListener('message', function (event) {
    var msg = event.data || {};
    switch (msg.action) {
        case 'OPEN_MENU':
            return qmShow(msg.data, true);
        case 'SHOW_HEADER':
            return qmShow(msg.data, false);
        case 'CLOSE_MENU':
            return qmHide(true);
    }
});

document.addEventListener('keydown', function (e) {
    if (!QM.visible) return;
    switch (e.key) {
        case 'ArrowDown':
        case 'Tab':
            qmSelectDelta(e.shiftKey && e.key === 'Tab' ? -1 : 1); e.preventDefault(); return;
        case 'ArrowUp':
            qmSelectDelta(-1); e.preventDefault(); return;
        case 'Enter':
        case ' ':
            if (QM.selected >= 0) qmActivate(QM.selected);
            e.preventDefault(); return;
    }
    // 1-9: jump straight to (and trigger) that option
    if (/^[1-9]$/.test(e.key)) {
        var idx = QM.order[parseInt(e.key, 10) - 1];
        if (idx !== undefined) qmActivate(idx);
    }
});

document.addEventListener('keyup', function (e) {
    if (e.key === 'Escape' || e.key === 'Backspace') qmCancel();
});
