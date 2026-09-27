'use strict';
/* ============================================================================
   Command Wheel — radial menu for qb-radialmenu
   Identity: deep navy glass, royal-blue signal light, one sound palette.
   Same public API as the original RadialMenu (new RadialMenu(params), open(),
   close(), destroy()) and the same item format coming from client/menu.lua:
     { id, title, icon: '#symbol', close, functiontype, functionName,
       functionParameters, items: [...] }
   ============================================================================ */

var MIN_SECTORS = 3;
var SVGNS = 'http://www.w3.org/2000/svg';
var XLINK = 'http://www.w3.org/1999/xlink';

// ---------------------------------------------------------------------------
// Sound identity: every cue is built from the same D-minor pentatonic set and
// the same soft "glass" timbre, so the menu always sounds like itself.
// ---------------------------------------------------------------------------
var WheelSfx = {
    enabled: true,
    volume: 0.35,
    ctx: null,
    master: null,
    notes: [293.66, 349.23, 392.0, 440.0, 523.25], // D4 F4 G4 A4 C5
    lastTick: 0,

    init: function () {
        if (this.ctx) {
            if (this.ctx.state === 'suspended') this.ctx.resume();
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
                this.tone(70, t, 0.16, 'sine', 0.35, 48);          // low body
                this.tone(n[0], t, 0.22, 'sine', 0.10, n[4]);     // rising sweep
                this.tone(n[3] * 2, t + 0.09, 0.14, 'triangle', 0.07);
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
            case 'enter':
                this.tone(n[0] * 2, t, 0.06, 'triangle', 0.08);
                this.tone(n[1] * 2, t + 0.05, 0.06, 'triangle', 0.08);
                this.tone(n[3] * 2, t + 0.1, 0.12, 'triangle', 0.09);
                break;
            case 'back':
                this.tone(n[3] * 2, t, 0.06, 'triangle', 0.08);
                this.tone(n[0] * 2, t + 0.06, 0.1, 'triangle', 0.08);
                break;
            case 'deny':
                this.tone(150, t, 0.09, 'square', 0.05, 110);
                break;
        }
    }
};

// ---------------------------------------------------------------------------
// Geometry helpers (angles in degrees, clockwise from 12 o'clock)
// ---------------------------------------------------------------------------
function rmPoint(angle, r) {
    var a = angle * Math.PI / 180;
    return { x: r * Math.sin(a), y: -r * Math.cos(a) };
}
function rmN(n) { return (Math.round(n * 1000) / 1000).toString(); }
function rmArcPath(a0, a1, r0, r1) {
    var large = (a1 - a0) > 180 ? 1 : 0;
    var p0 = rmPoint(a0, r1), p1 = rmPoint(a1, r1), p2 = rmPoint(a1, r0), p3 = rmPoint(a0, r0);
    return 'M' + rmN(p0.x) + ' ' + rmN(p0.y) +
        ' A' + r1 + ' ' + r1 + ' 0 ' + large + ' 1 ' + rmN(p1.x) + ' ' + rmN(p1.y) +
        ' L' + rmN(p2.x) + ' ' + rmN(p2.y) +
        ' A' + r0 + ' ' + r0 + ' 0 ' + large + ' 0 ' + rmN(p3.x) + ' ' + rmN(p3.y) + ' Z';
}
function rmEl(tag, attrs, parent) {
    var el = document.createElementNS(SVGNS, tag);
    for (var k in attrs) if (Object.prototype.hasOwnProperty.call(attrs, k)) el.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(el);
    return el;
}
function rmWrap(title, maxChars) {
    var words = String(title || '').split(/\s+/).filter(Boolean);
    var lines = [], cur = '';
    words.forEach(function (w) {
        if (!cur) cur = w;
        else if ((cur + ' ' + w).length <= maxChars) cur += ' ' + w;
        else { lines.push(cur); cur = w; }
    });
    if (cur) lines.push(cur);
    if (lines.length > 2) lines = [lines[0], lines.slice(1).join(' ')];
    return lines.map(function (l) { return l.length > maxChars + 3 ? l.slice(0, maxChars + 2) + '…' : l; });
}

// ---------------------------------------------------------------------------
// RadialMenu
// ---------------------------------------------------------------------------
function RadialMenu(params) {
    var self = this;
    self.parent = params.parent;
    self.size = params.size || 450;
    self.onClick = params.onClick || null;
    self.closeOnClick = params.closeOnClick !== undefined ? !!params.closeOnClick : false;
    self.menuItems = params.menuItems || [];

    self.R = 38;         // sector outer radius (svg units, viewBox 100)
    self.r = 15.5;       // sector inner radius
    self.padDeg = 1.4;   // gap between sectors

    self.stack = [];     // [{ items, title, level, selected }]
    self.level = null;   // current level <g>
    self.items = null;
    self.selected = -1;
    self.count = 0;
    self.indicatorAngle = 0;
    self.pointerInCenter = false;
    self.closed = false;
    self.busy = false;

    self.build();

    self.onMove = self.handlePointerMove.bind(self);
    self.onDown = self.handlePointerDown.bind(self);
    self.onKey = self.onKeyDown.bind(self);
    self.onWheel = self.onMouseWheel.bind(self);
    self.onContext = function (e) { e.preventDefault(); };
    window.addEventListener('mousemove', self.onMove);
    window.addEventListener('mousedown', self.onDown);
    window.addEventListener('contextmenu', self.onContext);
    document.addEventListener('keydown', self.onKey);
    document.addEventListener('wheel', self.onWheel, { passive: true });
}

RadialMenu.prototype.build = function () {
    var self = this;
    var holder = document.createElement('div');
    holder.className = 'rm-holder';
    holder.style.width = self.size + 'px';
    holder.style.height = self.size + 'px';
    self.holder = holder;

    var halo = document.createElement('div');
    halo.className = 'rm-halo';
    holder.appendChild(halo);

    var svg = rmEl('svg', { 'class': 'rm-svg', viewBox: '-50 -50 100 100', width: self.size, height: self.size });
    self.svg = svg;

    var defs = rmEl('defs', {}, svg);
    var g1 = rmEl('radialGradient', { id: 'rmSector', cx: '0', cy: '0', r: '40', gradientUnits: 'userSpaceOnUse' }, defs);
    rmEl('stop', { offset: '0.35', 'stop-color': '#050c20', 'stop-opacity': '0.9' }, g1);
    rmEl('stop', { offset: '1', 'stop-color': '#0b1a3d', 'stop-opacity': '0.88' }, g1);
    var g2 = rmEl('radialGradient', { id: 'rmSectorHot', cx: '0', cy: '0', r: '40', gradientUnits: 'userSpaceOnUse' }, defs);
    rmEl('stop', { offset: '0.35', 'stop-color': '#0a1f5c', 'stop-opacity': '0.95' }, g2);
    rmEl('stop', { offset: '1', 'stop-color': '#1a4bd6', 'stop-opacity': '0.95' }, g2);
    var g3 = rmEl('radialGradient', { id: 'rmCore', cx: '0', cy: '-4', r: '16', gradientUnits: 'userSpaceOnUse' }, defs);
    rmEl('stop', { offset: '0', 'stop-color': '#10275e' }, g3);
    rmEl('stop', { offset: '1', 'stop-color': '#040a1b' }, g3);
    var glow = rmEl('filter', { id: 'rmGlow', x: '-50%', y: '-50%', width: '200%', height: '200%' }, defs);
    rmEl('feGaussianBlur', { stdDeviation: '1.1', result: 'b' }, glow);
    var merge = rmEl('feMerge', {}, glow);
    rmEl('feMergeNode', { 'in': 'b' }, merge);
    rmEl('feMergeNode', { 'in': 'SourceGraphic' }, merge);

    // decorative rings (the "instrument" around the wheel)
    var deco = rmEl('g', { 'class': 'rm-deco' }, svg);
    rmEl('circle', { 'class': 'rm-ring-ticks', cx: 0, cy: 0, r: 46.2 }, deco);
    rmEl('circle', { 'class': 'rm-ring-thin', cx: 0, cy: 0, r: 43.4 }, deco);
    rmEl('circle', { 'class': 'rm-ring-scan', cx: 0, cy: 0, r: 44.8 }, deco);

    // indicator arc that follows the selected sector
    self.indicator = rmEl('g', { 'class': 'rm-indicator' }, svg);
    self.indicatorPath = rmEl('path', { d: '' }, self.indicator);

    self.levelsLayer = rmEl('g', { 'class': 'rm-levels' }, svg);

    // center core
    var center = rmEl('g', { 'class': 'rm-center' }, svg);
    self.center = center;
    rmEl('circle', { 'class': 'rm-core', cx: 0, cy: 0, r: self.r - 1.6 }, center);
    rmEl('circle', { 'class': 'rm-core-spin', cx: 0, cy: 0, r: self.r - 3.2 }, center);
    rmEl('circle', { 'class': 'rm-core-edge', cx: 0, cy: 0, r: self.r - 1.6 }, center);
    self.centerKicker = rmEl('text', { 'class': 'rm-kicker', x: 0, y: -5.6, 'text-anchor': 'middle' }, center);
    self.centerTitle = rmEl('text', { 'class': 'rm-title', x: 0, y: 0.4, 'text-anchor': 'middle' }, center);
    self.centerTitle2 = rmEl('text', { 'class': 'rm-title', x: 0, y: 3.9, 'text-anchor': 'middle' }, center);
    self.centerHint = rmEl('g', { 'class': 'rm-hint' }, center);
    self.centerHintText = rmEl('text', { x: 0, y: 8.4, 'text-anchor': 'middle' }, self.centerHint);

    holder.appendChild(svg);
    self.parent.appendChild(holder);
};

// ---------------------------------------------------------------------------
// Levels
// ---------------------------------------------------------------------------
RadialMenu.prototype.buildLevel = function (items) {
    var self = this;
    var count = Math.max(items.length, MIN_SECTORS);
    var step = 360 / count;
    var g = rmEl('g', { 'class': 'rm-level' });
    var dense = count >= 9;
    var iconSize = dense ? 6 : (count >= 7 ? 7 : 7.8);
    var fontSize = dense ? 2.25 : 2.6;
    var labelR = (self.r + self.R) / 2;

    for (var i = 0; i < count; i++) {
        var item = items[i] || null;
        var a0 = i * step - step / 2 + self.padDeg / 2;
        var a1 = i * step + step / 2 - self.padDeg / 2;
        var mid = i * step;
        var push = rmPoint(mid, 1.8);

        var wrap = rmEl('g', { 'class': 'rm-sw', style: 'animation-delay:' + (i * 26) + 'ms' }, g);
        var sector = rmEl('g', {
            'class': item ? 'rm-sector' : 'rm-sector rm-dummy',
            'data-index': item ? i : -1,
            style: '--dx:' + rmN(push.x) + 'px;--dy:' + rmN(push.y) + 'px'
        }, wrap);
        rmEl('path', { 'class': 'rm-face', d: rmArcPath(a0, a1, self.r, self.R) }, sector);
        rmEl('path', { 'class': 'rm-rim', d: rmArcPath(a0 + 0.6, a1 - 0.6, self.R - 0.9, self.R - 0.2) }, sector);

        if (!item) continue;
        var c = rmPoint(mid, labelR);
        var lines = item.title ? rmWrap(item.title, dense ? 9 : 11) : [];
        var iconY = c.y - (lines.length ? (lines.length > 1 ? 5.0 : 4.0) : 0);
        if (item.icon) {
            self.drawIcon(sector, item.icon, c.x, iconY, iconSize);
        }
        if (lines.length) {
            var text = rmEl('text', { 'class': 'rm-label', 'text-anchor': 'middle', 'font-size': fontSize }, sector);
            var startY = item.icon ? iconY + iconSize / 2 + fontSize * 1.2 : c.y - (lines.length - 1) * fontSize * 0.55 + fontSize * 0.35;
            lines.forEach(function (line, li) {
                var t = rmEl('tspan', { x: rmN(c.x), y: rmN(startY + li * fontSize * 1.1) }, text);
                t.textContent = line;
            });
        }
        if (item.items) {
            var p = rmPoint(mid, self.R - 2.6);
            rmEl('circle', { 'class': 'rm-sub-dot', cx: rmN(p.x), cy: rmN(p.y), r: 0.7 }, sector);
        }
    }
    return { g: g, count: count, step: step };
};

// Icons: copy the Font Awesome symbol's shapes into our own <svg> (its viewBox,
// no FA classes on the viewport), so FA's CSS can never resize/offset them.
// Falls back to <use> if the symbol isn't generated yet.
RadialMenu.prototype.drawIcon = function (parent, ref, cx, cy, size) {
    var wrap = rmEl('g', { 'class': 'rm-icon' }, parent);
    var id = String(ref || '').replace(/^#/, '');
    var sym = id ? document.getElementById(id) : null;
    if (sym && sym.tagName.toLowerCase() === 'symbol') {
        var inner = rmEl('svg', {
            x: rmN(cx - size / 2), y: rmN(cy - size / 2), width: size, height: size,
            viewBox: sym.getAttribute('viewBox') || '0 0 512 512',
            overflow: 'visible'
        }, wrap);
        inner.innerHTML = sym.innerHTML;
    } else {
        var use = rmEl('use', { x: rmN(cx - size / 2), y: rmN(cy - size / 2), width: size, height: size, style: 'font-size:' + size + 'px' }, wrap);
        use.setAttributeNS(XLINK, 'xlink:href', ref);
        use.setAttribute('href', ref);
    }
    return wrap;
};

RadialMenu.prototype.showLevel = function (items, direction) {
    var self = this;
    var built = self.buildLevel(items);
    var old = self.level;

    self.items = items;
    self.count = built.count;
    self.step = built.step;
    self.level = built.g;
    self.selected = -1;

    // indicator arc sized to one sector
    var half = self.step / 2 - self.padDeg / 2;
    self.indicatorPath.setAttribute('d', rmArcPath(-half, half, 40.3, 41.6));

    built.g.classList.add(direction === 'back' ? 'rm-from-out' : (direction === 'enter' ? 'rm-from-in' : 'rm-from-center'));
    self.levelsLayer.appendChild(built.g);

    if (old) {
        old.classList.add(direction === 'back' ? 'rm-leave-out' : 'rm-leave-in');
        old.style.pointerEvents = 'none';
        setTimeout(function () { if (old.parentNode) old.parentNode.removeChild(old); }, 320);
    }

    self.updateKicker();
    var first = items.length ? 0 : -1;
    var remembered = direction === 'back' && self.restoreSelected !== undefined ? self.restoreSelected : first;
    self.select(remembered, true);
};

RadialMenu.prototype.updateKicker = function () {
    var self = this;
    var path = self.stack.map(function (s) { return s.title; }).filter(Boolean);
    var kicker = path.length ? path[path.length - 1].toUpperCase() : 'MENU';
    if (kicker.length > 18) kicker = kicker.slice(0, 17) + '…';
    self.centerKicker.textContent = kicker;
    self.centerKicker.style.fontSize = kicker.length > 12 ? '1.55px' : '';
    self.centerKicker.style.letterSpacing = kicker.length > 12 ? '0.25px' : '';
    self.centerHintText.textContent = self.stack.length ? 'RMB · BACK' : 'RMB · CLOSE';
};

// ---------------------------------------------------------------------------
// Selection
// ---------------------------------------------------------------------------
RadialMenu.prototype.select = function (index, silent) {
    var self = this;
    if (!self.level || index === self.selected) return;
    if (index < 0 || index >= self.items.length) return;

    var prev = self.level.querySelector('.rm-sector.selected');
    if (prev) prev.classList.remove('selected');
    var node = self.level.querySelector('.rm-sector[data-index="' + index + '"]');
    if (node) node.classList.add('selected');
    self.selected = index;

    // shortest rotation for the indicator (no spinning the long way round)
    var target = index * self.step;
    var cur = self.indicatorAngle;
    var diff = ((target - cur) % 360 + 540) % 360 - 180;
    self.indicatorAngle = cur + diff;
    self.indicator.style.transform = 'rotate(' + self.indicatorAngle + 'deg)';
    self.indicator.classList.add('on');

    var item = self.items[index];
    var lines = rmWrap(item && item.title ? item.title : '', 13);
    self.centerTitle.textContent = lines[0] || '';
    self.centerTitle2.textContent = lines[1] || '';
    self.centerTitle.setAttribute('y', lines[1] ? -0.9 : 1.2);

    if (!silent) WheelSfx.play('tick', index);
};

RadialMenu.prototype.selectDelta = function (delta) {
    var self = this;
    if (!self.items || !self.items.length) return;
    var n = self.items.length;
    var i = self.selected < 0 ? 0 : self.selected;
    self.select(((i + delta) % n + n) % n);
};

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------
RadialMenu.prototype.activate = function () {
    var self = this;
    if (self.busy || self.closed || self.selected < 0) return;
    var item = self.items[self.selected];
    if (!item) return WheelSfx.play('deny');

    var node = self.level.querySelector('.rm-sector[data-index="' + self.selected + '"]');
    if (node) {
        node.classList.remove('rm-flash');
        void node.getBBox();
        node.classList.add('rm-flash');
    }
    self.pulse();

    if (item.items && item.items.length) {
        WheelSfx.play('enter');
        self.stack.push({ items: self.items, title: item.title, selected: self.selected });
        self.busy = true;
        setTimeout(function () { self.busy = false; }, 200);
        self.showLevel(item.items, 'enter');
        return;
    }

    WheelSfx.play('select');
    if (self.onClick) {
        self.onClick(item);
        if (self.closeOnClick) self.close();
    }
};

RadialMenu.prototype.back = function () {
    var self = this;
    if (self.busy || self.closed) return;
    if (self.stack.length) {
        var prev = self.stack.pop();
        WheelSfx.play('back');
        self.restoreSelected = prev.selected;
        self.busy = true;
        setTimeout(function () { self.busy = false; }, 200);
        self.showLevel(prev.items, 'back');
        self.restoreSelected = undefined;
    } else {
        self.close();
    }
};

RadialMenu.prototype.pulse = function () {
    var ring = rmEl('circle', { 'class': 'rm-pulse', cx: 0, cy: 0, r: this.r - 1.6 }, this.svg);
    setTimeout(function () { ring.remove(); }, 520);
};

// Kept for compatibility with the original API.
RadialMenu.prototype.handleClick = function () { this.activate(); };
RadialMenu.prototype.handleCenterClick = function () { this.back(); };

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------
RadialMenu.prototype.pointerInfo = function (e) {
    var rect = this.svg.getBoundingClientRect();
    var unit = rect.width / 100;
    var dx = (e.clientX - (rect.left + rect.width / 2)) / unit;
    var dy = (e.clientY - (rect.top + rect.height / 2)) / unit;
    var dist = Math.sqrt(dx * dx + dy * dy);
    var angle = (Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360;
    return { dist: dist, angle: angle };
};

RadialMenu.prototype.handlePointerMove = function (e) {
    var self = this;
    if (self.closed || !self.level) return;
    var p = self.pointerInfo(e);
    var inCenter = p.dist < self.r - 1;
    if (inCenter !== self.pointerInCenter) {
        self.pointerInCenter = inCenter;
        self.center.classList.toggle('hover', inCenter);
    }
    // Direction-based selection (like a weapon wheel): you don't have to be
    // exactly on a sector, just point toward it.
    if (!inCenter && p.dist > self.r - 1 && p.dist < 70) {
        var index = Math.round(p.angle / self.step) % self.count;
        if (index < self.items.length) self.select(index);
    }
};

RadialMenu.prototype.handlePointerDown = function (e) {
    var self = this;
    if (self.closed || !self.level) return;
    if (e.button === 2) { self.back(); return; }
    if (e.button !== 0) return;
    var p = self.pointerInfo(e);
    if (p.dist < self.r - 1) self.back();
    else if (p.dist < 70) self.activate();
};

RadialMenu.prototype.onKeyDown = function (event) {
    var self = this;
    if (self.closed || !self.level) return;
    switch (event.key) {
        case 'Escape':
        case 'Backspace':
            self.back(); event.preventDefault(); return;
        case 'Enter':
        case ' ':
            self.activate(); event.preventDefault(); return;
        case 'ArrowRight':
        case 'ArrowDown':
            self.selectDelta(1); event.preventDefault(); return;
        case 'ArrowLeft':
        case 'ArrowUp':
            self.selectDelta(-1); event.preventDefault(); return;
    }
    // 1-9: jump straight to (and trigger) that slot
    if (/^[1-9]$/.test(event.key)) {
        var idx = parseInt(event.key, 10) - 1;
        if (idx < self.items.length) { self.select(idx, true); self.activate(); }
    }
};

RadialMenu.prototype.onMouseWheel = function (event) {
    if (this.closed || !this.level) return;
    this.selectDelta(event.deltaY > 0 ? 1 : -1);
};

// ---------------------------------------------------------------------------
// Open / close
// ---------------------------------------------------------------------------
RadialMenu.prototype.open = function () {
    var self = this;
    self.closed = false;
    self.holder.classList.remove('rm-closing');
    self.showLevel(self.menuItems, 'open');
    requestAnimationFrame(function () { self.holder.classList.add('rm-open'); });
    WheelSfx.play('open');
};

// Closing from inside the menu: tell the client, play the exit animation.
RadialMenu.prototype.close = function () {
    var self = this;
    if (self.closed) return;
    self.collapse();
    fetch('https://' + RadialMenu.resource() + '/closemenu', { method: 'POST', body: '{}' }).catch(function () {});
};

RadialMenu.prototype.collapse = function () {
    var self = this;
    if (self.closed) return;
    self.closed = true;
    WheelSfx.play('close');
    self.holder.classList.remove('rm-open');
    self.holder.classList.add('rm-closing');
};

RadialMenu.prototype.destroy = function () {
    var self = this;
    window.removeEventListener('mousemove', self.onMove);
    window.removeEventListener('mousedown', self.onDown);
    window.removeEventListener('contextmenu', self.onContext);
    document.removeEventListener('keydown', self.onKey);
    document.removeEventListener('wheel', self.onWheel);
    if (!self.closed) self.collapse();
    var holder = self.holder;
    setTimeout(function () { if (holder.parentNode) holder.parentNode.removeChild(holder); }, 260);
};

RadialMenu.resource = function () {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-radialmenu';
};

// small helpers kept from the original for anything that referenced them
RadialMenu.nextTick = function (fn) { setTimeout(fn, 10); };
RadialMenu.degToRad = function (deg) { return deg * (Math.PI / 180); };
