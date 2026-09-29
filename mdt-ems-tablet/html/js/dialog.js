// ===========================================================================
// In-tablet dialogs — replaces window.prompt() / window.confirm().
// Browser prompt() in FiveM's CEF pops a native window OUTSIDE the NUI
// (that was the "pin label opens outside the tablet" bug). Everything here
// renders inside #screen instead.
// ===========================================================================

let dialogResolver = null;

function closeDialog(result) {
    const layer = document.getElementById('mdt-dialog');
    if (layer) {
        layer.classList.add('hidden');
        layer.innerHTML = '';
    }
    const resolve = dialogResolver;
    dialogResolver = null;
    if (resolve) resolve(result);
}

function isDialogOpen() {
    const layer = document.getElementById('mdt-dialog');
    return !!layer && !layer.classList.contains('hidden');
}

/**
 * Generic dialog.
 *   title, message, icon, confirmText, cancelText, danger
 *   label/placeholder/maxLength/value/multiline  → single text input (result.value)
 *   colors: ['#hex', …], color                   → colour picker (result.color)
 *   bodyHtml                                      → custom inner HTML (already escaped!)
 *   collect(layer) → value                        → read custom fields on confirm
 * Resolves to null on cancel.
 */
function mdtDialog(opts) {
    opts = opts || {};
    if (dialogResolver) closeDialog(null);

    const layer = document.getElementById('mdt-dialog');
    if (!layer) return Promise.resolve(null);

    const hasInput = opts.label !== undefined || opts.placeholder !== undefined || opts.value !== undefined;
    const colors = Array.isArray(opts.colors) ? opts.colors.filter(c => /^#[0-9a-fA-F]{6}$/.test(c)) : null;
    let pickedColor = (colors && colors.includes(opts.color)) ? opts.color : (colors ? colors[0] : null);

    const inputHtml = !hasInput ? '' : `
        <div class="field">
            ${opts.label ? `<label>${escapeHtml(opts.label)}</label>` : ''}
            ${opts.multiline
                ? `<textarea id="mdt-dialog-input" maxlength="${Number(opts.maxLength) || 250}" placeholder="${escapeHtml(opts.placeholder || '')}">${escapeHtml(opts.value || '')}</textarea>`
                : `<input id="mdt-dialog-input" type="text" maxlength="${Number(opts.maxLength) || 250}" placeholder="${escapeHtml(opts.placeholder || '')}" value="${escapeHtml(opts.value || '')}" autocomplete="off">`}
        </div>`;

    const colorHtml = !colors ? '' : `
        <div class="field">
            <label>Colour</label>
            <div class="dialog-colors">
                ${colors.map(c => `<button type="button" class="dialog-color${c === pickedColor ? ' active' : ''}" data-color="${c}" style="--c:${c}"></button>`).join('')}
            </div>
        </div>`;

    layer.innerHTML = `
        <div class="mdt-dialog-card${opts.danger ? ' danger' : ''}">
            <div class="mdt-dialog-head">
                ${opts.icon ? `<span class="mdt-dialog-icon">${escapeHtml(opts.icon)}</span>` : ''}
                <strong>${escapeHtml(opts.title || 'Confirm')}</strong>
            </div>
            ${opts.message ? `<div class="mdt-dialog-msg">${escapeHtml(opts.message)}</div>` : ''}
            ${opts.bodyHtml || ''}
            ${inputHtml}
            ${colorHtml}
            <div class="mdt-dialog-actions">
                <button type="button" class="btn btn-ghost" data-dialog="cancel">${escapeHtml(opts.cancelText || 'Cancel')}</button>
                <button type="button" class="btn ${opts.danger ? 'btn-danger' : 'btn-accent'}" data-dialog="ok">${escapeHtml(opts.confirmText || 'OK')}</button>
            </div>
        </div>
    `;
    layer.classList.remove('hidden');

    const input = layer.querySelector('#mdt-dialog-input');
    setTimeout(() => { if (input) { input.focus(); input.select?.(); } }, 30);

    return new Promise(resolve => {
        dialogResolver = resolve;

        const confirm = () => {
            const result = { ok: true };
            if (input) result.value = input.value.trim().slice(0, Number(opts.maxLength) || 250);
            if (colors) result.color = pickedColor;
            if (typeof opts.collect === 'function') {
                const collected = opts.collect(layer);
                if (collected === false) return; // validation failed, keep dialog open
                result.data = collected;
            }
            closeDialog(result);
        };

        layer.onclick = (e) => {
            const colorBtn = e.target.closest('[data-color]');
            if (colorBtn) {
                pickedColor = colorBtn.getAttribute('data-color');
                layer.querySelectorAll('.dialog-color').forEach(b => b.classList.toggle('active', b === colorBtn));
                return;
            }
            const action = e.target.closest('[data-dialog]');
            if (action) {
                if (action.getAttribute('data-dialog') === 'ok') confirm(); else closeDialog(null);
                return;
            }
            if (e.target === layer) closeDialog(null); // click on the dim backdrop
        };
        layer.onkeydown = (e) => {
            if (e.key === 'Enter' && !(e.target && e.target.tagName === 'TEXTAREA')) {
                e.preventDefault();
                confirm();
            }
        };
    });
}

function mdtPrompt(opts) {
    return mdtDialog(Object.assign({ label: '', value: '' }, opts));
}

function mdtConfirm(opts) {
    return mdtDialog(opts).then(res => !!res);
}

// Escape closes the dialog first instead of the whole tablet (capture phase
// runs before script.js's document-level Escape handler).
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isDialogOpen()) {
        e.preventDefault();
        e.stopImmediatePropagation();
        closeDialog(null);
    }
}, true);
