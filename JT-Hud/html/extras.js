/* Additions on top of the original HUD: sounds, need alerts, low health, animations.
   Listens to the same messages as the original script and only adds to it. */

window.JTX = (function () {
    var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'JT-Hud';

    function post(name, data) {
        if (typeof GetParentResourceName !== 'function') return;
        fetch('https://' + RES + '/' + name, { method: 'POST', body: JSON.stringify(data || {}) }).catch(function () {});
    }

    function el(id) { return document.getElementById(id); }
    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
    function restart(node, cls) {
        if (!node) return;
        node.classList.remove(cls); void node.offsetWidth; node.classList.add(cls);
    }

    // ── config (overwritten by the client script) ──
    var cfg = {
        bars: {},
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

    // ── extra elements ──
    var lowhp = document.createElement('div');
    lowhp.id = 'jtx-lowhp';
    document.body.insertBefore(lowhp, document.body.firstChild);
    var toasts = document.createElement('div');
    toasts.id = 'jtx-toasts';
    document.body.appendChild(toasts);

    // ════════════ Sound (generated, no audio files) ════════════
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
            var osc = c.createOscillator(), g = c.createGain();
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
            f.type = 'highpass';
            f.frequency.value = o.freq || 2000;
            var g = c.createGain();
            g.gain.setValueAtTime(o.g || 0.4, t);
            g.gain.exponentialRampToValueAtTime(0.0001, t + o.d);
            src.connect(f); f.connect(g); g.connect(master);
            src.start(t); src.stop(t + o.d + 0.02);
        }

        var lib = {
            hunger: function (crit) {
                tone({ f: 587, d: 0.35, type: 'triangle', g: 0.45 });
                tone({ f: 440, d: 0.55, type: 'triangle', g: 0.45, at: 0.16 });
                tone({ f: 90, f2: 70, d: 0.7, type: 'sawtooth', g: 0.08, a: 0.15, at: 0.05 });
                if (crit) tone({ f: 330, d: 0.7, type: 'triangle', g: 0.4, at: 0.34 });
            },
            thirst: function (crit) {
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
        };

        return {
            play: function (name, arg) {
                if (!lib[name] || cfg.volume <= 0) return;
                try { init(); if (ctx && ctx.state === 'suspended') ctx.resume(); lib[name](arg); } catch (e) {}
            },
            setVolume: function (v) { if (master) master.gain.value = v; },
        };
    })();

    // ════════════ Toasts ════════════
    function toast(o) {
        while (toasts.children.length >= 3) toasts.removeChild(toasts.firstChild);
        var t = document.createElement('div');
        t.className = 'jtx-toast';
        t.style.setProperty('--tc', o.color);
        var time = o.time || 5000;
        t.innerHTML =
            '<div class="jtx-toast-icon"><i class="fa-solid ' + o.icon + '"></i></div>' +
            '<div><div class="jtx-toast-title"></div><div class="jtx-toast-msg"></div></div>' +
            '<div class="jtx-toast-bar" style="animation-duration:' + time + 'ms"></div>';
        t.querySelector('.jtx-toast-title').textContent = o.title;
        t.querySelector('.jtx-toast-msg').textContent = o.msg;
        toasts.appendChild(t);
        setTimeout(function () {
            t.classList.add('out');
            setTimeout(function () { if (t.parentNode) t.parentNode.removeChild(t); }, 420);
        }, time);
    }

    // ════════════ Hunger / thirst alerts ════════════
    var COLORS = { hunger: '#ff8a00', thirst: '#00d4ff' };
    var needs = { hunger: { level: 'ok', last: 0 }, thirst: { level: 'ok', last: 0 } };

    function needAlert(id, crit) {
        var t = cfg.texts[id + (crit ? 'Crit' : 'Warn')] || ['', ''];
        Sound.play(id, crit);
        restart(el(id + '-box'), 'jtx-alert');
        toast({
            icon: id === 'hunger' ? 'fa-burger' : 'fa-bottle-water',
            color: crit ? '#ff2d55' : COLORS[id],
            title: t[0],
            msg: t[1],
            time: crit ? 7000 : 5000,
        });
    }

    function checkNeed(id, v, dead) {
        var c = cfg[id], st = needs[id];
        if (!c || !c.enabled || !barActive(id) || dead || !isFinite(v)) return;
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

    // ════════════ Low health heartbeat ════════════
    var heart = { timer: null, toastShown: false };

    function setLowHealth(on) {
        if (on && !heart.timer) {
            lowhp.classList.add('on');
            var beat = function () { Sound.play('heartbeat'); restart(lowhp, 'beat'); };
            beat();
            heart.timer = setInterval(beat, 1150);
            if (!heart.toastShown) {
                heart.toastShown = true;
                toast({ icon: 'fa-heart-pulse', color: '#ff2d55', title: cfg.texts.lowHealth[0], msg: cfg.texts.lowHealth[1], time: 5000 });
            }
        } else if (!on && heart.timer) {
            clearInterval(heart.timer);
            heart.timer = null;
            lowhp.classList.remove('on', 'beat');
        }
        if (!on) heart.toastShown = false;
    }

    function setCritical(id, on) {
        var box = el(id + '-box');
        if (box) box.classList.toggle('jtx-critical', !!on);
    }

    function onHud(d) {
        if (!d.show) { setLowHealth(false); return; }
        var dead = !!d.playerDead;
        var hp = Number(d.health) || 0;
        var low = cfg.lowHealth.enabled && !dead && hp > 0 && hp < cfg.lowHealth.below;
        setLowHealth(low);
        setCritical('health', low);

        var hu = Number(d.hunger), th = Number(d.thirst);
        setCritical('hunger', barActive('hunger') && hu <= cfg.hunger.critical);
        setCritical('thirst', barActive('thirst') && th <= cfg.thirst.critical);
        checkNeed('hunger', hu, dead);
        checkNeed('thirst', th, dead);

        var ox = d.oxygen || {};
        setCritical('oxygen', !!ox.inwater && Number(ox.range) < 25);

        var v = d.voice || {};
        var vb = el('voice-box');
        if (vb) vb.classList.toggle('jtx-talking', !!(v.talking || v.radio));
    }

    // ════════════ Vehicle: smooth speed, gear, seatbelt ════════════
    var speed = { target: 0, shown: 0, running: false, text: '' };

    function setSpeed(v) {
        if (!isFinite(Number(v))) return;
        speed.target = Math.max(0, Number(v));
        if (!speed.running) { speed.running = true; requestAnimationFrame(speedStep); }
    }

    function speedStep() {
        speed.shown += (speed.target - speed.shown) * 0.25;
        if (Math.abs(speed.target - speed.shown) < 0.5) speed.shown = speed.target;
        var txt = String(Math.min(999, Math.round(speed.shown))).padStart(3, '0');
        if (txt !== speed.text) {
            speed.text = txt;
            var d = el('speedDisplay');
            if (d) d.textContent = txt;
        }
        if (speed.shown !== speed.target) requestAnimationFrame(speedStep);
        else speed.running = false;
    }

    var gearNum = el('gearNum');
    if (gearNum && window.MutationObserver) {
        var lastGear = gearNum.textContent;
        new MutationObserver(function () {
            if (gearNum.textContent === lastGear) return;
            lastGear = gearNum.textContent;
            restart(el('gear-box'), 'jtx-shift');
        }).observe(gearNum, { childList: true, characterData: true, subtree: true });
    }

    var belt = { state: null, system: false, chimes: 0, lastChime: 0 };

    function onVeh(d) {
        if (d.seatbeltSystem !== undefined) belt.system = !!d.seatbeltSystem;
        if (d.seatbelt !== undefined) {
            var unbuckled = !!d.seatbelt;
            if (belt.state !== null && belt.state !== unbuckled && belt.system) Sound.play(unbuckled ? 'unbuckle' : 'buckle');
            if (!unbuckled) belt.chimes = 0;
            belt.state = unbuckled;
        }
        var sc = cfg.seatbeltChime;
        var spd = Number(d.speed);
        if (belt.system && belt.state && sc.enabled && spd >= sc.minSpeed && belt.chimes < sc.times) {
            var now = Date.now();
            if (now - belt.lastChime > 4000) {
                belt.lastChime = now;
                belt.chimes++;
                Sound.play('ding');
            }
        }
    }

    // ════════════ Ammo ════════════
    var lastClip = null;

    function onAmmo(a) {
        var box = el('ammo-container');
        if (!a || !a.show) { lastClip = null; return; }
        var clip = Number(a.clip) || 0;
        if (box) box.classList.toggle('jtx-empty', clip === 0);
        if (lastClip !== null && clip < lastClip) restart(el('ammo-clip'), 'jtx-bump');
        lastClip = clip;
    }

    // ════════════ Messages ════════════
    function applyConfig(c) {
        if (!c) return;
        ['bars', 'volume', 'hunger', 'thirst', 'lowHealth', 'seatbeltChime', 'moneySound'].forEach(function (k) {
            if (c[k] !== undefined) cfg[k] = c[k];
        });
        if (c.texts) for (var k in c.texts) cfg.texts[k] = c.texts[k];
        Sound.setVolume(cfg.volume);
    }

    window.addEventListener('message', function (e) {
        var d = e.data;
        if (!d || !d.action) return;
        switch (d.action) {
            case 'config': applyConfig(d.data); break;
            case 'hud': onHud(d); break;
            case 'hideHud': setLowHealth(false); break;
            case 'vehHud': onVeh(d); break;
            case 'vehHideHud': belt.state = null; belt.chimes = 0; speed.target = speed.shown = 0; speed.text = ''; break;
            case 'updateAmmo': onAmmo(d.data); break;
            case 'money':
                if (cfg.moneySound && (d.money === true || d.money === false)) Sound.play(d.money ? 'moneyOut' : 'moneyIn');
                break;
            case 'toggle':
                var wm = document.querySelector('.watermark-wrapper');
                if (wm) wm.classList.toggle('jtx-off');
                break;
            case 'setRouter':
                // this HUD has no settings page; give the mouse back straight away
                post('OnHideSettingsMenu');
                break;
            case 'hudTest':
                if (d.sound) Sound.play(d.sound, d.arg);
                if (d.toast) needAlert(d.toast, !!d.arg);
                break;
        }
    });

    post('hudReady');

    return { setSpeed: setSpeed };
})();
