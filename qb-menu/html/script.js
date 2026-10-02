'use strict';
/* ============================================================================
   qb-menu NUI — same look as the radial menu / qb-input, kept light:
   no sounds, no looping or heavy animations, just a short fade.
   Same messages from client/main.lua as the original:
     OPEN_MENU / SHOW_HEADER { data: [...] }, CLOSE_MENU
   and the same callbacks back: clickedButton (index + 1), closeMenu.
   Item format is unchanged:
     { header, txt | text, icon, image, isMenuHeader, disabled, hidden,
       ProgressBar = { Value, MaxValue }, params = {...} }
   ============================================================================ */

var QM = {
    visible: false,
    focus: true,
    data: [],
    order: [],     // data indexes of the selectable rows, in display order
    nav: [],       // same, filtered by the search box
    rows: {},
    selected: -1,
    closeTimer: null,
    pendingClose: null,
    faLoaded: false,
    el: {}
};

// Settings (index.html can override these)
var MenuConfig = {
    searchFrom: 8,   // show the search box when a menu has more options than this (0 = never)
    fontAwesome: 'https://kit-pro.fontawesome.com/releases/v6.5.0/css/pro.min.css'
};

// Font Awesome is a big stylesheet: only added the first time a menu uses an icon class.
function qmNeedFontAwesome() {
    if (QM.faLoaded || !MenuConfig.fontAwesome) return;
    QM.faLoaded = true;
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = MenuConfig.fontAwesome;
    document.head.appendChild(link);
}

function qmPlain(html) {
    return String(html == null ? '' : html).replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim().toLowerCase();
}

function qmResource() {
    return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'qb-menu';
}

function qmPost(name, data) {
    return fetch('https://' + qmResource() + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data === undefined ? {} : data)
    }).catch(function () {});
}

function qmAttr(s) {
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function qmIsImage(icon) {
    return /^(https?:|nui:|data:|\.{0,2}\/)/i.test(icon) || /\.(png|jpe?g|webp|gif|svg)(\?.*)?$/i.test(icon);
}

function qmIcon(icon) {
    if (icon === undefined || icon === null || icon === '' || icon === false) return '';
    icon = String(icon);
    var isImg = qmIsImage(icon);
    if (!isImg) qmNeedFontAwesome();
    var inner = isImg
        ? '<img src="' + qmAttr(icon) + '" onerror="this.remove()">'
        : '<i class="' + qmAttr(icon) + '"></i>';
    return '<div class="qm-icon">' + inner + '</div>';
}

function qmProgress(pb) {
    if (!pb || !pb.MaxValue) return '';
    var pct = Math.max(0, Math.min(100, (pb.Value / pb.MaxValue) * 100));
    return '<div class="qm-progress"><div class="qm-bar"><i style="width:' + pct + '%"></i></div>' +
        '<div class="qm-bar-info">' + pb.Value + '/' + pb.MaxValue + '</div></div>';
}

// header / txt are rendered as HTML on purpose: other resources send <br>, <b>, etc.
function qmRow(item, index, num) {
    var message = item.txt || item.text;
    var isTitle = !!item.isMenuHeader;
    var cls = 'qm-item' + (isTitle ? ' qm-title-row' : '') + (item.disabled ? ' disabled' : '');
    var search = isTitle ? '' : ' data-search="' + qmAttr(qmPlain((item.header || '') + ' ' + (message || ''))) + '"';
    return '<div class="' + cls + '" data-index="' + index + '"' + search + '>' +
        (isTitle ? '' : '<div class="qm-num">' + (num > 0 && num < 10 ? num : '') + '</div>') +
        qmIcon(item.icon) +
        '<div class="qm-body">' +
            '<div class="qm-header">' + (item.header || '') + '</div>' +
            (message ? '<div class="qm-text">' + message + '</div>' : '') +
            qmProgress(item.ProgressBar) +
        '</div>' +
        (isTitle ? '' : '<div class="qm-arrow">›</div>') +
    '</div>';
}

function qmRender(data) {
    var el = QM.el;
    QM.data = data || [];
    QM.order = [];
    QM.selected = -1;

    // A leading isMenuHeader becomes the panel title; the rest go in the list.
    var first = -1;
    for (var i = 0; i < QM.data.length; i++) { if (QM.data[i] && !QM.data[i].hidden) { first = i; break; } }
    var head = first >= 0 && QM.data[first].isMenuHeader ? QM.data[first] : null;

    if (head) {
        var sub = head.txt || head.text;
        el.titleWrap.innerHTML = qmIcon(head.icon) +
            '<div><div class="qm-title">' + (head.header || '') + '</div>' +
            (sub ? '<div class="qm-sub">' + sub + '</div>' : '') +
            qmProgress(head.ProgressBar) + '</div>';
    } else {
        el.titleWrap.innerHTML = '';
    }
    el.head.style.display = head ? '' : 'none';

    var html = '';
    var num = 0;
    QM.data.forEach(function (item, index) {
        if (!item || item.hidden || item === head) return;
        if (!item.isMenuHeader) { num++; QM.order.push(index); }
        html += qmRow(item, index, item.isMenuHeader ? 0 : num);
    });
    el.list.innerHTML = html + '<div class="qm-empty" style="display:none">No results</div>';
    el.list.scrollTop = 0;
    QM.rows = {};
    Array.prototype.forEach.call(el.list.querySelectorAll('.qm-item'), function (row) {
        QM.rows[row.getAttribute('data-index')] = row;
    });
    QM.nav = QM.order.slice();

    var useSearch = QM.focus && MenuConfig.searchFrom > 0 && QM.order.length > MenuConfig.searchFrom;
    el.search.classList.toggle('on', useSearch);
    el.searchInput.value = '';

    el.preview.classList.remove('on');
    if (QM.order.length) qmSelect(QM.order[0], true);
}

function qmFilter(query) {
    var q = qmPlain(query);
    Array.prototype.forEach.call(QM.el.list.querySelectorAll('.qm-item'), function (row) {
        var text = row.getAttribute('data-search');
        row.classList.toggle('hide', q !== '' && (text === null || text.indexOf(q) === -1)); // section rows hide while searching
    });
    QM.nav = QM.order.filter(function (i) { var r = QM.rows[i]; return r && !r.classList.contains('hide'); });
    QM.el.list.querySelector('.qm-empty').style.display = QM.nav.length ? 'none' : '';
    QM.el.list.scrollTop = 0;
    if (QM.nav.length && QM.nav.indexOf(QM.selected) === -1) qmSelect(QM.nav[0], true);
}

function qmSelect(index, noScroll) {
    if (index === QM.selected) return;
    var prev = QM.rows[QM.selected];
    if (prev) prev.classList.remove('selected');
    var row = QM.rows[index];
    if (!row) return;
    row.classList.add('selected');
    QM.selected = index;
    if (!noScroll) row.scrollIntoView({ block: 'nearest' });

    var item = QM.data[index];
    if (item && item.image) {
        QM.el.previewImg.src = item.image;
        QM.el.preview.classList.add('on');
    } else {
        QM.el.preview.classList.remove('on');
    }
}

function qmSelectDelta(delta) {
    var n = QM.nav.length;
    if (!n) return;
    var pos = QM.nav.indexOf(QM.selected);
    pos = pos < 0 ? 0 : ((pos + delta) % n + n) % n;
    qmSelect(QM.nav[pos]);
}

function qmActivate(index) {
    if (!QM.visible || QM.pendingClose) return;
    var item = QM.data[index];
    if (!item || !QM.rows[index] || item.isMenuHeader || item.disabled) return;

    qmSelect(index, true);
    qmPost('clickedButton', index + 1);

    // Most menus open the next menu straight from the clicked event. Give it a
    // moment to arrive so it swaps in place instead of close + reopen.
    QM.pendingClose = setTimeout(function () {
        QM.pendingClose = null;
        qmHide();
    }, 120);
}

function qmShow(data, focus) {
    var body = document.body;
    QM.focus = focus;
    body.classList.toggle('qm-nofocus', !focus);

    if (QM.pendingClose) { clearTimeout(QM.pendingClose); QM.pendingClose = null; }
    if (QM.closeTimer) { clearTimeout(QM.closeTimer); QM.closeTimer = null; }

    var wasVisible = QM.visible && body.classList.contains('qm-open');
    QM.visible = true;
    body.classList.add('qm-visible');
    qmRender(data);

    if (!wasVisible) {
        // next frame, so the short fade-in plays
        requestAnimationFrame(function () {
            requestAnimationFrame(function () { if (QM.visible) body.classList.add('qm-open'); });
        });
    }
}

function qmHide() {
    var body = document.body;
    if (QM.pendingClose) { clearTimeout(QM.pendingClose); QM.pendingClose = null; }
    if (!QM.visible) return;
    QM.visible = false;
    body.classList.remove('qm-open');
    QM.closeTimer = setTimeout(function () {
        QM.closeTimer = null;
        body.classList.remove('qm-visible');
        QM.el.list.innerHTML = '';
        QM.el.titleWrap.innerHTML = '';
        QM.el.preview.classList.remove('on');
        QM.el.search.classList.remove('on');
        QM.el.searchInput.value = '';
        QM.el.searchInput.blur();
        QM.data = [];
        QM.order = [];
        QM.nav = [];
        QM.rows = {};
        QM.selected = -1;
    }, 160);
}

function qmCancel() {
    if (!QM.visible || QM.pendingClose) return;
    qmPost('closeMenu');
    qmHide();
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', function () {
    ['list', 'titleWrap', 'preview', 'previewImg', 'head', 'search', 'searchInput'].forEach(function (id) {
        QM.el[id] = document.getElementById(id);
    });

    QM.el.list.addEventListener('mouseover', function (e) {
        var row = e.target.closest('.qm-item');
        if (!row || row.classList.contains('qm-title-row') || !QM.visible) return;
        qmSelect(parseInt(row.getAttribute('data-index'), 10), true);
    });

    QM.el.list.addEventListener('click', function (e) {
        var row = e.target.closest('.qm-item');
        if (!row || row.classList.contains('qm-title-row')) return;
        qmActivate(parseInt(row.getAttribute('data-index'), 10));
    });

    QM.el.previewImg.addEventListener('error', function () { QM.el.preview.classList.remove('on'); });
    QM.el.searchInput.addEventListener('input', function () { qmFilter(QM.el.searchInput.value); });
});

window.addEventListener('message', function (event) {
    var msg = event.data || {};
    switch (msg.action) {
        case 'OPEN_MENU':
            return qmShow(msg.data, true);
        case 'SHOW_HEADER':
            return qmShow(msg.data, false);
        case 'CLOSE_MENU':
            return qmHide();
    }
});

function qmSearching() {
    return document.activeElement === QM.el.searchInput;
}

document.addEventListener('keydown', function (e) {
    if (!QM.visible) return;
    // typing a letter jumps into the search box (long menus only)
    if (!qmSearching() && QM.el.search.classList.contains('on') && e.key.length === 1 && /[^\s0-9]/.test(e.key) && !e.ctrlKey && !e.altKey) {
        QM.el.searchInput.focus();
        return; // the key lands in the box
    }
    switch (e.key) {
        case 'ArrowDown':
        case 'Tab':
            qmSelectDelta(e.shiftKey && e.key === 'Tab' ? -1 : 1); e.preventDefault(); return;
        case 'ArrowUp':
            qmSelectDelta(-1); e.preventDefault(); return;
        case ' ':
            if (qmSearching()) return; // a space in the search box
            // falls through
        case 'Enter':
            if (QM.selected >= 0) qmActivate(QM.selected);
            e.preventDefault(); return;
    }
    if (qmSearching()) return; // digits etc. are typed into the search box
    // 1-9: jump straight to (and trigger) that option
    if (/^[1-9]$/.test(e.key)) {
        var idx = QM.order[parseInt(e.key, 10) - 1];
        if (idx !== undefined) qmActivate(idx);
    }
});

document.addEventListener('keyup', function (e) {
    if (e.key === 'Escape') {
        // first Esc clears an active search, the next one closes
        if (QM.el.searchInput.value !== '' || qmSearching()) {
            QM.el.searchInput.value = '';
            QM.el.searchInput.blur();
            qmFilter('');
            return;
        }
        qmCancel();
    } else if (e.key === 'Backspace' && !qmSearching()) {
        qmCancel();
    }
});
