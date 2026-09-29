# Rak — FiveM (QBCore) server resources

## UI style (applies to every NUI we build or edit)

The owner wants one consistent look across all UIs: the **qb-radialmenu** identity
(`qb-radialmenu/html/css/RadialMenu.css`). Any new UI, and any UI we touch, uses it.

**Colors** — the shared `--cm-*` tokens (same in qb-menu, qb-input and the owner's
current radial menu: mostly black, with the MDT blue on the edges):

| token | value | use |
|---|---|---|
| panel | `rgba(12, 13, 17, 0.96)` | panel background |
| head | `#121419` | header / footer strip |
| row | `#111317` | list rows |
| row-hover | `#16191f` | selected / hovered row |
| well | `#0b0c0f` | input fields |
| key | `#1b1d22` | keycap boxes (1-9, ENTER, ESC) |
| line | `rgba(255, 255, 255, 0.06)` | subtle borders |
| line-mid | `rgba(255, 255, 255, 0.11)` | field borders |
| edge | `#3b9dfb` | the blue: panel top edge, focus, selection, primary button |
| edge-dim | `rgba(59, 157, 251, 0.5)` | panel border, selected row border |
| edge-soft | `rgba(59, 157, 251, 0.14)` | selected chip / switch fill |
| text | `#f3f5f9` | main text |
| text-dim | `#a3aab7` | labels, secondary text |
| text-mute | `#6d7380` | hints, placeholders |
| bad | `#ef5a5a` | errors, required `*` |
| dim | `rgba(0, 0, 0, 0.35–0.45)` | backdrop behind menus / dialogs |

(The repo copy of `qb-radialmenu` is an older navy version; the server's radial menu
uses the tokens above.)

- **Font:** `Cairo` (Google Fonts, 600/700 — it has Arabic), fallback `'Segoe UI', Tahoma, sans-serif`.
  Load it without blocking (`media="print" onload="this.media='all'"`). Text inputs get `dir="auto"`.
- **Surfaces:** solid near-black panels, 1px `edge-dim` border with a 2px `edge` top border,
  rounded corners (~10–12px).
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
- Files ending in `.min.js` have gone missing on the owner's server (likely antivirus);
  pages that depend on a local library should fall back to a CDN copy.
- Replies to the owner are in Arabic (Gulf dialect).
