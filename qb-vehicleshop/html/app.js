const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-vehicleshop';

function post(name, body) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {})
    }).catch(() => {});
}

function money(n) { return '$' + Number(n || 0).toLocaleString('en-US'); }
function show(id) { $(id).classList.remove('hidden'); }
function hide(id) { $(id).classList.add('hidden'); }
function mmss(ms) {
    const s = Math.max(0, Math.ceil(ms / 1000));
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

// ---------------------------------------------------------------------------
// Buy confirm
// ---------------------------------------------------------------------------
function openBuy(msg) {
    const v = msg.vehicle || {};
    $('buy-store').textContent = msg.store || 'المعرض';
    $('buy-label').textContent = v.label || v.model || '—';
    $('buy-category').textContent = v.category || '—';
    $('buy-model').textContent = v.model || '';
    $('buy-price').textContent = money(v.price);
    show('buy');
}
function closeBuy(confirm) {
    if ($('buy').classList.contains('hidden')) return;
    hide('buy');
    post('buyConfirm', { confirm: !!confirm });
}

// ---------------------------------------------------------------------------
// Invite (auto "no" when the timer runs out)
// ---------------------------------------------------------------------------
let inviteTimer = null;
function openInvite(d) {
    $('inv-label').textContent = d.label || '—';
    $('inv-start').textContent = money(d.startPrice);
    $('inv-inc').textContent = '+' + money(d.increment);
    const secs = Number(d.timeout) || 30;
    const bar = $('inv-bar');
    bar.style.transition = 'none';
    bar.style.transform = 'scaleX(1)';
    requestAnimationFrame(() => requestAnimationFrame(() => {
        bar.style.transition = `transform ${secs}s linear`;
        bar.style.transform = 'scaleX(0)';
    }));
    clearTimeout(inviteTimer);
    inviteTimer = setTimeout(() => answerInvite(false), secs * 1000);
    show('invite');
}
function answerInvite(accept) {
    clearTimeout(inviteTimer);
    if ($('invite').classList.contains('hidden')) return;
    hide('invite');
    post('auctionRespond', { accept: !!accept });
}

// ---------------------------------------------------------------------------
// Admin form
// ---------------------------------------------------------------------------
let adminCfg = {};
function openAdmin(msg) {
    adminCfg = msg;
    $('ad-loc').innerHTML = (msg.locations || []).map(l => `<option value="${Number(l.index)}">${String(l.label).replace(/[<>&"]/g, '')}</option>`).join('');
    $('ad-start').min = msg.minStart || 5000;
    if (Number($('ad-start').value) < (msg.minStart || 5000)) $('ad-start').value = msg.minStart || 5000;
    $('ad-inc').min = msg.minIncrement || 100;
    $('ad-hint').textContent =
        `يبدأ لما يوافق ${msg.minParticipants} لاعبين داخل النطاق · المدة ${Math.round((msg.duration || 300) / 60)} دقائق · ` +
        `لو محد زاد خلال ${msg.soldAfter || 10} ثواني آخر مزايد يفوز. أنت ما تشارك.`;
    $('ad-error').textContent = '';
    show('admin');
    setTimeout(() => $('ad-model').focus(), 50);
}
function closeAdmin() {
    if ($('admin').classList.contains('hidden')) return;
    hide('admin');
    post('close');
}
$('admin-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const model = $('ad-model').value.trim().toLowerCase();
    const startPrice = Math.floor(Number($('ad-start').value));
    const increment = Math.floor(Number($('ad-inc').value));
    const minStart = adminCfg.minStart || 5000, minInc = adminCfg.minIncrement || 100;
    if (!/^[a-z0-9_]+$/.test(model)) return ($('ad-error').textContent = 'اكتب موديل صحيح (حروف إنجليزية وأرقام)');
    if (!(startPrice >= minStart)) return ($('ad-error').textContent = `أقل سعر بداية ${money(minStart)}`);
    if (!(increment >= minInc)) return ($('ad-error').textContent = `أقل زيادة ${money(minInc)}`);
    hide('admin');
    post('auctionCreate', { model, startPrice, increment, location: Number($('ad-loc').value) });
});

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------
let hud = null;          // last payload
let hudReceivedAt = 0;
let lastPrice = null;

function renderHud() {
    if (!hud || !hud.show || !hud.auction || !hud.auction.active) { hide('hud'); return; }
    const a = hud.auction;
    const elapsed = Date.now() - hudReceivedAt;
    show('hud');
    $('hud-car').textContent = a.label || a.model || '—';

    const running = a.state === 'running';
    $('hud-lobby').classList.toggle('hidden', running);
    $('hud-running').classList.toggle('hidden', !running);

    if (!running) {
        const needed = a.needed || 3, got = Math.min(a.accepted || 0, needed);
        $('hud-slots').innerHTML = Array.from({ length: needed }, (_, i) => `<span class="${i < got ? 'on' : ''}"></span>`).join('');
        if (a.state === 'countdown' && a.startsIn != null) {
            $('hud-status').textContent = `يبدأ بعد ${Math.max(0, Math.ceil((a.startsIn - elapsed) / 1000))} ثواني`;
        } else {
            $('hud-status').textContent = `بانتظار المشاركين ${got}/${needed}`;
        }
        $('hud-timer').textContent = '—';
    } else {
        $('hud-price').textContent = money(a.price);
        if (lastPrice !== null && lastPrice !== a.price) {
            const el = $('hud-price');
            el.classList.remove('bump'); void el.offsetWidth; el.classList.add('bump');
        }
        lastPrice = a.price;

        const top = $('hud-topname');
        top.textContent = a.topName ? a.topName + (a.topId === hud.me ? ' (أنت)' : '') : 'لا أحد بعد';
        top.parentElement.classList.toggle('me', a.topId === hud.me);
        $('hud-next').textContent = money(a.nextBid);

        const endsIn = a.endsIn != null ? a.endsIn - elapsed : 0;
        $('hud-timer').textContent = mmss(endsIn);

        const wrap = $('hud-sold-wrap');
        if (a.topId && a.soldIn != null) {
            const left = Math.max(0, a.soldIn - elapsed);
            const total = (Number(a.soldAfter) || 10) * 1000;
            wrap.classList.remove('hidden');
            wrap.classList.toggle('hot', left <= 3000);
            const secs = Math.ceil(left / 1000);
            $('hud-sold-label').textContent = secs <= 3 ? 'مرة… مرتين…' : 'يُباع بعد';
            $('hud-sold').textContent = secs;
            $('hud-sold-bar').style.width = Math.min(100, (left / total) * 100) + '%';
        } else {
            wrap.classList.add('hidden');
        }
    }

    const foot = $('hud-foot');
    if (a.adminId === hud.me) {
        foot.className = 'hud-foot';
        foot.innerHTML = 'أنت منشئ المزاد (ما تشارك) · /auctioncancel للإلغاء';
    } else if (hud.participant && !hud.inZone) {
        foot.className = 'hud-foot warn';
        foot.textContent = 'أنت برا النطاق — ارجع عشان تقدر تزيد';
    } else if (hud.participant) {
        foot.className = 'hud-foot';
        foot.innerHTML = running ? `استخدم الأيتم <b>${String(hud.itemName || '').replace(/[<>&"]/g, '')}</b> عشان تزيد` : 'أنت مشارك — انتظر البداية';
    } else {
        foot.className = 'hud-foot';
        foot.textContent = running ? `${a.participantCount} مشاركين` : 'اقبل الدعوة عشان تشارك';
    }
}
setInterval(renderHud, 200);

let toastTimer = null;
function bidToast(bid, me) {
    const el = $('bid-toast');
    el.innerHTML = `${bid.id === me ? 'أنت' : String(bid.name || '').replace(/[<>&"]/g, '')} زايد <b>${money(bid.amount)}</b>`;
    el.classList.add('hidden'); void el.offsetWidth; el.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 2500);
}

let resultTimer = null;
function showResult(r, me) {
    const box = $('result');
    const won = r.winnerId === me;
    box.classList.toggle('win', won);
    $('res-title').textContent = won ? 'مبروك! فزت بالمزاد' : `${r.winner || ''} فاز`;
    const safe = (v) => String(v || '').replace(/[<>&"]/g, '');
    $('res-sub').innerHTML = `${safe(r.label)} بـ <bdi>${money(r.amount)}</bdi>`;
    show('result');
    clearTimeout(resultTimer);
    resultTimer = setTimeout(() => hide('result'), 7000);
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------
window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'buyConfirm': openBuy(m); break;
        case 'auctionInvite': openInvite(m.data || {}); break;
        case 'auctionInviteClose': clearTimeout(inviteTimer); hide('invite'); break;
        case 'auctionAdmin': openAdmin(m); break;
        case 'auctionHud':
            hud = m; hudReceivedAt = Date.now();
            if (!m.auction || !m.auction.active) lastPrice = null;
            renderHud();
            break;
        case 'auctionBid': bidToast(m.bid || {}, m.me); break;
        case 'auctionResult': showResult(m.result || {}, m.me); break;
        case 'closeAll': hide('buy'); hide('invite'); hide('admin'); break;
    }
});

document.addEventListener('click', (e) => {
    const act = e.target.closest('[data-act]');
    if (!act) return;
    switch (act.dataset.act) {
        case 'buy-yes': closeBuy(true); break;
        case 'buy-no': closeBuy(false); break;
        case 'inv-yes': answerInvite(true); break;
        case 'inv-no': answerInvite(false); break;
        case 'ad-cancel': closeAdmin(); break;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('buy').classList.contains('hidden')) closeBuy(false);
    else if (!$('invite').classList.contains('hidden')) answerInvite(false);
    else if (!$('admin').classList.contains('hidden')) closeAdmin();
});
