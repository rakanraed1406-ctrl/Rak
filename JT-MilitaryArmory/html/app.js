'use strict';
/* ============================================================================
   Jinxed Town — Military Logistics NUI
   open → (intro: logo, 3s bar, logo flies to the header) → shop
   Everything shown is written with textContent (player names, labels…).
   Nothing runs while closed: one 1-second ticker only while open.
   ============================================================================ */

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'JT-MilitaryArmory';
const $ = (id) => document.getElementById(id);

function post(name, body) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {})
    }).then((r) => r.json()).catch(() => null);
}

function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
}

const money = (n) => '$' + Math.floor(Number(n) || 0).toLocaleString('en-US');
const pad = (n) => (n < 10 ? '0' : '') + n;
function hms(sec) {
    sec = Math.max(0, Math.ceil(sec));
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
}
function shortTime(sec) {
    sec = Math.max(0, Math.ceil(sec));
    if (sec >= 3600) return Math.ceil(sec / 3600) + 'H';
    return Math.max(1, Math.ceil(sec / 60)) + 'M';
}

// ---------------------------------------------------------------------------
// Placeholder icons (when a vehicle has no photo yet)
// ---------------------------------------------------------------------------
const ICON_PATHS = {
    armored: 'M4 15h40v6H4zM10 9h22l6 6H10zM30 11h14v2H30zM6 23a4 4 0 1 0 0.1 0M18 23a4 4 0 1 0 0.1 0M30 23a4 4 0 1 0 0.1 0M42 23a4 4 0 1 0 0.1 0',
    helicopters: 'M4 8h40v2H4zM23 10h2v4h-2zM12 14h20c4 0 8 3 8 7s-4 5-8 5H18l-4-4H6v-4h8zM22 26l-2 4h14l-2-4',
    jets: 'M2 22l18-3 6-13h4l-2 13 14 2 4-5h3l-2 8 2 8h-3l-4-5-14 2 2 13h-4l-6-13-18-3z',
    weapons: 'M2 18h30l4-4h10v6H36l-2 2v4h-6l-2 6h-6l2-6h-4l-2-4H2z',
    items: 'M6 14l18-8 18 8v20l-18 8-18-8zM24 22v20M6 14l18 8 18-8',
};
function placeholder(cat) {
    const d = ICON_PATHS[cat] || ICON_PATHS.items;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="${d}" fill="none" stroke="#4a7dff" stroke-width="1.6" stroke-linejoin="round"/></svg>`;
    return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

// own photo → FiveM's image of the model → category icon
function image(src, fallback, cat) {
    const im = document.createElement('img');
    im.alt = '';
    im.decoding = 'async';
    im.loading = 'lazy';
    const chain = [src, fallback].filter(Boolean);
    let i = 0;
    const toPlaceholder = () => { im.onerror = null; im.className = 'ph'; im.src = placeholder(cat); };
    im.onerror = () => { i++; if (i < chain.length) im.src = chain[i]; else toPlaceholder(); };
    if (chain.length) im.src = chain[0]; else toPlaceholder();
    return im;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const S = {
    data: null,
    cat: 'all',
    cart: new Map(),     // productId -> amount
    ends: {},            // countdown targets (ms)
    orders: [],          // [{ el, end, duration }]
    tick: null,
    introTimers: [],
    open: false,
    mode: null,          // 'shop' | 'pickup'
    depFrom: null,
    pickup: null,        // { data, amounts, picked } — picked: fleet vehicles to store
};

function product(id) { return S.data && S.data.products.find((p) => p.id === id); }

function setEnds() {
    const now = Date.now();
    S.ends.income = now + S.data.income.nextIn * 1000;
    S.ends.restock = now + S.data.restockIn * 1000;
    S.data.orders.forEach((o) => { o.end = now + o.arriveIn * 1000; });
}

function clampCart() {
    for (const [id, n] of S.cart) {
        const p = product(id);
        if (!p || p.remaining <= 0) S.cart.delete(id);
        else if (n > p.remaining) S.cart.set(id, p.remaining);
    }
}

// ---------------------------------------------------------------------------
// Ticker (only while open)
// ---------------------------------------------------------------------------
function tick() {
    const now = Date.now();
    document.querySelectorAll('[data-end]').forEach((n) => {
        const end = S.ends[n.dataset.end];
        if (end) n.textContent = hms((end - now) / 1000);
    });
    S.orders.forEach((o) => {
        const left = (o.end - now) / 1000;
        o.time.textContent = left > 0 ? hms(left) : 'ARRIVING';
        o.bar.style.transform = `scaleX(${Math.min(1, Math.max(0, 1 - left / o.duration)).toFixed(4)})`;
    });
}
function startTick() { if (!S.tick) { tick(); S.tick = setInterval(tick, 1000); } }
function stopTick() { clearInterval(S.tick); S.tick = null; }

// ---------------------------------------------------------------------------
// Toast
// ---------------------------------------------------------------------------
let toastTimer = null;
function toast(msg, kind) {
    const t = $('toast');
    t.textContent = msg;
    t.className = 'on ' + (kind || '');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.className = ''; }, 2600);
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------
function renderHeader() {
    const s = S.data.shop;
    $('hdrBadge').textContent = s.badge || s.id.toUpperCase();
    $('hdrBadge').parentNode.title = s.label || '';
    $('hdrAuthority').textContent = s.authority || 'MINISTRY OF INTERIOR';
    $('hdrTitle').textContent = s.title || 'MILITARY LOGISTICS';
    $('introAuthority').textContent = s.authority || 'MINISTRY OF INTERIOR';
    $('introTitle').textContent = s.title || 'MILITARY LOGISTICS';
}

function renderBudget() {
    const d = S.data;
    $('balance').textContent = money(d.balance);
    $('daily').textContent = '+' + money(d.income.daily);
    $('delivery').textContent = d.delivery + ' MIN';
    $('cartEta').textContent = d.delivery + ' MIN';
    $('btnDeposit').classList.toggle('hidden', !d.perms.deposit);
    const transit = d.orders.length;
    const oc = $('ordersCount');
    oc.textContent = transit + d.depot.length;
    oc.classList.toggle('on', transit + d.depot.length > 0);
}

function renderTabs() {
    const tabs = $('tabs');
    tabs.textContent = '';
    const all = [{ id: 'all', label: 'ALL' }].concat(S.data.categories);
    if (!all.some((c) => c.id === S.cat)) S.cat = 'all';
    all.forEach((c) => {
        const count = S.data.products.filter((p) => c.id === 'all' || p.category === c.id).length;
        const b = el('button', 'tab' + (c.id === S.cat ? ' on' : ''), c.label);
        b.appendChild(el('span', '', count));
        b.onclick = () => { if (S.cat !== c.id) { S.cat = c.id; renderTabs(); renderGrid(true); } };
        tabs.appendChild(b);
    });
}

function card(p, i) {
    const c = el('div', 'card');
    c.style.setProperty('--i', i);
    const top = el('div', 'c-top');
    const cat = S.data.categories.find((x) => x.id === p.category);
    top.appendChild(el('span', 'tag', cat ? cat.label : p.category.toUpperCase()));
    let stock;
    if (p.remaining <= 0) stock = el('span', 'stock out', '● SOLD OUT');
    else if (p.remaining <= Math.max(1, Math.floor(p.limit * 0.25))) stock = el('span', 'stock low', '● LOW STOCK');
    else stock = el('span', 'stock', `● ${p.remaining} IN STOCK`);
    top.appendChild(stock);
    c.appendChild(top);

    const box = el('div', 'c-img');
    box.appendChild(image(p.image, p.fallback, p.category));
    if (p.type === 'vehicle' && (p.garage || 0) + (p.out || 0) > 0) {
        // this sector already owns some: parked in the garage / out in the field
        const f = el('div', 'fleet');
        f.appendChild(el('b', '', 'FLEET'));
        f.appendChild(el('span', '', `${p.garage || 0} GARAGE · ${p.out || 0} OUT`));
        box.appendChild(f);
    }
    c.appendChild(box);
    c.appendChild(el('div', 'c-name', p.label));
    c.appendChild(el('div', 'c-desc', p.desc || ''));

    const foot = el('div', 'c-foot');
    const price = el('div');
    price.appendChild(el('small', '', 'PRICE'));
    price.appendChild(el('b', 'money', money(p.price)));
    const st = el('div');
    st.appendChild(el('small', '', 'STOCK'));
    st.appendChild(el('b', '', `${p.remaining}/${p.limit}`));
    foot.appendChild(price);
    foot.appendChild(st);
    const add = el('button', 'add');
    if (p.remaining <= 0) {
        add.textContent = 'RESTOCK IN ' + shortTime((S.ends.restock - Date.now()) / 1000);
        add.disabled = true;
    } else if (!S.data.perms.order) {
        add.textContent = 'NO CLEARANCE';
        add.disabled = true;
    } else {
        add.textContent = 'ADD TO CART';
        add.onclick = () => addToCart(p.id);
    }
    foot.appendChild(add);
    c.appendChild(foot);

    const n = S.cart.get(p.id);
    if (n) c.appendChild(el('div', 'incart', '×' + n + ' IN CART'));
    return c;
}

function renderGrid(stagger) {
    const grid = $('grid');
    grid.textContent = '';
    grid.classList.toggle('stagger', !!stagger);
    const list = S.data.products.filter((p) => S.cat === 'all' || p.category === S.cat);
    if (!list.length) { grid.appendChild(el('div', 'empty', 'NOTHING IN THIS SECTION')); return; }
    const frag = document.createDocumentFragment();
    list.forEach((p, i) => frag.appendChild(card(p, i)));
    grid.appendChild(frag);
    if (!stagger) grid.scrollTop = grid.scrollTop; // keep position on live updates
}

function stepper(value, onChange, max) {
    const s = el('div', 'stepper');
    const minus = el('button', '', '−');
    const val = el('span', '', value);
    const plus = el('button', '', '+');
    minus.onclick = () => onChange(-1);
    plus.onclick = () => onChange(1);
    if (max !== undefined && value >= max) plus.disabled = true;
    s.append(minus, val, plus);
    return s;
}

function renderCart() {
    const list = $('cartList');
    list.textContent = '';
    let total = 0, count = 0;
    for (const [id, n] of S.cart) {
        const p = product(id);
        if (!p) continue;
        total += p.price * n;
        count += n;
        const line = el('div', 'line');
        const th = el('div', 'thumb');
        th.appendChild(image(p.image, p.fallback, p.category));
        const info = el('div', 'info');
        info.appendChild(el('b', '', p.label));
        info.appendChild(el('small', '', money(p.price * n)));
        line.append(th, info, stepper(n, (d) => setCart(id, n + d), p.remaining));
        const rm = el('button', 'rm', '✕');
        rm.onclick = () => setCart(id, 0);
        line.appendChild(rm);
        list.appendChild(line);
    }
    if (!S.cart.size) list.appendChild(el('div', 'd-empty', 'YOUR CART IS EMPTY'));
    const after = S.data.balance - total;
    $('cartTotal').textContent = money(total);
    const af = $('cartAfter');
    af.textContent = money(after);
    af.classList.toggle('neg', after < 0);
    const cc = $('cartCount');
    cc.textContent = count;
    cc.classList.toggle('on', count > 0);

    let note = '';
    if (!S.data.perms.order) note = 'YOU HAVE NO ORDERING CLEARANCE';
    else if (after < 0) note = 'NOT ENOUGH BUDGET';
    else if (S.cart.size > S.data.maxLines) note = `MAX ${S.data.maxLines} PRODUCTS PER ORDER`;
    $('cartNote').textContent = note;
    $('btnCheckout').disabled = !S.cart.size || !!note;
}

function renderOrders() {
    const transit = $('transitList');
    transit.textContent = '';
    S.orders = [];
    S.data.orders.forEach((o) => {
        const box = el('div', 'order');
        const top = el('div', 'o-top');
        top.appendChild(el('span', '', '#' + o.id));
        const time = el('b', '', hms(o.arriveIn));
        top.appendChild(time);
        box.appendChild(top);
        box.appendChild(el('div', 'o-items', o.lines.map((l) => `${l.amount}× ${l.label}`).join(' · ')));
        box.appendChild(el('div', 'o-by', `${money(o.total)} · ${o.by || 'UNKNOWN'}`));
        const bar = el('div', 'o-bar');
        const fill = el('i');
        bar.appendChild(fill);
        box.appendChild(bar);
        transit.appendChild(box);
        S.orders.push({ time, bar: fill, end: o.end, duration: o.duration });
    });
    if (!S.data.orders.length) transit.appendChild(el('div', 'd-empty', 'NO ORDERS ON THE WAY'));

    const depot = $('depotList');
    depot.textContent = '';
    S.data.depot.forEach((d) => {
        const line = el('div', 'line');
        const th = el('div', 'thumb');
        const p = product(d.id);
        th.appendChild(image(d.image, p && p.fallback, p ? p.category : 'items'));
        const info = el('div', 'info');
        info.appendChild(el('b', '', d.label));
        info.appendChild(el('small', '', d.type === 'vehicle'
            ? `${d.amount} IN GARAGE · ${d.out || 0} OUT`
            : `${d.amount} READY · SUPPLY OFFICER`));
        const go = el('button', 'locate', 'LOCATE');
        go.onclick = () => { post('locate', { id: d.id }); toast('WAYPOINT SET', 'ok'); };
        line.append(th, info, go);
        depot.appendChild(line);
    });
    if (!S.data.depot.length) depot.appendChild(el('div', 'd-empty', 'THE DEPOT IS EMPTY'));
    if (S.data.depot.some((d) => d.type === 'vehicle')) {
        depot.appendChild(el('div', 'd-hint', 'TO STORE A VEHICLE: PARK IT NEXT TO THE SUPPLY OFFICER → STORE THE VEHICLE'));
    }
    tick();
}

function renderAll(stagger) {
    renderHeader();
    renderBudget();
    renderTabs();
    renderGrid(stagger);
    renderCart();
    renderOrders();
}

// ---------------------------------------------------------------------------
// Cart
// ---------------------------------------------------------------------------
function setCart(id, n) {
    const p = product(id);
    if (!p) return;
    n = Math.max(0, Math.min(n, p.remaining));
    if (n === 0) S.cart.delete(id); else S.cart.set(id, n);
    renderCart();
    renderGrid(false);
}

function addToCart(id) {
    const p = product(id);
    if (!p) return;
    const n = S.cart.get(id) || 0;
    if (n >= p.remaining) return toast('NO MORE STOCK TODAY', 'err');
    if (!n && S.cart.size >= S.data.maxLines) return toast(`MAX ${S.data.maxLines} PRODUCTS PER ORDER`, 'err');
    setCart(id, n + 1);
    const b = $('btnCart');
    b.classList.remove('bump'); void b.offsetWidth; b.classList.add('bump');
}

function drawer(id, open) {
    ['cart', 'orders'].forEach((d) => $(d).classList.toggle('open', d === id ? open : false));
}

async function checkout() {
    const cart = [...S.cart].map(([id, amount]) => ({ id, amount }));
    if (!cart.length) return;
    const btn = $('btnCheckout');
    btn.disabled = true;
    const res = await post('checkout', { cart });
    if (res && res.ok) {
        S.cart.clear();
        drawer('cart', false);
        renderCart();
        renderGrid(false);
        toast(`ORDER #${res.id} PLACED`, 'ok');
    } else {
        toast((res && res.msg) || 'ORDER FAILED', 'err');
        renderCart();
    }
}

// ---------------------------------------------------------------------------
// Deposit
// ---------------------------------------------------------------------------
function openDeposit() {
    const d = S.data;
    $('depAmount').value = '';
    $('depHint').textContent = `MIN ${money(d.deposit.min)} · MAX ${money(d.deposit.max)}`;
    const chips = $('depChips');
    chips.textContent = '';
    [10000, 100000, 1000000].forEach((v) => {
        const b = el('button', '', '+' + (v >= 1000000 ? v / 1000000 + 'M' : v / 1000 + 'K'));
        b.onclick = () => { $('depAmount').value = String((parseInt($('depAmount').value.replace(/\D/g, ''), 10) || 0) + v); };
        chips.appendChild(b);
    });
    const max = el('button', '', 'MAX');
    max.onclick = () => { $('depAmount').value = String(Math.min(d.deposit.max, d.wallet[S.depFrom] || 0)); };
    chips.appendChild(max);

    const from = $('depFrom');
    from.textContent = '';
    if (!d.deposit.from.includes(S.depFrom)) S.depFrom = d.deposit.from[0];
    d.deposit.from.forEach((src) => {
        const b = el('button', src === S.depFrom ? 'on' : '');
        b.appendChild(el('small', '', src.toUpperCase()));
        b.appendChild(el('b', '', money(d.wallet[src])));
        b.onclick = () => { S.depFrom = src; [...from.children].forEach((x) => x.classList.toggle('on', x === b)); };
        from.appendChild(b);
    });
    $('depositModal').classList.remove('hidden');
    setTimeout(() => $('depAmount').focus(), 30);
}

async function confirmDeposit() {
    const amount = parseInt($('depAmount').value.replace(/\D/g, ''), 10) || 0;
    const d = S.data;
    if (amount < d.deposit.min || amount > d.deposit.max) return toast(`${money(d.deposit.min)} – ${money(d.deposit.max)}`, 'err');
    $('btnDepConfirm').disabled = true;
    const res = await post('deposit', { amount, from: S.depFrom });
    $('btnDepConfirm').disabled = false;
    if (res && res.ok) {
        $('depositModal').classList.add('hidden');
        toast('DEPOSITED ' + money(amount), 'ok');
    } else {
        toast((res && res.msg) || 'DEPOSIT FAILED', 'err');
    }
}

// ---------------------------------------------------------------------------
// Intro
// ---------------------------------------------------------------------------
const STATUS = ['INITIALIZING SYSTEM…', 'VERIFYING CLEARANCE…', 'SYNCING DEPOT…', 'SECURE CHANNEL ESTABLISHED'];

function clearIntro() {
    S.introTimers.forEach(clearTimeout);
    S.introTimers = [];
    const fly = $('flyLogo');
    if (fly) fly.remove();
}

function runIntro(secs) {
    clearIntro();
    const panel = $('panel');
    const intro = $('intro');
    const fill = $('introFill');
    panel.classList.add('intro');
    intro.classList.remove('hidden', 'out', 'go');
    $('introLogo').style.visibility = '';
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(0)';
    $('introStatus').textContent = STATUS[0];
    void intro.offsetWidth;
    requestAnimationFrame(() => {
        intro.classList.add('go');
        fill.style.transition = `transform ${secs}s linear`;
        fill.style.transform = 'scaleX(1)';
    });
    STATUS.forEach((txt, i) => {
        if (i) S.introTimers.push(setTimeout(() => { $('introStatus').textContent = txt; }, (secs * 1000 / STATUS.length) * i));
    });
    S.introTimers.push(setTimeout(finishIntro, secs * 1000 + 180));
}

function finishIntro() {
    const panel = $('panel');
    const intro = $('intro');
    const logo = $('introLogo');
    const target = $('hdrLogo');
    const from = logo.getBoundingClientRect();

    panel.classList.remove('intro'); // header / budget / grid fade in
    renderGrid(true);                // cards come in one after another
    const to = target.getBoundingClientRect();
    target.style.opacity = '0';

    // the big logo flies into the header slot (top left) and shrinks
    const fly = logo.cloneNode();
    fly.id = 'flyLogo';
    Object.assign(fly.style, {
        position: 'fixed', left: from.left + 'px', top: from.top + 'px', width: from.width + 'px', height: from.height + 'px',
        margin: '0', opacity: '1', zIndex: '60', transformOrigin: '0 0', transform: 'none',
        transition: 'transform .65s cubic-bezier(.2,.8,.2,1)', visibility: 'visible',
        filter: 'drop-shadow(0 0 18px rgba(74,125,255,.35))',
    });
    document.body.appendChild(fly);
    logo.style.visibility = 'hidden';
    intro.classList.add('out');
    requestAnimationFrame(() => requestAnimationFrame(() => {
        fly.style.transform = `translate(${to.left - from.left}px, ${to.top - from.top}px) scale(${to.width / from.width})`;
    }));
    S.introTimers.push(setTimeout(() => {
        fly.remove();
        target.style.opacity = '';
        intro.classList.add('hidden');
    }, 700));
}

// ---------------------------------------------------------------------------
// Open / close
// ---------------------------------------------------------------------------
function showApp() {
    const app = $('app');
    app.classList.remove('hidden');
    requestAnimationFrame(() => requestAnimationFrame(() => app.classList.add('on')));
}

function openShop(msg) {
    S.open = true;
    S.mode = 'shop';
    S.data = msg.data;
    setEnds();
    clampCart();
    $('pickup').classList.add('hidden');
    $('depositModal').classList.add('hidden');
    drawer(null, false);
    renderHeader();
    renderBudget();
    renderTabs();
    renderCart();
    renderOrders();
    showApp();
    if (msg.intro) {
        $('grid').textContent = '';
        runIntro(Math.max(1, Number(msg.introSeconds) || 3));
    } else {
        clearIntro();
        $('intro').classList.add('hidden');
        $('panel').classList.remove('intro');
        $('hdrLogo').style.opacity = '';
        renderGrid(true);
    }
    startTick();
}

function update(data) {
    if (!S.open || S.mode !== 'shop') return;
    S.data = data;
    setEnds();
    clampCart();
    renderHeader();
    renderBudget();
    renderTabs();
    if (!$('panel').classList.contains('intro')) renderGrid(false);
    renderCart();
    renderOrders();
    if (!$('depositModal').classList.contains('hidden')) {
        // refresh the wallet numbers
        [...$('depFrom').children].forEach((b, i) => { b.lastChild.textContent = money(data.wallet[data.deposit.from[i]]); });
    }
}

function hideAll() {
    S.open = false;
    S.mode = null;
    stopTick();
    clearIntro();
    const app = $('app');
    app.classList.remove('on');
    setTimeout(() => { if (!S.open) app.classList.add('hidden'); }, 230);
    $('pickup').classList.add('hidden');
    $('depositModal').classList.add('hidden');
    drawer(null, false);
}

function close() {
    if (!S.open) return;
    hideAll();
    post('close');
}

// ---------------------------------------------------------------------------
// Pickup (garage vehicle / supply officer) and storing fleet vehicles
// ---------------------------------------------------------------------------
const PICKUP = {
    vehicle: { title: 'TAKE OUT VEHICLES', button: 'TAKE OUT' },
    items: { title: 'RECEIVE SUPPLIES', button: 'RECEIVE' },
    store: { title: 'STORE VEHICLES', button: 'STORE' },
};

function openPickup(data) {
    if (!data || !Array.isArray(data.list)) return;
    const kind = PICKUP[data.kind] ? data.kind : 'items';
    S.open = true;
    S.mode = 'pickup';
    S.pickup = { data, amounts: {}, picked: new Set() };
    $('app').classList.add('hidden');
    $('pShop').textContent = data.shop || '';
    $('pTitle').textContent = PICKUP[kind].title;
    if (kind === 'store') {
        data.list.forEach((x) => { if (!x.wrecked) S.pickup.picked.add(x.id); });
        renderStore();
    } else {
        $('btnPickup').textContent = PICKUP[kind].button;
        data.list.forEach((x) => { S.pickup.amounts[x.id] = kind === 'vehicle' ? Math.min(1, x.max) : x.max; });
        renderPickup();
    }
    $('pickup').classList.remove('hidden');
}

// fleet vehicles parked around the supply officer: tap to select, store
function renderStore() {
    const { data, picked } = S.pickup;
    const list = $('pList');
    list.textContent = '';
    data.list.forEach((x) => {
        const cond = Math.max(0, Math.min(100, Number(x.condition) || 0));
        const line = el('div', 'line pick' + (x.wrecked ? ' wrecked' : '') + (picked.has(x.id) ? ' on' : ''));
        const th = el('div', 'thumb');
        th.appendChild(image(x.image, x.fallback, x.category || 'armored'));
        const info = el('div', 'info');
        info.appendChild(el('b', '', x.label));
        info.appendChild(el('small', '', `${x.plate || '—'} · ${x.dist}M AWAY · ${x.wrecked ? 'DESTROYED' : cond + '%'}`));
        const bar = el('div', 'cond ' + (cond < 35 ? 'bad' : cond < 70 ? 'mid' : ''));
        const fill = el('i');
        fill.style.transform = `scaleX(${(cond / 100).toFixed(3)})`;
        bar.appendChild(fill);
        info.appendChild(bar);
        line.append(th, info, x.wrecked ? el('span', 'flag', 'WRECKED') : el('span', 'check'));
        if (!x.wrecked) {
            line.onclick = () => {
                if (picked.has(x.id)) picked.delete(x.id); else picked.add(x.id);
                renderStore();
            };
        }
        list.appendChild(line);
    });
    if (!data.list.length) list.appendChild(el('div', 'd-empty', `NO VEHICLES TO STORE WITHIN ${data.radius || 0}M OF THE OFFICER`));
    let note = '';
    if (!data.list.length) note = 'PARK THE VEHICLE NEXT TO THE SUPPLY OFFICER, THEN TRY AGAIN';
    else if (!picked.size) note = data.list.every((x) => x.wrecked) ? 'WRECKED VEHICLES CANNOT BE STORED' : 'SELECT THE VEHICLES TO STORE';
    $('pNote').textContent = note;
    $('btnPickup').textContent = picked.size ? `STORE (${picked.size})` : 'STORE';
    $('btnPickup').disabled = !picked.size;
}

function renderPickup() {
    const { data, amounts } = S.pickup;
    const list = $('pList');
    list.textContent = '';
    let any = false;
    data.list.forEach((x) => {
        const line = el('div', 'line');
        const th = el('div', 'thumb');
        th.appendChild(image(x.image, x.fallback, x.category || (data.kind === 'vehicle' ? 'armored' : 'items')));
        const info = el('div', 'info');
        info.appendChild(el('b', '', x.label));
        info.appendChild(el('small', '', data.kind === 'vehicle' ? `${x.amount} IN GARAGE · ${x.out || 0} OUT` : `${x.amount} AT THE DEPOT`));
        const n = amounts[x.id] || 0;
        if (n > 0) any = true;
        line.append(th, info, stepper(n, (d) => {
            amounts[x.id] = Math.max(0, Math.min(x.max, (amounts[x.id] || 0) + d));
            renderPickup();
        }, x.max));
        list.appendChild(line);
    });
    let note = '';
    if (data.kind === 'vehicle') {
        const x = data.list[0];
        if (!x || x.amount < 1) note = 'ALL UNITS ARE OUT — STORE ONE AT THE SUPPLY OFFICER';
        else if (x.max < 1) note = 'ALL PADS ARE BUSY — CLEAR ONE FIRST';
        else note = `FREE PADS: ${x.max} (ONE VEHICLE PER PAD)`;
    }
    $('pNote').textContent = note;
    $('btnPickup').disabled = !any;
}

async function confirmPickup() {
    const btn = $('btnPickup');
    btn.disabled = true;
    let body;
    if (S.pickup.data.kind === 'store') {
        body = { ids: [...S.pickup.picked] };
    } else {
        const amounts = {};
        Object.entries(S.pickup.amounts).forEach(([id, n]) => { if (n > 0) amounts[id] = n; });
        body = { amounts };
    }
    const res = await post('pickupConfirm', body);
    if (res && res.ok) {
        hideAll();
        post('close');
    } else {
        $('pNote').textContent = (res && res.msg) || 'FAILED';
        btn.disabled = false;
    }
}

// ---------------------------------------------------------------------------
// Vehicle photos (/logisticsphotos): four lossless studio shots per vehicle —
// with (a1, a2) and without (b1, b2) it, over two backdrops of different
// colour. Triangulation matting: a pixel C = α·F + (1-α)·B on both backdrops,
// so α comes from how much it changed between them and F from what is left
// once the backdrop share is removed. Edges, glass and rotor blur get their
// real transparency and none of the backdrop colour. Then every vehicle is
// framed the same way in a 640×360 transparent WebP.
// ---------------------------------------------------------------------------
function loadImage(src) {
    return new Promise((resolve, reject) => {
        const im = new Image();
        im.onload = () => resolve(im);
        im.onerror = reject;
        im.src = src;
    });
}

// per-channel gain: how much brighter shot `a` came out than shot `b` (auto exposure),
// from the outer ring of the frame. Median of the ratios, so a vehicle reaching the
// edge doesn't skew it.
function ringGain(a, b, w, h) {
    const ring = Math.max(4, Math.round(Math.min(w, h) * 0.03));
    const r = [[], [], []];
    for (let y = 0; y < h; y += 3) {
        const edgeRow = y < ring || y >= h - ring;
        for (let x = 0; x < w; x += 3) {
            if (!edgeRow && x >= ring && x < w - ring) { x = w - ring - 1; continue; }
            const i = (y * w + x) * 4;
            for (let c = 0; c < 3; c++) if (b[i + c] > 12) r[c].push(a[i + c] / b[i + c]);
        }
    }
    return r.map((v) => {
        if (v.length < 50) return 1;
        v.sort((x, y) => x - y);
        return Math.min(1.4, Math.max(0.7, v[v.length >> 1]));
    });
}

function matte(a1, a2, b1, b2, n, k1, k2, g) {
    const alpha = new Float32Array(n);
    const color = new Float32Array(n * 3);
    const clash = new Uint8Array(n); // the two shots disagree here (edge moved a pixel between them)
    const q0 = k2[0] * g[0], q1 = k2[1] * g[1], q2 = k2[2] * g[2];
    for (let p = 0, i = 0; p < n; p++, i += 4) {
        // the two backdrops at this pixel (exposure-matched to shot 1)
        const B10 = b1[i] * k1[0], B11 = b1[i + 1] * k1[1], B12 = b1[i + 2] * k1[2];
        const B20 = b2[i] * q0, B21 = b2[i + 1] * q1, B22 = b2[i + 2] * q2;
        const A20 = a2[i] * g[0], A21 = a2[i + 1] * g[1], A22 = a2[i + 2] * g[2];
        const D0 = B10 - B20, D1 = B11 - B21, D2 = B12 - B22;
        const dd = D0 * D0 + D1 * D1 + D2 * D2;
        let al;
        if (dd > 900) {
            al = 1 - ((a1[i] - A20) * D0 + (a1[i + 1] - A21) * D1 + (a1[i + 2] - A22) * D2) / dd;
        } else { // backdrops look the same here (shouldn't happen): "changed or not"
            al = Math.max(Math.abs(a1[i] - B10), Math.abs(a1[i + 1] - B11), Math.abs(a1[i + 2] - B12)) > 24 ? 1 : 0;
        }
        al = al < 0.04 ? 0 : al > 0.96 ? 1 : al;
        alpha[p] = al;
        if (al > 0) {
            const inv = 1 - al, k = 1 / (2 * al), j = p * 3;
            // foreground from each backdrop; they should agree
            const p0 = a1[i] - inv * B10, r0 = A20 - inv * B20;
            const p1 = a1[i + 1] - inv * B11, r1 = A21 - inv * B21;
            const p2 = a1[i + 2] - inv * B12, r2 = A22 - inv * B22;
            if (Math.max(Math.abs(p0 - r0), Math.abs(p1 - r1), Math.abs(p2 - r2)) > 40 * al) clash[p] = 1;
            let f = (p0 + r0) * k;
            color[j] = f < 0 ? 0 : f > 255 ? 255 : f;
            f = (p1 + r1) * k;
            color[j + 1] = f < 0 ? 0 : f > 255 ? 255 : f;
            f = (p2 + r2) * k;
            color[j + 2] = f < 0 ? 0 : f > 255 ? 255 : f;
        }
    }
    return { alpha, color, clash };
}

async function processPhoto(msg) {
    try {
        const imgs = await Promise.all([msg.a1, msg.a2, msg.b1, msg.b2].map(loadImage));
        const k = Math.min(1, 1080 / imgs[0].height);
        const w = Math.round(imgs[0].width * k), h = Math.round(imgs[0].height * k);
        const c = document.createElement('canvas');
        c.width = w; c.height = h;
        const ctx = c.getContext('2d', { willReadFrequently: true });
        const px = imgs.map((im) => { ctx.clearRect(0, 0, w, h); ctx.drawImage(im, 0, 0, w, h); return ctx.getImageData(0, 0, w, h).data; });
        const [a1, a2, b1, b2] = px;
        const n = w * h;

        // exposure: each "with" shot vs. its empty backdrop (from the edges of the frame)
        const k1 = ringGain(a1, b1, w, h), k2 = ringGain(a2, b2, w, h);
        // and shot 2 vs. shot 1 on the vehicle itself (solid pixels from a first pass)
        let g = [1, 1, 1];
        let m = matte(a1, a2, b1, b2, n, k1, k2, g);
        const s1 = [0, 0, 0], s2 = [0, 0, 0];
        for (let p = 0, i = 0; p < n; p++, i += 4) {
            if (m.alpha[p] < 0.9) continue;
            for (let ch = 0; ch < 3; ch++) { s1[ch] += a1[i + ch]; s2[ch] += a2[i + ch]; }
        }
        g = s1.map((v, ch) => (s2[ch] > 5000 ? Math.min(1.25, Math.max(0.8, v / s2[ch])) : 1));
        if (g.some((v) => Math.abs(v - 1) > 0.004)) m = matte(a1, a2, b1, b2, n, k1, k2, g);
        const { alpha, color, clash } = m;

        // the vehicle's box: rows / columns with enough visible pixels (ignores specks;
        // see-through parts like glass or a rotor disc count too)
        const cols = new Uint32Array(w), rows = new Uint32Array(h);
        for (let p = 0; p < n; p++) if (alpha[p] > 0.1) { cols[p % w]++; rows[(p / w) | 0]++; }
        const minC = Math.max(3, h * 0.006), minR = Math.max(3, w * 0.006);
        let x0 = 0, x1 = w - 1, y0 = 0, y1 = h - 1;
        while (x0 < w && cols[x0] < minC) x0++;
        while (x1 > x0 && cols[x1] < minC) x1--;
        while (y0 < h && rows[y0] < minR) y0++;
        while (y1 > y0 && rows[y1] < minR) y1--;
        if (x1 - x0 < 20 || y1 - y0 < 10) throw new Error('empty');
        const pad = Math.round(Math.max(w, h) * 0.004); // keep soft edges just outside the box
        x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad);
        x1 = Math.min(w - 1, x1 + pad); y1 = Math.min(h - 1, y1 + pad);

        // brightness: lift the vehicle's mid-tones to the same level for every vehicle
        // (a dark helicopter in shade and a sand-coloured tank end up equally readable);
        // a gamma curve, so highlights don't blow out
        const opts = msg.opts || {};
        const lut = new Uint8ClampedArray(256);
        for (let v = 0; v < 256; v++) lut[v] = v;
        if (opts.brightness > 0) {
            const hist = new Uint32Array(256);
            let total = 0;
            for (let p = 0; p < n; p++) {
                if (alpha[p] < 0.9) continue;
                const j = p * 3;
                hist[Math.round(0.2126 * color[j] + 0.7152 * color[j + 1] + 0.0722 * color[j + 2]) | 0]++;
                total++;
            }
            let acc = 0, med = 128;
            for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= total / 2) { med = v; break; } }
            const m = Math.min(0.95, Math.max(0.03, med / 255));
            const e = Math.min(1.1, Math.max(0.5, Math.log(opts.brightness) / Math.log(m))); // lift dark ones, barely touch bright ones
            for (let v = 0; v < 256; v++) lut[v] = Math.round(255 * Math.pow(v / 255, e));
        }

        const out = ctx.createImageData(w, h);
        const o = out.data;
        for (let y = y0; y <= y1; y++) {
            for (let x = x0; x <= x1; x++) {
                const p = y * w + x, i = p * 4;
                const al = alpha[p];
                if (al === 0) continue;
                let r = color[p * 3], gr = color[p * 3 + 1], b = color[p * 3 + 2];
                if (al < 0.3 || clash[p]) {
                    // faint pixels (soft edges, rotor blur) and pixels where the shots disagree:
                    // an α error there shows up as a backdrop tint, so take green / magenta excess out
                    const mx = Math.max(r, b), mn = Math.min(r, b);
                    if (gr > mx) gr = mx;
                    else if (mn > gr) { r -= mn - gr; b -= mn - gr; }
                }
                o[i] = lut[r | 0]; o[i + 1] = lut[gr | 0]; o[i + 2] = lut[b | 0];
                o[i + 3] = Math.round(al * 255);
            }
        }
        ctx.putImageData(out, 0, 0);

        // framing: the vehicle's box fills the picture (same margins for every vehicle)
        const W = Math.min(1600, Math.max(320, opts.width | 0 || 1024)), H = Math.round(W * 9 / 16), M = 0.035;
        const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
        const sc = Math.min(W * (1 - 2 * M) / bw, H * (1 - 2 * M) / bh);
        // shrink in halves first: a clean, anti-aliased downscale
        let src = c, sx = x0, sy = y0, sw = bw, sh = bh;
        const targetW = bw * sc;
        while (targetW < sw / 2) {
            const t = document.createElement('canvas');
            t.width = Math.round(sw / 2); t.height = Math.round(sh / 2);
            const tc = t.getContext('2d');
            tc.imageSmoothingQuality = 'high';
            tc.drawImage(src, sx, sy, sw, sh, 0, 0, t.width, t.height);
            src = t; sx = 0; sy = 0; sw = t.width; sh = t.height;
        }
        const fit = Math.min(W * (1 - 2 * M) / sw, H * (1 - 2 * M) / sh);
        const oc = document.createElement('canvas');
        oc.width = W; oc.height = H;
        const octx = oc.getContext('2d', { willReadFrequently: true });
        octx.imageSmoothingQuality = 'high';
        octx.drawImage(src, sx, sy, sw, sh, (W - sw * fit) / 2, (H - sh * fit) / 2, sw * fit, sh * fit);

        // light unsharp mask (inside the vehicle only, so the edges don't get halos)
        const amt = Math.min(1, Math.max(0, Number(opts.sharpen) || 0));
        if (amt > 0) {
            const im = octx.getImageData(0, 0, W, H);
            const d = im.data, src2 = new Uint8ClampedArray(d);
            for (let y = 1; y < H - 1; y++) {
                for (let x = 1; x < W - 1; x++) {
                    const i = (y * W + x) * 4;
                    if (src2[i + 3] < 250) continue;
                    for (let ch = 0; ch < 3; ch++) {
                        let sum = 0, cnt = 0;
                        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
                            const j = ((y + dy) * W + x + dx) * 4;
                            if (src2[j + 3] < 250) continue;
                            sum += src2[j + ch]; cnt++;
                        }
                        const v = src2[i + ch];
                        d[i + ch] = v + amt * (v - sum / cnt);
                    }
                }
            }
            octx.putImageData(im, 0, 0);
        }
        post('photoResult', { id: msg.id, image: oc.toDataURL('image/webp', 0.95) });
    } catch (e) {
        post('photoResult', { id: msg.id, image: null });
    }
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------
window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'open': return openShop(m);
        case 'update': return update(m.data);
        case 'pickup': return openPickup(m.data);
        case 'hide': return hideAll();
        case 'photoProcess': return processPhoto(m);
    }
});

$('btnClose').onclick = close;
$('btnCart').onclick = () => drawer('cart', !$('cart').classList.contains('open'));
$('btnOrders').onclick = () => drawer('orders', !$('orders').classList.contains('open'));
$('btnCheckout').onclick = checkout;
$('btnDeposit').onclick = openDeposit;
$('btnDepConfirm').onclick = confirmDeposit;
$('btnPickup').onclick = confirmPickup;
$('depAmount').addEventListener('input', (e) => {
    const v = e.target.value.replace(/\D/g, '').slice(0, 12);
    e.target.value = v ? Number(v).toLocaleString('en-US') : '';
});
document.addEventListener('click', (e) => {
    const c = e.target.closest('[data-close]');
    if (!c) return;
    const what = c.dataset.close;
    if (what === 'deposit') $('depositModal').classList.add('hidden');
    else if (what === 'pickup') close();
    else drawer(what, false);
});
document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !$('depositModal').classList.contains('hidden')) confirmDeposit();
});
document.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape' || !S.open) return;
    if (!$('depositModal').classList.contains('hidden')) return $('depositModal').classList.add('hidden');
    if ($('cart').classList.contains('open') || $('orders').classList.contains('open')) return drawer(null, false);
    close();
});
