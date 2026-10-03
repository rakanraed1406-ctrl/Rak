/* ============================================================================
   JT-Hud — NUI logic v2 (no jQuery, no icon fonts, no network)
   Every setter compares with the last value first, so repeated Lua messages
   with the same data cost nothing on the page.
   ============================================================================ */
(function () {
    'use strict';

    var RES = (typeof window.GetParentResourceName === 'function') ? window.GetParentResourceName() : 'JT-Hud';
    var byId = function (id) { return document.getElementById(id); };

    // ── state ──────────────────────────────────────────────────────────────
    var S = {
        visible: true,
        inVeh: false,
        forceAll: false,
        last: null,
        heading: 0,
        wp: null,            // waypoint compass bearing (0..359) or null
        bars: { voice: true, health: true, armor: true, hunger: true, thirst: true, stress: true, stamina: true, oxygen: true, engineHealth: true }
    };

    // ── tiny cached DOM helpers ────────────────────────────────────────────
    function setText(el, s) {
        s = String(s);
        if (el._t !== s) { el._t = s; el.textContent = s; }
    }
    function setCls(el, cls, on) {
        on = !!on;
        var k = '_c_' + cls;
        if (el[k] !== on) { el[k] = on; el.classList.toggle(cls, on); }
    }
    function setHref(el, id) {
        if (el._h !== id) { el._h = id; el.setAttribute('href', id); }
    }
    // works for SVG elements too (they have no .hidden property)
    function setHidden(el, hide) {
        hide = !!hide;
        if (el._hid !== hide) { el._hid = hide; if (hide) el.setAttribute('hidden', ''); else el.removeAttribute('hidden'); }
    }
    function setStyle(el, prop, val) {
        var k = '_s_' + prop;
        if (el[k] !== val) { el[k] = val; el.style[prop] = val; }
    }
    // fade/slide in or out; [hidden] removes it from layout once faded (HTML elements)
    function show(el, on) {
        on = !!on;
        if (el._on === on) return;
        el._on = on;
        clearTimeout(el._timer);
        if (on) {
            el.hidden = false;
            void el.offsetWidth;            // commit the start state so the transition runs
            el.classList.add('on');
        } else {
            el.classList.remove('on');
            el._timer = setTimeout(function () { if (!el._on) el.hidden = true; }, 260);
        }
    }
    function clamp(v, a, b) { v = Number(v); if (!isFinite(v)) v = a; return v < a ? a : v > b ? b : v; }
    function num(x) { return (x && typeof x === 'object') ? Number(x.range) : Number(x); }
    function two(n) { return (n < 10 ? '0' : '') + n; }
    function fmt(n) { return Math.floor(Math.abs(Number(n) || 0)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
    function fmtDist(km) { return km < 1 ? (Math.round(km * 100) * 10) + ' M' : km.toFixed(1) + ' KM'; }
    function wrap180(a) { return ((a % 360) + 540) % 360 - 180; }
    function post(name, body) {
        return fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {})
        });
    }

    // ── scale: lay out on 1920x1080, scale by height ───────────────────────
    var scaleEl = byId('scale');
    function fit() {
        var s = window.innerHeight / 1080;
        scaleEl.style.transform = 'scale(' + s + ')';
        scaleEl.style.width = (window.innerWidth / s) + 'px';
    }
    window.addEventListener('resize', fit);
    fit();

    var hudEl = byId('hud');
    function setHudVisible(on) {
        S.visible = !!on;
        setCls(hudEl, 'off', !on);
    }

    // ══════════════════ DATE / TIME (device time, like "WED SEP 16, 2026 00:18:16") ══════════
    var MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    var DAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    var dtEl = byId('datetime'), dtDate = byId('dt-date'), dtTime = byId('dt-time');
    var clockSeconds = true, clockTimer = null;
    function tick() {
        var d = new Date();
        setText(dtDate, DAYS[d.getDay()] + ' ' + MONTHS[d.getMonth()] + ' ' + two(d.getDate()) + ', ' + d.getFullYear());
        setText(dtTime, two(d.getHours()) + ':' + two(d.getMinutes()) + (clockSeconds ? ':' + two(d.getSeconds()) : ''));
        // next redraw exactly on the next second (or minute when seconds are off)
        clearTimeout(clockTimer);
        clockTimer = setTimeout(tick, clockSeconds ? 1010 - d.getMilliseconds() : 60050 - d.getSeconds() * 1000 - d.getMilliseconds());
    }
    tick();

    // ══════════════════ COMPASS (top centre) ══════════════════
    // The ribbon is drawn once (-180°..540°) and only slides with a transform.
    var CW = 500, PPD = 2.6, C0 = -180, C1 = 540;
    var CARD = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    var compassEl = byId('compass'), strip = byId('cmp-strip');
    var cmpCard = byId('cmp-card'), cmpDeg = byId('cmp-deg'), cmpStreet = byId('cmp-street'), cmpCross = byId('cmp-cross');
    var cmpZone = byId('cmp-zone'), cmpWpd = byId('cmp-wpd'), cmpWpdT = byId('cmp-wpd-t');
    var edgeL = byId('cmp-edge-l'), edgeR = byId('cmp-edge-r');
    var wpMarks = [];

    (function buildStrip() {
        var w = (C1 - C0) * PPD, o = [];
        o.push('<svg width="' + w + '" height="36" viewBox="0 0 ' + w + ' 36">');
        for (var d = C0; d <= C1; d += 5) {
            var x = ((d - C0) * PPD).toFixed(1), n = ((d % 360) + 360) % 360;
            if (n % 45 === 0) {
                var north = n === 0, col = north ? '#ff5d73' : '#eef3ff';
                o.push('<line x1="' + x + '" x2="' + x + '" y1="27" y2="36" stroke="' + col + '" stroke-width="2"/>');
                o.push('<text x="' + x + '" y="21" text-anchor="middle" font-size="' + (n % 90 === 0 ? 13 : 11) +
                       '" font-weight="800" fill="' + col + '">' + CARD[n / 45] + '</text>');
            } else if (n % 15 === 0) {
                o.push('<line x1="' + x + '" x2="' + x + '" y1="29" y2="36" stroke="rgba(143,176,255,0.6)" stroke-width="1.3"/>');
                o.push('<text x="' + x + '" y="20" text-anchor="middle" font-size="9" font-weight="600" fill="rgba(141,155,196,0.85)">' + n + '</text>');
            } else {
                o.push('<line x1="' + x + '" x2="' + x + '" y1="32" y2="36" stroke="rgba(143,176,255,0.35)" stroke-width="1"/>');
            }
        }
        o.push('</svg>');
        strip.innerHTML = o.join('');
        strip.style.width = w + 'px';
        for (var i = 0; i < 3; i++) {
            var m = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            m.setAttribute('class', 'ic cmp-wp');
            m.innerHTML = '<use href="#i-pin"/>';
            setHidden(m, true);
            strip.appendChild(m);
            wpMarks.push(m);
        }
    })();

    var cmpU = null;   // unwrapped heading, so 359° → 1° slides 2° and not 358°
    function compassHeading(h) {
        h = ((Number(h) || 0) % 360 + 360) % 360;
        var snap = false;
        if (cmpU === null) { cmpU = h; snap = true; }
        else {
            cmpU += wrap180(h - cmpU);
            // the ribbon repeats every 360°, so re-centring is invisible
            if (cmpU < -60 || cmpU > 420) { cmpU = ((cmpU % 360) + 360) % 360; snap = true; }
        }
        setCls(strip, 'snap', snap);
        strip.style.transform = 'translateX(' + (CW / 2 - (cmpU - C0) * PPD).toFixed(1) + 'px)';
        S.heading = h;
        setText(cmpDeg, Math.round(h) % 360 + '°');
        setText(cmpCard, CARD[Math.round(h / 45) % 8]);
        wpEdges();
    }

    function wpEdges() {
        var rel = S.wp === null ? 0 : wrap180(S.wp - S.heading);
        setCls(edgeL, 'on', S.wp !== null && rel < -62);
        setCls(edgeR, 'on', S.wp !== null && rel > 62);
    }

    function updateNav(d) {
        var area = String(d.area || d.zone || '');
        setText(cmpZone, area.toUpperCase());
        setText(cmpStreet, d.street || d.streetName || area || 'Unknown');
        var cross = d.crossing ? String(d.crossing) : '';
        setText(cmpCross, cross ? '/ ' + cross : '');
        setHidden(cmpCross, !cross);

        var dist = Number(d.waydist);
        var has = isFinite(dist) && dist >= 0 && typeof d.wpBearing === 'number';
        if (has) {
            if (S.wp !== d.wpBearing) {
                S.wp = d.wpBearing;
                for (var i = 0; i < 3; i++) {
                    wpMarks[i].style.left = ((S.wp + (i - 1) * 360 - C0) * PPD).toFixed(1) + 'px';
                    setHidden(wpMarks[i], false);
                }
            }
            setText(cmpWpdT, fmtDist(dist));
        } else if (S.wp !== null) {
            S.wp = null;
            for (var j = 0; j < 3; j++) setHidden(wpMarks[j], true);
        }
        setHidden(cmpWpd, !has);
        wpEdges();
    }

    // ══════════════════ STATUS (bottom right, tilted) ══════════════════
    var statusEl = byId('status'), sHeart = byId('s-heart'), sHpFill = byId('s-hp-fill'), sHpNum = byId('s-hp-num');
    var stamCells = byId('s-stam').children, STAM = stamCells.length;
    var sVoice = byId('s-voice'), sMic = byId('s-mic'), vBars = byId('s-vbars').children, VB = vBars.length;

    function box(key) {
        var el = byId('b-' + key);
        return { el: el, line: el.querySelector('.s-line i'), num: el.querySelector('b'), v: -1 };
    }
    var B = { stress: box('stress'), hunger: box('hunger'), thirst: box('thirst'), armor: box('armor') };
    var BOX_KEYS = ['stress', 'hunger', 'thirst', 'armor'];
    var CRIT = {
        stress: function (v) { return v >= 80; },
        hunger: function (v) { return v <= 20; },
        thirst: function (v) { return v <= 20; },
        armor:  function () { return false; }
    };

    function boxLevel(t, key, v) {
        v = Math.round(clamp(v, 0, 100));
        if (t.v !== v) {
            t.v = v;
            t.line.style.transform = 'scaleX(' + (v / 100) + ')';
            setText(t.num, v);
        }
        setCls(t.el, 'crit', CRIT[key](v));
        setHidden(t.el, !S.bars[key]);
    }

    var lastHp = -1, lastStam = -1;
    function vitals(d) {
        var hp = Math.round(clamp(num(d.health), 0, 100));
        if (hp !== lastHp) {
            lastHp = hp;
            sHpFill.style.transform = 'scaleX(' + (hp / 100) + ')';
            setText(sHpNum, hp);
        }
        var crit = hp <= 25 || !!d.playerDead;
        setCls(statusEl, 'crit', crit);
        setCls(sHeart, 'crit', crit);                      // re-adding .crit replays the short heartbeat

        // stamina dashes on top of the bar (oxygen under water)
        var o = d.oxygen, water = !!(o && typeof o === 'object' && o.inwater);
        setCls(statusEl, 'water', water);
        var lit = Math.ceil(clamp(num(o), 0, 100) / 100 * STAM);
        if (lit !== lastStam) {
            lastStam = lit;
            for (var i = 0; i < STAM; i++) setCls(stamCells[i], 'on', i < lit);
        }
        setStyle(byId('s-stam'), 'visibility', (water ? (S.bars.oxygen || S.bars.stamina) : S.bars.stamina) ? 'visible' : 'hidden');
    }

    // voice: lit bars = range; they only move while you talk (or transmit on radio)
    var voiceState = { mode: null, lvl: 0 };
    function voice(d) {
        if (!d || typeof d !== 'object') return;
        var mode = d.radio ? 'radio' : (d.talking ? 'talk' : 'idle');
        if (mode !== voiceState.mode) {
            voiceState.mode = mode;
            setCls(sVoice, 'talk', mode === 'talk');
            setCls(sVoice, 'radio', mode === 'radio');
            setHref(sMic, mode === 'radio' ? '#i-radio' : '#i-mic');
        }
        var r = Number(d.range) || 3;
        var lvl = r <= 1.5 ? 3 : r <= 3 ? 6 : VB;
        if (lvl !== voiceState.lvl) {
            voiceState.lvl = lvl;
            for (var i = 0; i < VB; i++) setCls(vBars[i], 'on', i < lvl);
        }
        setHidden(sVoice, !S.bars.voice);
    }

    function updateHud(d) {
        S.last = d;
        vitals(d);
        voice(d.voice);
        for (var i = 0; i < BOX_KEYS.length; i++) {
            var k = BOX_KEYS[i];
            var v = clamp(num(k === 'armor' ? d.armor : d[k]), 0, 100);
            boxLevel(B[k], k, v < 1 ? 0 : v);
        }
    }

    // ══════════════════ VEHICLE CLUSTER ══════════════════
    // "Kick" lines: a short diagonal into a long horizontal (SVG space 340x126).
    var RPM_PTS = [[4, 90], [32, 58], [338, 58]];
    var FUEL_PTS = [[22, 26], [32, 16], [166, 16]];
    var ENG_PTS = [[22, 45], [32, 35], [166, 35]];
    var RPM_SEGS = 40, RED_SEGS = 6, BAR_SEGS = 20;   // must match the mask dash patterns in index.html

    function poly(pts) {
        var s = 'M ' + pts[0][0] + ' ' + pts[0][1];
        for (var i = 1; i < pts.length; i++) s += ' L ' + pts[i][0].toFixed(2) + ' ' + pts[i][1].toFixed(2);
        return s;
    }
    // split a polyline at fraction t of its length
    function splitAt(pts, t) {
        var lens = [], total = 0, i;
        for (i = 1; i < pts.length; i++) {
            var l = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
            lens.push(l); total += l;
        }
        var want = total * t, acc = 0;
        for (i = 1; i < pts.length; i++) {
            if (acc + lens[i - 1] >= want) {
                var f = (want - acc) / lens[i - 1];
                var p = [pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * f, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * f];
                return [pts.slice(0, i).concat([p]), [p].concat(pts.slice(i))];
            }
            acc += lens[i - 1];
        }
        return [pts, [pts[pts.length - 1]]];
    }
    (function buildCar() {
        var set = function (id, d) { byId(id).setAttribute('d', d); };
        var parts = splitAt(RPM_PTS, (RPM_SEGS - RED_SEGS) / RPM_SEGS);
        var normal = poly(parts[0]), red = poly(parts[1]);
        set('sh-rpm', poly(RPM_PTS)); set('sh-fuel', poly(FUEL_PTS)); set('sh-eng', poly(ENG_PTS));
        set('m-rpm', poly(RPM_PTS)); set('m-fuel', poly(FUEL_PTS)); set('m-eng', poly(ENG_PTS));
        set('p-track', normal); set('p-track-red', red);
        set('p-rpm', normal); set('p-rpm-red', red); set('p-glow', normal);
        set('p-fuel-track', poly(FUEL_PTS)); set('p-fuel', poly(FUEL_PTS));
        set('p-eng-track', poly(ENG_PTS)); set('p-eng', poly(ENG_PTS));
    })();

    var carEl = byId('car'), mapEl = byId('mapframe');
    var pRpm = byId('p-rpm'), pRed = byId('p-rpm-red'), pGlow = byId('p-glow');
    var pFuel = byId('p-fuel'), pEng = byId('p-eng');
    var fuelIc = byId('c-fuel-ic'), engIc = byId('c-eng-ic'), fuelUse = byId('fuel-use');
    var fuelV = byId('c-fuel-v'), engV = byId('c-eng-v');
    var digits = byId('c-speed').children, unitEl = byId('c-unit');
    var gearsEl = byId('c-gears'), altEl = byId('c-alt'), altV = byId('c-alt-v');
    var ci = {
        left: byId('ci-left'), right: byId('ci-right'), lock: byId('ci-lock'), lights: byId('ci-lights'),
        lightsUse: byId('ci-lights-use'), belt: byId('ci-belt'), brake: byId('ci-brake'),
        engine: byId('ci-engine'), body: byId('ci-body'), cruise: byId('ci-cruise')
    };

    function setVehicleUi(on) {
        S.inVeh = !!on;
        show(carEl, on);
        show(mapEl, on);
        setCls(dtEl, 'veh', on);                        // date/time moves up onto the minimap
    }

    var lastSpeed = -1;
    function speed(sp) {
        sp = Math.min(999, sp);
        if (sp === lastSpeed) return;
        lastSpeed = sp;
        var s = String(sp);
        while (s.length < 3) s = '0' + s;
        var lead = true;
        for (var i = 0; i < 3; i++) {
            if (s.charAt(i) !== '0' || i === 2) lead = false;
            setText(digits[i], s.charAt(i));
            setCls(digits[i], 'z', lead);
        }
    }

    var gearCells = {}, gearMax = 0, gearOn = null, gearNext = null;
    function buildGears(max) {
        max = Math.max(1, Math.min(10, Math.round(Number(max) || 6)));
        if (max === gearMax) return;
        gearMax = max; gearOn = null; gearNext = null; gearCells = {};
        var labels = ['R', 'N'];
        for (var g = 1; g <= max; g++) labels.push(String(g));
        gearsEl.innerHTML = '';
        for (var i = 0; i < labels.length; i++) {
            var s = document.createElement('span');
            s.textContent = labels[i];
            gearsEl.appendChild(s);
            gearCells[labels[i]] = s;
        }
        if (max > 7) { gearsEl.style.gap = '2px'; for (var k in gearCells) gearCells[k].style.width = '17px'; }
        else gearsEl.style.gap = '';
    }
    function gear(g, sp) {
        var txt = sp <= 0 ? 'N' : (g === 'R' || Number(g) <= 0) ? 'R' : String(g);
        if (txt === gearOn) return;
        if (gearOn && gearCells[gearOn]) { gearCells[gearOn].className = ''; gearCells[gearOn]._c_next = false; }
        gearOn = txt;
        var cell = gearCells[txt];
        if (cell) { cell.className = 'on' + (txt === 'R' ? ' rev' : txt === 'N' ? ' neu' : ''); cell._c_next = false; }
        if (gearNext === txt) gearNext = null;
        shiftCue();
    }
    // when the needle is in the red zone, outline the next gear in amber
    function shiftCue() {
        var n = Number(gearOn);
        var next = (lastRpm > RPM_SEGS - RED_SEGS && n >= 1 && n < gearMax) ? String(n + 1) : null;
        if (next === gearNext) return;
        if (gearNext && gearCells[gearNext]) setCls(gearCells[gearNext], 'next', false);
        gearNext = next;
        if (next && gearCells[next]) setCls(gearCells[next], 'next', true);
    }

    // whole segments only: a line is redrawn only when a segment lights up or goes out
    var lastRpm = -1;
    function rpm(v) {
        var segs = Math.round(clamp(v, 0, 1) * RPM_SEGS);
        if (segs === lastRpm) return;
        lastRpm = segs;
        var normal = RPM_SEGS - RED_SEGS;
        var off = String(100 - Math.min(segs, normal) / normal * 100);
        setStyle(pRpm, 'strokeDashoffset', off);
        setStyle(pGlow, 'strokeDashoffset', off);
        setStyle(pRed, 'strokeDashoffset', String(100 - Math.max(0, segs - normal) / RED_SEGS * 100));
        shiftCue();
    }

    function miniBar(path, icon, label, v, warnAt, critAt) {
        v = clamp(v, 0, 100);
        var segs = Math.ceil(v / 100 * BAR_SEGS);               // a segment stays lit while any of it is left
        setStyle(path, 'strokeDashoffset', String(100 - segs / BAR_SEGS * 100));
        setText(label, Math.round(v));
        var crit = v <= critAt, warn = !crit && v <= warnAt;
        setCls(path, 'crit', crit); setCls(path, 'warn', warn);
        setCls(icon, 'crit', crit); setCls(icon, 'warn', warn);
        return crit ? 'crit' : warn ? 'warn' : '';
    }

    function updateVehHud(d) {
        if (!S.inVeh) setVehicleUi(true);

        if (d.maxGear !== undefined || !gearMax) buildGears(d.maxGear);
        var sp = Math.max(0, Math.floor(Number(d.speed) || 0));
        if (d.speed !== undefined) { speed(sp); gear(d.gear, sp); }

        if (d.isAircraft !== undefined) {
            if (d.isAircraft) {
                rpm(Math.min(sp, 300) / 300);
                setText(altV, fmt(d.altitude));
            } else if (d.rpm !== undefined) {
                rpm(Number(d.rpm) / 100);
            }
            setHidden(altEl, !d.isAircraft);
            setHidden(gearsEl, !!d.isAircraft);
        } else if (d.rpm !== undefined) {
            rpm(Number(d.rpm) / 100);
        }

        if (d.fuel !== undefined) miniBar(pFuel, fuelIc, fuelV, Number(d.fuel), 25, 10);
        var engState = '';
        if (d.engineHp !== undefined) engState = miniBar(pEng, engIc, engV, Number(d.engineHp) / 10, 60, 30);
        if (d.electric !== undefined) setHref(fuelUse, d.electric ? '#i-bolt' : '#i-fuel');
        if (d.engineOn !== undefined) setCls(carEl, 'off', !d.engineOn);

        // dashboard lights
        if (d.ind !== undefined) {
            setCls(ci.left, 'on', (d.ind & 1) === 1);
            setCls(ci.right, 'on', (d.ind & 2) === 2);
        }
        if (d.locked !== undefined) setCls(ci.lock, 'on', !!d.locked);
        if (d.lights !== undefined) {
            setHref(ci.lightsUse, d.lights === 2 ? '#i-highbeam' : '#i-lowbeam');
            setCls(ci.lights, 'on', d.lights === 1);
            setCls(ci.lights, 'hi', d.lights === 2);
        }
        if (d.seatbelt !== undefined || d.belted !== undefined) {
            setCls(ci.belt, 'crit', !!d.seatbelt);             // re-adding .crit replays the short blink
            setCls(ci.belt, 'on', !d.seatbelt && !!d.belted);
        }
        if (d.handbrake !== undefined) setCls(ci.brake, 'crit', !!d.handbrake);
        if (d.engineHp !== undefined || d.engineOn !== undefined) {
            if (d.engineHp === undefined) engState = engIc._c_crit ? 'crit' : engIc._c_warn ? 'warn' : '';
            setCls(ci.engine, 'crit', engState === 'crit');
            setCls(ci.engine, 'warn', engState === 'warn');
            setCls(ci.engine, 'on', !engState && d.engineOn !== false);
        }
        if (d.bodyHp !== undefined) {
            var body = clamp(Number(d.bodyHp) / 10, 0, 100);
            setCls(ci.body, 'crit', body <= 30);
            setCls(ci.body, 'warn', body > 30 && body <= 60);
            setCls(ci.body, 'on', body > 60);
        }
        if (d.cruise !== undefined) setCls(ci.cruise, 'on', !!d.cruise);
    }

    function hideVehHud() {
        setVehicleUi(false);
        lastSpeed = -1; lastRpm = -1;
    }

    // ══════════════════ AMMO ══════════════════
    var ammoEl = byId('ammo'), aClip = byId('a-clip'), aRes = byId('a-res');
    function updateAmmo(d) {
        if (d && d.show) {
            var clip = Math.max(0, Number(d.clip) || 0);
            setText(aClip, clip);
            setText(aRes, two(Math.max(0, Number(d.reserve) || 0)));
            setCls(aClip, 'empty', clip === 0);
            show(ammoEl, true);
        } else {
            show(ammoEl, false);
        }
    }

    // ══════════════════ MONEY ══════════════════
    var moneyEl = byId('money'), mIc = byId('m-ic'), mLbl = byId('m-lbl'), mVal = byId('m-val'), mDelta = byId('m-delta');
    var moneyTimer = null;
    function updateMoney(d) {
        var type = String(d.type || '').toLowerCase();
        setHref(mIc, type === 'bank' ? '#i-bank' : '#i-wallet');
        setText(mLbl, type ? type.toUpperCase() : 'BALANCE');
        setText(mVal, '$' + fmt(d.bank));
        if (d.money === true || d.money === false) {
            setText(mDelta, (d.money ? '-' : '+') + '$' + fmt(d.amount));
            setCls(mDelta, 'neg', d.money === true);
            setCls(mDelta, 'pos', d.money === false);
            setHidden(mDelta, false);
        } else {
            setHidden(mDelta, true);
        }
        show(moneyEl, true);
        clearTimeout(moneyTimer);
        moneyTimer = setTimeout(function () { show(moneyEl, false); }, 2800);
    }

    // ══════════════════ MINIMAP FRAME ══════════════════
    var root = document.documentElement;
    function setMapFrame(d) {
        if (!d.resX || !d.resY) return;
        root.style.setProperty('--map-w', (d.width * 1920 / d.resX).toFixed(1) + 'px');
        root.style.setProperty('--map-h', (d.height * 1080 / d.resY).toFixed(1) + 'px');
    }

    // ══════════════════ CONFIG (from config.lua) ══════════════════
    var wmEl = byId('wm'), wmTxt = byId('wm-txt');
    function applyConfig(c) {
        if (!c || typeof c !== 'object') return;
        if (c.bars) for (var k in c.bars) if (Object.prototype.hasOwnProperty.call(c.bars, k)) S.bars[k] = !!c.bars[k];
        if (c.kmH !== undefined) setText(unitEl, c.kmH ? 'KM/H' : 'MPH');
        if (c.smooth !== undefined) setCls(document.body, 'lite', !c.smooth);
        if (c.watermark !== undefined) setCls(wmEl, 'off', !c.watermark);
        if (c.watermarkText) setText(wmTxt, c.watermarkText);
        var engOn = S.bars.engineHealth !== false;
        if (c.clockSeconds !== undefined && clockSeconds !== !!c.clockSeconds) { clockSeconds = !!c.clockSeconds; tick(); }
        ['p-eng', 'p-eng-track', 'sh-eng', 'c-eng-ic', 'c-eng-v'].forEach(function (id) { byId(id).style.display = engOn ? '' : 'none'; });
        if (S.last) updateHud(S.last);
    }

    // ══════════════════ MESSAGES ══════════════════
    window.addEventListener('message', function (e) {
        var d = e.data;
        if (!d || typeof d !== 'object') return;
        switch (d.action) {
            case 'hud':
                setHudVisible(d.show !== false);
                // {action:'hud', show:true} alone only shows the HUD; stats follow from the main loop
                if (d.show !== false && d.health !== undefined) updateHud(d);
                break;
            case 'hideHud':
                setHudVisible(false);
                break;
            case 'vehHud':
                updateVehHud(d);
                break;
            case 'vehHideHud':
                hideVehHud();
                break;
            case 'compass':
                compassHeading(d.h);
                break;
            case 'compassShow':
                show(compassEl, !!d.show);
                break;
            case 'updateNav':
                updateNav(d);
                break;
            case 'setMapFrame':
                setMapFrame(d);
                break;
            case 'updateAmmo':
                updateAmmo(d.data);
                break;
            case 'money':
                updateMoney(d);
                break;
            case 'showAllStats':
                S.forceAll = !!d.show;
                if (S.last) updateHud(S.last);
                break;
            case 'config':
                applyConfig(d);
                break;
            case 'toggle':                       // F9 / togglewatermark
                setCls(wmEl, 'off', !wmEl._c_off);
                break;
            case 'setRouter':                    // no settings screen in this HUD: hand focus back
                post('OnHideSettingsMenu').catch(function () {});
                break;
            case 'SetClock':                     // clock uses the device time
            default:
                break;
        }
    });

    // first paint + ask Lua for config.lua values (retries until the client script is ready)
    buildGears(6);
    updateHud({
        voice: { talking: false, range: 3, radio: false },
        health: 100, armor: 0, playerDead: false,
        hunger: 100, thirst: 100, stress: 0,
        oxygen: { range: 100, inwater: false }
    });
    (function askConfig(tries) {
        post('hudReady').then(function (r) { return r.json(); }).then(applyConfig).catch(function () {
            if (tries > 0) setTimeout(function () { askConfig(tries - 1); }, 2000);
        });
    })(10);
})();
