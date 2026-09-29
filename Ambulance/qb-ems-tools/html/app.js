(() => {
    const $ = (id) => document.getElementById(id);
    const root = $('monitor');

    const state = {
        open: false, hr: 0, spo2: 0, rr: 0, rhythm: 'SINUS', dead: false,
        triage: 'green', volume: 0.25,
    };

    // ── Audio ────────────────────────────────────────────────────────────
    let audio = null;
    function tone(freq, ms, gain) {
        if (!state.volume) return;
        try {
            audio = audio || new (window.AudioContext || window.webkitAudioContext)();
            const osc = audio.createOscillator();
            const g = audio.createGain();
            osc.type = 'sine';
            osc.frequency.value = freq;
            g.gain.value = 0;
            g.gain.linearRampToValueAtTime(state.volume * gain, audio.currentTime + 0.01);
            g.gain.linearRampToValueAtTime(0, audio.currentTime + ms / 1000);
            osc.connect(g).connect(audio.destination);
            osc.start();
            osc.stop(audio.currentTime + ms / 1000 + 0.02);
        } catch (e) { /* audio not available */ }
    }
    function beep() {
        // pitch follows oxygen saturation, like a real pulse oximeter
        const f = 480 + Math.max(0, Math.min(20, state.spo2 - 80)) * 22;
        tone(f, 70, 0.35);
    }
    let lastAlarm = 0;
    function alarm(now) {
        if (state.triage !== 'red' || now - lastAlarm < 1600) return;
        lastAlarm = now;
        if (state.rhythm === 'ASYSTOLE') { tone(620, 900, 0.25); return; }
        tone(960, 160, 0.25);
        setTimeout(() => tone(720, 160, 0.25), 200);
    }

    // ── Waveforms ────────────────────────────────────────────────────────
    const gauss = (x, mu, w) => Math.exp(-(((x - mu) / w) ** 2));
    const ecgShape = (p) =>
        0.12 * gauss(p, 0.10, 0.025) - 0.10 * gauss(p, 0.215, 0.008) + 1.0 * gauss(p, 0.235, 0.011)
        - 0.25 * gauss(p, 0.255, 0.01) + 0.30 * gauss(p, 0.46, 0.05);
    const plethShape = (p) => 0.9 * gauss(p, 0.36, 0.1) + 0.35 * gauss(p, 0.62, 0.08);

    function makeTrace(id, color, speed, range) {
        const canvas = $(id);
        const ctx = canvas.getContext('2d');
        return { canvas, ctx, color, speed, range, x: 0, prevY: null, carry: 0 };
    }
    const traces = {
        ecg: makeTrace('ecg', '#39ff7a', 130, [-0.35, 1.1]),
        pleth: makeTrace('pleth', '#35d4ff', 130, [-0.05, 1.0]),
        resp: makeTrace('resp', '#ffd23f', 45, [-1.1, 1.1]),
    };

    function resize() {
        const dpr = window.devicePixelRatio || 1;
        for (const t of Object.values(traces)) {
            const r = t.canvas.getBoundingClientRect();
            t.canvas.width = Math.max(1, Math.floor(r.width * dpr));
            t.canvas.height = Math.max(1, Math.floor(r.height * dpr));
            t.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
            t.w = r.width; t.h = r.height; t.x = 0; t.prevY = null;
            t.ctx.clearRect(0, 0, t.w, t.h);
        }
    }

    let ecgPhase = 0, respPhase = 0, vfTime = 0;
    function ecgSample(dt) {
        if (state.rhythm === 'VF') {
            vfTime += dt;
            return 0.35 * Math.sin(vfTime * 31) + 0.22 * Math.sin(vfTime * 46 + 1) + (Math.random() - 0.5) * 0.12;
        }
        if (state.rhythm === 'ASYSTOLE' || state.hr <= 0) return (Math.random() - 0.5) * 0.02;
        ecgPhase += dt * state.hr / 60;
        if (ecgPhase >= 1) {
            ecgPhase -= 1;
            onBeat();
        }
        return ecgShape(ecgPhase) + (Math.random() - 0.5) * 0.015;
    }
    function plethSample() {
        if (state.dead || state.hr <= 0) return 0.02 * (Math.random() - 0.5);
        const p = (ecgPhase + 0.85) % 1;
        return plethShape(p) * Math.max(0.35, state.spo2 / 100);
    }
    function respSample(dt) {
        if (state.rr <= 0) return 0;
        respPhase += dt * state.rr / 60;
        return Math.sin(respPhase * Math.PI * 2) * 0.8;
    }

    function plot(t, value) {
        const [lo, hi] = t.range;
        const y = t.h - 6 - ((value - lo) / (hi - lo)) * (t.h - 16);
        const { ctx } = t;
        ctx.clearRect(t.x + 1, 0, 14, t.h);
        if (t.prevY !== null) {
            ctx.strokeStyle = t.color;
            ctx.lineWidth = 1.6;
            ctx.shadowColor = t.color;
            ctx.shadowBlur = 4;
            ctx.beginPath();
            ctx.moveTo(t.x, t.prevY);
            ctx.lineTo(t.x + 1, y);
            ctx.stroke();
        }
        t.prevY = y;
        t.x += 1;
        if (t.x >= t.w) { t.x = 0; t.prevY = null; ctx.clearRect(0, 0, 16, t.h); }
    }

    function step(t, dt, sampler) {
        t.carry += dt * t.speed;
        while (t.carry >= 1) {
            t.carry -= 1;
            plot(t, sampler(1 / t.speed));
        }
    }

    const heart = $('heart');
    function onBeat() {
        heart.classList.add('beat');
        setTimeout(() => heart.classList.remove('beat'), 110);
        beep();
    }

    let last = performance.now();
    function frame(now) {
        const dt = Math.min(0.1, (now - last) / 1000);
        last = now;
        if (state.open) {
            step(traces.ecg, dt, ecgSample);
            step(traces.pleth, dt, plethSample);
            step(traces.resp, dt, respSample);
            alarm(now);
        }
        requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);

    setInterval(() => {
        const d = new Date();
        $('clock').textContent = [d.getHours(), d.getMinutes(), d.getSeconds()].map((n) => String(n).padStart(2, '0')).join(':');
    }, 1000);

    // ── Data ─────────────────────────────────────────────────────────────
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const SEVERITY = ['', 'Irritated', 'Quite painful', 'Painful', 'Really painful'];

    function setClass(el, cls) {
        el.classList.remove('bad', 'warn');
        if (cls) el.classList.add(cls);
    }

    function render(v) {
        state.hr = Number(v.hr) || 0;
        state.spo2 = Number(v.spo2) || 0;
        state.rr = Number(v.rr) || 0;
        state.rhythm = v.rhythm || 'SINUS';
        state.dead = !!v.dead;
        state.triage = v.triage || 'green';

        $('p-name').textContent = v.name || 'Unknown';
        $('p-id').textContent = '#' + (v.id ?? '?');
        $('p-meta').textContent = [v.gender, v.dob].filter(Boolean).join(' · ') || '—';
        $('p-blood').textContent = v.blood || '?';

        const tri = $('triage');
        tri.className = 'triage ' + state.triage;
        tri.textContent = v.condition || state.triage.toUpperCase();
        root.classList.toggle('alarm', state.triage === 'red');

        $('v-hr').textContent = state.hr > 0 && state.rhythm !== 'VF' ? state.hr : (state.rhythm === 'VF' ? '???' : '0');
        $('v-spo2').textContent = state.spo2 > 0 ? state.spo2 : '--';
        $('v-rr').textContent = state.rr;
        $('v-bp').textContent = v.sys > 0 ? `${v.sys}/${v.dia}` : '--/--';
        setClass($('v-bp'), v.sys <= 0 || v.sys < 90 ? 'bad' : (v.sys < 105 ? 'warn' : null));
        $('v-temp').textContent = Number(v.temp).toFixed(1);
        setClass($('v-temp'), v.temp < 35.5 ? 'warn' : null);
        $('v-gcs').textContent = v.gcs;
        setClass($('v-gcs'), v.gcs <= 8 ? 'bad' : (v.gcs < 15 ? 'warn' : null));
        $('v-health').textContent = (v.health ?? 0) + '%';
        setClass($('v-health'), v.health < 30 ? 'bad' : (v.health < 70 ? 'warn' : null));
        $('v-armor').textContent = v.armor ?? 0;

        const rhythm = $('rhythm');
        rhythm.textContent = v.rhythmLabel || state.rhythm;
        rhythm.classList.toggle('bad', state.rhythm === 'VF' || state.rhythm === 'ASYSTOLE');

        const tags = [];
        if (v.dead) tags.push(['red', 'NO PULSE — DEFIBRILLATOR']);
        else if (v.laststand) tags.push(['red', 'BLEEDING OUT — ADRENALINE / CPR']);
        if (v.bleeding) tags.push([v.bleedLevel >= 3 ? 'red' : 'yellow', 'BLEEDING: ' + v.bleeding]);
        if (v.painkillers) tags.push(['blue', 'ANALGESIA ACTIVE']);
        for (const w of (v.weapons || []).slice(0, 3)) tags.push(['', 'CAUSE: ' + w]);
        $('tags').innerHTML = tags.map(([c, t]) => `<span class="tag ${c}">${esc(t)}</span>`).join('');

        document.querySelectorAll('.body [id^="b-"]').forEach((el) => el.setAttribute('class', ''));
        const limbs = (v.limbs || []).slice().sort((a, b) => (b.severity || 0) - (a.severity || 0));
        for (const l of limbs) {
            const el = document.getElementById('b-' + l.part);
            if (el) el.setAttribute('class', 's' + Math.max(1, Math.min(4, l.severity || 1)));
        }
        $('injuries').innerHTML = limbs.length
            ? limbs.slice(0, 6).map((l) => `<li><span>${esc(l.label || l.part)}</span><span>${esc(l.state || SEVERITY[l.severity] || '')}</span></li>`).join('')
            : '<li class="none">No injuries found</li>';
    }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.action === 'open') {
            state.open = true;
            state.volume = Number(msg.volume) || 0;
            root.classList.remove('hidden');
            requestAnimationFrame(resize);
            if (msg.data) render(msg.data);
        } else if (msg.action === 'vitals' && msg.data) {
            render(msg.data);
        } else if (msg.action === 'close') {
            state.open = false;
            root.classList.add('hidden');
        }
    });
    window.addEventListener('resize', () => state.open && resize());
})();
