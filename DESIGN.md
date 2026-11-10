---
name: MANI
description: Traceable service operations for multi-tenant companies, from request to close.
colors:
  brand: "#F8DE7E"
  brand-soft: "#FDF3D2"
  on-brand: "#1E1E1E"
  on-brand-muted: "#5F583B"
  ink: "#1E1E1E"
  ink-muted: "#5F6672"
  ink-subtle: "#666D79"
  on-ink: "#FFFFFF"
  background: "#FDFBF7"
  surface: "#FFFFFF"
  surface-muted: "#F5F3EE"
  surface-warm: "#F6EFDA"
  border-subtle: "#E5E7EB"
  success: "#15803D"
  success-text: "#166534"
  success-container: "#DCFCE7"
  warning: "#B45309"
  warning-text: "#92400E"
  warning-container: "#FEF3C7"
  danger: "#DC2626"
  danger-text: "#B91C1C"
  danger-container: "#FEE2E2"
  info: "#1D4ED8"
  info-text: "#1E40AF"
  info-container: "#DBEAFE"
  accent: "#3730A3"
  accent-container: "#E0E7FF"
typography:
  display:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "40px"
    fontWeight: 900
    lineHeight: 1.05
    letterSpacing: "-0.8px"
  headline:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "24px"
    fontWeight: 900
    lineHeight: 1.15
    letterSpacing: "-0.5px"
  title:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "18px"
    fontWeight: 900
    lineHeight: 1.25
  body:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.45
  label:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "13px"
    fontWeight: 800
    letterSpacing: "0.2px"
  overline:
    fontFamily: "Plus Jakarta Sans, sans-serif"
    fontSize: "11px"
    fontWeight: 800
    letterSpacing: "0.6px"
rounded:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "999px"
spacing:
  xxs: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
  xxxl: "32px"
  huge: "40px"
  giant: "48px"
components:
  button-primary:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "13px 20px"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "13px 20px"
  button-danger:
    backgroundColor: "{colors.danger}"
    textColor: "{colors.on-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "13px 20px"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
  card-selected:
    backgroundColor: "{colors.brand-soft}"
    rounded: "{rounded.lg}"
    padding: "16px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "14px 16px"
  status-badge:
    rounded: "{rounded.pill}"
    typography: "{typography.overline}"
    padding: "5px 10px"
  page-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    padding: "12px 32px"
---

# Design System: MANI

## Overview

**Creative North Star: "La ficha sellada"**

Every surface in MANI reads like a printed, stamped work card: a white card with a firm charcoal outline, sitting on a warm paper ground, casting a hard shadow as if it had been pressed onto the desk. The brand color is the stamp. It marks what matters right now (the active tab, the primary action, the selected option, the identity of the page) and nothing else. A service moves from request to close as a stack of these cards, and each one shows its state openly.

The system is neo-brutalist by product decision, taken from the official Figma prototypes and kept on purpose when the product owner chose refinement over replacement (2026-11-10). Density is moderate: the screens are working tools for clients, allies and tenant admins, so structure and state come first and expression lives in the outline, the shadow and the stamp. Light only; there is no dark theme.

**Key Characteristics:**
- Charcoal 2px outlines on every container and control; the outline, not the fill, separates surfaces.
- Hard offset shadows with no blur; they collapse when a control is pressed.
- One stamp color (#F8DE7E) used for state and primary action, always with its outline.
- Plus Jakarta Sans in heavy weights for titles and labels; medium for reading text.
- A single page bar under the main menu on every in-app screen.

## Colors

A warm paper ground, white cards, charcoal ink and a single soft-butter stamp color; state colors appear only where they carry meaning.

### Primary
- **Stamp Butter** (brand): primary buttons, the active menu entry and tab, selected options, the icon box of every page bar and empty state, the logo square. Pinned by the product owner.
- **Pale Stamp** (brand-soft): selected cards and highlighted rows.

### Neutral
- **Charcoal Ink** (ink): all primary text, every outline, every hard shadow, focus rings.
- **Slate Muted** (ink-muted): secondary text, descriptions under titles.
- **Slate Subtle** (ink-subtle): hints, placeholders, tertiary metadata.
- **Warm Paper** (background): the page ground behind every card.
- **Card White** (surface): cards, fields, bars, dialogs.
- **Sunk Paper** (surface-muted): grouped backgrounds, neutral chips, table headings.

### Tertiary (state)
- **Success / Warning / Danger / Info / Accent**, each a container tint with its own AA text tone. They are expressed through `ManiTono` and the status badge, never as free-floating colors.

### Named Rules
**The Stamp Needs Ink Rule.** Stamp Butter against the paper ground is only 1.3:1, so a brand fill always carries the charcoal outline. Color alone never separates a brand surface.

**The Stamp Is Not Text Rule.** Stamp Butter is a fill, never a text color. On a brand fill, text is Charcoal Ink (12.5:1) and secondary text is On-Brand Muted (5.3:1); the gray Slate Muted fails there (4.3:1).

**The Red Means Loss Rule.** Danger red is reserved for destructive or failed outcomes. A normal save is the primary stamp button, never red.

## Typography

**Display Font:** Plus Jakarta Sans (with the platform sans-serif)
**Body Font:** Plus Jakarta Sans

**Character:** One family carries the whole system. Weight does the work: 900 for titles, 800 for labels and controls, 500 to 600 for reading text, so a card reads as a heading, its fields and its fine print at a glance.

### Hierarchy
- **Display** (900, 40px, 1.05): the login brand panel headline only.
- **Headline** (900, 24 to 32px): large section headings, rare inside the app.
- **Title** (900, 18px, 1.25): the page bar title and dialog titles.
- **Body** (500, 14px, 1.45): descriptions and content; secondary body at 13px in Slate Muted.
- **Label** (800, 13px, 0.2px tracking): buttons, tabs, field labels.
- **Overline** (800, 11px, 0.6px tracking, uppercase): field captions and status badges.

### Named Rules
**The Weight Before Size Rule.** Hierarchy steps by weight first and size second; every size comes from the scale (10, 11, 12, 13, 14, 16, 18, 20, 24, 32, 40).

**The Variant Font Rule.** Every style goes through Plus Jakarta Sans for its own weight; the theme sets no global font family, which would collapse bold text into synthetic bold.

## Layout

A 4-point spacing scale (2 to 48) for padding and gaps. Signed-in screens stack the main menu, the page bar and the content. Content is centered at a width cap chosen by screen type: narrow 480 (access, dialogs), form 720, list 880, panel 1200, dashboard 1400. On phones everything takes the full width with 16px side margins, and page bar actions drop to a second row below 600px. The shell menu becomes a compact menu below its desktop breakpoint; registration and login switch to two columns from 850px.

### Named Rules
**The Width By Job Rule.** A screen's content width comes from what it is (form, list, panel), never from a literal. Fields never stretch to the full desktop width.

## Elevation & Depth

Depth is structural and hard-edged. Surfaces sit on the paper ground with an offset shadow and no blur; the offset grows with prominence and collapses on press, so the card or button visibly "stamps" into place. There is no tonal elevation and no soft ambient shadow anywhere.

### Shadow Vocabulary
- **Stamp Small** (2px 2px 0 Charcoal Ink): buttons, icon boxes, chips that act like buttons.
- **Stamp Medium** (4px 4px 0 Charcoal Ink): cards and sections at rest.
- **Stamp Large** (6px 6px 0 Charcoal Ink): selected or hovered cards, the logo.

### Named Rules
**The Press Collapses Rule.** A pressed control loses its shadow and moves by the shadow's offset (a transform, never a layout change). Hover lifts by 1px and grows the shadow one step.

## Shapes

Gently rounded rectangles throughout: 12px for controls, fields and small panels, 16px for cards and sections, 8px for small boxes and menu items, a full pill for status badges and counters. Outlines are 1.5px (chips, rows, dividers), 2px (standard) or 2.5 to 3px (focus, dialogs).

## Components

### Buttons
- **Shape:** gently rounded (12px), 2px charcoal outline, Stamp Small shadow.
- **Primary:** Stamp Butter fill, Charcoal Ink label in uppercase-friendly 900 weight (13px), 13px by 20px padding.
- **Secondary:** Card White fill, same outline and shadow.
- **Danger:** Danger red fill with white label, only for destructive actions.
- **Hover / Focus / Press:** hover lifts 1px and grows to Stamp Medium; keyboard focus draws a charcoal ring outside a thin stamp ring; press collapses the shadow. Disabled drops to 45% opacity without a shadow.

### Status badges
- **Style:** pill, 1.5px charcoal outline, tinted container from `ManiTono` with its AA text tone, an icon before the label so state never depends on color alone.

### Cards / Containers
- **Corner Style:** 16px.
- **Background:** Card White; Pale Stamp when selected.
- **Shadow Strategy:** Stamp Medium at rest, Stamp Large when selected or hovered.
- **Border:** 2px Charcoal Ink.
- **Internal Padding:** 16 to 20px.

### Inputs / Fields
- **Style:** Card White fill, 2px charcoal outline, 12px radius, 14px by 16px padding, uppercase overline caption above.
- **Focus:** outline thickens to 3px.
- **Error:** Danger outline with the message in Danger Text below; disabled uses the subtle border.

### Navigation
- **Main menu:** a white top bar with the logo and session identity, and a row of outlined pill entries below; the active entry is filled with Stamp Butter. On narrow screens it collapses into a menu button.
- **Page bar:** directly under the menu on every in-app screen: a 40px Stamp Butter icon box with Stamp Small shadow, the title (18px, 900), an optional description and the screen's actions on the right. A back arrow appears when the screen opened on top of another.

### Empty, error and loading states
- **Empty:** a Stamp Butter circle with an icon, a title and one explanatory line, plus the action that resolves it.
- **Error:** a Danger Container card with the message and "Reintentar".
- **Loading:** skeleton cards shaped like the content, static under reduced motion; a centered spinner where the shape is unknown.

## Do's and Don'ts

### Do:
- **Do** give every brand fill its 2px charcoal outline (The Stamp Needs Ink Rule).
- **Do** start every in-app screen with the shared page bar and take its width from the width tokens.
- **Do** express state through `ManiTono` and the status badge, with an icon.
- **Do** keep every value on the token scales (color, spacing, radius, type size, width, motion).

### Don't:
- **Don't** use Stamp Butter as a text color or rely on it without an outline.
- **Don't** use red for a non-destructive action.
- **Don't** add soft, blurred shadows or tonal elevation; depth is the hard offset stamp.
- **Don't** let fields or cards stretch to the full desktop width.
- **Don't** invent customer metrics, testimonials or logos in any surface.
