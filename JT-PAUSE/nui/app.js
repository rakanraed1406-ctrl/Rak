(() => {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'jt-pause';
    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

    const app = $('#app');
    const views = {
        overview: $('#view-overview'),
        updates: $('#view-updates'),
        audio: $('#view-audio'),
    };
    const navItems = $$('.nav-item');
    const indicator = $('#nav-indicator');
    const modalLayer = $('#modal-layer');
    const modals = { quit: $('#modal-quit'), publish: $('#modal-publish') };

    const S = {
        ready: false,
        open: false,
        view: 'overview',
        modal: null,
        focus: -1,
        escArmed: false,
        locale: 'en',
        strings: {},
        robberies: [],
        showRequirement: true,
        playerCard: { enabled: true },
        prefs: { sounds: true, blur: true, reducedMotion: false, seenUpdate: '' },
        soundVolume: 0.35,
        updates: [],
        isAdmin: false,
        lastServer: null,
        pendingOpen: null,
    };

    // ════════════════════════════ Helpers ════════════════════════════

    function nui(name, data = {}) {
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        })
            .then((response) => response.json().catch(() => null))
            .catch(() => null);
    }

    function t(key, vars) {
        let text = S.strings[key] ?? key;
        if (vars) {
            for (const name in vars) text = text.replace(`{${name}}`, vars[name]);
        }
        return text;
    }

    function toArray(value) {
        if (Array.isArray(value)) return value;
        if (value && typeof value === 'object') return Object.values(value);
        return [];
    }

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined && text !== null) node.textContent = text;
        return node;
    }

    const ICONS = new Set($$('symbol').map((symbol) => symbol.id.slice(2)));
    function icon(name) {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('class', 'ic');
        const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
        use.setAttribute('href', `#i-${ICONS.has(name) ? name : 'box'}`);
        svg.appendChild(use);
        return svg;
    }

    function setText(node, text) {
        if (node && node.textContent !== text) node.textContent = text;
    }

    const reducedMotion = () => S.prefs.reducedMotion || window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // Counts a number up/down smoothly; stops itself when done.
    function animateNumber(node, to, format = String) {
        if (!node) return;
        const from = Number(node.dataset.value || 0);
        node.dataset.value = to;
        cancelAnimationFrame(node._raf);
        if (from === to || reducedMotion() || !S.open) {
            setText(node, format(to));
            return;
        }
        const start = performance.now();
        const duration = 650;
        const step = (now) => {
            const k = Math.min(1, (now - start) / duration);
            const eased = 1 - Math.pow(1 - k, 3);
            setText(node, format(Math.round(from + (to - from) * eased)));
            if (k < 1) node._raf = requestAnimationFrame(step);
        };
        node._raf = requestAnimationFrame(step);
    }

    const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
    const formatMoney = (value) => money.format(value);

    // ════════════════════════════ Sounds (Web Audio, no files) ════════════════════════════

    const Sfx = { ctx: null, master: null, idle: null, last: 0 };
    const SOUNDS = {
        hover: [[1480, 0, 0.035, 0.05]],
        select: [[880, 0, 0.07, 0.11], [1320, 0.045, 0.08, 0.09]],
        open: [[523.25, 0, 0.14, 0.09], [783.99, 0.06, 0.18, 0.09]],
        close: [[659.25, 0, 0.1, 0.08], [440, 0.05, 0.14, 0.07]],
        toggle: [[1046.5, 0, 0.05, 0.09]],
        back: [[587.33, 0, 0.09, 0.08]],
        error: [[220, 0, 0.13, 0.1, 'triangle'], [196, 0.08, 0.15, 0.09, 'triangle']],
        success: [[783.99, 0, 0.09, 0.09], [1174.66, 0.07, 0.16, 0.09]],
    };

    function sfx(name) {
        if (!S.prefs.sounds || S.soundVolume <= 0) return;
        const notes = SOUNDS[name];
        if (!notes) return;
        const now = performance.now();
        if (name === 'hover' && now - Sfx.last < 45) return;
        Sfx.last = now;
        try {
            if (!Sfx.ctx) {
                const Context = window.AudioContext || window.webkitAudioContext;
                if (!Context) return;
                Sfx.ctx = new Context();
                Sfx.master = Sfx.ctx.createGain();
                Sfx.master.connect(Sfx.ctx.destination);
            }
            const ctx = Sfx.ctx;
            if (ctx.state === 'suspended') ctx.resume();
            Sfx.master.gain.value = S.soundVolume;
            for (const [freq, delay, duration, gain, type] of notes) {
                const start = ctx.currentTime + delay;
                const osc = ctx.createOscillator();
                const env = ctx.createGain();
                osc.type = type || 'sine';
                osc.frequency.setValueAtTime(freq, start);
                env.gain.setValueAtTime(0.0001, start);
                env.gain.exponentialRampToValueAtTime(gain, start + 0.008);
                env.gain.exponentialRampToValueAtTime(0.0001, start + duration);
                osc.connect(env).connect(Sfx.master);
                osc.start(start);
                osc.stop(start + duration + 0.03);
            }
            // Suspend the audio thread when idle so it costs nothing.
            clearTimeout(Sfx.idle);
            Sfx.idle = setTimeout(() => ctx.state === 'running' && ctx.suspend(), 1500);
        } catch (error) {
            /* audio is optional */
        }
    }

    // ════════════════════════════ Clock ════════════════════════════

    const Clock = { timer: null, time: null, date: null };

    function buildClock(config = {}) {
        const locale = S.locale === 'ar' ? 'ar-u-nu-latn-ca-gregory' : 'en-US';
        const make = (options) => {
            try {
                return new Intl.DateTimeFormat(locale, { ...options, timeZone: config.timeZone || undefined });
            } catch (error) {
                return new Intl.DateTimeFormat(locale, options);
            }
        };
        Clock.time = make({ hour: '2-digit', minute: '2-digit', hour12: config.hour12 === true });
        Clock.date = make({ weekday: 'short', month: 'short', day: '2-digit' });
        setText($('#clock-tz'), config.label || '');
        $('#clock-tz').previousElementSibling.hidden = !config.label;
    }

    function tickClock() {
        if (!Clock.time) return;
        const now = new Date();
        setText($('#clock-time'), Clock.time.format(now));
        setText($('#clock-date'), Clock.date.format(now).toUpperCase());
    }

    function startClock() {
        tickClock();
        clearInterval(Clock.timer);
        Clock.timer = setInterval(tickClock, 1000);
    }

    function stopClock() {
        clearInterval(Clock.timer);
        Clock.timer = null;
    }

    // ════════════════════════════ Init ════════════════════════════

    function hexToRgb(hex) {
        const match = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(String(hex || '').trim());
        if (!match) return null;
        let value = match[1];
        if (value.length === 3) value = value.split('').map((c) => c + c).join('');
        const number = parseInt(value, 16);
        return [(number >> 16) & 255, (number >> 8) & 255, number & 255];
    }

    function applyAccent(hex) {
        const rgb = hexToRgb(hex);
        if (!rgb) return;
        const light = rgb.map((c) => Math.round(c + (255 - c) * 0.35));
        const root = document.documentElement.style;
        root.setProperty('--accent', `rgb(${rgb.join(',')})`);
        root.setProperty('--accent-rgb', rgb.join(','));
        root.setProperty('--accent-hi', `rgb(${light.join(',')})`);
    }

    function applyStrings() {
        $$('[data-i18n]').forEach((node) => setText(node, t(node.dataset.i18n)));
        $$('[data-i18n-ph]').forEach((node) => node.setAttribute('placeholder', t(node.dataset.i18nPh)));
    }

    function applyBrand(brand = {}) {
        const name = String(brand.name || '');
        setText($('#brand-name'), name);
        if (brand.logoHeight) document.documentElement.style.setProperty('--logo-h', `${Number(brand.logoHeight) || 8}rem`);

        const logo = $('#logo');
        const fallback = $('#logo-fallback');
        setText(fallback, name);
        logo.alt = name;
        logo.onerror = () => {
            logo.hidden = true;
            fallback.hidden = false;
        };
        logo.onload = () => {
            logo.hidden = false;
            fallback.hidden = true;
        };
        if (brand.logo) {
            logo.src = brand.logo;
        } else {
            logo.hidden = true;
            fallback.hidden = false;
        }
    }

    function renderLinks(links) {
        const box = $('#links');
        box.textContent = '';
        toArray(links).forEach((link) => {
            if (!link || !link.url) return;
            const button = el('button', 'link-btn');
            button.append(icon(link.icon || 'link'), el('span', null, link.label || link.url));
            button.addEventListener('click', () => openLink(String(link.url)));
            box.appendChild(button);
        });
    }

    function openLink(url) {
        if (typeof window.invokeNative === 'function') {
            window.invokeNative('openUrl', url);
            return;
        }
        const area = el('textarea');
        area.value = url;
        area.style.position = 'fixed';
        area.style.opacity = '0';
        document.body.appendChild(area);
        area.select();
        try {
            document.execCommand('copy');
            toast(t('toast_copied'), true);
        } catch (error) {
            /* ignore */
        }
        area.remove();
    }

    function renderRobberies() {
        const list = $('#robbery-list');
        list.textContent = '';
        S.robberies.forEach((robbery, index) => {
            const row = el('div', 'r-row');
            row.dataset.id = robbery.id;
            row.style.setProperty('--i', index);

            const iconBox = el('div', 'r-icon');
            iconBox.appendChild(icon(robbery.icon));

            const text = el('div', 'r-text');
            text.appendChild(el('div', 'r-name', robbery.label));
            if (robbery.description) text.appendChild(el('div', 'r-desc', robbery.description));
            if (S.showRequirement && robbery.minPolice > 0) {
                const req = el('div', 'r-req');
                req.append(icon('shield'), el('span', null, t('requires', { n: robbery.minPolice })));
                text.appendChild(req);
            }

            const status = el('div', 'r-status');
            status.append(el('span', 'dot'), el('span', null, '—'));

            row.append(iconBox, text, status);
            list.appendChild(row);
        });
        $('#robbery-summary').hidden = S.robberies.length === 0;
    }

    function init(message) {
        S.locale = message.locale === 'ar' ? 'ar' : 'en';
        S.strings = message.strings || {};
        S.robberies = toArray(message.robberies);
        S.showRequirement = message.showRequirement !== false;
        S.playerCard = message.playerCard || { enabled: true };
        S.soundVolume = Math.max(0, Math.min(1, Number(message.sounds && message.sounds.volume) || 0));
        Object.assign(S.prefs, message.prefs || {});

        document.documentElement.lang = S.locale;
        document.documentElement.dir = S.locale === 'ar' ? 'rtl' : 'ltr';

        applyAccent(message.brand && message.brand.accent);
        applyBrand(message.brand);
        applyStrings();
        buildClock(message.clock);
        renderLinks(message.links);
        renderRobberies();
        applyPrefs();
        $('#character-card').hidden = S.playerCard.enabled === false;

        S.ready = true;
        if (S.lastServer) setServer(S.lastServer);
        if (S.pendingOpen) {
            const pending = S.pendingOpen;
            S.pendingOpen = null;
            open(pending);
        }
    }

    // ════════════════════════════ Data ════════════════════════════

    function setPlayer(player) {
        if (!player) return;
        const name = String(player.name || '').trim();
        const initials = name
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map((part) => Array.from(part)[0])
            .join('')
            .toUpperCase();

        setText($('#player-initials'), initials || '?');
        setText($('#player-name'), name);
        setText($('#character-name'), name);
        setText($('#player-sid'), String(player.serverId ?? ''));
        setText($('#player-cid'), String(player.citizenid || ''));
        $('#player-cid-wrap').hidden = !player.citizenid;

        const job = player.job;
        $('#stat-job').hidden = !job;
        if (job) {
            setText($('#stat-job-value'), job.label || t('none'));
            setText($('#stat-job-grade'), job.grade || '');
            const duty = $('#stat-job-duty');
            duty.classList.toggle('is-on', !!job.onduty);
            setText(duty, job.onduty ? t('on_duty') : t('off_duty'));
        }

        const gang = player.gang;
        $('#stat-gang').hidden = S.playerCard.gang === false;
        setText($('#stat-gang-value'), gang ? gang.label : t('none'));
        setText($('#stat-gang-grade'), gang ? gang.grade || '' : '');

        $('#stat-cash').hidden = player.cash === undefined || player.cash === null;
        $('#stat-bank').hidden = player.bank === undefined || player.bank === null;
        if (player.cash !== undefined && player.cash !== null) animateNumber($('#stat-cash-value'), Number(player.cash) || 0, formatMoney);
        if (player.bank !== undefined && player.bank !== null) animateNumber($('#stat-bank-value'), Number(player.bank) || 0, formatMoney);
    }

    function setDuty(id, info) {
        const chip = $(id);
        const active = !!(info && info.active);
        chip.classList.toggle('is-on', active);
        chip.classList.toggle('is-off', !active);
        const label = info && typeof info.count === 'number' ? String(info.count) : active ? t('active') : t('inactive');
        setText($('b', chip), label);
    }

    function setServer(data) {
        if (!data || typeof data !== 'object') return;
        S.lastServer = data;
        if (!S.ready) return;

        const players = Number(data.players) || 0;
        const max = Number(data.maxPlayers) || 0;
        animateNumber($('#online-count'), players);
        setText($('#online-max'), max ? `/ ${max}` : '');
        $('#capacity-fill').style.setProperty('--fill', max ? Math.min(1, players / max).toFixed(3) : 0);

        setDuty('#duty-police', data.police);
        setDuty('#duty-ems', data.ems);

        const states = data.robberies || {};
        let available = 0;
        $$('.r-row').forEach((row) => {
            const on = states[row.dataset.id] === true;
            if (on) available += 1;
            const before = row.classList.contains('is-on') ? 'on' : row.classList.contains('is-off') ? 'off' : '';
            const after = on ? 'on' : 'off';
            row.classList.toggle('is-on', on);
            row.classList.toggle('is-off', !on);
            setText($('.r-status span:last-child', row), on ? t('available') : t('unavailable'));
            if (before && before !== after) {
                row.classList.remove('flash');
                void row.offsetWidth;
                row.classList.add('flash');
            }
        });
        setText($('#robbery-summary'), t('x_available', { n: available, t: S.robberies.length }));

        S.isAdmin = data.isAdmin === true;
        $('#btn-publish').hidden = !S.isAdmin;
        if (data.updates !== undefined && data.updates !== null) {
            S.updates = toArray(data.updates);
            renderUpdates();
        } else if (S.updates.length) {
            $$('.u-delete').forEach((button) => (button.hidden = !S.isAdmin));
        }
    }

    function renderUpdates() {
        const list = $('#updates-list');
        list.textContent = '';
        const latest = $('#latest-version');

        if (!S.updates.length) {
            const empty = el('div', 'empty');
            empty.append(icon('megaphone'), el('span', null, t('no_updates')));
            list.appendChild(empty);
            latest.hidden = true;
            updateBadge();
            return;
        }

        latest.hidden = false;
        setText(latest, S.updates[0].version || '');

        S.updates.forEach((update, index) => {
            const item = el('article', `u-item${index === 0 ? ' is-latest' : ''}`);
            item.style.setProperty('--i', Math.min(index, 6));

            const head = el('div', 'u-head');
            const titleWrap = el('div', 'u-title-wrap');
            titleWrap.append(el('span', 'u-version', update.version || ''), el('span', 'u-title', update.title || ''));
            if (index === 0) titleWrap.appendChild(el('span', 'u-latest', t('latest')));

            const side = el('div', 'u-side');
            side.appendChild(el('span', 'u-date', update.date || ''));
            const remove = el('button', 'u-delete');
            remove.type = 'button';
            remove.hidden = !S.isAdmin;
            remove.append(icon('trash'), el('span', null, t('delete')));
            remove.addEventListener('click', () => confirmDelete(remove, update.id));
            side.appendChild(remove);
            head.append(titleWrap, side);
            item.appendChild(head);

            const section = (items, title, className, iconName) => {
                const lines = toArray(items);
                if (!lines.length) return;
                item.appendChild(el('div', 'u-section', title));
                const ul = el('ul', `u-list ${className}`);
                lines.forEach((line) => {
                    const li = el('li');
                    li.append(icon(iconName), el('span', null, line));
                    ul.appendChild(li);
                });
                item.appendChild(ul);
            };
            section(update.added, t('added_section'), 'is-added', 'check');
            section(update.removed, t('changed_section'), 'is-changed', 'wrench');

            list.appendChild(item);
        });
        updateBadge();
    }

    function confirmDelete(button, id) {
        if (!id) return;
        if (button.classList.contains('is-confirm')) {
            clearTimeout(button._timer);
            button.disabled = true;
            nui('deleteUpdate', { id });
            sfx('select');
            return;
        }
        button.classList.add('is-confirm');
        setText($('span', button), t('confirm_delete'));
        sfx('toggle');
        button._timer = setTimeout(() => {
            button.classList.remove('is-confirm');
            setText($('span', button), t('delete'));
        }, 3000);
    }

    function updateBadge() {
        const latest = S.updates[0];
        const unseen = !!latest && latest.id !== S.prefs.seenUpdate;
        $('#updates-badge').hidden = !unseen || S.view === 'updates';
        if (unseen && S.view === 'updates' && S.open) markSeen();
    }

    function markSeen() {
        const latest = S.updates[0];
        if (!latest || latest.id === S.prefs.seenUpdate) return;
        S.prefs.seenUpdate = latest.id;
        $('#updates-badge').hidden = true;
        nui('seenUpdate', { id: latest.id });
    }

    // ════════════════════════════ Audio / prefs ════════════════════════════

    function paintRange(input) {
        input.style.setProperty('--p', `${input.value}%`);
        setText($(`[data-value-for="${input.dataset.kind}"]`), `${input.value}%`);
    }

    function setSwitch(button, on) {
        button.setAttribute('aria-checked', on ? 'true' : 'false');
    }

    function setAudio(audio) {
        if (!audio) return;
        $$('.range').forEach((input) => {
            const value = Number(audio[input.dataset.kind]);
            if (Number.isFinite(value)) {
                input.value = Math.round(value / 10) * 10;
                paintRange(input);
            }
        });
        const toggles = audio.toggles || {};
        $$('[data-toggle]').forEach((button) => {
            if (toggles[button.dataset.toggle] !== undefined) setSwitch(button, toggles[button.dataset.toggle] === true);
        });
    }

    function applyPrefs() {
        app.classList.toggle('reduced-motion', !!S.prefs.reducedMotion);
        $$('[data-pref]').forEach((button) => setSwitch(button, !!S.prefs[button.dataset.pref]));
    }

    $$('.range').forEach((input) => {
        let last = 0;
        let timer = null;
        const send = () => {
            last = performance.now();
            nui('setVolume', { kind: input.dataset.kind, value: Number(input.value) });
        };
        paintRange(input);
        input.addEventListener('input', () => {
            paintRange(input);
            sfx('hover');
            clearTimeout(timer);
            if (performance.now() - last > 150) send();
            else timer = setTimeout(send, 150);
        });
        input.addEventListener('change', () => {
            clearTimeout(timer);
            send();
        });
    });

    $$('[data-toggle]').forEach((button) => {
        button.addEventListener('click', () => {
            const on = button.getAttribute('aria-checked') !== 'true';
            setSwitch(button, on);
            sfx('toggle');
            nui('setToggle', { key: button.dataset.toggle, value: on });
        });
    });

    $$('[data-pref]').forEach((button) => {
        button.addEventListener('click', () => {
            const key = button.dataset.pref;
            S.prefs[key] = button.getAttribute('aria-checked') !== 'true';
            applyPrefs();
            sfx('toggle');
            nui('setPref', { key, value: S.prefs[key] });
        });
    });

    $('#btn-reset-audio').addEventListener('click', () => {
        sfx('select');
        nui('resetAudio').then((audio) => {
            setAudio(audio && typeof audio === 'object' ? audio : { sfx: 100, music: 100 });
            toast(t('toast_reset'), true);
        });
    });

    // ════════════════════════════ Views / navigation ════════════════════════════

    function moveIndicator() {
        const active = navItems.find((item) => item.dataset.view === S.view);
        if (!active || active.offsetParent === null) {
            indicator.classList.add('is-hidden');
            return;
        }
        indicator.classList.remove('is-hidden');
        indicator.style.setProperty('--y', `${active.offsetTop}px`);
        indicator.style.height = `${active.offsetHeight}px`;
    }

    function showView(name, initial = false) {
        const next = views[name];
        if (!next) return;
        const previous = views[S.view];
        if (!initial && name === S.view) return;
        S.view = name;

        navItems.forEach((item) => item.classList.toggle('active', item.dataset.view === name));
        moveIndicator();

        Object.entries(views).forEach(([key, view]) => {
            if (view === next) return;
            if (!initial && view === previous && view.classList.contains('active')) {
                view.classList.remove('active');
                view.classList.add('leaving');
                clearTimeout(view._leave);
                view._leave = setTimeout(() => view.classList.remove('leaving'), 190);
            } else {
                view.classList.remove('active', 'leaving');
            }
        });

        clearTimeout(next._leave);
        next.classList.remove('leaving', 'active');
        void next.offsetWidth; // restart the entrance animation
        next.classList.add('active');

        if (name === 'updates') markSeen();
    }

    function setFocus(index) {
        const items = navItems.filter((item) => item.offsetParent !== null);
        if (!items.length) return;
        S.focus = (index + items.length) % items.length;
        navItems.forEach((item) => item.classList.remove('is-focused'));
        items[S.focus].classList.add('is-focused');
        items[S.focus].focus({ preventScroll: true });
        sfx('hover');
    }

    function activate(item) {
        if (!item) return;
        if (item.dataset.view) {
            if (item.dataset.view !== S.view) sfx('select');
            showView(item.dataset.view);
            return;
        }
        switch (item.dataset.action) {
            case 'map':
                sfx('select');
                close(false);
                nui('openMap');
                break;
            case 'settings':
                sfx('select');
                close(false);
                nui('openSettings');
                break;
            case 'resume':
                close(true);
                break;
            case 'quit':
                openModal('quit');
                break;
        }
    }

    navItems.forEach((item) => {
        item.addEventListener('click', () => activate(item));
        item.addEventListener('mouseenter', () => {
            navItems.forEach((other) => other.classList.remove('is-focused'));
            sfx('hover');
        });
    });

    // ════════════════════════════ Modals ════════════════════════════

    function openModal(name) {
        const modal = modals[name];
        if (!modal) return;
        clearTimeout(modalLayer._hide);
        modalLayer.classList.remove('hiding');
        Object.values(modals).forEach((other) => (other.hidden = other !== modal));
        modalLayer.classList.add('show');
        S.modal = name;
        sfx(name === 'quit' ? 'back' : 'select');

        if (name === 'publish') {
            $('#form-error').textContent = '';
            $$('.field', modal).forEach((field) => field.classList.remove('is-invalid'));
            setTimeout(() => $('#f-version').focus(), 60);
        } else {
            setTimeout(() => $('#btn-confirm-quit').focus({ preventScroll: true }), 60);
        }
    }

    function closeModal(instant = false) {
        if (!S.modal) return;
        S.modal = null;
        clearTimeout(modalLayer._hide);
        if (instant) {
            modalLayer.classList.remove('show', 'hiding');
            return;
        }
        sfx('back');
        modalLayer.classList.add('hiding');
        modalLayer._hide = setTimeout(() => modalLayer.classList.remove('show', 'hiding'), 160);
    }

    $$('[data-close-modal]').forEach((button) => button.addEventListener('click', () => closeModal()));
    modalLayer.addEventListener('mousedown', (event) => {
        if (event.target === modalLayer) closeModal();
    });

    $('#btn-confirm-quit').addEventListener('click', () => {
        closeModal(true);
        close(false);
        nui('quit');
    });

    $('#btn-publish').addEventListener('click', () => openModal('publish'));

    const lines = (value) =>
        value
            .split('\n')
            .map((line) => line.trim())
            .filter(Boolean)
            .slice(0, 30);

    $('#modal-publish').addEventListener('submit', (event) => {
        event.preventDefault();
        const version = $('#f-version').value.trim();
        const title = $('#f-title').value.trim();
        $('#f-version').closest('.field').classList.toggle('is-invalid', !version);
        $('#f-title').closest('.field').classList.toggle('is-invalid', !title);

        if (!version || !title) {
            const form = $('#modal-publish');
            $('#form-error').textContent = t('required');
            form.classList.remove('shake');
            void form.offsetWidth;
            form.classList.add('shake');
            sfx('error');
            return;
        }

        nui('publishUpdate', {
            version,
            title,
            added: lines($('#f-added').value),
            removed: lines($('#f-changed').value),
        });
        ['#f-version', '#f-title', '#f-added', '#f-changed'].forEach((id) => ($(id).value = ''));
        closeModal();
    });

    // ════════════════════════════ Toast ════════════════════════════

    let toastTimer = null;
    function toast(text, ok = true) {
        const box = $('#toast');
        setText($('span', box), text || '');
        $('use', box).setAttribute('href', ok ? '#i-check' : '#i-alert');
        box.classList.toggle('is-error', !ok);
        box.classList.add('show');
        sfx(ok ? 'success' : 'error');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => box.classList.remove('show'), 2600);
    }

    // ════════════════════════════ Open / close ════════════════════════════

    let closeTimer = null;

    function open(message) {
        clearTimeout(closeTimer);
        app.classList.remove('is-closing');
        app.hidden = false; // display:none -> visible restarts every entrance animation
        S.open = true;
        S.escArmed = false;
        S.focus = -1;
        navItems.forEach((item) => item.classList.remove('is-focused'));

        setPlayer(message.player);
        if (message.server) setServer(message.server);
        setAudio(message.audio);

        closeModal(true);
        showView(views[message.view] ? message.view : 'overview', true);
        if (message.modal) openModal(message.modal);
        updateBadge();
        startClock();
        sfx('open');

        // Place the nav indicator without sliding from its old position.
        indicator.classList.add('snap');
        moveIndicator();
        requestAnimationFrame(() => requestAnimationFrame(() => indicator.classList.remove('snap')));
    }

    function close(notify) {
        if (!S.open) return;
        S.open = false;
        closeModal(true);
        stopClock();
        sfx('close');
        app.classList.add('is-closing');
        clearTimeout(closeTimer);
        closeTimer = setTimeout(() => {
            app.hidden = true;
            app.classList.remove('is-closing');
            $('#toast').classList.remove('show');
        }, 220);
        if (notify) nui('close');
    }

    // ════════════════════════════ Keyboard ════════════════════════════

    const isTyping = (target) => target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') && target.type !== 'range';

    document.addEventListener('keydown', (event) => {
        if (!S.open) return;
        const key = event.key;

        // ESC / P only count when the key went down inside the menu (prevents the key
        // that opened the menu from closing it again on release).
        if (key === 'Escape') {
            if (!event.repeat) S.escArmed = true;
            event.preventDefault();
            return;
        }
        if (isTyping(event.target)) return;
        if ((key === 'p' || key === 'P') && !S.modal) {
            if (!event.repeat) S.escArmed = true;
            return;
        }
        if (key === 'Tab' && !S.modal) {
            event.preventDefault();
            return;
        }
        if (S.modal) return;

        const onRange = event.target && event.target.classList && event.target.classList.contains('range');
        if (key === 'ArrowDown' && !onRange) {
            event.preventDefault();
            setFocus(S.focus + 1);
        } else if (key === 'ArrowUp' && !onRange) {
            event.preventDefault();
            setFocus(S.focus - 1);
        } else if (key === 'Enter' || key === ' ') {
            // A focused button clicks itself natively; only handle the case where focus moved away.
            const focused = navItems.find((item) => item.classList.contains('is-focused'));
            if (focused && document.activeElement !== focused) {
                event.preventDefault();
                activate(focused);
            }
        } else if (key === 'Backspace') {
            event.preventDefault();
            if (S.view !== 'overview') {
                sfx('back');
                showView('overview');
            }
        } else if (/^[1-9]$/.test(key)) {
            const item = navItems.find((nav) => $('.ni-key', nav) && $('.ni-key', nav).textContent === key);
            if (item) activate(item);
        }
    });

    document.addEventListener('keyup', (event) => {
        if (!S.open) return;
        const key = event.key;
        const isPause = key === 'Escape' || ((key === 'p' || key === 'P') && !isTyping(event.target));
        if (!isPause || !S.escArmed) return;
        S.escArmed = false;
        if (S.modal) {
            if (key === 'Escape') closeModal();
        } else {
            close(true);
        }
    });

    document.addEventListener('contextmenu', (event) => event.preventDefault());
    window.addEventListener('resize', () => S.open && moveIndicator());

    // ════════════════════════════ Messages from Lua ════════════════════════════

    window.addEventListener('message', (event) => {
        const message = event.data;
        if (!message || typeof message !== 'object') return;
        switch (message.action) {
            case 'init':
                init(message);
                break;
            case 'open':
                if (S.ready) {
                    open(message);
                } else {
                    // init got lost (page loaded late): ask for it again and open right after.
                    S.pendingOpen = message;
                    nui('ready');
                }
                break;
            case 'close':
                S.pendingOpen = null;
                close(false);
                break;
            case 'server':
                setServer(message.data);
                break;
            case 'player':
                if (S.open) setPlayer(message.player);
                break;
            case 'show':
                if (!S.open) break;
                if (message.view) showView(message.view);
                if (message.modal) openModal(message.modal);
                break;
            case 'toast':
                if (S.open) toast(message.text, message.ok !== false);
                break;
        }
    });

    nui('ready');
})();
