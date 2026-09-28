/* JT HUD — vanilla JS, no external libraries */

var $ = function (id) { return document.getElementById(id); };
var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'JT-Hud';

function post(name, data) {
    if (typeof GetParentResourceName !== 'function') return;
    fetch('https://' + RES + '/' + name, { method: 'POST', body: JSON.stringify(data || {}) }).catch(function () {});
}

function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

// ════════════════════════════════════════════
//  Config (overwritten by the client script)
// ════════════════════════════════════════════

var cfg = {
    bars: {},
    compass: true,
    volume: 0.35,
    hunger: { enabled: true, warn: 25, critical: 10, repeatEvery: 60 },
    thirst: { enabled: true, warn: 25, critical: 10, repeatEvery: 60 },
    lowHealth: { enabled: true, below: 25 },
    seatbeltChime: { enabled: true, minSpeed: 30, times: 6 },
    moneySound: true,
    texts: {
        hungerWarn: ['HUNGRY', 'You should eat something soon.'],
        hungerCrit: ['STARVING', 'Eat now or you will start losing health.'],
        thirstWarn: ['THIRSTY', 'You should drink something soon.'],
        thirstCrit: ['DEHYDRATED', 'Drink now or you will start losing health.'],
        lowHealth: ['CRITICAL CONDITION', 'Find a medic.'],
    },
};

function barActive(name) {
    var b = cfg.bars[name];
    return !b || b.active !== false;
}

// ════════════════════════════════════════════
//  Scale (design space is 1920x1080)
// ════════════════════════════════════════════

function updateScale() {
    var s = window.innerHeight / 1080;
    var el = $('ui-scale');
    el.style.transform = 'scale(' + s + ')';
    el.style.width = (window.innerWidth / s) + 'px';
}
window.addEventListener('resize', updateScale);
updateScale();

// ════════════════════════════════════════════
//  Sound (generated, no audio files)
// ════════════════════════════════════════════

var Sound = (function () {
    var ctx = null, master = null, noiseBuf = null;

    function init() {
        if (ctx) return ctx;
        try {
            ctx = new (window.AudioContext || window.webkitAudioContext)();
            master = ctx.createGain();
            master.gain.value = cfg.volume;
            master.connect(ctx.destination);
            noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 0.25, ctx.sampleRate);
            var d = noiseBuf.getChannelData(0);
            for (var i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
        } catch (e) { ctx = null; }
        return ctx;
    }

    function tone(o) {
        var c = init(); if (!c) return;
        var t = c.currentTime + (o.at || 0);
        var osc = c.createOscillator();
        var g = c.createGain();
        osc.type = o.type || 'sine';
        osc.frequency.setValueAtTime(o.f, t);
        if (o.f2) osc.frequency.exponentialRampToValueAtTime(o.f2, t + (o.slide || o.d));
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(o.g || 0.5, t + (o.a || 0.008));
        g.gain.exponentialRampToValueAtTime(0.0001, t + o.d);
        osc.connect(g); g.connect(master);
        osc.start(t); osc.stop(t + o.d + 0.05);
    }

    function noise(o) {
        var c = init(); if (!c || !noiseBuf) return;
        var t = c.currentTime + (o.at || 0);
        var src = c.createBufferSource();
        src.buffer = noiseBuf;
        var f = c.createBiquadFilter();
        f.type = o.filter || 'highpass';
        f.frequency.value = o.freq || 2000;
        var g = c.createGain();
        g.gain.setValueAtTime(o.g || 0.4, t);
        g.gain.exponentialRampToValueAtTime(0.0001, t + o.d);
        src.connect(f); f.connect(g); g.connect(master);
        src.start(t); src.stop(t + o.d + 0.02);
    }

    var lib = {
        hunger: function (crit) {
            // warm two-note chime + low rumble
            tone({ f: 587, d: 0.35, type: 'triangle', g: 0.45 });
            tone({ f: 440, d: 0.55, type: 'triangle', g: 0.45, at: 0.16 });
            tone({ f: 90, f2: 70, d: 0.7, type: 'sawtooth', g: 0.08, a: 0.15, at: 0.05 });
            if (crit) tone({ f: 330, d: 0.7, type: 'triangle', g: 0.4, at: 0.34 });
        },
        thirst: function (crit) {
            // water drops
            tone({ f: 520, f2: 1400, slide: 0.09, d: 0.16, g: 0.5 });
            tone({ f: 620, f2: 1700, slide: 0.08, d: 0.14, g: 0.4, at: 0.2 });
            if (crit) tone({ f: 480, f2: 1300, slide: 0.09, d: 0.16, g: 0.45, at: 0.4 });
        },
        heartbeat: function () {
            tone({ f: 70, f2: 42, slide: 0.12, d: 0.18, g: 0.9, a: 0.005 });
            tone({ f: 62, f2: 40, slide: 0.12, d: 0.16, g: 0.6, a: 0.005, at: 0.24 });
        },
        ding: function () {
            tone({ f: 880, d: 1.1, g: 0.35, a: 0.004 });
            tone({ f: 1760, d: 0.6, g: 0.08, a: 0.004 });
        },
        buckle: function () {
            noise({ d: 0.04, freq: 2500, g: 0.5 });
            noise({ d: 0.05, freq: 1800, g: 0.45, at: 0.07 });
            tone({ f: 1200, d: 0.05, g: 0.12, at: 0.07 });
        },
        unbuckle: function () {
            noise({ d: 0.05, freq: 1400, g: 0.45 });
            tone({ f: 500, f2: 300, d: 0.12, g: 0.12, at: 0.02 });
        },
        moneyIn: function () {
            tone({ f: 1318, d: 0.18, g: 0.3, type: 'triangle' });
            tone({ f: 1976, d: 0.35, g: 0.28, type: 'triangle', at: 0.08 });
        },
        moneyOut: function () {
            tone({ f: 660, f2: 440, slide: 0.2, d: 0.28, g: 0.28, type: 'triangle' });
        },
        alert: function () {
            tone({ f: 740, d: 0.18, g: 0.35, type: 'triangle' });
            tone({ f: 740, d: 0.18, g: 0.35, type: 'triangle', at: 0.22 });
        },
    };

    return {
        play: function (name, arg) {
            if (!lib[name] || cfg.volume <= 0) return;
            try { init(); if (ctx && ctx.state === 'suspended') ctx.resume(); lib[name](arg); } catch (e) {}
        },
        setVolume: function (v) { if (master) master.gain.value = v; },
    };
})();

// ════════════════════════════════════════════
//  Toasts
// ════════════════════════════════════════════

function toast(o) {
    var box = $('toasts');
    while (box.children.length >= 3) box.removeChild(box.firstChild);
    var el = document.createElement('div');
    el.className = 'toast';
    el.style.setProperty('--tc', o.color);
    el.style.setProperty('--tg', o.glow || o.color);
    var time = o.time || 5000;
    el.innerHTML =
        '<div class="toast-icon"><i class="fa-solid ' + o.icon + '"></i></div>' +
        '<div><div class="toast-title"></div><div class="toast-msg"></div></div>' +
        '<div class="toast-bar" style="animation-duration:' + time + 'ms"></div>';
    el.querySelector('.toast-title').textContent = o.title;
    el.querySelector('.toast-msg').textContent = o.msg;
    box.appendChild(el);
    setTimeout(function () {
        el.classList.add('out');
        setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 420);
    }, time);
}

// ════════════════════════════════════════════
//  Status rings
// ════════════════════════════════════════════

var RING_LEN = 2 * Math.PI * 19;

var STATS = [
    { id: 'voice',  icon: 'fa-microphone-lines-slash', color: '#34d399' },
    { id: 'health', icon: 'fa-heart',                  color: '#ff4d6d' },
    { id: 'armor',  icon: 'fa-shield-halved',          color: '#3da2ff' },
    { id: 'hunger', icon: 'fa-burger',                 color: '#ffb547' },
    { id: 'thirst', icon: 'fa-droplet',                color: '#38bdf8' },
    { id: 'stress', icon: 'fa-brain',                  color: '#c084fc' },
    { id: 'oxygen', icon: 'fa-person-running',         color: '#fd8a3a' },
];

var statEls = {};

(function buildStats() {
    var root = $('status');
    STATS.forEach(function (s) {
        var el = document.createElement('div');
        el.className = 'stat ' + s.id;
        el.style.setProperty('--c', s.color);
        el.innerHTML =
            '<svg viewBox="0 0 46 46"><circle class="bg" cx="23" cy="23" r="19"/>' +
            '<circle class="ring" cx="23" cy="23" r="19" stroke-dasharray="' + RING_LEN + '" stroke-dashoffset="0"/></svg>' +
            '<i class="fa-solid ' + s.icon + '"></i><span class="val">100</span>';
        root.appendChild(el);
        statEls[s.id] = {
            el: el,
            ring: el.querySelector('.ring'),
            icon: el.querySelector('i'),
            val: el.querySelector('.val'),
            color: s.color,
        };
    });
})();

var forceShowStats = false;

function setRing(id, pct, visible, critical) {
    var s = statEls[id];
    pct = clamp(pct, 0, 100);
    s.ring.style.strokeDashoffset = String(RING_LEN * (1 - pct / 100));
    s.val.textContent = Math.round(pct);
    s.el.classList.toggle('on', !!(visible || forceShowStats));
    s.el.classList.toggle('critical', !!critical);
}

function setIcon(id, icon) {
    var s = statEls[id];
    var cls = 'fa-solid ' + icon;
    if (s.icon.className !== cls) s.icon.className = cls;
}

function flashStat(id) {
    var el = statEls[id].el;
    el.classList.remove('alert');
    void el.offsetWidth;
    el.classList.add('alert');
}

// ════════════════════════════════════════════
//  Needs alerts (hunger / thirst) + low health
// ════════════════════════════════════════════

var needs = {
    hunger: { level: 'ok', last: 0 },
    thirst: { level: 'ok', last: 0 },
};

function needAlert(id, crit) {
    var t = cfg.texts[id + (crit ? 'Crit' : 'Warn')] || ['', ''];
    Sound.play(id, crit);
    flashStat(id);
    toast({
        icon: id === 'hunger' ? 'fa-burger' : 'fa-droplet',
        color: crit ? '#ff4d5e' : statEls[id].color,
        title: t[0],
        msg: t[1],
        time: crit ? 7000 : 5000,
    });
}

function checkNeed(id, v, dead) {
    var c = cfg[id], st = needs[id];
    if (!c || !c.enabled || !barActive(id) || dead) return;
    var now = Date.now();
    if (v <= c.critical) {
        if (st.level !== 'crit' || now - st.last >= c.repeatEvery * 1000) {
            needAlert(id, true);
            st.last = now;
        }
        st.level = 'crit';
    } else if (v <= c.warn) {
        if (st.level === 'ok') { needAlert(id, false); st.last = now; }
        st.level = 'warn';
    } else if (v > c.warn + 5) {
        st.level = 'ok';
    }
}

var heart = { timer: null, toastShown: false };

function setLowHealth(on) {
    var fx = $('low-health');
    if (on && !heart.timer) {
        fx.classList.add('on');
        var beat = function () {
            Sound.play('heartbeat');
            fx.classList.remove('beat'); void fx.offsetWidth; fx.classList.add('beat');
        };
        beat();
        heart.timer = setInterval(beat, 1150);
        if (!heart.toastShown) {
            heart.toastShown = true;
            toast({ icon: 'fa-heart-pulse', color: '#ff4d5e', title: cfg.texts.lowHealth[0], msg: cfg.texts.lowHealth[1], time: 5000 });
        }
    } else if (!on && heart.timer) {
        clearInterval(heart.timer);
        heart.timer = null;
        fx.classList.remove('on', 'beat');
    }
    if (!on) heart.toastShown = false;
}

// ════════════════════════════════════════════
//  Player HUD
// ════════════════════════════════════════════

var lastHud = null;
var lastVoice = {};

function updateVoice(v) {
    if (!v || typeof v !== 'object') return;
    var s = statEls.voice;
    var talking = !!v.talking, radio = !!v.radio, range = v.range || 3;
    if (lastVoice.talking !== talking || lastVoice.radio !== radio) {
        lastVoice.talking = talking; lastVoice.radio = radio;
        var color = radio ? '#ff4d5e' : talking ? '#3da2ff' : '#34d399';
        s.el.style.setProperty('--c', color);
        setIcon('voice', radio ? 'fa-walkie-talkie' : talking ? 'fa-microphone' : 'fa-microphone-lines-slash');
        s.el.classList.toggle('talking', talking || radio);
    }
    var pct = range <= 1.5 ? 33 : range <= 3.0 ? 66 : 100;
    setRing('voice', pct, barActive('voice'), false);
}

function updateOxygen(o) {
    if (!o || typeof o !== 'object') return;
    var s = statEls.oxygen;
    var val = clamp(o.range, 0, 100);
    if (o.inwater) {
        s.el.style.setProperty('--c', '#22d3ee');
        setIcon('oxygen', 'fa-person-swimming');
        setRing('oxygen', val, barActive('oxygen'), val < 25);
    } else {
        s.el.style.setProperty('--c', val < 25 ? '#ff4d5e' : '#fd8a3a');
        setIcon('oxygen', 'fa-person-running');
        setRing('oxygen', val, barActive('stamina') && val < 99, false);
    }
}

function updateHud(d) {
    lastHud = d;
    var dead = !!d.playerDead;
    updateVoice(d.voice);

    var hp = clamp(Number(d.health) || 0, 0, 100);
    var lowHp = cfg.lowHealth.enabled && !dead && hp > 0 && hp < cfg.lowHealth.below;
    setRing('health', hp, barActive('health') && hp < 97, lowHp || dead);
    setLowHealth(lowHp);

    var ar = clamp(Number(d.armor) || 0, 0, 100);
    setRing('armor', ar, barActive('armor') && ar > 0, false);

    var hu = clamp(Number(d.hunger), 0, 100), th = clamp(Number(d.thirst), 0, 100);
    setRing('hunger', hu, barActive('hunger') && hu < 80, barActive('hunger') && hu <= cfg.hunger.critical);
    setRing('thirst', th, barActive('thirst') && th < 80, barActive('thirst') && th <= cfg.thirst.critical);
    checkNeed('hunger', hu, dead);
    checkNeed('thirst', th, dead);

    var st = clamp(Number(d.stress) || 0, 0, 100);
    setRing('stress', st, barActive('stress') && st > 0, st >= 80);

    updateOxygen(d.oxygen);
}

function setHudVisible(show) {
    $('ui-scale').classList.toggle('hidden', !show);
    if (!show) setLowHealth(false);
}

// ════════════════════════════════════════════
//  Vehicle dashboard
// ════════════════════════════════════════════

var CX = 120, CY = 120;

function polar(r, deg) {
    var a = deg * Math.PI / 180;
    return [CX + r * Math.cos(a), CY + r * Math.sin(a)];
}

function arc(r, a0, a1) {
    var p0 = polar(r, a0), p1 = polar(r, a1);
    var sweep = a1 > a0 ? 1 : 0;
    var large = Math.abs(a1 - a0) > 180 ? 1 : 0;
    return 'M' + p0[0].toFixed(2) + ' ' + p0[1].toFixed(2) + ' A' + r + ' ' + r + ' 0 ' + large + ' ' + sweep + ' ' + p1[0].toFixed(2) + ' ' + p1[1].toFixed(2);
}

var RPM_START = 135, RPM_SWEEP = 270, RPM_R = 100;

(function buildGauge() {
    $('rpm-track').setAttribute('d', arc(RPM_R, RPM_START, RPM_START + RPM_SWEEP));
    $('rpm-red').setAttribute('d', arc(RPM_R, RPM_START + RPM_SWEEP * 0.84, RPM_START + RPM_SWEEP));
    var fill = $('rpm-fill');
    fill.setAttribute('d', arc(RPM_R, RPM_START, RPM_START + RPM_SWEEP));
    fill.setAttribute('pathLength', '100');
    fill.style.strokeDasharray = '100';
    fill.style.strokeDashoffset = '100';

    var ticks = '';
    var n = 40;
    for (var i = 0; i <= n; i++) {
        var deg = RPM_START + RPM_SWEEP * i / n;
        var major = i % 5 === 0;
        var p0 = polar(major ? 83 : 86, deg), p1 = polar(91, deg);
        var cls = (major ? 'major' : '') + (i / n >= 0.84 ? ' red' : '');
        ticks += '<line class="' + cls + '" x1="' + p0[0].toFixed(1) + '" y1="' + p0[1].toFixed(1) + '" x2="' + p1[0].toFixed(1) + '" y2="' + p1[1].toFixed(1) + '"/>';
    }
    $('ticks').innerHTML = ticks;

    [['fuel', 150, 210], ['eng', 30, -30]].forEach(function (m) {
        $(m[0] + '-track').setAttribute('d', arc(76, m[1], m[2]));
        var f = $(m[0] + '-fill');
        f.setAttribute('d', arc(76, m[1], m[2]));
        f.setAttribute('pathLength', '100');
        f.style.strokeDasharray = '100';
        f.style.strokeDashoffset = '0';
    });
})();

var veh = {
    on: false,
    speed: 0, speedShown: -1, speedLerp: 0,
    rpm: 0, rpmLerp: 0,
    gear: null,
    heading: 0, bearingLerp: 0,
    belt: null, beltSystem: false, chimes: 0, lastChime: 0,
    air: false,
};

function renderSpeed(v) {
    var s = Math.max(0, Math.round(v));
    if (s === veh.speedShown) return;
    veh.speedShown = s;
    var str = String(Math.min(999, s));
    var pad = 3 - str.length, html = '';
    for (var i = 0; i < pad; i++) html += '<span class="dim">0</span>';
    $('speed').innerHTML = html + '<span>' + str + '</span>';
}

function renderRpm(pct) {
    pct = clamp(pct, 0, 100);
    $('rpm-fill').style.strokeDashoffset = String(100 - pct);
    var p = polar(RPM_R, RPM_START + RPM_SWEEP * pct / 100);
    var head = $('rpm-head');
    head.setAttribute('cx', p[0].toFixed(2));
    head.setAttribute('cy', p[1].toFixed(2));
    $('dash').classList.toggle('redline', pct >= 92);
}

function setGear(g) {
    if (g === veh.gear) return;
    veh.gear = g;
    var el = $('gear');
    $('gear-num').textContent = g;
    el.classList.toggle('rev', g === 'R');
    el.classList.toggle('neutral', g === 'N');
    el.classList.remove('shift'); void el.offsetWidth; el.classList.add('shift');
}

function updateVehHud(d) {
    if (d.seatbelt !== undefined) updateBelt(!!d.seatbelt, d.seatbeltSystem);
    if (d.speed === undefined) return;

    setVehicleVisible(true);

    veh.speed = Math.max(0, Math.floor(Number(d.speed) || 0));
    veh.air = !!d.isAircraft;
    $('dash').classList.toggle('air', veh.air);
    veh.rpm = veh.air ? clamp(veh.speed / 300 * 100, 0, 100) : clamp(Number(d.rpm) || 0, 0, 100);
    if (veh.air) $('alt-val').textContent = Math.floor(d.altitude || 0);

    var g = d.gear;
    if (g === 'R' || (typeof g === 'number' && g <= 0)) g = 'R';
    if (veh.speed <= 0 && g !== 'R') g = 'N';
    setGear(String(g));

    var fuel = clamp(Number(d.fuel) || 0, 0, 100);
    var ff = $('fuel-fill');
    ff.style.strokeDashoffset = String(100 - fuel);
    ff.style.setProperty('--fuel-c', fuel >= 50 ? '#34d399' : fuel >= 25 ? '#ffb547' : '#ff4d5e');
    $('dash').classList.toggle('low-fuel', fuel < 15);

    var eng = clamp((Number(d.engineHp) || 0) / 10, 0, 100);
    var ef = $('eng-fill');
    ef.style.strokeDashoffset = String(100 - eng);
    ef.style.setProperty('--eng-c', eng >= 60 ? '#3da2ff' : eng >= 35 ? '#ffb547' : '#ff4d5e');
    $('dash').classList.toggle('eng-bad', eng < 40);
    $('ind-engine').classList.toggle('on', eng < 40);

    if (d.lights !== undefined) $('ind-lights').classList.toggle('on', !!d.lights);
    if (d.cruise !== undefined) $('ind-cruise').classList.toggle('on', !!d.cruise);
    if (d.heading !== undefined) veh.heading = Number(d.heading) || 0;

    // seatbelt chime while driving unbuckled
    var sc = cfg.seatbeltChime;
    if (veh.beltSystem && veh.belt && sc.enabled && veh.speed >= sc.minSpeed && veh.chimes < sc.times) {
        var now = Date.now();
        if (now - veh.lastChime > 4000) {
            veh.lastChime = now;
            veh.chimes++;
            Sound.play('ding');
        }
    }
}

function updateBelt(unbuckled, system) {
    if (system !== undefined) veh.beltSystem = !!system;
    var ind = $('ind-belt');
    ind.classList.toggle('hidden', !veh.beltSystem);
    ind.classList.toggle('on', unbuckled && veh.beltSystem);
    if (veh.belt !== null && veh.belt !== unbuckled && veh.beltSystem) {
        Sound.play(unbuckled ? 'unbuckle' : 'buckle');
    }
    if (!unbuckled) veh.chimes = 0;
    veh.belt = unbuckled;
}

function setVehicleVisible(show) {
    if (show === veh.on) return;
    veh.on = show;
    $('dash').classList.toggle('on', show);
    $('map-frame').classList.toggle('on', show);
    $('nav').classList.toggle('on', show);
    $('compass').classList.toggle('on', show && cfg.compass);
    if (show) {
        veh.speedShown = -1;
        startLoop();
    } else {
        veh.belt = null;
        veh.chimes = 0;
        veh.gear = null;
    }
}

// compass tape
var PX_PER_DEG = 3;

(function buildCompass() {
    var names = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };
    var html = '';
    for (var deg = -180; deg <= 540; deg += 15) {
        var x = (deg + 180) * PX_PER_DEG;
        var norm = ((deg % 360) + 360) % 360;
        var name = names[norm];
        if (name) html += '<span class="card' + (norm === 0 ? ' n' : '') + '" style="left:' + x + 'px">' + name + '</span>';
        else if (norm % 30 === 0) html += '<span style="left:' + x + 'px;top:2px">' + norm + '</span>';
        html += '<i class="' + (norm % 45 === 0 ? 'major' : '') + '" style="left:' + x + 'px"></i>';
    }
    $('compass-strip').innerHTML = html;
})();

function renderCompass(bearing) {
    $('compass-strip').style.transform = 'translateX(' + (210 - (bearing + 180) * PX_PER_DEG).toFixed(1) + 'px)';
    var d = Math.round(((bearing % 360) + 360) % 360);
    $('compass-deg').textContent = ('00' + d).slice(-3) + '°';
}

// animation loop (only while in a vehicle)
var looping = false, lastTs = 0;

function startLoop() {
    if (looping) return;
    looping = true;
    lastTs = 0;
    requestAnimationFrame(loop);
}

function loop(ts) {
    if (!veh.on) { looping = false; return; }
    var dt = lastTs ? Math.min(0.1, (ts - lastTs) / 1000) : 0.016;
    lastTs = ts;
    var k = 1 - Math.pow(0.0015, dt);

    veh.speedLerp += (veh.speed - veh.speedLerp) * k;
    veh.rpmLerp += (veh.rpm - veh.rpmLerp) * Math.min(1, k * 1.6);
    renderSpeed(veh.speedLerp);
    renderRpm(veh.rpmLerp);

    if (cfg.compass) {
        var target = (360 - veh.heading) % 360;
        var diff = ((target - veh.bearingLerp + 540) % 360) - 180;
        veh.bearingLerp = (veh.bearingLerp + diff * Math.min(1, k * 1.4) + 360) % 360;
        renderCompass(veh.bearingLerp);
    }
    requestAnimationFrame(loop);
}

// ════════════════════════════════════════════
//  Navigation
// ════════════════════════════════════════════

var DIRS = {
    Front: ['fa-arrow-up', 0], Back: ['fa-arrow-down', 0],
    Left: ['fa-arrow-left', 0], Right: ['fa-arrow-right', 0],
    Halfright: ['fa-arrow-up', 45], Halfleft: ['fa-arrow-up', -45],
};

function updateNav(d) {
    var area = d.area || d.zone || '';
    var street = d.street || d.streetName || area || 'Unknown';
    $('nav-area').textContent = area.toUpperCase();
    $('nav-street').textContent = street;

    var dist = Number(d.waydist !== undefined ? d.waydist : d.distance);
    var has = Number.isFinite(dist) && dist >= 0;
    $('nav').classList.toggle('waypoint', has);
    var icon = $('nav-icon');
    if (has) {
        var dir = DIRS[d.directions] || ['fa-location-arrow', 0];
        icon.className = 'fa-solid ' + dir[0];
        icon.style.transform = 'rotate(' + dir[1] + 'deg)';
        $('nav-dist').textContent = dist < 1 ? Math.round(dist * 1000) + ' M' : dist.toFixed(1) + ' KM';
    } else {
        icon.className = 'fa-solid fa-location-dot';
        icon.style.transform = '';
        $('nav-dist').textContent = '';
    }
}

// ════════════════════════════════════════════
//  Ammo
// ════════════════════════════════════════════

var lastClip = null;

function updateAmmo(a) {
    var el = $('ammo');
    if (!a || !a.show) { el.classList.remove('on'); lastClip = null; return; }
    var clip = Number(a.clip) || 0;
    el.classList.add('on');
    el.classList.toggle('empty', clip === 0);
    var ce = $('ammo-clip');
    ce.textContent = clip;
    if (lastClip !== null && clip < lastClip) {
        ce.classList.remove('bump'); void ce.offsetWidth; ce.classList.add('bump');
    }
    lastClip = clip;
    $('ammo-reserve').textContent = String(Number(a.reserve) || 0).padStart(2, '0');
}

// ════════════════════════════════════════════
//  Money
// ════════════════════════════════════════════

var money = { timer: null, anim: null, shown: 0 };

function fmt(n) { return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ','); }

function showMoney(d) {
    var el = $('money');
    var minus = d.money === true;
    var isDelta = d.money === true || d.money === false;
    var target = Number(d.bank) || 0;

    el.classList.toggle('minus', minus && isDelta);
    $('money-icon').className = 'fa-solid ' + (d.type === 'bank' ? 'fa-building-columns' : d.type === 'cash' ? 'fa-money-bill-wave' : 'fa-wallet');
    $('money-delta').textContent = isDelta
        ? (minus ? '−' : '+') + '$' + fmt(Number(d.amount) || 0) + (d.type ? '  ' + String(d.type).toUpperCase() : '')
        : (d.type ? String(d.type).toUpperCase() : 'BALANCE');

    // count up/down to the new balance
    var from = isDelta ? target + (minus ? 1 : -1) * (Number(d.amount) || 0) : target;
    var start = performance.now();
    cancelAnimationFrame(money.anim);
    (function step(now) {
        var t = clamp((now - start) / 700, 0, 1);
        var e = 1 - Math.pow(1 - t, 3);
        $('money-balance').textContent = fmt(from + (target - from) * e);
        if (t < 1) money.anim = requestAnimationFrame(step);
    })(start);

    el.classList.add('on');
    if (isDelta && cfg.moneySound) Sound.play(minus ? 'moneyOut' : 'moneyIn');
    clearTimeout(money.timer);
    money.timer = setTimeout(function () { el.classList.remove('on'); }, 3500);
}

// ════════════════════════════════════════════
//  Clock (device time, like the original)
// ════════════════════════════════════════════

(function clock() {
    var months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    function tick() {
        var now = new Date();
        var h = now.getHours(), m = now.getMinutes();
        $('time').textContent = String(h % 12 || 12).padStart(2, '0') + ':' + String(m).padStart(2, '0');
        $('ampm').textContent = h >= 12 ? 'PM' : 'AM';
        $('date').textContent = months[now.getMonth()] + ' ' + now.getDate();
    }
    tick();
    setInterval(tick, 1000);
})();

// ════════════════════════════════════════════
//  Messages from the client script
// ════════════════════════════════════════════

function applyConfig(c) {
    if (!c) return;
    ['bars', 'compass', 'volume', 'hunger', 'thirst', 'lowHealth', 'seatbeltChime', 'moneySound'].forEach(function (k) {
        if (c[k] !== undefined) cfg[k] = c[k];
    });
    if (c.texts) for (var k in c.texts) cfg.texts[k] = c.texts[k];
    Sound.setVolume(cfg.volume);
    if (lastHud) updateHud(lastHud);
}

window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || !d.action) return;
    switch (d.action) {
        case 'config': applyConfig(d.data); break;
        case 'hud':
            if (d.show) { setHudVisible(true); updateHud(d); }
            else setHudVisible(false);
            break;
        case 'hideHud': setHudVisible(false); break;
        case 'vehHud': updateVehHud(d); break;
        case 'vehHideHud': setVehicleVisible(false); break;
        case 'updateNav': updateNav(d); break;
        case 'updateAmmo': updateAmmo(d.data); break;
        case 'money': showMoney(d); break;
        case 'setMapFrame':
            var f = $('map-frame');
            f.style.width = (d.width * 1920 / d.resX) + 'px';
            f.style.height = (d.height * 1080 / d.resY) + 'px';
            break;
        case 'showAllStats':
            forceShowStats = !!d.show;
            $('status').classList.toggle('show-values', forceShowStats);
            if (lastHud) updateHud(lastHud);
            break;
        case 'toggle': $('watermark').classList.toggle('off'); break;
        case 'setRouter':
            // there is no settings page in this HUD; give the mouse back straight away
            post('OnHideSettingsMenu');
            break;
        case 'hudTest':
            if (d.sound) Sound.play(d.sound, d.arg);
            if (d.toast) needAlert(d.toast, !!d.arg);
            break;
    }
});

post('hudReady');
