---
name: PerfectLiturgy
version: 1
colors:
  # Light surface (default)
  background: "#f6f1e7"        # cream, the page floor
  foreground: "#1c2a24"        # ink
  card: "#fbf8f1"
  muted: "#eee7d6"
  muted-foreground: "#56615a"  # secondary text
  primary: "#1f4d3b"           # forest, the action colour
  primary-foreground: "#f6f1e7"
  secondary: "#e8dfca"         # sand
  secondary-foreground: "#1f4d3b"
  destructive: "#a12a1c"
  border: "#d8cfb9"
  input: "#8a8068"             # control outline, 3.5:1 on cream
  ring: "#1f4d3b"
  emphasis: "#a63e1b"          # terracotta, the italic second line
  # Dark theme (follows the system setting)
  dark.background: "#111c17"
  dark.foreground: "#f1ebdd"
  dark.card: "#18261f"
  dark.muted-foreground: "#b3bdb5"
  dark.primary: "#e3b25a"
  dark.primary-foreground: "#1c2a24"
  dark.border: "#2c4036"
  dark.input: "#6f8b7c"
  dark.emphasis: "#e8906a"
  dark.sand.background: "#2a2820"
  # Forest band (.tone-forest) re-maps the same names
  forest.background: "#1f4d3b"
  forest.foreground: "#f6f1e7"
  forest.card: "#275a46"
  forest.muted-foreground: "#cfd8cb"
  forest.primary: "#e3b25a"    # gold buttons
  forest.primary-foreground: "#1c2a24"
  forest.border: "#4a7866"
  forest.input: "#7a9a8b"
  forest.emphasis: "#e3b25a"
  # Sand band (.tone-sand)
  sand.background: "#e8dfca"
  sand.card: "#f1ead9"
  sand.muted-foreground: "#4d5851"
  sand.input: "#766d57"
typography:
  logo: { family: "Cinzel", weight: 600, tracking: "0.04em", use: "The wordmark only" }
  display: { family: "Cormorant Garamond", weight: 500, size: "clamp(2.875rem, 7.2vw, 5.25rem)", leading: 1, tracking: "-0.02em" }
  heading: { family: "Cormorant Garamond", weight: 500, size: "clamp(2.25rem, 4.6vw, 3.5rem)", leading: 1.04, tracking: "-0.015em" }
  title: { family: "Cormorant Garamond", weight: 600, size: "1.625rem", leading: 1.15 }
  lead: { family: "Plus Jakarta Sans", weight: 400, size: "clamp(1.0625rem, 1.5vw, 1.25rem)", leading: 1.65 }
  body: { family: "Plus Jakarta Sans", weight: 400, size: "1rem", leading: 1.625 }
  eyebrow: { family: "Plus Jakarta Sans", weight: 600, size: "0.75rem", tracking: "0.16em", case: "uppercase" }
rounded: { sm: "4px", md: "6px", lg: "8px", xl: "12px", arch: "full top, 220/440 of the artwork width" }
spacing: { section: "py-20 md:py-28", section-compact: "py-14 md:py-16", container: "max-w-6xl, px-5 sm:px-8" }
---

# PerfectLiturgy design system

How the PerfectLiturgy Products look. The tokens live once, in `packages/ui/src/styles/globals.css`, and every app imports them. This file explains the choices. When a value here and the CSS disagree, fix both in the same change.

## Overview

A quiet, warm, printed-page feel: cream paper, deep green ink bands, one terracotta accent, and a serif that reads like a missal. The goal is a platform that feels like it belongs to the Church, not a software product. It is also built for modest phones and slow networks, so the look relies on type, colour and a little hand-drawn artwork, not on photographs, effects or heavy scripts.

Every Product (Landing site, Mass Times site, later the Choir site) shares these tokens, so a person moving between them is never in a different place.

## Voice

The words are part of the design. PerfectLiturgy should sound like a good parish bulletin: plain, warm, concrete and brief. A Catholic reader should feel it was written by someone who goes to Mass.

- **Say what is true today.** Mass Times is not open until it is. The apps are planned. No dates, no promised features, no "free" or "offline" unless the PRD says so.
- **Be concrete.** Name Sunday Mass, weekday Mass, Confession, Adoration, the Parish, the Church's own time zone, 12-hour times.
- **No country names.** PerfectLiturgy is for Catholics. Landing copy never names a country or continent.
- **Short sentences,** under about 20 words. No exclamation marks, no emoji, no em or en dashes.
- **Use the glossary.** Church is the building, Parish is the community, "Mass times" in running text, "Mass Times" only as the Product name. Say "iPhone app" for visitors (the stored key stays `ios`).
- **Banned:** closer, journey, companion, "whole life of the Church", "faith lived", discover, seamless, empower, elevate, "experience" as a noun about the product, "heart of it", "wherever you are", gathering as a marketing word, inspirational triads, and the "Not just X. Y." construction.
- **No borrowed text.** No Scripture, prayers, Hymn titles or lectionary text in copy (rights are open items O4 and O5).

## Colour

Colours are semantic (`bg-primary`, `text-muted-foreground`, `text-emphasis`). Components never use a raw colour.

| Role | Light | Used for |
| :--- | :--- | :--- |
| Background | cream `#f6f1e7` | Page floor |
| Foreground | ink `#1c2a24` | Headings and body text |
| Primary | forest `#1f4d3b` | Buttons and the dark bands |
| Secondary | sand `#e8dfca` | The beige band |
| Emphasis | terracotta `#a63e1b` | The italic second line of a heading, small icons |
| Muted foreground | `#56615a` | Secondary text |

**Bands re-theme through tokens.** A band is a `Section` with a `tone`. `forest` and `sand` set the same CSS variable names to new values, so every shadcn component placed inside (buttons, inputs, badges, checkboxes) adapts with no extra classes. On forest, the primary button turns gold and the emphasis colour turns gold. Do not add per-band or `dark:` colour classes to components; both themes change tokens only.

**Contrast, measured** (WCAG 2.1 AA needs 4.5:1 for text, 3:1 for large text and control outlines):

| Pair | Ratio |
| :--- | :--- |
| Ink on cream | 13.3 |
| Muted text on cream / card | 5.7 / 6.1 |
| Muted text on sand | 5.6 |
| Cream on forest | 8.6 |
| Muted text on forest | 6.6 |
| Gold on forest | 4.9 |
| Ink on the gold button | 7.7 |
| Terracotta on cream / sand | 5.6 / 4.8 |
| Input outline on cream / on forest | 3.5 / 3.1 |

### Dark theme

The site follows the visitor's system setting (`prefers-color-scheme`). There is no toggle and nothing to configure. Only the token values change, in one `@media` block in `globals.css`, so no component carries `dark:` colour classes.

| Role | Dark value |
| :--- | :--- |
| Background | `#111c17` (deep green-black) |
| Foreground | `#f1ebdd` |
| Card | `#18261f` |
| Primary (buttons) | gold `#e3b25a`, ink text |
| Emphasis | light terracotta `#e8906a` |
| Muted text | `#b3bdb5` |
| Control outline | `#6f8b7c` |
| Sand band | warm dark `#2a2820` |

The forest band keeps its colours in both themes; it simply stands out against the darker page. Contrast, measured: text on background 14.7, muted text 9.0, emphasis 7.2, gold 9.0, ink on gold 7.7, control outline 4.7 (needs 3). The church artwork keeps its light palette in both themes.


### Illustration palette

The church artwork (`apps/landing/src/components/arch-scene.tsx`) has its own small palette (forest, cream, gold, terracotta, two hill browns, sun yellow). It is artwork, not interface, so it is kept beside the artwork and is not a token.

## Typography

Three families, each with one job, loaded with `next/font` (self-hosted, no request to Google at runtime):

1. **Cinzel**, 600: the wordmark and nothing else.
2. **Cormorant Garamond**, 500 and 600, upright and italic: every heading.
3. **Plus Jakarta Sans**, variable: body text, labels, buttons, forms.

**The two-line heading.** Headings use a lead line in ink and an optional second line in italic terracotta (gold on forest): "Every Parish, every Mass, / *in one place.*". Use the `Heading` component (`lead`, `emphasis`) so this stays consistent. One emphasised line per heading, never inside a sentence.

Type utilities (`type-display`, `type-heading`, `type-title`, `type-lead`, `type-eyebrow`) are defined once in the CSS. Cormorant is light and small at body sizes, so it is never used below 1.5rem. Eyebrows are always uppercase with wide tracking and lead with a short terracotta rule (`Eyebrow`).

## Shape and spacing

- Radius is small: 4 to 8 px on controls and cards, so the page feels like paper, not like an app. The only large curve is the **arch**, a church-window shape reserved for the illustration frames.
- Sections are full-width bands inside a `max-w-6xl` container. `Section` owns padding and tone.
- Dividers are hairlines (`Separator`) with generous padding, not boxed cards.
- Elevation: none. Cards are flat tints. Separation comes from colour and whitespace, not shadow.

## Components

Built on shadcn/ui (new-york style, Radix) in `packages/ui`. Rules:

- **Server-safe on public pages.** Public pages must work without JavaScript and ship almost none, so `Separator` is a server-safe version of the shadcn component: a native element wearing its name and classes, with no Radix client code. Do the same for any shadcn component you add (shadcn's `Label` and `Checkbox` also wrap Radix and need JavaScript). `Button` and `Badge` use Radix `Slot`, which only runs on the server. Adding a Radix interactive component (dialog, dropdown, popover, tabs) to a public page is not allowed; use it only in features a visitor triggers.
- **Buttons** are 44 px tall (`default`), 48 px (`lg`). Variants: `default` (forest, gold on forest), `outline`, `ghost`, `link` (underlined text with an arrow, for secondary actions), `secondary`. One primary button per band.
- **Forms** use shadcn's `Field` + `FieldLabel` + `FieldDescription` + `FieldError`, with `FieldSet` and `FieldLegend` for grouped checkboxes. Invalid controls set `aria-invalid`. On signed-in Mass Times screens, `ActionForm` and `FormField` wrap these so every action shares one error shape. Public filters are chips and a GET form, not a client form library.
- **Brand components** (`packages/ui/src/components/brand`): `Logo`, `Heading`, `Eyebrow`, `Section`/`Container`, `Hero`, `Band`, `IconCard`, `ArchScene`. `Hero` is the first band of a Product home (text and one primary action, artwork in the arch). `Band` is a forest close. `IconCard` is the flat card with its icon in a round sand tile.
- **Product cards** on the Landing site are `IconCard`: one card per Product, not per platform. Mass Times (lucide `Church`) and the PerfectLiturgy app (lucide `Smartphone`). The app card carries one button per mobile platform with its mark (Android and Apple, simple-icons, CC0, inline SVG in `apps/landing/src/components/brand-icons.tsx`). Platforms are a list in `content/products.ts`; a new one is one entry.
- **Chips** (`Chip`, `ChipChoice`) are the only pill. As a link (`asChild`) a Chip is a filter that works without JavaScript. `ChipChoice` wraps a native radio or checkbox so a GET form can look the same. Selected is forest fill; idle is a hairline. Press scale matches the Button (0.97, 150 ms, ease-out).
- **Icons** are `lucide-react`, 1.5 to 1.75 px stroke, used sparingly, always `aria-hidden` beside a text label.
- **Adding a component:** run `shadcn` from `packages/ui`, then fix the generated imports (the CLI writes `from "cn"`, it must be `../../lib/utils`) and remove `"use client"` and Radix if the component can be a native element.

## Do

- Write headings as lead + emphasis, in the Voice above. Keep copy short, plain and warm.
- Use band tones for rhythm: cream, forest, sand, forest.
- Keep one idea and one primary action per band.
- Use the GLOSSARY terms in every piece of copy.
- Check contrast with the table above before adding a colour pair.
- Respect `prefers-reduced-motion`. See Motion below.

## Don't

- No gradients in the interface (the soft sky inside the church artwork is the one exception), and no glass, glow, blobs, drop shadows, emoji, stock photography or AI-generated artwork.
- No marketing language or slogans. If a line could sit on any startup site, rewrite it.
- No raw colours or `dark:` classes in components. Use the tokens.
- No `space-x-*` / `space-y-*`; use `flex` with `gap-*`.
- No sizing classes on icons inside buttons; the button sizes them.
- No Cinzel outside the wordmark; no Cormorant below 1.5 rem.
- No client-side data fetching and no Radix interactive components on public pages.
- No copyrighted text in copy, seed data or tests (see AGENTS.md).

## Motion

Restraint is the rule. This is a quiet reading surface, visited rarely, so motion only confirms and orients.

- **Press feedback.** Every `Button` scales to 0.97 on press (150 ms, ease-out), so the page feels like it heard the tap. Reduced-motion users get no scale.
- **Arrows nudge 2 px** on hover inside a button. Hover effects only run on devices that can hover (Tailwind's `hover:` already gates this), so touch screens never get stuck states.
- **No entrance animation.** Content is on screen the moment the page loads. An entrance effect that starts from zero opacity risks hiding the headline from slow devices, scrapers and print, for no gain on a page seen once.
- **Never** animate with `transition: all`, ease-in, or from `scale(0)`. Animate only `transform`, `opacity` and colour. Keep UI motion under 300 ms.
- Smooth anchor scrolling ("Get the apps") is off under reduced motion.

## Responsive

Mobile first. Two columns appear at `md` (768 px): hero text beside artwork, heading beside paragraph, list rows as columns. Below `md`, everything stacks, artwork is centred and capped at `max-w-sm`, and tap targets stay at least 44 px. Verified at 360, 390, 768 and 1280 px with no horizontal scroll.

The Mass Times header keeps Find Mass, Near me, Help us and Sign in (or Account) in a row from `md` up. On a phone the same links sit in a native `<details>` menu, so the header works without JavaScript.

## Mass Times

The directory is a reading surface first. A person looking for Mass should see times before anything else. Interactive pieces (map, near me, editor, review) stay off the first paint and load only when asked for.

- **Page head.** Every interior page opens with `Eyebrow` + `Heading` (lead + terracotta emphasis) + a short intro. One idea per page. The home page is the only `Hero`.
- **Filters.** Day, Service kind, language, time of day and sort are `Chip` links on a GET URL. On a phone they scroll sideways inside the page; from `sm` they wrap. The row label is a `w-24` eyebrow so "Language" does not run into the first chip. A `<details>` holds the quieter filters. Reset is a text link, never a second primary button.
- **Times.** A Service time is a Chip. The Church page shows today's Services first, then the week. A tiny client island highlights today once the browser's date is known; the full week is always in the HTML.
- **Results and map.** The list is the source of truth. Numbered pins match the list. On `md` and up the map sits beside the list; on a phone it is behind Show map. Leaflet and its tiles load only after that tap (or after the map scrolls into view on a Church page).
- **Tables.** Shared `Table` for the review queue, Moderators, places and the audit log. Hairline rows, no zebra, no shadow. Status is a word (`Waiting`, `Approved`, `Not approved`), not a colour-only badge.
- **Workspace.** Signed-in screens share one chip nav (Account, Add a Church, Send a bulletin, Review, Admin). Admin adds a second row of text links. The same `ChurchEditor` serves add, suggest a change, and edit-then-approve. `ActionForm` is the only submit wrapper.
- **Numerals in titles.** Cormorant at display size makes some digits look like letters. Stat cards use words ("2 requests"), not a bare number.

## Known gaps

- The church artwork is not re-coloured for dark mode. If it looks too bright beside a dark page, dim it with a CSS filter rather than a second set of drawings.
- The Open Graph image uses a system serif, not Cormorant, because loading fonts into `ImageResponse` was not worth the cost for Phase 0.
- Terracotta on sand is 4.8:1; keep it for large headings or bold text on sand, never for small body text.
