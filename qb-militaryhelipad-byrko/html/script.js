// Helipad NUI — plain JS (no jQuery download from the internet).
// Everything shown comes from data (plates / models can be player-made), so it
// is written with textContent and data-attributes, never pasted into onclick.
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-militaryhelipad-byrko';
let isOpened = false;
const $ = (id) => document.getElementById(id);

function post(name, data) {
    return fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).catch(() => {});
}

function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
}

function card(title, line, btnText, act, value, extraCls) {
    const c = el('div', 'card');
    if (extraCls === 'nearby') c.style.borderColor = '#3b82f6';
    const info = el('div', 'card-info');
    info.appendChild(el('h4', '', title));
    info.appendChild(el('p', '', line));
    const btn = el('button', 'action-btn' + (act === 'store' ? ' store-btn' : ''), btnText);
    btn.dataset.act = act;
    btn.dataset.value = value;
    c.appendChild(info);
    c.appendChild(btn);
    return c;
}

function fill(listId, items, empty) {
    const list = $(listId);
    list.textContent = '';
    if (!items.length) {
        if (empty) list.appendChild(el('div', 'empty-msg', empty));
        return;
    }
    items.forEach((i) => list.appendChild(i));
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action !== 'open') return;
    isOpened = true;
    const app = $('app');
    app.style.display = 'block';
    setTimeout(() => app.classList.add('active'), 10);

    fill('shop-list', (data.shopHelis || []).map((h) =>
        card(String(h.label || h.model), 'Price: $' + Number(h.price || 0).toLocaleString(), 'Purchase', 'buy', String(h.model))));

    fill('nearby-list', (data.nearbyHelis || []).map((h) =>
        card('Model: ' + String(h.model || '').toUpperCase(), 'Plate: ' + String(h.plate || ''), 'Store', 'store', String(h.plate || ''), 'nearby')),
        'No nearby helicopters found.');

    fill('garage-list', (data.ownedHelis || []).map((h) =>
        card('Model: ' + String(h.vehicle || '').toUpperCase(), 'Plate: ' + String(h.plate || '') + (h.lost ? ' (lost — can be recovered)' : ''),
            'Spawn', 'spawn', String(h.plate || ''))),
        'You do not own any stored helicopters.');

    filterHelicopters();
});

document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-act]');
    if (btn) {
        const v = btn.dataset.value;
        if (btn.dataset.act === 'buy') post('buyHeli', { model: v });
        else if (btn.dataset.act === 'spawn') post('spawnOwnedHeli', { plate: v });
        else if (btn.dataset.act === 'store') post('storeSpecificHeli', { plate: v });
        closeMenu(true);
        return;
    }
    if (e.target.closest('#close-btn')) closeMenu();
});

function switchTab(tabName) {
    const tabs = document.querySelectorAll('.tab-btn');
    tabs.forEach((t) => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach((t) => t.classList.remove('active'));
    if (tabName === 'shop') {
        tabs[0].classList.add('active');
        $('shop-content').classList.add('active');
    } else {
        tabs[1].classList.add('active');
        $('garage-content').classList.add('active');
    }
}

// `silent`: the action callback already released the focus in Lua
function closeMenu(silent) {
    if (!isOpened) return;
    isOpened = false;
    if (!silent) post('close');
    const app = $('app');
    app.classList.remove('active');
    setTimeout(() => { if (!isOpened) app.style.display = 'none'; }, 300);
}

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') closeMenu();
});

function filterHelicopters() {
    const input = ($('search-input').value || '').toLowerCase();
    document.querySelectorAll('.card').forEach((c) => {
        c.style.display = c.textContent.toLowerCase().includes(input) ? '' : 'none';
    });
}
