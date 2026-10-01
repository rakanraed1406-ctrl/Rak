(() => {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-inventory';
    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

    const app = $('#app');
    const grids = { player: $('#grid-player'), other: $('#grid-other') };
    const tooltip = $('#tooltip');
    const ctx = $('#ctx');
    const ghost = $('#ghost');
    const amountInput = $('#amount');
    const modalLayer = $('#modal-layer');

    const S = {
        open: false,
        strings: {},
        special: 41,
        drops: true,
        dropSlots: 30,
        dropMaxWeight: 100000,
        player: { key: 'player', name: 'player', type: 'player', items: {}, slots: 41, maxweight: 0 },
        other: null,
        selected: null,
        filter: 'all',
        search: '',
        robTarget: null,
        modal: null,
    };

    // ════════════════════════════ Helpers ════════════════════════════

    function post(name, data = {}) {
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        })
            .then((response) => response.json().catch(() => null))
            .catch(() => null);
    }

    const t = (key) => S.strings[key] || key;

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined && text !== null) node.textContent = String(text);
        return node;
    }

    function icon(name) {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('class', 'ic');
        const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
        use.setAttribute('href', `#i-${name}`);
        svg.appendChild(use);
        return svg;
    }

    function setText(node, text) {
        text = text === undefined || text === null ? '' : String(text);
        if (node && node.textContent !== text) node.textContent = text;
    }

    /** Items arrive as arrays (slot 1 at index 0) or as objects keyed by slot: always rebuild by item.slot */
    function toMap(items) {
        const map = {};
        const list = Array.isArray(items) ? items : items && typeof items === 'object' ? Object.values(items) : [];
        for (const item of list) {
            if (item && typeof item === 'object' && item.name && Number(item.slot) > 0) {
                map[Number(item.slot)] = item;
            }
        }
        return map;
    }

    const info = (item) => (item && item.info && typeof item.info === 'object' ? item.info : {});
    const isWeapon = (item) => item.type === 'weapon' || String(item.name).startsWith('weapon_');
    const stackable = (item) => !item.unique && !isWeapon(item);

    function imageSrc(image) {
        const value = String(image || '');
        if (/^https?:\/\//i.test(value)) return value;
        return `images/${value.replace(/^\/+/, '')}`;
    }

    function weightOf(items) {
        let total = 0;
        for (const slot in items) total += (Number(items[slot].weight) || 0) * (Number(items[slot].amount) || 0);
        return total;
    }

    const kg = (grams) => (grams / 1000).toFixed(2);
    const money = (value) => '$' + Math.floor(Number(value) || 0).toLocaleString('en-US');

    function invType(name) {
        if (name === 'player' || name === 'hotbar') return 'player';
        if (name === 0 || name === '0' || name === 'ground') return 'ground';
        if (typeof name === 'number' || /^\d+$/.test(String(name))) return 'drop';
        const value = String(name);
        if (value === 'none-inv') return 'none';
        if (value === 'crafting' || value === 'attachment_crafting') return 'crafting';
        const kind = value.split('-')[0];
        return { itemshop: 'shop', trunk: 'trunk', glovebox: 'glovebox', stash: 'stash', otherplayer: 'otherplayer', traphouse: 'traphouse' }[kind] || 'stash';
    }

    const inv = (key) => (key === 'player' ? S.player : S.other);
    const readOnlyTarget = (type) => type === 'shop' || type === 'crafting' || type === 'none';

    function quality(item) {
        const q = info(item).quality;
        return q === undefined || q === null || isNaN(Number(q)) ? null : Math.max(0, Math.min(100, Number(q)));
    }

    function sound(ok) {
        post(ok ? 'PlayDropSound' : 'PlayDropFail');
    }

    // ════════════════════════════ Strings ════════════════════════════

    function applyStrings() {
        $$('[data-t]').forEach((node) => setText(node, t(node.dataset.t)));
        $$('[data-t-ph]').forEach((node) => node.setAttribute('placeholder', t(node.dataset.tPh)));
        $$('[data-t-title]').forEach((node) => node.setAttribute('title', t(node.dataset.tTitle)));
    }

    // ════════════════════════════ Slots ════════════════════════════

    function buildGrid(key) {
        const grid = grids[key];
        const data = inv(key);
        const fragment = document.createDocumentFragment();
        grid.textContent = '';
        const count = data ? Math.max(0, Number(data.slots) || 0) : 0;
        for (let i = 1; i <= count; i++) {
            const slot = el('div', 'slot');
            slot.dataset.slot = i;
            slot.style.setProperty('--r', Math.min(Math.floor((i - 1) / 5), 8));
            if (key === 'player' && (i <= 5 || i === S.special)) slot.classList.add('hotkey');
            fragment.appendChild(slot);
        }
        grid.appendChild(fragment);
        paintGrid(key);
    }

    function hotkeyFor(key, slot) {
        if (key !== 'player') return null;
        if (slot <= 5) return slot;
        if (slot === S.special) return 6;
        return null;
    }

    function fillSlot(slotEl, item, opts = {}) {
        const q = item ? quality(item) : null;
        const signature = item ? `${item.name}|${item.amount}|${q}|${item.price}|${item.image}|${item.label}` : '';
        if (slotEl._sig === signature && slotEl._key === opts.key) return;
        slotEl._sig = signature;
        slotEl._key = opts.key;
        slotEl.textContent = '';
        slotEl.classList.toggle('filled', !!item);
        slotEl.classList.toggle('broken', q === 0);

        if (opts.key) slotEl.appendChild(el('span', 'slot-key', opts.key));
        if (!item) return;

        const img = el('img', 'slot-img');
        img.loading = 'lazy';
        img.decoding = 'async';
        img.draggable = false;
        img.alt = '';
        img.onerror = () => (img.style.visibility = 'hidden');
        img.src = imageSrc(item.image);
        slotEl.appendChild(img);

        if (item.price !== undefined && item.price !== null && !opts.key) {
            slotEl.appendChild(el('span', 'slot-price', money(item.price)));
        }
        if (Number(item.amount) > 1 || item.price !== undefined) {
            slotEl.appendChild(el('span', 'slot-amount', `${item.amount}x`));
        }
        slotEl.appendChild(el('span', 'slot-label', item.label || item.name));
        if (q !== null) {
            const bar = el('span', `quality-bar${q < 25 ? ' low' : q < 50 ? ' mid' : ''}`);
            const fill = el('i');
            fill.style.setProperty('--q', `${q}%`);
            bar.appendChild(fill);
            slotEl.appendChild(bar);
        }
    }

    function paintGrid(key) {
        const data = inv(key);
        if (!data) return;
        for (const slotEl of grids[key].children) {
            const slot = Number(slotEl.dataset.slot);
            fillSlot(slotEl, data.items[slot], { key: hotkeyFor(key, slot) });
        }
        applyFilter();
    }

    function slotEl(key, slot) {
        return grids[key].querySelector(`.slot[data-slot="${slot}"]`);
    }

    function flash(key, slot, className) {
        const node = slotEl(key, slot);
        if (!node) return;
        node.classList.remove(className);
        void node.offsetWidth;
        node.classList.add(className);
        setTimeout(() => node.classList.remove(className), 400);
    }

    // ════════════════════════════ Weights / headers ════════════════════════════

    function paintWeight(prefix, data) {
        const weight = weightOf(data.items);
        const max = Number(data.maxweight) || 0;
        setText($(`#${prefix}-weight`), kg(weight));
        setText($(`#${prefix}-maxweight`), `/ ${kg(max)} kg`);
        const ratio = max > 0 ? Math.min(1, weight / max) : 0;
        const bar = $(`#${prefix}-weight-bar`);
        bar.style.setProperty('--w', ratio.toFixed(3));
        bar.parentElement.classList.toggle('warn', ratio >= 0.8 && ratio < 0.95);
        bar.parentElement.classList.toggle('full', ratio >= 0.95);
    }

    const OTHER_ICONS = { ground: 'ground', drop: 'ground', trunk: 'car', glovebox: 'glove', stash: 'archive', shop: 'cart', crafting: 'hammer', otherplayer: 'user', traphouse: 'archive', none: 'lock' };

    function paintOtherHeader() {
        const panel = $('#panel-other');
        const other = S.other;
        panel.hidden = !other;
        if (!other) return;

        const type = other.type;
        const label = String(other.label || '');
        const afterDash = label.includes('-') ? label.slice(label.indexOf('-') + 1) : '';
        let title = label;
        let sub = '';
        if (type === 'ground') { title = t('ground'); }
        else if (type === 'drop') { title = t('drop'); sub = `#${other.name}`; }
        else if (type === 'trunk') { title = t('trunk'); sub = afterDash; }
        else if (type === 'glovebox') { title = t('glovebox'); sub = afterDash; }
        else if (type === 'stash') { title = t('stash'); sub = afterDash; }
        else if (type === 'otherplayer') { title = t('player'); sub = `ID ${afterDash}`; }
        else if (type === 'shop') { sub = t('shop'); }
        else if (type === 'crafting') { sub = t('crafting'); }
        else if (type === 'none') { title = label.split('-')[0] || t('stash'); }

        setText($('#other-title'), title);
        setText($('#other-sub'), sub);
        const iconEl = $('#other-icon');
        iconEl.textContent = '';
        iconEl.appendChild(icon(OTHER_ICONS[type] || 'archive'));

        const showWeight = type !== 'shop' && type !== 'crafting' && type !== 'none';
        $('#other-weight-wrap').hidden = !showWeight;
        $('#other-weight-bar-wrap').hidden = !showWeight;
        $('#other-empty').hidden = type !== 'none';
        grids.other.hidden = type === 'none';
        panel.classList.toggle('is-ground', type === 'ground' || type === 'drop');
        if (showWeight) paintWeight('other', other);
    }

    function paintAll() {
        paintGrid('player');
        paintWeight('player', S.player);
        if (S.other) {
            paintGrid('other');
            paintOtherHeader();
        }
    }

    // ════════════════════════════ Filters ════════════════════════════

    const FOOD = /(water|sandwich|burger|cola|coffee|food|drink|bread|tosti|beer|whiskey|vodka|wine|candy|donut|pizza|chips|snack|juice|soda|milk|kurkakola|twerks|apple|banana|meat|taco)/;
    const TOOLS = /(lockpick|drill|screwdriver|repair|kit|wrench|hammer|tool|crowbar|radio|phone|binocular|cutter|jack|tablet|laptop|hack)/;

    function category(item) {
        const name = String(item.name).toLowerCase();
        if (isWeapon(item) || /ammo|_clip|suppressor|flashlight|scope|grip|^mag_|^body_/.test(name)) return 'weapons';
        if (item.category === 'food' || FOOD.test(name)) return 'food';
        if (item.category === 'tools' || TOOLS.test(name)) return 'tools';
        return 'general';
    }

    function applyFilter() {
        const search = S.search;
        for (const key of ['player', 'other']) {
            const data = inv(key);
            if (!data) continue;
            for (const node of grids[key].children) {
                const item = data.items[Number(node.dataset.slot)];
                let dim = false;
                if (item) {
                    if (key === 'player' && S.filter !== 'all' && category(item) !== S.filter) dim = true;
                    if (search && !`${item.label || ''} ${item.name}`.toLowerCase().includes(search)) dim = true;
                } else if (search || (key === 'player' && S.filter !== 'all')) {
                    dim = false;
                }
                node.classList.toggle('dimmed', dim);
            }
        }
    }

    $('#filters').addEventListener('click', (event) => {
        const chip = event.target.closest('.chip');
        if (!chip) return;
        S.filter = chip.dataset.filter === S.filter ? 'all' : chip.dataset.filter;
        $$('.chip').forEach((c) => c.classList.toggle('active', c.dataset.filter === S.filter));
        applyFilter();
    });

    $('#search').addEventListener('input', (event) => {
        S.search = event.target.value.trim().toLowerCase();
        applyFilter();
    });

    // ════════════════════════════ Amount ════════════════════════════

    function readAmount(item, fallbackOne) {
        const value = Math.floor(Number(amountInput.value) || 0);
        if (value <= 0) return fallbackOne ? 1 : Number(item.amount);
        return Math.min(value, Number(item.amount) || value);
    }

    $$('.amount-btn').forEach((button) => {
        button.addEventListener('click', () => {
            const next = Math.max(0, (Math.floor(Number(amountInput.value) || 0)) + Number(button.dataset.step));
            amountInput.value = next === 0 ? '' : next;
        });
    });

    amountInput.addEventListener('input', () => {
        if (Number(amountInput.value) < 0) amountInput.value = '';
    });

    // ════════════════════════════ Moving items ════════════════════════════

    function firstTargetSlot(target, item) {
        if (stackable(item)) {
            for (const slot in target.items) {
                if (target.items[slot].name === item.name) return Number(slot);
            }
        }
        for (let i = 1; i <= target.slots; i++) {
            if (!target.items[i]) return i;
        }
        return null;
    }

    function fail(key, slot) {
        flash(key, slot, 'error');
        sound(false);
    }

    function nameFor(key) {
        const data = inv(key);
        if (key === 'player') return 'player';
        if (data.type === 'ground') return 0;
        return data.name;
    }

    function canDrop(fromKey, fromSlot, toKey, toSlot) {
        const from = inv(fromKey);
        const to = inv(toKey);
        if (!from || !to) return false;
        if (fromKey === toKey && fromSlot === toSlot) return false;
        if (readOnlyTarget(to.type)) return false;
        if ((from.type === 'shop' || from.type === 'crafting') && to.type !== 'player') return false;
        if (toSlot > to.slots) return false;
        if (to.type === 'ground' && !S.drops) return false;
        return true;
    }

    function moveItem(fromKey, fromSlot, toKey, toSlot, forcedAmount) {
        const from = inv(fromKey);
        const to = inv(toKey);
        const item = from && from.items[fromSlot];
        if (!item) return;
        if (!canDrop(fromKey, fromSlot, toKey, toSlot)) return fail(fromKey, fromSlot);

        const buying = from.type === 'shop' || from.type === 'crafting';
        let amount = forcedAmount || readAmount(item, buying);
        if (amount < 1) return fail(fromKey, fromSlot);

        // Shops and crafting: the server decides, the refresh shows the result
        if (buying) {
            if (to.items[toSlot] && to.items[toSlot].name !== item.name) return fail(toKey, toSlot);
            post('SetInventoryData', { fromInventory: nameFor(fromKey), toInventory: 'player', fromSlot, toSlot, fromAmount: amount });
            flash(toKey, toSlot, 'pop');
            sound(true);
            return;
        }

        const target = to.items[toSlot];
        const stack = target && target.name === item.name && stackable(item);
        const swap = target && !stack;

        if (swap && amount < Number(item.amount)) return fail(fromKey, fromSlot);

        // Combining two items (player inventory only)
        if (swap && fromKey === 'player' && toKey === 'player' && target.combinable && Array.isArray(target.combinable.accept) && target.combinable.accept.includes(item.name)) {
            return openCombine(fromSlot, toSlot);
        }

        // Weight
        if (fromKey !== toKey) {
            const moving = (Number(item.weight) || 0) * amount;
            const back = swap ? (Number(target.weight) || 0) * Number(target.amount) : 0;
            const toMax = Number(to.maxweight) || 0;
            const fromMax = Number(from.maxweight) || 0;
            if (toMax && weightOf(to.items) + moving - back > toMax) return fail(fromKey, fromSlot);
            if (fromMax && swap && weightOf(from.items) - moving + back > fromMax) return fail(fromKey, fromSlot);
        }

        // Optimistic update (the server refresh confirms it a moment later)
        const moved = Object.assign({}, item, { amount, slot: toSlot });
        if (stack) {
            target.amount = Number(target.amount) + amount;
        } else if (swap) {
            to.items[toSlot] = moved;
            from.items[fromSlot] = Object.assign({}, target, { slot: fromSlot });
        } else {
            to.items[toSlot] = moved;
        }
        if (!swap) {
            if (Number(item.amount) - amount > 0) item.amount = Number(item.amount) - amount;
            else delete from.items[fromSlot];
        }

        post('SetInventoryData', {
            fromInventory: nameFor(fromKey),
            toInventory: nameFor(toKey),
            fromSlot,
            toSlot,
            fromAmount: amount,
            toAmount: target ? Number(target.amount) : undefined,
        });

        clearSelection();
        paintAll();
        flash(toKey, toSlot, 'pop');
        sound(true);
    }

    function quickMove(fromKey, fromSlot) {
        const from = inv(fromKey);
        const item = from && from.items[fromSlot];
        const toKey = fromKey === 'player' ? 'other' : 'player';
        const to = inv(toKey);
        if (!item || !to || readOnlyTarget(to.type)) return fail(fromKey, fromSlot);
        const slot = firstTargetSlot(to, item);
        if (!slot) return fail(fromKey, fromSlot);
        moveItem(fromKey, fromSlot, toKey, slot);
    }

    function splitItem(slot) {
        const item = S.player.items[slot];
        if (!item || Number(item.amount) < 2 || !stackable(item)) return;
        let free = null;
        for (let i = 1; i <= S.player.slots; i++) {
            if (!S.player.items[i]) { free = i; break; }
        }
        if (!free) return fail('player', slot);
        moveItem('player', slot, 'player', free, Math.floor(Number(item.amount) / 2));
    }

    function useItem(slot) {
        const item = S.player.items[slot];
        if (!item) return;
        if (item.shouldClose !== false || isWeapon(item)) close();
        post('UseItem', { inventory: 'player', item });
    }

    // ════════════════════════════ Pointer: drag / click ════════════════════════════

    let drag = null;
    let hoverTarget = null;

    function slotFromEvent(target) {
        const node = target && target.closest ? target.closest('.slot') : null;
        if (!node || !node.parentElement || !node.parentElement.dataset.inv) return null;
        return { node, key: node.parentElement.dataset.inv, slot: Number(node.dataset.slot) };
    }

    function clearHover() {
        if (hoverTarget) hoverTarget.classList.remove('drop-ok', 'drop-bad');
        hoverTarget = null;
    }

    function startDrag(event) {
        drag.active = true;
        hideTooltip();
        hideCtx();
        const item = inv(drag.key).items[drag.slot];
        ghost.textContent = '';
        const img = el('img', 'slot-img');
        img.src = imageSrc(item.image);
        img.alt = '';
        ghost.appendChild(img);
        const buying = inv(drag.key).type === 'shop' || inv(drag.key).type === 'crafting';
        const amount = readAmount(item, buying);
        if (amount > 1) ghost.appendChild(el('span', 'slot-amount', `${amount}x`));
        ghost.hidden = false;
        drag.node.classList.add('drag-source');
        moveGhost(event);
    }

    function moveGhost(event) {
        const size = ghost.offsetWidth || 80;
        ghost.style.transform = `translate3d(${event.clientX - size / 2}px, ${event.clientY - size / 2}px, 0) scale(1.06)`;
    }

    function dropTargetAt(x, y) {
        const node = document.elementFromPoint(x, y);
        if (!node) return null;
        const zone = node.closest('[data-zone]');
        if (zone) return { zone: zone.dataset.zone, node: zone };
        const slot = slotFromEvent(node);
        return slot;
    }

    function endDrag(event) {
        const current = drag;
        drag = null;
        ghost.hidden = true;
        clearHover();
        if (!current) return;
        current.node.classList.remove('drag-source');
        if (!current.active) return;

        const target = dropTargetAt(event.clientX, event.clientY);
        if (!target) return;
        if (target.zone) {
            if (current.key !== 'player') return fail(current.key, current.slot);
            const item = S.player.items[current.slot];
            if (target.zone === 'use') useItem(current.slot);
            if (target.zone === 'give' && item) openGive(current.slot, readAmount(item, false));
            return;
        }
        moveItem(current.key, current.slot, target.key, target.slot);
    }

    document.addEventListener('pointerdown', (event) => {
        if (!S.open) return;
        if (!event.target.closest('#ctx')) hideCtx();
        if (event.button !== 0) return;
        const hit = slotFromEvent(event.target);
        if (!hit || !inv(hit.key) || !inv(hit.key).items[hit.slot]) return;
        drag = { ...hit, x: event.clientX, y: event.clientY, active: false, shift: event.shiftKey };
    });

    document.addEventListener('pointermove', (event) => {
        if (!S.open) return;
        if (drag) {
            if (!drag.active && Math.hypot(event.clientX - drag.x, event.clientY - drag.y) > 5) startDrag(event);
            if (drag && drag.active) {
                moveGhost(event);
                const target = dropTargetAt(event.clientX, event.clientY);
                const node = target ? target.node : null;
                if (node !== hoverTarget) {
                    clearHover();
                    if (node && node !== drag.node) {
                        const ok = target.zone ? drag.key === 'player' : canDrop(drag.key, drag.slot, target.key, target.slot);
                        node.classList.add(ok ? 'drop-ok' : 'drop-bad');
                        hoverTarget = node;
                    }
                }
            }
            return;
        }
        moveTooltip(event);
    });

    document.addEventListener('pointerup', (event) => {
        if (!drag) return;
        if (!drag.active) {
            const hit = drag;
            drag = null;
            if (hit.shift) return quickMove(hit.key, hit.slot);
            select(hit.key, hit.slot);
            return;
        }
        endDrag(event);
    });

    window.addEventListener('blur', () => {
        if (drag) endDrag({ clientX: -1, clientY: -1 });
    });

    function clearSelection() {
        S.selected = null;
        $$('.slot.selected').forEach((node) => node.classList.remove('selected'));
    }

    function select(key, slot) {
        $$('.slot.selected').forEach((node) => node.classList.remove('selected'));
        if (S.selected && S.selected.key === key && S.selected.slot === slot) {
            S.selected = null;
            return;
        }
        S.selected = { key, slot };
        const node = slotEl(key, slot);
        if (node) node.classList.add('selected');
    }

    for (const key of ['player', 'other']) {
        grids[key].addEventListener('dblclick', (event) => {
            const hit = slotFromEvent(event.target);
            if (!hit) return;
            if (hit.key === 'player') useItem(hit.slot);
            else quickMove(hit.key, hit.slot);
        });

        grids[key].addEventListener('contextmenu', (event) => {
            event.preventDefault();
            const hit = slotFromEvent(event.target);
            if (!hit || !inv(hit.key).items[hit.slot]) return hideCtx();
            if (event.shiftKey) return quickMove(hit.key, hit.slot);
            showCtx(hit.key, hit.slot, event.clientX, event.clientY);
        });

        grids[key].addEventListener('pointerover', (event) => {
            if (drag) return;
            const hit = slotFromEvent(event.target);
            if (!hit) return;
            const item = inv(hit.key) && inv(hit.key).items[hit.slot];
            if (item) showTooltip(item, inv(hit.key).type, event);
            else hideTooltip();
        });

        grids[key].addEventListener('pointerleave', hideTooltip);
    }

    $('#action-use').addEventListener('click', () => {
        if (S.selected && S.selected.key === 'player') useItem(S.selected.slot);
    });

    $('#action-give').addEventListener('click', () => {
        if (S.selected && S.selected.key === 'player') {
            const item = S.player.items[S.selected.slot];
            if (item) openGive(S.selected.slot, readAmount(item, false));
        }
    });

    document.addEventListener('contextmenu', (event) => event.preventDefault());

    // ════════════════════════════ Context menu ════════════════════════════

    function showCtx(key, slot, x, y) {
        hideTooltip();
        const item = inv(key).items[slot];
        const entries = [];
        if (key === 'player') {
            if (item.useable || isWeapon(item)) entries.push(['bolt', t('use'), () => useItem(slot)]);
            entries.push(['hand', t('give'), () => openGive(slot, readAmount(item, false))]);
            if (Number(item.amount) > 1 && stackable(item)) entries.push(['scissors', t('split'), () => splitItem(slot)]);
            if (isWeapon(item)) entries.push(['gun', t('attachments'), () => openWeapon(slot)]);
            if (S.other && (S.other.type === 'ground' || S.other.type === 'drop')) entries.push(['down', t('drop'), () => quickMove('player', slot)]);
            else if (S.other && !readOnlyTarget(S.other.type)) entries.push(['arrow', $('#other-title').textContent, () => quickMove('player', slot)]);
        } else {
            entries.push(['arrow', t('pockets'), () => quickMove(key, slot)]);
        }

        ctx.textContent = '';
        for (const [iconName, label, action] of entries) {
            const button = el('button');
            button.append(icon(iconName), el('span', null, label));
            button.addEventListener('click', () => {
                hideCtx();
                action();
            });
            ctx.appendChild(button);
        }
        ctx.hidden = false;
        const rect = ctx.getBoundingClientRect();
        const left = Math.min(x, innerWidth - rect.width - 8);
        const top = Math.min(y, innerHeight - rect.height - 8);
        ctx.style.transform = `translate(${left}px, ${top}px)`;
    }

    function hideCtx() {
        ctx.hidden = true;
    }

    // ════════════════════════════ Tooltip ════════════════════════════

    function rows(item) {
        const i = info(item);
        const r = [];
        const add = (label, value) => {
            if (value !== undefined && value !== null && value !== '') r.push([label, value]);
        };
        const name = item.name;

        if (isWeapon(item)) {
            add(t('serial'), i.serie);
            add(t('ammo'), i.ammo || 0);
            if (Array.isArray(i.attachments) && i.attachments.length) add(t('attachments'), i.attachments.map((a) => a.label).join(', '));
            return r;
        }
        switch (name) {
            case 'id_card':
                add('CSN', i.citizenid); add('First Name', i.firstname); add('Last Name', i.lastname);
                add('Birth Date', i.birthdate); add('Gender', i.gender === 1 ? 'Woman' : i.gender === undefined ? '' : 'Man'); add('Nationality', i.nationality);
                break;
            case 'driver_license':
                add('First Name', i.firstname); add('Last Name', i.lastname); add('Birth Date', i.birthdate); add('Licenses', i.type);
                break;
            case 'weaponlicense':
                add('First Name', i.firstname); add('Last Name', i.lastname); add('Birth Date', i.birthdate);
                break;
            case 'lawyerpass':
                add('First Name', i.firstname); add('Last Name', i.lastname); add('Pass ID', i.id);
                break;
            case 'filled_evidence_bag':
                add('Evidence', i.label);
                if (i.type === 'casing') { add('Type', i.ammotype); add('Caliber', i.ammolabel); add('Serial', i.serie); }
                if (i.type === 'blood') { add('Blood type', i.bloodtype); add('DNA', i.dnalabel); }
                if (i.type === 'fingerprint') add('Fingerprint', i.fingerprint);
                if (i.type === 'dna') add('DNA', i.dnalabel);
                add('Crime scene', i.street);
                break;
            case 'visa':
            case 'mastercard':
                add('Card Holder', i.name); add('Citizen ID', i.citizenid);
                if (i.cardNumber) add('Card Number', '**** ' + String(i.cardNumber).slice(-4));
                break;
            case 'moneybag':
                if (i.cash !== undefined) add('Cash', money(i.cash));
                break;
            case 'markedbills': case 'moneyroll': case 'treasuregoldcoins': case 'fakemoneybag': case 'bighousecas':
                if (i.worth !== undefined) add('Worth', money(i.worth));
                break;
            case 'moneybox':
                if (i.money !== undefined) add('Money', money(i.money));
                break;
            case 'harness': case 'ciggypack': case 'breaker': case 'lockpick':
                add('Uses left', i.uses);
                break;
            case 'labkey': add('Lab', i.lab); break;
            case 'hacking_device': add('Expires', i.explable); break;
            case 'backpack': case 'backpackgirl': add('Backpack ID', i.id); break;
            case 'plate': add('Plate', i.plate); break;
            case 'paperweed': add('Number', i.number); break;
            case 'syphoningkit': case 'jerrycan01':
                if (i.gasamount !== undefined) add('Fuel', `${i.gasamount} L`);
                break;
            case 'evidencebox':
                add('Case ID', i.caseid); add('Officer', i.officer); add('Date', i.date); add('Suspect', i.vecName); add('Suspect CID', i.vecCid);
                break;
            case 'case':
                add('Principal', i.name); add('Case', i.case); add('Evidence', i.evidence);
                break;
            case 'phone':
                add('Phone Number', i.lbFormattedNumber || i.lbPhoneNumber);
                break;
            case 'spray': add('Gang', i.gang); break;
            case 'dna-paper':
                add('Doctor CID', i.DoctorCitizenid); add('Citizen ID', i.citizenid); add('Weed', i.weed); add('Hemoglobin', i.hemoglobin);
                break;
            case 'mazebank_ticket': add('Price', i.price); break;
        }
        if (i.costs) add(t('costs'), i.costs);
        return r;
    }

    function showTooltip(item, type, event) {
        const i = info(item);
        tooltip.textContent = '';
        const title = item.name === 'phone' && i.lbPhoneName ? i.lbPhoneName : item.label || item.name;
        tooltip.appendChild(el('div', 'tip-title', title));
        tooltip.appendChild(el('div', 'tip-name', item.name));

        let description = item.description || '';
        if (item.name === 'stickynote' && i.label) description = i.label;
        if (description) tooltip.appendChild(el('div', 'tip-desc', description));

        const list = rows(item);
        if (list.length) {
            const box = el('div', 'tip-rows');
            for (const [label, value] of list) {
                const row = el('div', 'tip-row');
                row.append(el('span', null, label), el('b', null, value));
                box.appendChild(row);
            }
            tooltip.appendChild(box);
        }

        const foot = el('div', 'tip-foot');
        const weightSpan = el('span');
        weightSpan.append(icon('weight'), document.createTextNode(`${kg((Number(item.weight) || 0) * (Number(item.amount) || 1))} kg`));
        foot.appendChild(weightSpan);
        const q = quality(item);
        if (q !== null) {
            const qSpan = el('span');
            qSpan.append(icon('bolt'), document.createTextNode(q === 0 ? t('broken') : `${Math.floor(q)}%`));
            foot.appendChild(qSpan);
        }
        if (type === 'shop' && item.price !== undefined) {
            const pSpan = el('span');
            pSpan.append(icon('cash'), document.createTextNode(money(item.price)));
            foot.appendChild(pSpan);
        }
        tooltip.appendChild(foot);
        tooltip.hidden = false;
        moveTooltip(event);
    }

    let tipFrame = 0;
    function moveTooltip(event) {
        if (tooltip.hidden || tipFrame) return;
        const x = event.clientX;
        const y = event.clientY;
        tipFrame = requestAnimationFrame(() => {
            tipFrame = 0;
            const w = tooltip.offsetWidth;
            const h = tooltip.offsetHeight;
            let left = x + 18;
            let top = y + 14;
            if (left + w > innerWidth - 8) left = x - w - 18;
            if (top + h > innerHeight - 8) top = innerHeight - h - 8;
            tooltip.style.transform = `translate(${Math.max(8, left)}px, ${Math.max(8, top)}px)`;
        });
    }

    function hideTooltip() {
        tooltip.hidden = true;
    }

    // ════════════════════════════ Modals ════════════════════════════

    function openModal(id) {
        hideTooltip();
        hideCtx();
        $$('.modal').forEach((modal) => (modal.hidden = modal.id !== id));
        modalLayer.classList.add('show');
        S.modal = id;
    }

    function closeModal() {
        modalLayer.classList.remove('show');
        $$('.modal').forEach((modal) => (modal.hidden = true));
        S.modal = null;
    }

    $$('[data-close-modal]').forEach((button) => button.addEventListener('click', closeModal));
    modalLayer.addEventListener('pointerdown', (event) => {
        if (event.target === modalLayer) closeModal();
    });

    function initials(name) {
        return String(name || '?').trim().split(/\s+/).slice(0, 2).map((part) => Array.from(part)[0] || '').join('').toUpperCase() || '?';
    }

    function openGive(slot, amount) {
        const item = S.player.items[slot];
        if (!item) return;
        setText($('#give-item'), `${amount}x ${item.label || item.name}`);
        const list = $('#give-list');
        list.textContent = '';
        list.appendChild(el('div', 'list-empty', '...'));
        openModal('modal-give');

        post('GetNearbyPlayers').then((players) => {
            if (S.modal !== 'modal-give') return;
            list.textContent = '';
            const entries = Array.isArray(players) ? players : players && typeof players === 'object' ? Object.values(players) : [];
            if (!entries.length) {
                list.appendChild(el('div', 'list-empty', t('no_players')));
                return;
            }
            for (const player of entries) {
                const row = el('button', 'player-row');
                row.append(el('div', 'avatar', initials(player.name)), el('b', null, player.name), el('span', null, `ID ${player.id}`));
                row.addEventListener('click', () => {
                    post('GiveItemTo', { playerId: player.id, item: { name: item.name, slot: item.slot }, amount });
                    closeModal();
                });
                list.appendChild(row);
            }
        });
    }

    function openWeapon(slot) {
        const item = S.player.items[slot];
        if (!item) return;
        const i = info(item);
        setText($('#weapon-title'), item.label || item.name);
        setText($('#weapon-sub'), item.name);
        setText($('#weapon-serial'), i.serie || '—');
        setText($('#weapon-ammo'), i.ammo || 0);
        const q = quality(item) === null ? 100 : quality(item);
        setText($('#weapon-durability'), `${Math.floor(q)}%`);
        const bar = $('#weapon-durability-bar');
        bar.style.setProperty('--q', `${q}%`);
        bar.parentElement.className = `quality-bar big${q < 25 ? ' low' : q < 50 ? ' mid' : ''}`;
        const img = $('#weapon-img');
        img.onerror = () => {
            img.onerror = null;
            img.src = imageSrc(item.image);
        };
        img.src = `attachment_images/${item.name}.png`;
        renderAttachments([]);
        openModal('modal-weapon');

        post('GetWeaponData', { weapon: item.name, ItemData: item }).then((data) => {
            if (!data || S.modal !== 'modal-weapon') return;
            renderAttachments(data.AttachmentData, item);
        });
    }

    function renderAttachments(list, weapon) {
        const box = $('#weapon-attachments');
        box.textContent = '';
        const entries = Array.isArray(list) ? list : list && typeof list === 'object' ? Object.values(list) : [];
        if (!entries.length) {
            box.appendChild(el('div', 'list-empty', t('no_attachments')));
            return;
        }
        for (const attachment of entries) {
            const row = el('div', 'attachment');
            const img = el('img');
            img.alt = '';
            img.src = imageSrc(attachment.image || `${attachment.attachment}.png`);
            const remove = el('button', null, t('remove'));
            remove.addEventListener('click', () => {
                remove.disabled = true;
                post('RemoveAttachment', { AttachmentData: attachment, WeaponData: weapon }).then((data) => {
                    if (S.modal !== 'modal-weapon') return;
                    renderAttachments(data && data.Attachments ? data.Attachments : [], weapon);
                });
            });
            row.append(img, el('b', null, attachment.label || attachment.attachment), remove);
            box.appendChild(row);
        }
    }

    let combine = null;
    function openCombine(fromSlot, toSlot) {
        const from = S.player.items[fromSlot];
        const to = S.player.items[toSlot];
        combine = { fromSlot, toSlot, from, to };
        setText($('#combine-text'), `${from.label} + ${to.label}`);
        const preview = $('#combine-preview');
        preview.textContent = '';
        const a = el('div', 'slot');
        const b = el('div', 'slot');
        fillSlot(a, from, {});
        fillSlot(b, to, {});
        preview.append(a, icon('plus'), b);
        openModal('modal-combine');
    }

    $('#combine-go').addEventListener('click', () => {
        if (!combine) return;
        const recipe = combine.to.combinable;
        if (recipe.anim) {
            post('combineWithAnim', { combineData: recipe, usedItem: combine.to.name, requiredItem: combine.from.name });
        } else {
            post('combineItem', { reward: recipe.reward, toItem: combine.to.name, fromItem: combine.from.name });
        }
        closeModal();
        close();
    });

    $('#combine-swap').addEventListener('click', () => {
        if (!combine) return;
        const { fromSlot, toSlot } = combine;
        closeModal();
        const to = S.player.items[toSlot];
        const keep = to.combinable;
        to.combinable = null; // skip the prompt for this swap
        moveItem('player', fromSlot, 'player', toSlot, Number(S.player.items[fromSlot].amount));
        if (S.player.items[fromSlot]) S.player.items[fromSlot].combinable = keep;
    });

    // ════════════════════════════ Rob ════════════════════════════

    $('#rob-btn').addEventListener('click', () => {
        if (S.robTarget === null) return;
        post('RobMoney', { TargetId: S.robTarget });
        S.robTarget = null;
        $('#rob-btn').hidden = true;
    });

    // ════════════════════════════ Open / close / refresh ════════════════════════════

    let closeTimer = null;

    function setPlayerCard(data) {
        const name = `${data.firstname || ''} ${data.lastname || ''}`.trim();
        setText($('#avatar'), initials(name));
        setText($('#id-name'), name);
        setText($('#player-sub'), name);
        setText($('#id-sid'), data.pid);
        setText($('#id-cid'), data.citizenid || '');
        $('#id-cid-wrap').hidden = !data.citizenid;
        setText($('#id-cash'), money(data.cash));
        setText($('#id-job'), data.job || '');
        $('#id-job-wrap').hidden = !data.job;
    }

    function makeOther(other) {
        if (!other || typeof other !== 'object') {
            if (!S.drops) return null;
            return { key: 'other', name: 0, type: 'ground', label: t('ground'), items: {}, slots: S.dropSlots, maxweight: S.dropMaxWeight };
        }
        const type = invType(other.name);
        return {
            key: 'other',
            name: other.name,
            type,
            label: other.label,
            items: toMap(other.inventory),
            slots: type === 'none' ? 0 : Number(other.slots) || 0,
            maxweight: Number(other.maxweight) || 0,
        };
    }

    function open(data) {
        clearTimeout(closeTimer);
        app.classList.remove('closing');
        if (data.strings) {
            S.strings = data.strings;
            applyStrings();
        }
        S.special = Number(data.special) || 41;
        S.drops = data.drops !== false;
        S.dropSlots = Number(data.dropSlots) || 30;
        S.dropMaxWeight = Number(data.dropMaxWeight) || 100000;

        S.player.items = toMap(data.inventory);
        S.player.slots = Number(data.slots) || 41;
        S.player.maxweight = Number(data.maxweight) || 0;
        S.other = makeOther(data.other);
        S.selected = null;
        S.filter = 'all';
        S.search = '';
        $('#search').value = '';
        $$('.chip').forEach((chip) => chip.classList.toggle('active', chip.dataset.filter === 'all'));
        $('#rob-btn').hidden = true;
        S.robTarget = null;

        setPlayerCard(data);
        closeModal();
        hideCtx();
        hideTooltip();

        S.open = true;
        app.hidden = false;
        buildGrid('player');
        paintWeight('player', S.player);
        if (S.other) buildGrid('other');
        paintOtherHeader();
    }

    function close() {
        if (!S.open) return;
        S.open = false;
        drag = null;
        ghost.hidden = true;
        hideTooltip();
        hideCtx();
        closeModal();
        app.classList.add('closing');
        clearTimeout(closeTimer);
        closeTimer = setTimeout(() => {
            app.hidden = true;
            app.classList.remove('closing');
        }, 180);
        post('CloseInventory');
    }

    function refresh(data) {
        if (!S.open) return;
        if (data.inventory !== undefined && data.inventory !== null) S.player.items = toMap(data.inventory);
        if (data.cash !== undefined && data.cash !== null) setText($('#id-cash'), money(data.cash));
        if (data.otherName !== undefined && data.otherName !== null && S.other) {
            const type = invType(data.otherName);
            if (type !== S.other.type || String(data.otherName) !== String(S.other.name)) {
                S.other.name = data.otherName;
                S.other.type = type;
                if (type === 'drop') S.other.label = `Dropped-${data.otherName}`;
            }
            S.other.items = toMap(data.other);
        }
        if (data.error) sound(false);
        paintAll();
    }

    // ════════════════════════════ Notifications / hotbar / required ════════════════════════════

    function itemBox(data) {
        const item = data.item;
        if (!item) return;
        const stack = $('#itembox-stack');
        const box = el('div', 'itembox');
        const img = el('img');
        img.alt = '';
        img.src = imageSrc(item.image);
        img.onerror = () => (img.style.visibility = 'hidden');
        const text = el('div', 'itembox-text');
        text.appendChild(el('b', null, item.label || item.name));
        const amount = Number(data.itemAmount) || 1;
        let badge;
        if (data.type === 'add') badge = el('span', 'badge add', `${t('received')} ${amount}x`);
        else if (data.type === 'remove') badge = el('span', 'badge remove', `${t('removed')} ${amount}x`);
        else badge = el('span', 'badge', t('used'));
        text.appendChild(badge);
        box.append(img, text);
        stack.appendChild(box);
        while (stack.children.length > 5) stack.firstElementChild.remove();
        setTimeout(() => {
            box.classList.add('out');
            setTimeout(() => box.remove(), 300);
        }, 3000);
    }

    let hotbarTimer = null;
    function toggleHotbar(data) {
        const bar = $('#hotbar');
        clearTimeout(hotbarTimer);
        if (!data.open) {
            if (bar.hidden) return;
            bar.classList.add('out');
            hotbarTimer = setTimeout(() => {
                bar.hidden = true;
                bar.classList.remove('out');
            }, 200);
            return;
        }
        const special = Number(data.special) || S.special;
        const items = toMap(data.items);
        bar.textContent = '';
        [1, 2, 3, 4, 5, special].forEach((slot, index) => {
            const node = el('div', 'slot hotkey');
            fillSlot(node, items[slot], { key: index + 1 });
            bar.appendChild(node);
        });
        bar.classList.remove('out');
        bar.hidden = false;
    }

    function requiredItems(data) {
        const box = $('#required');
        if (!data.toggle) {
            box.hidden = true;
            box.textContent = '';
            return;
        }
        box.textContent = '';
        const list = Array.isArray(data.items) ? data.items : data.items ? Object.values(data.items) : [];
        for (const item of list) {
            const node = el('div', 'slot filled');
            const img = el('img', 'slot-img');
            img.alt = '';
            img.src = imageSrc(item.image);
            node.append(el('span', 'slot-amount', t('required')), img, el('span', 'slot-label', item.label || item.item));
            box.appendChild(node);
        }
        box.hidden = !list.length;
    }

    // ════════════════════════════ Keyboard ════════════════════════════

    document.addEventListener('keydown', (event) => {
        if (!S.open || event.repeat) return;
        if (event.key === 'Escape' || event.key === 'Tab') {
            event.preventDefault();
            if (!ctx.hidden) return hideCtx();
            if (S.modal) return closeModal();
            close();
        }
    });

    // ════════════════════════════ Messages ════════════════════════════

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || typeof data !== 'object') return;
        switch (data.action) {
            case 'open':
                open(data);
                break;
            case 'close':
                close();
                break;
            case 'refresh':
            case 'update':
                refresh(data);
                break;
            case 'itemBox':
                itemBox(data);
                break;
            case 'requiredItem':
                requiredItems(data);
                break;
            case 'toggleHotbar':
                toggleHotbar(data);
                break;
            case 'RobMoney':
                S.robTarget = data.TargetId;
                $('#rob-btn').hidden = false;
                break;
        }
    });
})();
