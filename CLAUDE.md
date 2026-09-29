# Rak — FiveM (QBCore) server resources

## UI style (applies to every NUI we build or edit)

The owner wants one consistent look across all UIs: the **qb-radialmenu** identity
(`qb-radialmenu/html/css/RadialMenu.css`). Any new UI, and any UI we touch, uses it.

**Colors** (same tokens as the radial menu):

| token | value | use |
|---|---|---|
| void | `#030813` | darkest background |
| deep | `#050c20` | panel background |
| navy | `#0b1a3d` | raised surfaces, inputs, hover |
| blue | `#1a4bd6` | primary buttons, selection |
| blue-hi | `#3a6cff` | highlight edge, focus ring, active text |
| blue-glow | `rgba(38, 92, 255, 0.55)` | glow (use sparingly) |
| line | `rgba(92, 130, 255, 0.28)` | borders |
| line-dim | `rgba(92, 130, 255, 0.12)` | subtle dividers |
| text | `#e8eeff` | main text |
| text-dim | `#8d9bc4` | secondary text, labels |

- **Font:** `Oxanium` (Google Fonts, weights 500–800), fallback `'Rajdhani', 'Segoe UI', sans-serif`.
  Load it without blocking (`media="print" onload="this.media='all'"`).
- **Surfaces:** deep-navy glass panels, thin `line` borders, rounded corners (~10–12px).
- **Backdrop:** menus and dialogs dim the game **lightly** behind them
  (e.g. `rgba(3, 8, 19, 0.35–0.45)`). Never a heavy blackout.

**Keep it light:**
- No sound effects in menus/inputs.
- No heavy animation: at most a short fade/scale (~150–200ms) on open/close and simple
  hover transitions. No looping effects, particles, blur-heavy filters or big shadows.
- Vanilla JS where possible; don't add big libraries for small UIs.
- Keep the existing NUI message protocol and callback names so other scripts keep working.

**Layout reference for input dialogs (qb-input):** a single centered card
(title + close ✕ at top, labelled fields with a red `*` for required ones,
Cancel as a text button and the primary action as a filled button at bottom-right),
over the light backdrop. Colors from the table above, not from the reference screenshot.

## Other notes

- Many uploaded resources came from a leak source with Discord-ad comments and
  backdoors (obfuscated JS in odd/hidden file names, stray `@mysql-async` manifest lines,
  unknown `shared_scripts` JS). Scan every upload before importing; commit a cleaned
  import first, then changes.
- Files ending in `.min.js` have gone missing on the owner's server (likely antivirus);
  pages that depend on a local library should fall back to a CDN copy.
- Replies to the owner are in Arabic (Gulf dialect).
