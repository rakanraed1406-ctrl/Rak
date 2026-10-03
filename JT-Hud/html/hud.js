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

    // ══════════════════ COMPASS (top centre, no panel) ══════════════════
    // The ribbon is drawn once (-180°..540°) and only slides with a transform.
    var CW = 600, PPD = 3.0, C0 = -180, C1 = 540, CH = 40;
    var CARD = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    var compassEl = byId('compass'), strip = byId('cmp-strip');
    var cmpCard = byId('cmp-card'), cmpDeg = byId('cmp-deg'), cmpStreet = byId('cmp-street'), cmpCross = byId('cmp-cross');
    var cmpZone = byId('cmp-zone');
    var edgeL = byId('cmp-edge-l'), edgeR = byId('cmp-edge-r');
    var edgeLT = edgeL.querySelector('span'), edgeRT = edgeR.querySelector('span');
    var wpMarks = [], wpText = [];

    (function buildStrip() {
        var w = (C1 - C0) * PPD, o = [];
        var halo = ' paint-order="stroke" stroke="rgba(0,3,14,0.75)" stroke-width="2.6" stroke-linejoin="round"';
        o.push('<svg width="' + w + '" height="' + CH + '" viewBox="0 0 ' + w + ' ' + CH + '">');
        for (var d = C0; d <= C1; d += 5) {
            var x = ((d - C0) * PPD).toFixed(1), n = ((d % 360) + 360) % 360, y1, sw, col;
            if (n % 45 === 0) { y1 = 28; sw = 2; col = n === 0 ? '#ff6b80' : '#ffffff'; }
            else if (n % 15 === 0) { y1 = 31; sw = 1.4; col = 'rgba(225,235,255,0.82)'; }
            else { y1 = 34; sw = 1; col = 'rgba(200,215,255,0.5)'; }
            o.push('<line x1="' + x + '" x2="' + x + '" y1="' + (y1 - 0.5) + '" y2="' + CH + '" stroke="rgba(0,3,14,0.55)" stroke-width="' + (sw + 2) + '"/>');
            o.push('<line x1="' + x + '" x2="' + x + '" y1="' + y1 + '" y2="' + CH + '" stroke="' + col + '" stroke-width="' + sw + '"/>');
            if (n % 45 === 0) {
                o.push('<text x="' + x + '" y="25" text-anchor="middle" font-size="' + (n % 90 === 0 ? 14 : 12) +
                       '" font-weight="800" fill="' + col + '"' + halo + '>' + CARD[n / 45] + '</text>');
            } else if (n % 15 === 0) {
                o.push('<text x="' + x + '" y="25" text-anchor="middle" font-size="9.5" font-weight="600" fill="rgba(225,235,255,0.8)"' + halo + '>' + n + '</text>');
            }
        }
        o.push('</svg>');
        strip.innerHTML = o.join('');
        strip.style.width = w + 'px';
        for (var i = 0; i < 3; i++) {
            var m = document.createElement('div');
            m.className = 'cmp-wp';
            m.innerHTML = '<i></i><span></span>';
            m.hidden = true;
            strip.appendChild(m);
            wpMarks.push(m);
            wpText.push(m.querySelector('span'));
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
        setText(cmpDeg, Math.round(h) % 360);
        setText(cmpCard, CARD[Math.round(h / 45) % 8]);
        wpEdges();
    }

    function wpEdges() {
        var rel = S.wp === null ? 0 : wrap180(S.wp - S.heading);
        setCls(edgeL, 'on', S.wp !== null && rel < -55);
        setCls(edgeR, 'on', S.wp !== null && rel > 55);
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
        var i;
        if (has) {
            var label = fmtDist(dist);
            if (S.wp !== d.wpBearing) {
                S.wp = d.wpBearing;
                for (i = 0; i < 3; i++) wpMarks[i].style.left = ((S.wp + (i - 1) * 360 - C0) * PPD).toFixed(1) + 'px';
            }
            for (i = 0; i < 3; i++) { setText(wpText[i], label); wpMarks[i].hidden = false; }
            setText(edgeLT, label); setText(edgeRT, label);
        } else if (S.wp !== null) {
            S.wp = null;
            for (i = 0; i < 3; i++) wpMarks[i].hidden = true;
        }
        wpEdges();
    }

    // ══════════════════ STATUS (bottom right, leans in) ══════════════════
    var statusEl = byId('status'), emblem = byId('emblem');
    var hpFill = byId('hp-fill'), hpGhost = byId('hp-ghost'), hpHead = byId('hp-head'), hpNum = byId('hp-num');
    var arRow = byId('st-ar'), arFill = byId('ar-fill'), arNum = byId('ar-num');
    var stamRow = byId('st-stam-row'), stamIc = byId('st-stam-ic'), chev = byId('st-stam').children, CHEV = chev.length;
    var voiceEl = byId('voice'), vIc = byId('v-ic'), wave = byId('wave').children, WAVE = wave.length;

    function scaleX(el, v) { setStyle(el, 'transform', 'scaleX(' + (v / 100).toFixed(3) + ')'); }
    function headAt(el, v) {
        setStyle(el, 'transform', 'translateX(' + (v - 100).toFixed(1) + '%)');
        setStyle(el, 'opacity', v > 0.5 ? '1' : '0');
    }

    function chip(key) {
        var el = byId('c-' + key);
        return { el: el, ring: el.querySelector('.r-fill'), num: el.querySelector('b'), v: -1 };
    }
    var CHIPS = { stress: chip('stress'), hunger: chip('hunger'), thirst: chip('thirst') };
    var CHIP_KEYS = ['stress', 'hunger', 'thirst'];
    var CHIP_CRIT = {
        stress: function (v) { return v >= 80; },
        hunger: function (v) { return v <= 20; },
        thirst: function (v) { return v <= 20; }
    };

    var lastHp = -1, lastAr = -1, lastStam = -1;
    function vitals(d) {
        var hp = Math.round(clamp(num(d.health), 0, 100));
        if (hp !== lastHp) {
            lastHp = hp;
            scaleX(hpFill, hp); scaleX(hpGhost, hp); headAt(hpHead, hp);   // ghost trails behind on damage
            setText(hpNum, hp);
        }
        var crit = hp <= 25 || !!d.playerDead;
        setCls(statusEl, 'crit', crit);
        setCls(emblem, 'crit', crit);                       // re-adding .crit replays the three beats

        var ar = Math.round(clamp(num(d.armor), 0, 100));
        if (ar !== lastAr) { lastAr = ar; scaleX(arFill, ar); setText(arNum, ar); }
        setHidden(arRow, !S.bars.armor);

        var o = d.oxygen, water = !!(o && typeof o === 'object' && o.inwater);
        setCls(statusEl, 'water', water);
        setHref(stamIc, water ? '#i-lungs' : '#i-run');
        var lit = Math.ceil(clamp(num(o), 0, 100) / 100 * CHEV);
        if (lit !== lastStam) {
            lastStam = lit;
            for (var i = 0; i < CHEV; i++) setCls(chev[i], 'on', i < lit);
        }
        setStyle(stamRow, 'visibility', (water ? (S.bars.oxygen || S.bars.stamina) : S.bars.stamina) ? 'visible' : 'hidden');
    }

    function chipLevel(t, key, v) {
        v = Math.round(clamp(v, 0, 100));
        if (t.v !== v) {
            t.v = v;
            t.ring.style.strokeDashoffset = String(100 - v);
            t.ring.style.opacity = v > 0 ? '1' : '0';
            setText(t.num, v);
        }
        setCls(t.el, 'crit', CHIP_CRIT[key](v));
        setHidden(t.el, !S.bars[key]);
    }

    // voice: lit bars = range, from the centre out; the waveform only moves while you talk
    var voiceState = { mode: null, lvl: -1 };
    function voice(d) {
        if (!d || typeof d !== 'object') return;
        var mode = d.radio ? 'radio' : (d.talking ? 'talk' : 'idle');
        if (mode !== voiceState.mode) {
            voiceState.mode = mode;
            setCls(voiceEl, 'talk', mode === 'talk');
            setCls(voiceEl, 'radio', mode === 'radio');
            setHref(vIc, mode === 'radio' ? '#i-radio' : '#i-mic');
        }
        var r = Number(d.range) || 3;
        var half = r <= 1.5 ? 1 : r <= 3 ? 2 : 4;              // 3, 5 or 9 bars
        if (half !== voiceState.lvl) {
            voiceState.lvl = half;
            var mid = (WAVE - 1) / 2;
            for (var i = 0; i < WAVE; i++) setCls(wave[i], 'on', Math.abs(i - mid) <= half);
        }
        setHidden(voiceEl, !S.bars.voice);
    }

    function updateHud(d) {
        S.last = d;
        vitals(d);
        voice(d.voice);
        for (var i = 0; i < CHIP_KEYS.length; i++) {
            var k = CHIP_KEYS[i], v = clamp(num(d[k]), 0, 100);
            chipLevel(CHIPS[k], k, v < 1 ? 0 : v);
        }
    }

    // ══════════════════ VEHICLE CLUSTER (bottom left, leans in) ══════════════════
    var carEl = byId('car'), mapEl = byId('mapframe');
    var digits = byId('cr-speed').children, unitEl = byId('cr-unit');
    var gearbox = byId('gearbox'), gearEl = byId('gear');
    var rpmWin = byId('rpm-win'), rpmGrad = byId('rpm-grad'), rpmHead = byId('rpm-head');
    var rpmScale = byId('rpm-scale'), altEl = byId('cr-alt'), altNum = byId('alt-num');
    var miniFuel = byId('mini-fuel'), fuelFill = byId('fuel-fill'), fuelNum = byId('fuel-num'), fuelUse = byId('fuel-use');
    var miniEng = byId('mini-eng'), engFill = byId('eng-fill'), engNum = byId('eng-num');
    var li = {
        left: byId('li-left'), right: byId('li-right'), lock: byId('li-lock'), beam: byId('li-beam'),
        beamUse: byId('li-beam-use'), belt: byId('li-belt'), brake: byId('li-brake'),
        engine: byId('li-engine'), body: byId('li-body'), cruise: byId('li-cruise')
    };
    var RED_AT = 86;      // % of the RPM bar where the redline starts (matches the CSS gradient)

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

    var gearTxt = null, gearMax = 6, rpmPct = 0;
    function gear(g, sp) {
        var txt = sp <= 0 ? 'N' : (g === 'R' || Number(g) <= 0) ? 'R' : String(g);
        if (txt !== gearTxt) {
            gearTxt = txt;
            setText(gearEl, txt);
            setCls(gearbox, 'rev', txt === 'R');
            setCls(gearbox, 'neu', txt === 'N');
        }
        shiftCue();
    }
    // in the red zone and not in top gear: the gear box turns amber with a small ▲
    function shiftCue() {
        var n = Number(gearTxt);
        setCls(gearbox, 'shift', rpmPct >= RED_AT && n >= 1 && n < gearMax);
    }

    // the gradient stays put and a window slides over it: smooth on the GPU, no repaint
    function rpm(v) {
        var p = Math.round(clamp(v, 0, 1) * 200) / 2;          // 0.5 % steps
        if (p === rpmPct) return;
        rpmPct = p;
        setStyle(rpmWin, 'transform', 'translateX(' + (p - 100) + '%)');
        setStyle(rpmGrad, 'transform', 'translateX(' + (100 - p) + '%)');
        setStyle(rpmHead, 'transform', 'translateX(' + (p - 100) + '%)');
        setStyle(rpmHead, 'opacity', p > 0.5 ? '1' : '0');
        shiftCue();
    }

    function mini(row, fill, label, v, warnAt, critAt) {
        v = clamp(v, 0, 100);
        scaleX(fill, v);
        setText(label, Math.round(v));
        var crit = v <= critAt, warn = !crit && v <= warnAt;
        setCls(row, 'crit', crit); setCls(row, 'warn', warn);
        return crit ? 'crit' : warn ? 'warn' : '';
    }

    function updateVehHud(d) {
        if (S_FLY) setFlying(false);
        if (!S.inVeh) setVehicleUi(true);

        if (d.maxGear !== undefined) gearMax = Math.max(1, Number(d.maxGear) || 6);
        var sp = Math.max(0, Math.floor(Number(d.speed) || 0));
        if (d.speed !== undefined) speed(sp);

        if (d.isAircraft !== undefined) {
            if (d.isAircraft) {
                rpm(Math.min(sp, 300) / 300);
                setText(altNum, fmt(d.altitude));
            } else if (d.rpm !== undefined) {
                rpm(Number(d.rpm) / 100);
            }
            setHidden(altEl, !d.isAircraft);
            setHidden(rpmScale, !!d.isAircraft);
        } else if (d.rpm !== undefined) {
            rpm(Number(d.rpm) / 100);
        }
        if (d.speed !== undefined) gear(d.gear, sp);

        if (d.fuel !== undefined) mini(miniFuel, fuelFill, fuelNum, Number(d.fuel), 25, 10);
        var engState = '';
        if (d.engineHp !== undefined) engState = mini(miniEng, engFill, engNum, Number(d.engineHp) / 10, 60, 30);
        if (d.electric !== undefined) setHref(fuelUse, d.electric ? '#i-bolt' : '#i-fuel');
        if (d.engineOn !== undefined) setCls(carEl, 'off', !d.engineOn);

        // dashboard lights
        if (d.ind !== undefined) {
            setCls(li.left, 'on', (d.ind & 1) === 1);
            setCls(li.right, 'on', (d.ind & 2) === 2);
        }
        if (d.locked !== undefined) setCls(li.lock, 'on', !!d.locked);
        if (d.lights !== undefined) {
            setHref(li.beamUse, d.lights === 2 ? '#i-highbeam' : '#i-lowbeam');
            setCls(li.beam, 'on', d.lights === 1);
            setCls(li.beam, 'hi', d.lights === 2);
        }
        if (d.seatbelt !== undefined || d.belted !== undefined) {
            setCls(li.belt, 'crit', !!d.seatbelt);              // re-adding .crit replays the short blink
            setCls(li.belt, 'on', !d.seatbelt && !!d.belted);
        }
        if (d.handbrake !== undefined) setCls(li.brake, 'crit', !!d.handbrake);
        if (d.engineHp !== undefined || d.engineOn !== undefined) {
            if (d.engineHp === undefined) engState = miniEng._c_crit ? 'crit' : miniEng._c_warn ? 'warn' : '';
            setCls(li.engine, 'crit', engState === 'crit');
            setCls(li.engine, 'warn', engState === 'warn');
            setCls(li.engine, 'on', !engState && d.engineOn !== false);
        }
        if (d.bodyHp !== undefined) {
            var body = clamp(Number(d.bodyHp) / 10, 0, 100);
            setCls(li.body, 'crit', body <= 30);
            setCls(li.body, 'warn', body > 30 && body <= 60);
            setCls(li.body, 'on', body > 60);
        }
        if (d.cruise !== undefined) setCls(li.cruise, 'on', !!d.cruise);
    }

    function hideVehHud() {
        setFlying(false);
        setVehicleUi(false);
        lastSpeed = -1;
    }

    // ══════════════════ FLIGHT HUD (bottom centre; replaces the car cluster) ══════════════════
    var flightEl = byId('flight'), S_FLY = false;
    // a tape is 9 rows that slide; labels are rewritten only when a row boundary is crossed
    function Tape(id, step, minVal) {
        var el = byId(id), rows = [], i;
        for (i = 0; i < 9; i++) {
            var r = document.createElement('div');
            r.className = 'trow';
            r.innerHTML = '<span></span>';
            el.appendChild(r);
            rows.push(r.firstChild);
        }
        return { el: el, rows: rows, step: step, min: minVal, base: null, ROW: 36, WIN: 162 };
    }
    function tapeSet(t, v) {
        var b = Math.floor(v / t.step), snap = false;
        if (b !== t.base) {
            snap = t.base !== null;
            t.base = b;
            for (var i = 0; i < 9; i++) {
                var val = (b + 4 - i) * t.step;
                setText(t.rows[i], val < t.min ? '' : val);
            }
        }
        var y = t.WIN / 2 - (4 * t.ROW + t.ROW / 2) + (v / t.step - b) * t.ROW;
        setCls(t.el, 'snap', snap);
        t.el.style.transform = 'translateY(' + y.toFixed(1) + 'px)';
    }
    var tpSpd = Tape('tp-spd', 20, 0), tpAlt = Tape('tp-alt', 100, -1000);
    var fl = {
        hdg: byId('fl-hdg'), spd: byId('fl-spd'), alt: byId('fl-alt'), hor: byId('fl-hor'), rollp: byId('fl-rollp'),
        eng: byId('fl-eng'), engN: byId('fl-eng-n'), dot: byId('fl-dot'), fuel: byId('fl-fuel'), fuelN: byId('fl-fuel-n'),
        vsu: byId('fl-vsu'), vsd: byId('fl-vsd'), vs: byId('fl-vs'), thr: byId('fl-thr'), thrN: byId('fl-thr-n'),
        agl: byId('fl-agl'), gear: byId('fl-gear'), gearT: byId('fl-gear-t'), warn: byId('fl-warn')
    };
    function three(n) { n = Math.round(n) % 360; return (n < 10 ? '00' : n < 100 ? '0' : '') + n; }
    function vfill(el, label, v, warnAt, critAt) {
        v = clamp(v, 0, 100);
        setStyle(el, 'transform', 'scaleY(' + (v / 100).toFixed(3) + ')');
        setText(label, Math.round(v));
        setCls(el, 'crit', v <= critAt);
        setCls(el, 'warn', v > critAt && v <= warnAt);
    }

    function setFlying(on) {
        on = !!on;
        if (on === S_FLY) return;
        S_FLY = on;
        show(flightEl, on);
        if (on) show(carEl, false);                       // the car cluster steps aside in the air
        else if (S.inVeh) show(carEl, true);
    }

    function updateFlight(d) {
        if (d.show === false) { setFlying(false); return; }
        if (!S.inVeh) { S.inVeh = true; show(mapEl, true); setCls(dtEl, 'veh', true); }
        setFlying(true);

        setText(fl.hdg, three(Number(d.hdg) || 0));
        var spd = Math.max(0, Number(d.spd) || 0), alt = Number(d.alt) || 0;
        setText(fl.spd, spd); tapeSet(tpSpd, spd);
        setText(fl.alt, fmt(alt)); tapeSet(tpAlt, alt);

        // attitude: rotate by roll, then slide by pitch along the rotated vertical
        var pitch = clamp(d.pitch, -90, 90), roll = clamp(d.roll, -180, 180);
        fl.hor.style.transform = 'rotate(' + (-roll) + 'deg) translateY(' + (pitch * 2.6).toFixed(1) + 'px)';
        fl.rollp.style.transform = 'rotate(' + (-roll) + 'deg)';

        vfill(fl.eng, fl.engN, Number(d.eng), 60, 30);
        vfill(fl.fuel, fl.fuelN, Number(d.fuel), 25, 10);
        setCls(fl.dot, 'on', !!d.engineOn);

        var vs = clamp(d.vs, -30, 30);
        setStyle(fl.vsu, 'transform', 'scaleY(' + Math.max(0, vs / 20).toFixed(3) + ')');
        setStyle(fl.vsd, 'transform', 'scaleY(' + Math.max(0, -vs / 20).toFixed(3) + ')');
        setText(fl.vs, (vs > 0 ? '+' : '') + vs.toFixed(1));

        var thr = clamp(d.thr, 0, 100);
        setStyle(fl.thr, 'transform', 'scaleX(' + (thr / 100).toFixed(3) + ')');
        setText(fl.thrN, Math.round(thr) + '%');
        setText(fl.agl, fmt(d.agl));

        var g = Number(d.gear);
        setHidden(fl.gear, d.heli || g < 0);
        setText(fl.gearT, g === 0 ? 'DOWN' : (g === 1 || g === 2) ? 'MOVING' : 'UP');
        setCls(fl.gear, 'up', g >= 3);
        setCls(fl.gear, 'moving', g === 1 || g === 2);

        // warnings: low and sinking fast, or almost out of fuel
        var pull = d.agl < 400 && d.vs < -12, lowFuel = Number(d.fuel) <= 10;
        setText(fl.warn, pull ? 'PULL UP' : 'LOW FUEL');
        setHidden(fl.warn, !(pull || lowFuel));
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
        miniEng.style.display = engOn ? '' : 'none';
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
            case 'flightHud':
                updateFlight(d);
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
