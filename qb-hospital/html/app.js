const screen = document.getElementById('death-screen');
const canvas = document.getElementById('ecg');
const ctx = canvas.getContext('2d');
const timerEl = document.getElementById('timer');
const statusEl = document.getElementById('status');
const subEl = document.getElementById('sub');
const helpEl = document.getElementById('help');
const helpLabel = document.getElementById('help-label');
const respawnEl = document.getElementById('respawn');
const respawnLabel = document.getElementById('respawn-label');
const respawnRing = document.getElementById('respawn-ring');

const LINE_COLOR = '#3da2ff';
const GLOW_COLOR = 'rgba(61, 162, 255, 0.85)';
const HEAD_POS = 0.94;      // where the newest point is drawn (fraction of width)
const SPEED = 0.2;          // how fast the trace scrolls (fraction of width per second)

// One heartbeat (P, QRS, T), as [seconds since beat, height]
const BEAT = [
    [0.00, 0], [0.04, 0.07], [0.08, 0.1], [0.12, 0],
    [0.15, -0.1], [0.19, 1], [0.23, -0.4], [0.27, 0.03], [0.30, 0],
    [0.38, 0.08], [0.45, 0.2], [0.52, 0.07], [0.58, 0],
];
const R_PEAK = 0.19;

let texts = {};
let sound = true;
let volume = 0.15;

let visible = false;
let state = null;
let maxTime = 1;
let lastTime = null;

let width = 0;
let height = 0;
let samples = [];
let carry = 0;
let beatClock = 0;
let skipBeat = false;
let beatInterval = 0.6;
let amplitude = 1;
let targetAmplitude = 1;
let flat = false;
let frame = null;
let prevTs = 0;

// Audio

let audio = null;

function getAudio() {
    if (!audio) {
        try { audio = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { audio = null; }
    }
    return audio;
}

function tone(freq, duration, gain) {
    if (!sound) return;
    const ac = getAudio();
    if (!ac) return;
    const now = ac.currentTime;
    const osc = ac.createOscillator();
    const amp = ac.createGain();
    osc.type = 'sine';
    osc.frequency.value = freq;
    amp.gain.setValueAtTime(0, now);
    amp.gain.linearRampToValueAtTime(volume * gain, now + 0.01);
    amp.gain.setValueAtTime(volume * gain, now + duration - 0.05);
    amp.gain.linearRampToValueAtTime(0, now + duration);
    osc.connect(amp).connect(ac.destination);
    osc.start(now);
    osc.stop(now + duration + 0.02);
}

// Waveform

function beatValue(t) {
    for (let i = 1; i < BEAT.length; i++) {
        const [t1, v1] = BEAT[i];
        if (t <= t1) {
            const [t0, v0] = BEAT[i - 1];
            return v0 + (v1 - v0) * ((t - t0) / (t1 - t0));
        }
    }
    return 0;
}

function resize() {
    const dpr = window.devicePixelRatio || 1;
    width = canvas.clientWidth;
    height = canvas.clientHeight;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const len = Math.ceil(width * HEAD_POS);
    if (samples.length > len) samples = samples.slice(samples.length - len);
    while (samples.length < len) samples.unshift(0);
}

function step(dt) {
    // heart rate slows down (110 -> 30 bpm) and starts missing beats as the timer runs out
    const ratio = Math.max(0, Math.min(1, (state ? state.time : 0) / maxTime));
    beatInterval = 60 / (30 + 80 * ratio);
    targetAmplitude = flat ? 0 : 0.6 + 0.4 * ratio;
    const skipChance = ratio < 0.3 ? 0.3 - ratio : 0;
    amplitude += (targetAmplitude - amplitude) * Math.min(1, dt * (flat ? 4 : 2));

    carry += width * SPEED * dt;
    const px = Math.floor(carry);
    carry -= px;
    const dtPx = 1 / (width * SPEED);

    for (let i = 0; i < px; i++) {
        const prev = beatClock;
        beatClock += dtPx;
        if (!flat && !skipBeat && prev < R_PEAK && beatClock >= R_PEAK) tone(1050, 0.09, 1);
        if (beatClock >= beatInterval) {
            beatClock -= beatInterval;
            skipBeat = Math.random() < skipChance;
        }
        samples.push(flat || skipBeat ? 0 : beatValue(beatClock) * amplitude);
    }

    const len = Math.ceil(width * HEAD_POS);
    if (samples.length > len) samples.splice(0, samples.length - len);
}

function draw() {
    ctx.clearRect(0, 0, width, height);
    if (!samples.length) return;

    const mid = height * 0.56;
    const scale = height * 0.48;
    const headX = width * HEAD_POS;
    const start = headX - (samples.length - 1);

    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.strokeStyle = LINE_COLOR;
    ctx.shadowColor = GLOW_COLOR;
    ctx.shadowBlur = 10;
    ctx.lineWidth = 3;

    ctx.beginPath();
    for (let i = 0; i < samples.length; i++) {
        const x = start + i;
        const y = mid - samples[i] * scale;
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // bright head of the trace
    const headY = mid - samples[samples.length - 1] * scale;
    ctx.shadowBlur = 18;
    ctx.fillStyle = '#e8f4ff';
    ctx.beginPath();
    ctx.arc(headX, headY, 3.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
}

function loop(ts) {
    const dt = prevTs ? Math.min(0.1, (ts - prevTs) / 1000) : 0;
    prevTs = ts;
    step(dt);
    draw();
    if (visible) frame = requestAnimationFrame(loop);
}

// UI

function formatTime(sec) {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
}

function setFlat(value) {
    if (value === flat) return;
    flat = value;
    screen.classList.toggle('flat', flat);
    screen.classList.toggle('bleeding', !flat);
    if (flat) tone(1050, 2.6, 0.8);
}

function render(next) {
    const prev = state;
    state = next;

    if (next.mode === 'bleeding' && (!prev || prev.mode !== 'bleeding')) maxTime = Math.max(1, next.time);
    if (next.mode === 'bleeding' && next.time > maxTime) maxTime = next.time;

    setFlat(next.mode === 'dead' || next.time <= 0);

    if (next.time !== lastTime) {
        timerEl.textContent = formatTime(next.time);
        if (!flat) {
            timerEl.classList.remove('tick');
            void timerEl.offsetWidth;
            timerEl.classList.add('tick');
        }
        lastTime = next.time;
    }

    statusEl.textContent = next.mode === 'dead' ? texts.dead : texts.bleeding;
    subEl.textContent = next.mode === 'dead' && !next.canRespawn ? texts.respawn_wait : '';

    helpEl.classList.toggle('show', next.canRequestHelp || next.helpRequested);
    helpEl.classList.toggle('done', next.helpRequested);
    helpLabel.textContent = next.helpRequested ? texts.help_requested : texts.request_help;

    respawnEl.classList.toggle('show', next.canRespawn);
    respawnLabel.textContent = texts.respawn_hold;
    const progress = next.holdMax > 0 ? (next.holdMax - next.hold) / next.holdMax : 0;
    respawnRing.style.strokeDashoffset = String(100 - Math.max(0, Math.min(1, progress)) * 100);
}

function show(data) {
    texts = data.texts || {};
    sound = data.sound !== false;
    volume = typeof data.volume === 'number' ? data.volume : 0.15;

    state = null;
    lastTime = null;
    flat = false;
    amplitude = 1;
    beatClock = 0;
    skipBeat = false;
    samples = [];
    screen.classList.remove('flat');
    screen.classList.add('bleeding');
    screen.classList.remove('hidden');

    visible = true;
    resize();
    prevTs = 0;
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(loop);
}

function hide() {
    visible = false;
    screen.classList.add('hidden');
    setTimeout(() => {
        if (!visible) {
            cancelAnimationFrame(frame);
            ctx.clearRect(0, 0, width, height);
        }
    }, 700);
}

window.addEventListener('resize', () => { if (visible) resize(); });

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    if (data.action === 'show') show(data);
    else if (data.action === 'hide') hide();
    else if (data.action === 'update' && visible) render(data);
});
