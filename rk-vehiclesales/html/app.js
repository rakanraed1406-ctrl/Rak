const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rk-vehiclesales';

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
// Router
// ---------------------------------------------------------------------------
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'buyConfirm') openBuy(m);
    else if (m.action === 'closeAll') hide('buy');
});

document.addEventListener('click', (e) => {
    const act = e.target.closest('[data-act]');
    if (!act) return;
    if (act.dataset.act === 'buy-yes') closeBuy(true);
    if (act.dataset.act === 'buy-no') closeBuy(false);
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('buy').classList.contains('hidden')) closeBuy(false);
});
