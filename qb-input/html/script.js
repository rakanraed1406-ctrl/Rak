'use strict';
/* ============================================================================
   Command Form — NUI for qb-input
   Identity shared with the qb-radialmenu Command Wheel and the qb-menu Command
   Panel: deep navy + royal blue, one sound palette.
   Same messages from client/main.lua as the original:
     OPEN_MENU { header, submitText, inputs = [...] }, CLOSE_MENU, SET_STYLE
   and the same callbacks back: buttonSubmit { data = {...} }, closeMenu.
   The returned data has the same shape as before:
     text/password/number/color/radio/select -> data[name] = value (string)
     checkbox -> data[option.value] = "true" | "false"
   ============================================================================ */

// ---------------------------------------------------------------------------
// Sound identity: same D-minor pentatonic set and "glass" timbre as WheelSfx
// (qb-radialmenu) and MenuSfx (qb-menu).
// ---------------------------------------------------------------------------
var FormSfx = {
    enabled: true,
    volume: 0.35,
    ctx: null,
    master: null,
    notes: [293.66, 349.23, 392.0, 440.0, 523.25], // D4 F4 G4 A4 C5
    lastTick: 0,
    idleTimer: null,

    // the audio thread costs CPU while running, so it sleeps when the form is closed
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
                if (now - this.lastTick < 30) return;
                this.lastTick = now;
                this.tone(n[(index || 0) % n.length] * 2, t, 0.05, 'triangle', 0.06);
                break;
            }
            case 'select': // submit
                this.tone(n[0] * 2, t, 0.07, 'triangle', 0.1);
                this.tone(n[3] * 2, t + 0.06, 0.12, 'triangle', 0.1);
                this.tone(n[4] * 2, t + 0.12, 0.14, 'triangle', 0.08);
                break;
            case 'deny':
                this.tone(150, t, 0.09, 'square', 0.05, 110);
                break;
        }
    }
};

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------
var QI = {
    visible: false,
    inputs: [],
    closeTimer: null,
    el: {}
};

function qiResource() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-input';
}

function qiPost(name, data) {
    return fetch('https://' + qiResource() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data === undefined ? {} : data)
    }).catch(function () {});
}

function qiAttr(s) {
    return String(s === undefined || s === null ? '' : s)
        .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function qiEsc(s) {
    return String(s === undefined || s === null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function qiRequired(item) {
    return item.isRequired === true || item.isRequired === 'true';
}

// labels / header are rendered as HTML on purpose (same as the original)
function qiField(item, i) {
    var name = qiAttr(item.name);
    var text = item.text || '';
    var req = qiRequired(item);
    var def = item.default !== undefined && item.default !== null ? item.default : '';
    var delay = 'style="animation-delay:' + Math.min(i * 40, 360) + 'ms"';

    var id = 'qi_' + i;
    var ph = qiAttr(text.replace(/<[^>]*>/g, ''));
    var max = Number(item.maxLength || item.maxlength) || 0;           // optional: character limit + counter
    var common = ' id="' + id + '" name="' + name + '" placeholder="' + ph + '"' +
        (req ? ' data-required="1"' : '') + (max ? ' maxlength="' + max + '"' : '');
    var label = '<label class="qi-label" for="' + id + '">' + text + (req ? ' <em>*</em>' : '') + '</label>';
    var counter = max ? '<b class="qi-count" data-for="' + id + '">' + String(def).length + '/' + max + '</b>' : '';

    switch (item.type) {
        case 'text':
            return '<div class="qi-field" ' + delay + '>' + label +
                '<span class="qi-wrap"><input class="qi-input" type="text"' + common + ' value="' + qiAttr(def) + '">' + counter + '</span>' +
            '</div>';

        case 'password':
            // eye button to show / hide what was typed
            return '<div class="qi-field" ' + delay + '>' + label +
                '<span class="qi-wrap"><input class="qi-input qi-has-btn" type="password"' + common + ' value="' + qiAttr(def) + '">' +
                '<button type="button" class="qi-eye" tabindex="-1" data-eye="' + id + '" aria-label="Show"><i></i></button></span>' +
            '</div>';

        case 'number': {
            // optional min / max / step on the item; - and + buttons
            var lim = (item.min !== undefined ? ' min="' + qiAttr(item.min) + '"' : '') +
                (item.max !== undefined ? ' max="' + qiAttr(item.max) + '"' : '') +
                (item.step !== undefined ? ' step="' + qiAttr(item.step) + '"' : '');
            return '<div class="qi-field" ' + delay + '>' + label +
                '<span class="qi-stepper"><button type="button" tabindex="-1" data-step="-1" data-for="' + id + '">−</button>' +
                '<input class="qi-input" type="number" inputmode="numeric"' + common + lim + ' value="' + qiAttr(def) + '">' +
                '<button type="button" tabindex="-1" data-step="1" data-for="' + id + '">+</button></span>' +
            '</div>';
        }

        case 'textarea': // new type: multi-line text
            return '<div class="qi-field" ' + delay + '>' + label +
                '<span class="qi-wrap"><textarea class="qi-input qi-area" rows="3"' + common + '>' + qiEsc(def) + '</textarea>' + counter + '</span>' +
            '</div>';

        case 'color':
            return '<label class="qi-field" ' + delay + '>' +
                '<span class="qi-label">' + text + '</span>' +
                '<span class="qi-color"><input type="color" name="' + name + '" value="' + qiAttr(def || '#ffffff') + '"><b>' + qiAttr(def || '#ffffff') + '</b></span>' +
            '</label>';

        case 'radio': {
            var opts = item.options || [];
            var html = '<div class="qi-field" ' + delay + '><span class="qi-label">' + text + '</span><div class="qi-chips">';
            opts.forEach(function (o, oi) {
                var checked = item.default !== undefined ? item.default == o.value : oi === 0;
                html += '<label class="qi-chip"><input type="radio" name="' + name + '" value="' + qiAttr(o.value) + '"' + (checked ? ' checked' : '') + '><span>' + o.text + '</span></label>';
            });
            return html + '</div></div>';
        }

        case 'checkbox': {
            var html2 = '<div class="qi-field" ' + delay + '><span class="qi-label">' + text + '</span><div class="qi-checks">';
            (item.options || []).forEach(function (o) {
                html2 += '<label class="qi-check"><span>' + o.text + '</span>' +
                    '<input type="checkbox" data-key="' + qiAttr(o.value) + '"' + (o.checked ? ' checked' : '') + '><i class="qi-switch"></i></label>';
            });
            return html2 + '</div></div>';
        }

        case 'select': {
            var html3 = '<label class="qi-field" ' + delay + '><span class="qi-label">' + text + '</span><span class="qi-select"><select name="' + name + '">';
            (item.options || []).forEach(function (o) {
                html3 += '<option value="' + qiAttr(o.value) + '"' + (item.default == o.value ? ' selected' : '') + '>' + qiAttr(o.text) + '</option>';
            });
            return html3 + '</select></span></label>';
        }

        default:
            return '<div class="qi-note" ' + delay + '>' + text + '</div>';
    }
}

function qiCollect() {
    var data = {};
    var form = QI.el.form;
    QI.inputs.forEach(function (item) {
        switch (item.type) {
            case 'text':
            case 'password':
            case 'number':
            case 'textarea':
            case 'color':
            case 'select': {
                var el = form.querySelector('[name="' + CSS.escape(String(item.name)) + '"]');
                data[item.name] = el ? el.value : '';
                break;
            }
            case 'radio': {
                var r = form.querySelector('input[type="radio"][name="' + CSS.escape(String(item.name)) + '"]:checked');
                data[item.name] = r ? r.value : (item.options && item.options[0] ? item.options[0].value : '');
                break;
            }
            case 'checkbox':
                (item.options || []).forEach(function (o) {
                    var c = form.querySelector('input[type="checkbox"][data-key="' + CSS.escape(String(o.value)) + '"]');
                    data[o.value] = c && c.checked ? 'true' : 'false';
                });
                break;
        }
    });
    return data;
}

function qiNumberBad(inp) {
    if (inp.type !== 'number' || inp.value === '') return false;
    var v = Number(inp.value);
    if (isNaN(v)) return true;
    if (inp.min !== '' && v < Number(inp.min)) return true;
    if (inp.max !== '' && v > Number(inp.max)) return true;
    return false;
}

function qiValidate() {
    var bad = null;
    QI.el.form.querySelectorAll('.qi-input').forEach(function (inp) {
        var field = inp.closest('.qi-field');
        var wrong = (inp.hasAttribute('data-required') && String(inp.value).trim() === '') || qiNumberBad(inp);
        field.classList.toggle('qi-invalid', wrong);
        if (wrong && !bad) bad = inp;
    });
    if (bad) {
        var f = bad.closest('.qi-field');
        f.classList.remove('qi-shake');
        void f.offsetWidth;
        f.classList.add('qi-shake');
        bad.focus();
        FormSfx.play('deny');
        return false;
    }
    return true;
}

function qiOpen(data) {
    if (!data) return;
    var el = QI.el;
    if (QI.closeTimer) { clearTimeout(QI.closeTimer); QI.closeTimer = null; }

    QI.inputs = Array.isArray(data.inputs) ? data.inputs : [];
    el.title.innerHTML = data.header != null ? data.header : 'Form Title';
    el.submit.textContent = data.submitText ? data.submitText : 'Submit';
    el.fields.innerHTML = QI.inputs.map(qiField).join('');
    el.kicker.textContent = QI.inputs.length > 1 ? 'INPUT · ' + QI.inputs.length + ' FIELDS' : 'INPUT';

    document.body.classList.remove('qi-closing', 'qi-visible');
    void document.body.offsetWidth;
    document.body.classList.add('qi-visible');
    QI.visible = true;
    FormSfx.play('open');

    var first = el.fields.querySelector('.qi-input, select, input[type="radio"], input[type="checkbox"]');
    if (first) setTimeout(function () { if (QI.visible) first.focus({ preventScroll: true }); }, 60);
}

function qiClose(withSound) {
    if (!QI.visible) return;
    QI.visible = false;
    if (withSound) FormSfx.play('close');
    FormSfx.sleep();
    document.body.classList.add('qi-closing');
    QI.closeTimer = setTimeout(function () {
        QI.closeTimer = null;
        document.body.classList.remove('qi-visible', 'qi-closing');
        QI.el.fields.innerHTML = '';
        QI.inputs = [];
    }, 220);
}

function qiSubmit() {
    if (!QI.visible) return;
    if (!qiValidate()) return;
    FormSfx.play('select');
    QI.el.submit.classList.remove('qi-flash');
    void QI.el.submit.offsetWidth;
    QI.el.submit.classList.add('qi-flash');
    qiPost('buttonSubmit', { data: qiCollect() });
    qiClose(false);
}

function qiCancel() {
    if (!QI.visible) return;
    qiPost('closeMenu');
    qiClose(true);
}

function qiSetStyle(style) {
    if (!style) return;
    var link = document.getElementById('qiStyle');
    var href = './styles/' + style + '.css';
    if (link && link.getAttribute('href') !== href) link.setAttribute('href', href);
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', function () {
    ['form', 'fields', 'title', 'kicker', 'submit', 'cancel'].forEach(function (id) {
        QI.el[id] = document.getElementById(id);
    });

    QI.el.form.addEventListener('submit', function (e) {
        e.preventDefault();
        qiSubmit();
    });
    QI.el.cancel.addEventListener('click', qiCancel);

    // focus moving between fields = tick (pitch follows the field)
    QI.el.fields.addEventListener('focusin', function (e) {
        var field = e.target.closest('.qi-field');
        if (!field) return;
        var all = Array.prototype.indexOf.call(QI.el.fields.children, field);
        FormSfx.play('tick', all);
    });

    // password eye / number - + buttons
    QI.el.fields.addEventListener('click', function (e) {
        var eye = e.target.closest('[data-eye]');
        if (eye) {
            var pw = document.getElementById(eye.getAttribute('data-eye'));
            var show = pw.type === 'password';
            pw.type = show ? 'text' : 'password';
            eye.classList.toggle('on', show);
            FormSfx.play('tick', show ? 3 : 0);
            return;
        }
        var btn = e.target.closest('[data-step]');
        if (btn) {
            var inp = document.getElementById(btn.getAttribute('data-for'));
            var step = Number(inp.step) || 1;
            var v = (Number(inp.value) || 0) + step * Number(btn.getAttribute('data-step'));
            if (inp.min !== '') v = Math.max(Number(inp.min), v);
            if (inp.max !== '') v = Math.min(Number(inp.max), v);
            inp.value = Math.round(v * 1000) / 1000;
            inp.closest('.qi-field').classList.remove('qi-invalid');
            FormSfx.play('tick', btn.getAttribute('data-step') === '1' ? 3 : 1);
        }
    });

    QI.el.fields.addEventListener('input', function (e) {
        var t = e.target;
        if (t.maxLength > 0) {
            var c = QI.el.fields.querySelector('.qi-count[data-for="' + t.id + '"]');
            if (c) c.textContent = t.value.length + '/' + t.maxLength;
        }
        var field = t.closest('.qi-field');
        if (field && field.classList.contains('qi-invalid') && String(t.value).trim() !== '' && !qiNumberBad(t)) field.classList.remove('qi-invalid');
        if (t.type === 'color') {
            var b = t.parentNode.querySelector('b');
            if (b) b.textContent = t.value;
        }
    });

    QI.el.fields.addEventListener('change', function (e) {
        var t = e.target;
        if (t.type === 'radio' || t.type === 'checkbox') FormSfx.play('tick', t.checked ? 3 : 0);
        else if (t.tagName === 'SELECT') FormSfx.play('tick', t.selectedIndex);
    });
});

window.addEventListener('message', function (event) {
    var msg = event.data || {};
    switch (msg.action) {
        case 'SET_STYLE':
            return qiSetStyle(msg.data);
        case 'OPEN_MENU':
            return qiOpen(msg.data);
        case 'CLOSE_MENU':
            return qiClose(true);
    }
});

document.addEventListener('keyup', function (e) {
    if (e.key === 'Escape') qiCancel();
});

// Enter inside an <input> already submits the form natively; this covers the rest (select, page)
document.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' || !QI.visible) return;
    var tag = e.target && e.target.tagName;
    if (tag === 'INPUT' || tag === 'BUTTON' || tag === 'TEXTAREA') return;
    e.preventDefault();
    qiSubmit();
});
