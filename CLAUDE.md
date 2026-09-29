# Rak — FiveM (QBCore) server resources

## UI style (applies to every NUI we build or edit)

The owner wants one consistent look across all UIs: the **qb-radialmenu** identity
(`qb-radialmenu/html/css/RadialMenu.css`). Any new UI, and any UI we touch, uses it.

**Colors** — the radial menu's own palette (`--rm-*` in RadialMenu.css; the server copy
is identical to the repo copy): deep navy + royal blue. In other UIs they are the
`--cm-*` tokens (see qb-menu / qb-input):

| token | value | radial source | use |
|---|---|---|---|
| panel | `linear-gradient(180deg, rgba(9,21,52,.96), rgba(5,12,32,.96))` | deep `#050c20` | panel background |
| row | `rgba(11, 26, 61, 0.55)` | navy `#0b1a3d` | list rows |
| row-hot | `linear-gradient(90deg, rgba(26,75,214,.42), rgba(10,31,92,.55))` | selected sector | selected row |
| well | `rgba(4, 10, 27, 0.9)` | core `#040a1b` | input fields |
| key | `#0b1a3d` | navy | keycap boxes (1-9, ENTER, ESC) |
| line | `rgba(92, 130, 255, 0.12)` | line-dim | subtle borders |
| line-mid | `rgba(92, 130, 255, 0.28)` | line | panel and field borders |
| blue | `#1a4bd6` | blue | filled primary buttons |
| edge | `#3a6cff` | blue-hi | focus, selection edge, accents |
| edge-dim / edge-soft | `rgba(58,108,255,.5)` / `.16` | | selected borders / fills |
| glow | `rgba(58, 108, 255, 0.2)` | blue-glow | the soft light at the top of a panel |
| text | `#e8eeff` | text | main text (white on selected rows) |
| text-dim | `#8d9bc4` | text-dim | labels, secondary text |
| text-mute | `#5d6a92` | | hints, placeholders |
| bad | `#ef5a5a` | | errors, required `*` |
| dim | `rgba(3, 8, 19, 0.35–0.45)` | void `#030813` | backdrop behind menus / dialogs |

- **Font:** `Oxanium` (same as the radial menu) with `Cairo` as fallback for Arabic glyphs:
  `'Oxanium', 'Cairo', 'Segoe UI', Tahoma, sans-serif`. Load both from Google Fonts without
  blocking (`media="print" onload="this.media='all'"`). Text inputs get `dir="auto"`.
- **Surfaces:** navy gradient panel, 1px `line-mid` border, rounded corners (~10–12px), a soft
  shadow. **Signature detail:** a very light blue light at the top of the panel
  (`::before` radial-gradient with `glow`, ~110px tall) plus a 1px fading `edge` highlight line
  on the top edge (`::after`). Keep it subtle.
- **Backdrop:** menus and dialogs dim the game **lightly** behind them (`dim` token).
  Never a heavy blackout. No dim for non-focus overlays (e.g. qb-menu `showHeader`).

**Keep it light:**
- No sound effects in menus/inputs.
- No heavy animation: at most a short fade/scale (~150–200ms) on open/close and simple
  hover transitions. No looping effects, particles, blur-heavy filters or big shadows.
- Vanilla JS where possible; don't add big libraries for small UIs.
- Keep the existing NUI message protocol and callback names so other scripts keep working.

**Reference implementations:** `qb-input` (centered card: title + ✕, labelled fields with a
red `*` for required ones, Cancel as a text button + filled primary button at bottom-right,
over the light dim) and `qb-menu` (side panel with keycap numbers). Copy their CSS tokens
and structure for new UIs.

## Other notes

- Many uploaded resources came from a leak source with Discord-ad comments and
  backdoors (obfuscated JS in odd/hidden file names, stray `@mysql-async` manifest lines,
  unknown `shared_scripts` JS). Scan every upload before importing; commit a cleaned
  import first, then changes.
- Earlier sessions guessed the radial menu was black + MDT blue; the owner's actual radial
  menu is the navy one above. Always use the navy palette.
- Files ending in `.min.js` have gone missing on the owner's server (likely antivirus);
  pages that depend on a local library should fall back to a CDN copy.
- Replies to the owner are in Arabic (Gulf dialect).
