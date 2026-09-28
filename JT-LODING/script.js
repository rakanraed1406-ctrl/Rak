'use strict';
/* ============================================================================
   JT loading screen
   - real progress from FiveM's loading events (stages + loadFraction + log lines)
   - music player: playlist, play/pause, next/prev, volume slider/buttons/wheel,
     mute, seek, visualizer, keyboard shortcuts, remembers the player's volume
   - animated background: drifting light, moving grid, particles, optional slides
   Settings live in config.js.
   ============================================================================ */
var C = window.LoadConfig || {};
function $(id) { return document.getElementById(id); }
function pad(n) { return (n < 10 ? '0' : '') + n; }
function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }
var inGame = typeof window.invokeNative === 'function' || typeof window.GetParentResourceName === 'function';
var startedAt = Date.now();

// ---------------------------------------------------------------------------
// Header / title / team / tips / clock
// ---------------------------------------------------------------------------
(function setupText() {
    var t = C.title || { first: 'Jinxed', second: 'Town' };
    $('welcome').textContent = C.welcome || 'WELCOME TO';
    $('tagline').textContent = C.tagline || '';
    if (!C.tagline) $('tagline').style.display = 'none';
    $('logo-text').textContent = C.logo || 'JT';
    $('brand-name').textContent = (t.first + ' ' + t.second).trim();

    // title letters rise one after the other
    var title = $('title');
    var delay = 450;
    function addWord(word, cls) {
        for (var i = 0; i < word.length; i++) {
            var s = document.createElement('span');
            s.className = 'ch' + (cls ? ' ' + cls : '');
            s.textContent = word[i];
            s.style.animationDelay = delay + 'ms';
            delay += 55;
            title.appendChild(s);
        }
    }
    addWord(t.first || '', 'blue');
    if (t.second) {
        var gap = document.createElement('span');
        gap.className = 'ch gap';
        title.appendChild(gap);
        addWord(t.second, '');
    }
    setTimeout(function () { title.classList.add('glow'); }, delay + 800);

    // socials
    (C.socials || []).forEach(function (s) {
        var el = document.createElement('div');
        el.className = 'social edge';
        el.innerHTML = '<small></small><span></span>';
        el.children[0].textContent = s.label || '';
        el.children[1].textContent = s.value || '';
        $('socials').appendChild(el);
    });

    // team
    (C.team || []).forEach(function (m, i) {
        var el = document.createElement('div');
        el.className = 'member edge';
        el.style.animationDelay = (1400 + i * 120) + 'ms';
        var av = document.createElement('div');
        av.className = 'avatar';
        if (m.image) {
            var img = document.createElement('img');
            img.src = m.image;
            img.onerror = function () { av.textContent = (m.name || '?')[0]; };
            av.appendChild(img);
        } else {
            av.textContent = (m.name || '?')[0].toUpperCase();
        }
        var b = document.createElement('b'); b.textContent = m.name || '';
        var sm = document.createElement('small'); sm.textContent = m.role || '';
        el.appendChild(av); el.appendChild(b); el.appendChild(sm);
        $('team').appendChild(el);
    });

    // tips rotate
    var tips = C.tips || [];
    var tipEl = $('tip-text');
    var dots = $('tip-dots');
    if (!tips.length) { document.querySelector('.tip').style.display = 'none'; return; }
    tips.forEach(function () { dots.appendChild(document.createElement('i')); });
    var tipIdx = 0;
    function showTip(i) {
        tipEl.textContent = tips[i];
        Array.prototype.forEach.call(dots.children, function (d, j) { d.classList.toggle('on', j === i); });
    }
    showTip(0);
    setInterval(function () {
        tipEl.classList.add('out');
        setTimeout(function () {
            tipIdx = (tipIdx + 1) % tips.length;
            showTip(tipIdx);
            tipEl.classList.remove('out');
        }, 450);
    }, (C.tipSeconds || 7) * 1000);
})();

(function clock() {
    function tick() {
        var d = new Date();
        $('clock').textContent = pad(d.getHours()) + ':' + pad(d.getMinutes());
        var s = Math.floor((Date.now() - startedAt) / 1000);
        $('elapsed').textContent = pad(Math.floor(s / 60)) + ':' + pad(s % 60);
    }
    tick();
    setInterval(tick, 1000);
})();

// ---------------------------------------------------------------------------
// Background: optional image slideshow + particles
// ---------------------------------------------------------------------------
(function slides() {
    var list = C.backgrounds || [];
    if (!list.length) return;
    var box = $('bg-slides');
    var els = list.map(function (src) {
        var d = document.createElement('div');
        d.className = 'bg-slide';
        d.style.backgroundImage = 'url("' + src + '")';
        box.appendChild(d);
        return d;
    });
    var i = 0;
    els[0].classList.add('on');
    if (els.length < 2) return;
    setInterval(function () {
        els[i].classList.remove('on');
        i = (i + 1) % els.length;
        void els[i].offsetWidth;
        els[i].classList.add('on');
    }, (C.backgroundSeconds || 9) * 1000);
})();

(function particles() {
    var count = Math.max(0, Math.min(150, C.particles === undefined ? 55 : C.particles));
    var canvas = $('particles');
    if (!count) { canvas.style.display = 'none'; return; }
    var ctx = canvas.getContext('2d');
    var W, H, dots = [];
    function size() {
        W = canvas.width = window.innerWidth;
        H = canvas.height = window.innerHeight;
    }
    size();
    window.addEventListener('resize', size);
    for (var i = 0; i < count; i++) {
        dots.push({
            x: Math.random() * W, y: Math.random() * H,
            r: Math.random() * 1.6 + 0.4,
            vx: (Math.random() - 0.5) * 0.25, vy: -(Math.random() * 0.35 + 0.08),
            a: Math.random() * 0.5 + 0.2, tw: Math.random() * Math.PI * 2
        });
    }
    var last = 0;
    function frame(t) {
        requestAnimationFrame(frame);
        if (t - last < 33) return; // ~30 fps is plenty and keeps the game loading fast
        last = t;
        ctx.clearRect(0, 0, W, H);
        for (var i = 0; i < dots.length; i++) {
            var p = dots[i];
            p.x += p.vx; p.y += p.vy; p.tw += 0.03;
            if (p.y < -5) { p.y = H + 5; p.x = Math.random() * W; }
            if (p.x < -5) p.x = W + 5; else if (p.x > W + 5) p.x = -5;
            var alpha = p.a * (0.6 + 0.4 * Math.sin(p.tw));
            ctx.beginPath();
            ctx.fillStyle = 'rgba(120, 185, 255,' + alpha.toFixed(3) + ')';
            ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            ctx.fill();
        }
    }
    requestAnimationFrame(frame);
})();

// ---------------------------------------------------------------------------
// Loading progress (real FiveM events)
// ---------------------------------------------------------------------------
var Load = (function () {
    var order = ['INIT_CORE', 'INIT_BEFORE_MAP_LOADED', 'MAP', 'INIT_AFTER_MAP_LOADED', 'INIT_SESSION'];
    var labels = {
        INIT_CORE: 'Starting the game',
        INIT_BEFORE_MAP_LOADED: 'Loading resources',
        MAP: 'Loading the map',
        INIT_AFTER_MAP_LOADED: 'Building the world',
        INIT_SESSION: 'Joining the session'
    };
    var count = {}, done = {};
    var current = null;
    var fraction = 0;       // from loadProgress
    var target = 0, shown = 0;

    function stagePct() {
        var total = 0;
        for (var i = 0; i < order.length; i++) {
            var k = order[i];
            var part = 0;
            if (count[k]) part = Math.min(1, (done[k] || 0) / count[k]);
            else if (order.indexOf(current) > i) part = 1;
            total += part / order.length;
        }
        return total * 100;
    }

    function setStage(k) {
        if (!labels[k] || current === k) return;
        current = k;
        $('stage').textContent = labels[k];
        var idx = order.indexOf(k);
        Array.prototype.forEach.call($('steps').children, function (s) {
            var i = order.indexOf(s.getAttribute('data-s'));
            s.classList.toggle('done', i < idx);
            s.classList.toggle('active', i === idx);
        });
    }

    function update() {
        target = Math.max(target, stagePct(), fraction * 100);
        target = Math.min(100, target);
    }

    var handlers = {
        startInitFunctionOrder: function (d) { count[d.type] = (count[d.type] || 0) + (d.count || 0); setStage(d.type); update(); },
        initFunctionInvoking: function (d) { done[d.type] = Math.max(done[d.type] || 0, (d.idx || 0) + 1); setStage(d.type); update(); },
        startDataFileEntries: function (d) { count.MAP = d.count || 1; setStage('MAP'); update(); },
        performMapLoadFunction: function () { done.MAP = (done.MAP || 0) + 1; setStage('MAP'); update(); },
        loadProgress: function (d) { fraction = Math.max(fraction, Number(d.loadFraction) || 0); update(); },
        onLogLine: function (d) { if (d.message) $('log').textContent = String(d.message).replace(/\.\.\.$/, '…'); }
    };

    window.addEventListener('message', function (e) {
        var d = e.data || {};
        if (d.eventName && handlers[d.eventName]) handlers[d.eventName](d);
        else if (typeof d.progress !== 'undefined') { target = Math.max(target, Number(d.progress) || 0); }
    });

    // smooth display (the number and bar glide to the real value)
    var fill = $('bar-fill'), pct = $('percent');
    function draw() {
        shown += (target - shown) * 0.08;
        if (target - shown < 0.05) shown = target;
        fill.style.transform = 'scaleX(' + (shown / 100).toFixed(4) + ')';
        pct.textContent = Math.floor(shown);
        requestAnimationFrame(draw);
    }
    requestAnimationFrame(draw);

    // outside the game (browser preview): fake the stages so the page can be checked
    if (!inGame) {
        var fake = 0;
        setInterval(function () {
            if (fake >= order.length) return;
            var k = order[fake];
            count[k] = count[k] || 20;
            done[k] = (done[k] || 0) + 1;
            setStage(k);
            $('log').textContent = 'Loading ' + k.toLowerCase().replace(/_/g, ' ') + ' (' + done[k] + '/' + count[k] + ')';
            if (done[k] >= count[k]) fake++;
            update();
        }, 180);
    }

    setStage('INIT_CORE');
    return { handlers: handlers };
})();

// ---------------------------------------------------------------------------
// Music player
// ---------------------------------------------------------------------------
(function music() {
    var cfg = C.music || {};
    var tracks = (cfg.tracks || []).filter(function (t) { return t && t.src; });
    var audio = $('audio');
    var body = document.body;
    if (!tracks.length) { $('player').style.display = 'none'; return; }

    var saved = parseFloat(store('jt_volume'));
    var volume = isNaN(saved) ? (cfg.volume === undefined ? 0.35 : cfg.volume) : saved;
    var muted = store('jt_muted') === '1';
    var idx = cfg.shuffle ? Math.floor(Math.random() * tracks.length) : 0;

    function load(i, autoplay) {
        idx = (i + tracks.length) % tracks.length;
        var t = tracks[idx];
        audio.src = t.src;
        $('track-title').textContent = t.title || 'Unknown';
        $('track-artist').textContent = t.artist || '';
        var tr = document.querySelector('.track');
        tr.classList.remove('swap'); void tr.offsetWidth; tr.classList.add('swap');
        if (autoplay) play();
    }
    function play() {
        startViz();
        var p = audio.play();
        if (p && p.catch) p.catch(function () { waitForGesture(); });
    }
    function toggle() { if (audio.paused) play(); else audio.pause(); }
    function next() { load(cfg.shuffle && tracks.length > 2 ? idx + 1 + Math.floor(Math.random() * (tracks.length - 1)) : idx + 1, true); }
    function prev() {
        if (audio.currentTime > 3) { audio.currentTime = 0; return; }
        load(idx - 1, true);
    }

    // autoplay can be blocked outside the game: start on the first click / key
    var waiting = false;
    function waitForGesture() {
        if (waiting) return;
        waiting = true;
        body.classList.add('paused');
        var go = function () {
            waiting = false;
            document.removeEventListener('mousedown', go);
            document.removeEventListener('keydown', go);
            play();
        };
        document.addEventListener('mousedown', go);
        document.addEventListener('keydown', go);
    }

    // ---- volume ----
    var toast = null, toastTimer = null;
    function showToast() {
        if (!toast) {
            toast = document.createElement('div');
            toast.className = 'vol-toast edge';
            toast.innerHTML = '<span>VOLUME</span><div class="vt-bar"><i></i></div><b></b>';
            document.body.appendChild(toast);
        }
        toast.querySelector('i').style.transform = 'scaleX(' + (muted ? 0 : volume) + ')';
        toast.querySelector('b').textContent = muted ? 'MUTED' : Math.round(volume * 100) + '%';
        toast.classList.add('on');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () { toast.classList.remove('on'); }, 1100);
    }
    function applyVolume(bump) {
        volume = Math.max(0, Math.min(1, Math.round(volume * 100) / 100));
        audio.volume = volume;
        audio.muted = muted;
        body.classList.toggle('muted', muted || volume === 0);
        $('vol-fill').style.transform = 'scaleX(' + volume + ')';
        $('vol-knob').style.left = (volume * 100) + '%';
        var v = $('vol-val');
        v.textContent = muted ? 'OFF' : Math.round(volume * 100) + '%';
        if (bump) { v.classList.remove('bump'); void v.offsetWidth; v.classList.add('bump'); }
        store('jt_volume', String(volume));
        store('jt_muted', muted ? '1' : '0');
    }
    function setVolume(v, fromKeys) {
        volume = v;
        if (volume > 0) muted = false;
        applyVolume(true);
        if (fromKeys) showToast();
    }
    function toggleMute(fromKeys) {
        muted = !muted;
        if (!muted && volume === 0) volume = 0.2;
        applyVolume(true);
        if (fromKeys) showToast();
    }

    // drag on the slider
    var track = $('vol-track'), dragging = false;
    function fromPointer(e) {
        var r = track.getBoundingClientRect();
        setVolume((e.clientX - r.left) / r.width);
    }
    track.addEventListener('mousedown', function (e) { dragging = true; fromPointer(e); });
    window.addEventListener('mousemove', function (e) { if (dragging) fromPointer(e); });
    window.addEventListener('mouseup', function () { dragging = false; });

    // wheel over the player = volume
    $('player').addEventListener('wheel', function (e) {
        e.preventDefault();
        setVolume(volume + (e.deltaY < 0 ? 0.05 : -0.05));
    }, { passive: false });

    $('vol-up').addEventListener('click', function () { setVolume(volume + 0.05); });
    $('vol-down').addEventListener('click', function () { setVolume(volume - 0.05); });
    $('mute').addEventListener('click', function () { toggleMute(false); });
    $('play').addEventListener('click', toggle);
    $('next').addEventListener('click', next);
    $('prev').addEventListener('click', prev);

    // click on the seek bar = jump
    document.querySelector('.seek').addEventListener('click', function (e) {
        if (!audio.duration) return;
        var r = this.getBoundingClientRect();
        audio.currentTime = audio.duration * ((e.clientX - r.left) / r.width);
    });

    // keyboard
    document.addEventListener('keydown', function (e) {
        switch (e.key) {
            case ' ': case 'k': case 'K': toggle(); e.preventDefault(); break;
            case 'ArrowUp': case '+': case '=': setVolume(volume + 0.05, true); e.preventDefault(); break;
            case 'ArrowDown': case '-': case '_': setVolume(volume - 0.05, true); e.preventDefault(); break;
            case 'm': case 'M': toggleMute(true); break;
            case 'n': case 'N': case 'ArrowRight': next(); break;
            case 'p': case 'P': case 'ArrowLeft': prev(); break;
        }
    });

    audio.addEventListener('play', function () { body.classList.remove('paused'); });
    audio.addEventListener('pause', function () { body.classList.add('paused'); });
    audio.addEventListener('ended', function () { if (tracks.length > 1) next(); else { audio.currentTime = 0; play(); } });
    audio.addEventListener('error', function () { if (tracks.length > 1) setTimeout(next, 500); });
    audio.addEventListener('timeupdate', function () {
        if (audio.duration) $('seek-fill').style.transform = 'scaleX(' + (audio.currentTime / audio.duration).toFixed(4) + ')';
    });

    // ---- visualizer (real audio levels; animated fallback if not available) ----
    var viz = $('viz'), vctx = viz.getContext('2d');
    var analyser = null, data = null, vizStarted = false, silentSince = 0;
    function startViz() {
        if (vizStarted) return;
        vizStarted = true;
        try {
            var AC = window.AudioContext || window.webkitAudioContext;
            var ac = new AC();
            var src = ac.createMediaElementSource(audio);
            analyser = ac.createAnalyser();
            analyser.fftSize = 64;
            src.connect(analyser);
            analyser.connect(ac.destination);
            data = new Uint8Array(analyser.frequencyBinCount);
            if (ac.state === 'suspended') ac.resume();
        } catch (e) { analyser = null; }
        requestAnimationFrame(drawViz);
    }
    var vlast = 0;
    function drawViz(t) {
        requestAnimationFrame(drawViz);
        if (t - vlast < 40) return;
        vlast = t;
        var W = viz.width, H = viz.height, bars = 22, gap = 3;
        var bw = (W - gap * (bars - 1)) / bars;
        vctx.clearRect(0, 0, W, H);
        if (analyser) {
            analyser.getByteFrequencyData(data);
            // no real levels for 2s while playing (blocked source) -> animated bars
            var sum = 0;
            for (var j = 0; j < data.length; j++) sum += data[j];
            if (sum > 0 || audio.paused) silentSince = 0;
            else if (!silentSince) silentSince = t;
            else if (t - silentSince > 2000) analyser = null;
        }
        for (var i = 0; i < bars; i++) {
            var v;
            if (audio.paused) v = 0.06;
            else if (analyser) v = (data[Math.floor(i * data.length / bars)] || 0) / 255;
            else v = 0.25 + 0.6 * Math.abs(Math.sin(t / 260 + i * 0.7)) * Math.abs(Math.cos(t / 410 + i));
            var h = Math.max(2, v * H);
            var g = vctx.createLinearGradient(0, H - h, 0, H);
            g.addColorStop(0, '#3b9dfb');
            g.addColorStop(1, '#174ea6');
            vctx.fillStyle = g;
            vctx.fillRect(i * (bw + gap), H - h, bw, h);
        }
    }

    applyVolume(false);
    load(idx, true);
})();
