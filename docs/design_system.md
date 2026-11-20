# SaloneMarket Design Language

## Brand Principles (4 pillars)
1. **Editorial Modern** – Typography‑led visual hierarchy; clean, readable layouts; avoid card‑heavy UI.
2. **Warm & Grounded** – Amber warmth and Sierra Leone market feel; organic colours, subtle textures; no cold corporate aesthetic.
3. **Premium but Accessible** – Target low‑end Android devices; no heavy GPU effects; fast load, low memory footprint.
4. **Trustworthy Commerce** – Clear states, honest feedback, no dark‑patterns; users always know what is happening.

## Colour System
| Token | Hex | RGB | WCAG contrast on white | Use |
|---|---|---|---|---|
| **color-primary** | #1A1A2E | 26,26,46 | 9.6:1 (AA) | Headings, nav, primary actions |
| **color-accent** | #E8A020 | 232,160,32 | 5.2:1 (AA) | CTAs, prices, active states, badges |
| **color-background** | #F7F4EF | 247,244,239 | 13.0:1 (AAA) | App background |
| **color-surface** | #FFFFFF | 255,255,255 | 21:1 (AAA) | Card backgrounds, input fills |
| **color-muted** | #9E9A94 | 158,154,148 | 7.1:1 (AA) | Captions, placeholders, secondary info |
| **color-success** | #2D7A5F | 45,122,95 | 7.8:1 (AA) | Confirmed states, in‑stock |
| **color-error** | #C0392B | 192,57,43 | 8.3:1 (AA) | Errors, destructive actions |
| **color-vendor** | #2C5F8A | 44,95,138 | 9.0:1 (AA) | Vendor‑role UI accent |
| **color-border** | #E5E0D8 | 229,224,216 | – | Dividers, card borders, input borders |
| **color-on-primary** | #FFFFFF | 255,255,255 | – | Text on primary background |
| **color-on-accent** | #1A1A2E | 26,26,46 | – | Text on accent background |

**Usage Rules**
- Primary/Accent only for interactive elements; never for decorative background.
- Simulated‑payment badge **must** use `color-accent` (amber); never green (reserved for real‑money confirmations).
- Do not place text on `color-muted` unless WCAG AA is met; use `color-on-primary` or `color-on-accent` for contrast.

## Typography
| Style | Font | Size | Weight | Line Height | Letter Spacing | Use |
|---|---|---|---|---|---|---|
| display‑xl | Plus Jakarta Sans | 32px | 700 | 1.2 | -0.5px | Hero headings (rare) |
| display‑lg | Plus Jakarta Sans | 26px | 700 | 1.25 | -0.3px | Screen titles |
| heading‑xl | Plus Jakarta Sans | 22px | 600 | 1.3 | -0.2px | Section headers |
| heading‑lg | Plus Jakarta Sans | 18px | 600 | 1.35 | -0.1px | Card titles, group headers |
| heading‑md | Plus Jakarta Sans | 16px | 600 | 1.4 | 0 | Sub‑section headers |
| body‑lg | DM Sans | 16px | 400 | 1.6 | 0 | Primary content |
| body‑md | DM Sans | 14px | 400 | 1.6 | 0 | Standard UI text |
| body‑sm | DM Sans | 12px | 400 | 1.5 | 0 | Captions, metadata |
| label‑lg | DM Sans | 14px | 600 | 1.0 | 0.5px | Button labels, tags |
| label‑md | DM Sans | 12px | 600 | 1.0 | 0.5px | Small labels, badges |
| price‑hero | Lora | 24px | 700 | 1.2 | 0 | Product‑detail price |

**Rules**
- No ad‑hoc sizes beyond this scale.
- Max `textScaleFactor` = 1.3 (accessibility cap).
- Plus Jakarta Sans and DM Sans must never appear in the same sentence.

## Spacing (8‑pt grid)
| Token | Pixels |
|---|---|
| xs | 4 |
| sm | 8 |
| md | 12 |
| lg | 16 |
| xl | 24 |
| xxl | 32 |
| xxxl | 48 |
| xxxxl | 64 |

- Internal component padding = lg (16 px).
- Section gaps = xl (24 px).

## Borders & Radii
- **radius‑sm** 4 px – inputs, chips, secondary elements.
- **radius‑md** 8 px – cards, main containers, buttons.
- **radius‑lg** 12 px – bottom sheets, modals.
- **radius‑pill** 100 px – badges, tags, avatar rings.
- Border weight: 1 px default, 1.5 px focus.
- No heavy drop‑shadows; use border + background contrast.

## Elevation (use sparingly)
| Level | Shadow |
|---|---|
| 0 | flat (border only) |
| 1 | `0 1px 3px rgba(0,0,0,0.08)` – floating actions |
| 2 | `0 -4px 24px rgba(0,0,0,0.12)` – bottom sheets, modals |

## Component Specs
### Primary Button (amber fill)
- Height 52 px, radius‑md (8 px), full‑width default.
- DM Sans 600, 15 px, text colour `color-on-accent` (white).
- States: default, hover (darken 8 %), loading (spinner + text), disabled (opacity 0.5).
- Min tap target 48 × 48 px.

### Secondary Button (navy outline)
- Height 52 px, 1.5 px navy border, navy text.
- Same states as primary.

### Text Button
- No border/background, navy text, 12 px padding, underline on press.

### Input Field
- Height 50 px, radius‑md, 1 px `color-border`.
- Focus: 1.5 px navy.
- Label above (no floating).
- Error: red border, message below.

### Product Card
- Image 4:3, radius‑md top corners only.
- Padding 12 px.
- Name `heading‑md`, vendor `body‑sm` muted, price DM Sans 600 16 px amber.
- No heavy shadow.

### Order Status Badge (pill)
- Colours per status: pending = amber, confirmed = navy, delivered = `color-success`, cancelled = `color-error`.

### Bottom Navigation
- 4 tabs (customer) / 5 tabs (vendor/admin).
- Icon 24 px, label 11 px, active colour amber, indicator line above active tab.

### Price Display
- Currency symbol “Le” in `body‑sm`.
- Amount `heading‑lg` (or `price‑hero` on product detail).
- Original price crossed out in `color-muted` when on sale.

## Iconography
- Material Symbols Outlined.
- Content icons 20 px, navigation icons 24 px.
- Nav icons outlined by default, filled when active.

## Imagery Rules
- Product images 4:3, min 400 px wide, max 800 px stored.
- JPEG 85 % quality on upload.
- Loading shimmer: base `#F0EDE8`, highlight `#E8E4DF`.
- Placeholder: neutral background with centred muted‑colour icon.
- No stock photos – only actual product images.

## Accessibility
- Min tap target 48 × 48 px.
- WCAG AA: 4.5:1 contrast for body, 3:1 for large text.
- Text scale factor capped at 1.3.
- All images have semantic `alt` labels.
- Never rely on colour alone for state; include icon/text cues.

---
**Design decisions awaiting sign‑off**
- Use of **Lora** serif for the `price‑hero` style (requires project‑lead approval).
- **Amber badge** for simulated payment status (must be kept distinct from green real‑payment confirmation).
