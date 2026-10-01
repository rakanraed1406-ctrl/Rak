/* ------------------------------------------------------------------ */
/* Physical bank card preview controller                               */
/*                                                                      */
/* Deliberately plain JS/CSS, separate from the banking app            */
/* (app.js/app.css). Using the card item triggers the "showCardPreview"*/
/* NUI message below instead of opening the full banking NUI. Click    */
/* the card itself to flip between the front and back.                 */
/* ------------------------------------------------------------------ */

(function () {
    var RESOURCE_NAME =
        (typeof GetParentResourceName === 'function' && GetParentResourceName()) || 'Renewed-Banking';
    var isEnvBrowser = !window.invokeNative;

    var CARD_COLORS = ['blue', 'gold', 'silver', 'purple', 'green', 'red', 'black'];

    var root = document.getElementById('card-preview-root');

    var overlay = document.createElement('div');
    overlay.className = 'card-preview-overlay';

    var scene = document.createElement('div');
    scene.className = 'card-preview-scene';

    var closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'card-preview-close';
    closeBtn.setAttribute('aria-label', 'Close');
    closeBtn.innerHTML = '<i class="fa-solid fa-xmark"></i>';

    var tilt = document.createElement('div');
    tilt.className = 'card-preview-tilt';

    var flip = document.createElement('div');
    flip.className = 'card-preview-flip';
    flip.setAttribute('data-color', 'blue');

    flip.innerHTML =
        '<div class="card-preview-face card-preview-face-front">' +
        '<div class="card-preview-top">' +
        '<div class="card-preview-bank"><i class="fa-solid fa-building-columns"></i><span class="card-preview-bank-name">Los Santos Bank</span></div>' +
        '<div class="card-preview-frozen" hidden><i class="fa-solid fa-snowflake"></i><span>Frozen</span></div>' +
        '</div>' +
        '<div class="card-preview-chip-row">' +
        '<div class="card-preview-chip"></div>' +
        '<i class="fa-solid fa-wifi card-preview-contactless"></i>' +
        '</div>' +
        '<div class="card-preview-middle">' +
        '<div class="card-preview-iban-label">IBAN</div>' +
        '<div class="card-preview-iban"></div>' +
        '</div>' +
        '<div class="card-preview-bottom">' +
        '<div>' +
        '<div class="card-preview-holder-label">Card Holder</div>' +
        '<div class="card-preview-holder"></div>' +
        '</div>' +
        '<div>' +
        '<div class="card-preview-expiry-label">Valid Thru</div>' +
        '<div class="card-preview-expiry"></div>' +
        '</div>' +
        '<div class="card-preview-network">VISA</div>' +
        '</div>' +
        '<i class="fa-solid fa-rotate card-preview-flip-hint"></i>' +
        '</div>' +
        '<div class="card-preview-face card-preview-face-back">' +
        '<div class="card-preview-magstripe"></div>' +
        '<div class="card-preview-signature-row">' +
        '<div class="card-preview-signature">Authorized Signature</div>' +
        '<div class="card-preview-cvv"></div>' +
        '</div>' +
        '<div class="card-preview-back-meta">' +
        '<div><span>Card balance</span><b class="card-preview-balance"></b></div>' +
        '<div><span>PIN</span><b class="card-preview-pin"></b></div>' +
        '</div>' +
        '<div class="card-preview-back-footer">' +
        '<div class="card-preview-back-text">This card remains the property of the bank. If found, please return to any branch.</div>' +
        '<div class="card-preview-back-iban"></div>' +
        '</div>' +
        '</div>';

    var hint = document.createElement('div');
    hint.className = 'card-preview-hint';
    hint.textContent = 'Click to flip \u2022 ESC to close';

    tilt.appendChild(flip);
    scene.appendChild(tilt);
    scene.appendChild(closeBtn);
    scene.appendChild(hint);
    overlay.appendChild(scene);
    root.appendChild(overlay);

    var GLOW_COLORS = {
        blue: '#2a5298', gold: '#d8b24c', silver: '#9aa5ad', purple: '#6a2ec7',
        green: '#1f8a5f', red: '#b91e1e', black: '#d8b259'
    };

    var frozenBadge = flip.querySelector('.card-preview-frozen');
    var ibanEl = flip.querySelector('.card-preview-iban');
    var holderEl = flip.querySelector('.card-preview-holder');
    var expiryEl = flip.querySelector('.card-preview-expiry');
    var cvvEl = flip.querySelector('.card-preview-cvv');
    var backIbanEl = flip.querySelector('.card-preview-back-iban');
    var bankNameEl = flip.querySelector('.card-preview-bank-name');
    var balanceEl = flip.querySelector('.card-preview-balance');
    var pinEl = flip.querySelector('.card-preview-pin');
    var moneyFmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });

    var isVisible = false;

    function formatIban(raw) {
        var clean = (raw || '').toString().toUpperCase().replace(/\s+/g, '');
        return clean.replace(/(.{4})/g, '$1 ').trim();
    }

    // Deterministic hash so the same physical card always shows the same
    // "Valid Thru" / CVV - purely cosmetic, no backend data needed.
    function hashString(str) {
        var hash = 5381;
        for (var i = 0; i < str.length; i++) {
            hash = (hash * 33) ^ str.charCodeAt(i);
        }
        return Math.abs(hash);
    }

    function formatExpiry(seed) {
        var hash = hashString(seed || 'card');
        var month = (hash % 12) + 1;
        var year = new Date().getFullYear() + 3 + (hash % 4);
        return (month < 10 ? '0' + month : month) + '/' + (year % 100);
    }

    function formatCvv(seed) {
        var hash = hashString('cvv:' + (seed || 'card'));
        return (100 + (hash % 900)).toString();
    }

    function showCard(data) {
        data = data || {};
        var color = CARD_COLORS.indexOf(data.color) !== -1 ? data.color : 'blue';
        var seed = data.iban || data.holder || 'card';

        flip.setAttribute('data-color', color);
        flip.classList.remove('flipped');
        scene.style.setProperty('--glow-color', GLOW_COLORS[color] || GLOW_COLORS.blue);

        ibanEl.textContent = formatIban(data.iban) || '---- ---- --';
        holderEl.textContent = data.holder || 'Unknown';
        expiryEl.textContent = formatExpiry(seed);
        cvvEl.textContent = formatCvv(seed);
        backIbanEl.textContent = formatIban(data.iban);
        balanceEl.textContent = moneyFmt.format(Number(data.balance) || 0);
        pinEl.textContent = data.hasPin ? 'Protected' : 'Not set';
        pinEl.classList.toggle('warn', !data.hasPin);

        // status badge: a deactivated (replaced) card wins over a frozen one
        var badgeIcon = frozenBadge.querySelector('i');
        var badgeText = frozenBadge.querySelector('span');
        frozenBadge.hidden = !data.frozen && !data.deactivated;
        frozenBadge.classList.toggle('deactivated', !!data.deactivated);
        badgeIcon.className = 'fa-solid ' + (data.deactivated ? 'fa-ban' : 'fa-snowflake');
        badgeText.textContent = data.deactivated ? 'Deactivated' : 'Frozen';

        overlay.classList.add('visible');
        isVisible = true;
    }

    function hideCard() {
        overlay.classList.remove('visible');
        tilt.style.transform = '';
        flip.classList.remove('flipped');
        isVisible = false;
    }

    function closeCard() {
        if (!isEnvBrowser) {
            fetch('https://' + RESOURCE_NAME + '/closeCardPreview', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({}),
            }).catch(function () {});
        }
        hideCard();
    }

    closeBtn.addEventListener('click', closeCard);

    // Click the card itself to flip it front/back.
    tilt.addEventListener('click', function () {
        flip.classList.toggle('flipped');
    });

    // Click outside the card (on the dimmed backdrop) closes it.
    overlay.addEventListener('mousedown', function (e) {
        if (e.target === overlay) closeCard();
    });

    // Subtle 3D tilt that follows the cursor.
    // rAF-throttled: only one style write per rendered frame, no matter
    // how many mousemove events fire in between.
    var pendingTiltEvent = null;
    tilt.addEventListener('mousemove', function (e) {
        if (pendingTiltEvent) { pendingTiltEvent = e; return; }
        pendingTiltEvent = e;
        requestAnimationFrame(function () {
            var ev = pendingTiltEvent;
            pendingTiltEvent = null;
            var rect = tilt.getBoundingClientRect();
            var x = (ev.clientX - rect.left) / rect.width - 0.5;
            var y = (ev.clientY - rect.top) / rect.height - 0.5;
            var rotateY = x * 14;
            var rotateX = y * -14;
            tilt.style.transform = 'rotateX(' + rotateX + 'deg) rotateY(' + rotateY + 'deg) scale(1.02)';
        });
    });

    tilt.addEventListener('mouseleave', function () {
        tilt.style.transform = 'rotateX(0deg) rotateY(0deg) scale(1)';
    });

    window.addEventListener('keydown', function (e) {
        if (!isVisible) return;
        if (e.code === 'Escape') {
            closeCard();
        } else if (e.code === 'Space' || e.code === 'KeyF') {
            e.preventDefault();
            flip.classList.toggle('flipped');
        }
    });

    window.addEventListener('message', function (event) {
        var data = event.data;
        if (!data || !data.action) return;

        if (data.action === 'updateLocale' && data.translations && data.translations.bank_name) {
            bankNameEl.textContent = data.translations.bank_name;
        } else if (data.action === 'showCardPreview') {
            showCard(data.card);
        } else if (data.action === 'hideCardPreview') {
            hideCard();
        }
    });

    // Local preview when opening index.html directly in a browser
    // (add ?card to the URL; otherwise the banking mock is shown).
    if (isEnvBrowser && location.search.indexOf('card') !== -1) {
        setTimeout(function () {
            showCard({
                iban: 'B617521932',
                holder: 'John Doe',
                frozen: false,
                color: 'gold',
                balance: 1250,
                hasPin: true,
            });
        }, 1000);
    }
})();
