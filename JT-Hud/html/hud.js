/* ============================================================================
   JT-Hud — NUI logic (no jQuery, no icon fonts)
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
    // fade/slide in or out; [hidden] removes it from layout once faded
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
    function fmt(n) { return Math.floor(Math.abs(Number(n) || 0)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
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

    // ══════════════════ CLOCK (device time, redrawn once a minute) ══════════
    var MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    var DAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    var cTime = byId('c-time'), cAmpm = byId('c-ampm'), cDow = byId('c-dow'), cDate = byId('c-date');
    function two(n) { return (n < 10 ? '0' : '') + n; }
    function tick() {
        var d = new Date();
        var h = d.getHours();
        setText(cTime, two(h % 12 || 12) + ':' + two(d.getMinutes()));
        setText(cAmpm, h >= 12 ? 'PM' : 'AM');
        setText(cDow, DAYS[d.getDay()]);
        setText(cDate, two(d.getDate()) + ' ' + MONTHS[d.getMonth()] + ' ' + d.getFullYear());
        setTimeout(tick, 60050 - d.getSeconds() * 1000 - d.getMilliseconds());
    }
    tick();

    // ══════════════════ STATUS TILES ══════════════════
    var TRAVEL = 44; // px the level line travels (tile inner height - line height)
    function tile(key) {
        var el = byId('st-' + key);
        return { el: el, fill: el.querySelector('.stat-fill'), lvl: el.querySelector('.stat-lvl'), v: -1 };
    }
    var T = {
        voice: tile('voice'), health: tile('health'), armor: tile('armor'), hunger: tile('hunger'),
        thirst: tile('thirst'), stress: tile('stress'), stamina: tile('stamina')
    };
    var vUse = byId('v-use'), staUse = byId('sta-use');
    var vBars = T.voice.el.querySelectorAll('.vbars i');

    function level(t, v) {
        v = Math.round(clamp(v, 0, 100));
        if (t.v === v) return;
        t.v = v;
        t.fill.style.transform = 'scaleY(' + (v / 100) + ')';
        t.lvl.style.transform = 'translateY(' + ((1 - v / 100) * TRAVEL).toFixed(1) + 'px)';
    }
    function num(x) { return (x && typeof x === 'object') ? Number(x.range) : Number(x); }

    // when each tile is worth showing, and when it turns critical (d = whole hud payload)
    var RULES = {
        health: { show: function (v, d) { return v < 97 || d.playerDead; }, crit: function (v, d) { return v <= 25 || d.playerDead; } },
        armor:  { show: function (v) { return v > 0; },  crit: function () { return false; } },
        hunger: { show: function (v) { return v < 80; }, crit: function (v) { return v <= 20; } },
        thirst: { show: function (v) { return v < 80; }, crit: function (v) { return v <= 20; } },
        stress: { show: function (v) { return v > 0; },  crit: function (v) { return v >= 80; } }
    };
    var RULE_KEYS = ['health', 'armor', 'hunger', 'thirst', 'stress'];

    function bar(key, d) {
        var t = T[key], rule = RULES[key];
        var v = clamp(num(d[key]), 0, 100);
        if (v < 1) v = 0;
        level(t, v);
        setCls(t.el, 'crit', rule.crit(v, d));
        show(t.el, S.bars[key] && (S.forceAll || rule.show(v, d)));
    }

    var voiceState = { mode: null, lvl: 0 };
    function voice(d) {
        if (!d || typeof d !== 'object') return;
        var mode = d.radio ? 'radio' : (d.talking ? 'talk' : 'idle');
        if (mode !== voiceState.mode) {
            voiceState.mode = mode;
            setCls(T.voice.el, 'talk', mode === 'talk');
            setCls(T.voice.el, 'radio', mode === 'radio');
            setHref(vUse, mode === 'radio' ? '#i-radio' : mode === 'talk' ? '#i-mic' : '#i-mic-off');
        }
        var r = Number(d.range) || 3;
        var lvl = r <= 1.5 ? 1 : r <= 3 ? 2 : 3;
        if (lvl !== voiceState.lvl) {
            voiceState.lvl = lvl;
            for (var i = 0; i < 3; i++) setCls(vBars[i], 'on', i < lvl);
        }
        show(T.voice.el, S.bars.voice);
    }

    function stamina(d) {
        var t = T.stamina;
        var water = !!(d && typeof d === 'object' && d.inwater);
        var v = clamp(num(d), 0, 100);
        setCls(t.el, 'water', water);
        setHref(staUse, water ? '#i-lungs' : '#i-run');
        level(t, v);
        setCls(t.el, 'crit', water ? v <= 25 : v <= 15);
        var enabled = water ? (S.bars.oxygen || S.bars.stamina) : S.bars.stamina;
        show(t.el, enabled && (S.forceAll || water || v < 99));
    }

    function updateHud(d) {
        S.last = d;
        voice(d.voice);
        for (var i = 0; i < RULE_KEYS.length; i++) bar(RULE_KEYS[i], d);
        stamina(d.oxygen);
    }

    // ══════════════════ VEHICLE DIAL ══════════════════
    // Angles in degrees, SVG space: 0 = right, 90 = down (clockwise).
    var CX = 100, CY = 100, R = 84;
    var RPM_A0 = 150, RPM_A1 = 390, RED_T = 0.8;           // 240° sweep over the top, redline last 20%
    var RPM_SEGS = 30, RED_SEGS = 6, SIDE_SEGS = 8;          // must match the mask dash patterns in index.html
    var RED_A = RPM_A0 + (RPM_A1 - RPM_A0) * RED_T;
    var FUEL_A0 = 106, FUEL_A1 = 144;                        // lower left, fills upward
    var ENG_A0 = 74, ENG_A1 = 36;                            // lower right, fills upward

    function pt(a, r) {
        var rad = a * Math.PI / 180;
        return (CX + r * Math.cos(rad)).toFixed(2) + ' ' + (CY + r * Math.sin(rad)).toFixed(2);
    }
    function arc(a0, a1, r) {
        var sweep = a1 > a0 ? 1 : 0;
        var large = Math.abs(a1 - a0) > 180 ? 1 : 0;
        return 'M ' + pt(a0, r) + ' A ' + r + ' ' + r + ' 0 ' + large + ' ' + sweep + ' ' + pt(a1, r);
    }
    (function buildDial() {
        var rpm = arc(RPM_A0, RPM_A1, R), fuel = arc(FUEL_A0, FUEL_A1, R), eng = arc(ENG_A0, ENG_A1, R);
        var set = function (id, d) { byId(id).setAttribute('d', d); };
        set('m-rpm', rpm); set('m-fuel', fuel); set('m-eng', eng);
        set('p-track', arc(RPM_A0, RED_A, R)); set('p-track-red', arc(RED_A, RPM_A1, R));
        set('p-rpm', arc(RPM_A0, RED_A, R)); set('p-rpm-red', arc(RED_A, RPM_A1, R));
        set('p-glow', arc(RPM_A0, RED_A, R));
        set('p-fuel-track', fuel); set('p-fuel', fuel);
        set('p-eng-track', eng); set('p-eng', eng);
        set('p-ticks', arc(RPM_A0, RPM_A1 + 1, 72));
    })();

    var vehEl = byId('veh'), mapEl = byId('mapframe'), streetEl = byId('street');
    var pRpm = byId('p-rpm'), pRed = byId('p-rpm-red'), pGlow = byId('p-glow');
    var pFuel = byId('p-fuel'), pEng = byId('p-eng');
    var fuelIc = byId('i-fuel-ic'), engIc = byId('i-eng-ic'), fuelUse = byId('fuel-use');
    var digits = byId('d-speed').children, unitEl = byId('d-unit'), gearEl = byId('d-gear');
    var beltEl = byId('f-belt'), cruiseEl = byId('f-cruise');
    var altEl = byId('alt'), altVal = byId('alt-val');

    function setVehicleUi(on) {
        S.inVeh = !!on;
        show(vehEl, on);
        show(mapEl, on);
        if (!on) show(streetEl, false);
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

    function gear(g, sp) {
        var txt = sp <= 0 ? 'N' : (g === 'R' || Number(g) <= 0) ? 'R' : String(g);
        setText(gearEl, txt);
        setCls(gearEl, 'neutral', txt === 'N');
        setCls(gearEl, 'rev', txt === 'R');
    }

    // whole segments only: the arc is redrawn only when a segment lights up or goes out
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
    }

    function sideBar(path, icon, v, warnAt, critAt) {
        v = clamp(v, 0, 100);
        var segs = Math.ceil(v / 100 * SIDE_SEGS);               // a segment stays lit while any of it is left
        setStyle(path, 'strokeDashoffset', String(100 - segs / SIDE_SEGS * 100));
        var crit = v <= critAt, warn = !crit && v <= warnAt;
        setCls(path, 'crit', crit); setCls(path, 'warn', warn);
        setCls(icon, 'crit', crit); setCls(icon, 'warn', warn);
    }

    function updateVehHud(d) {
        if (!S.inVeh) setVehicleUi(true);   // the street bar follows with the next updateNav

        var sp = Math.max(0, Math.floor(Number(d.speed) || 0));
        if (d.speed !== undefined) { speed(sp); gear(d.gear, sp); }

        if (d.isAircraft !== undefined) {
            if (d.isAircraft) {
                rpm(Math.min(sp, 300) / 300);
                setText(altVal, fmt(d.altitude));
            } else if (d.rpm !== undefined) {
                rpm(Number(d.rpm) / 100);
            }
            show(altEl, !!d.isAircraft);
        } else if (d.rpm !== undefined) {
            rpm(Number(d.rpm) / 100);
        }

        if (d.fuel !== undefined) sideBar(pFuel, fuelIc, Number(d.fuel), 25, 10);
        if (d.engineHp !== undefined) sideBar(pEng, engIc, Number(d.engineHp) / 10, 60, 30);
        if (d.electric !== undefined) setHref(fuelUse, d.electric ? '#i-bolt' : '#i-fuel');

        if (d.seatbelt !== undefined) {
            setHidden(beltEl, !d.seatbelt);
            setCls(beltEl, 'on', !!d.seatbelt);  // re-adding .on replays the short blink
        }
        if (d.cruise !== undefined) setHidden(cruiseEl, !d.cruise);
    }

    function hideVehHud() {
        setVehicleUi(false);
        show(altEl, false);
        lastSpeed = -1; lastRpm = -1;
    }

    // ══════════════════ STREET / NAVIGATION ══════════════════
    var sArea = byId('s-area'), sName = byId('s-name'), sHead = byId('s-head'), sDist = byId('s-dist');
    var navEl = byId('nav'), navIc = byId('nav-ic'), navUse = byId('nav-use');
    var DIR_ANGLE = { Front: 0, Halfright: 45, Right: 90, Back: 180, Left: -90, Halfleft: -45 };
    var navAngle = null;

    function setBearing(b) {
        if (navAngle === null) navAngle = b;
        else navAngle += ((b - navAngle) % 360 + 540) % 360 - 180;   // shortest way round
        // the arrow glyph points north-east, so turn it back 45°
        setStyle(navIc, 'transform', 'rotate(' + (navAngle - 45) + 'deg)');
    }

    function updateNavigation(d) {
        if (!S.inVeh) { show(streetEl, false); return; }
        show(streetEl, true);

        var area = String(d.area || d.zone || '');
        setText(sArea, area.toUpperCase());
        setText(sName, d.street || d.streetName || area || 'Unknown');
        if (d.heading) setText(sHead, d.heading);

        var dist = Number(d.waydist !== undefined ? d.waydist : d.distance);
        var wp = isFinite(dist) && dist >= 0;
        setCls(navEl, 'wp', wp);
        setCls(navIc, 'arrow', wp);
        if (wp) {
            setHref(navUse, '#i-arrow');
            var b = (typeof d.bearing === 'number') ? d.bearing : DIR_ANGLE[d.directions || d.direction];
            setBearing(typeof b === 'number' ? b : 0);
            setText(sDist, dist < 1 ? (Math.round(dist * 100) * 10) + ' M' : dist.toFixed(1) + ' KM');
            setHidden(sDist, false);
        } else {
            setHref(navUse, '#i-pin');
            setStyle(navIc, 'transform', 'none');
            navAngle = null;
            setHidden(sDist, true);
        }
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
        byId('p-eng').style.display = engOn ? '' : 'none';
        byId('p-eng-track').style.display = engOn ? '' : 'none';
        engIc.style.display = engOn ? '' : 'none';
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
            case 'updateNav':
                updateNavigation(d);
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
