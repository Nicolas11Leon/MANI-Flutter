---
name: MANI
description: Traceable service operations for multi-tenant companies, from request to close.
colors:
  brand: "#FED1B0"
  brand-soft: "#FFF2E8"
  on-brand: "#1C1613"
  on-brand-muted: "#63341E"
  ink: "#1C1613"
  ink-muted: "#5C5049"
  ink-subtle: "#665A52"
  on-ink: "#FFFFFF"
  background: "#FAF6F2"
  surface: "#FFFFFF"
  surface-muted: "#F3ECE6"
  surface-warm: "#FCE6D4"
  border-subtle: "#E4DAD1"
  success: "#15803D"
  success-text: "#166534"
  success-container: "#DCFCE7"
  warning: "#B45309"
  warning-text: "#92400E"
  warning-container: "#FEF3C7"
  palette-red: "#EE1C25"
  danger: "#D61921"
  danger-text: "#B01219"
  danger-container: "#FEE2E2"
  info: "#0065B3"
  info-text: "#005294"
  info-container: "#E0F0FF"
  accent: "#894C2F"
  accent-container: "#F7E6DC"
  dark-background: "#14110F"
  dark-surface: "#1F1A17"
  dark-surface-muted: "#2B2420"
  dark-surface-warm: "#362A22"
  dark-ink: "#F7F2ED"
  dark-ink-muted: "#C4B5AA"
  dark-ink-subtle: "#9E8E83"
  dark-border: "#D6C2B2"
  dark-border-subtle: "#3D332D"
  dark-brand-soft: "#3A291F"
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
  top-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    height: "68px"
  screen-heading:
    textColor: "{colors.ink}"
    typography: "{typography.headline}"
    padding: "24px 24px 8px"
---

# Design System: MANI

## Overview

**Creative North Star: "La ficha sellada"**

Every surface in MANI reads like a printed, stamped work card: a crisp card with a firm 2px outline, sitting on a warm paper ground, casting a hard offset shadow as if it had been pressed onto the desk. The brand color (`#FED1B0`, warm peach / peanut cream) is the stamp. It marks what matters right now (the active tab, the primary action, the selected option, the identity of the page) and nothing else. A service moves from request to close as a stack of these cards, and each one shows its state openly.

The system is neo-brutalist by product decision, supporting both **Light Mode** (`AppTheme.light` / `ManiTokens.claro`) and **Dark Mode** (`AppTheme.dark` / `ManiTokens.oscuro`, toggled via `maniThemeController` in the top bar). Density is moderate: the screens are working tools for clients, allies and tenant/platform admins, so structure, hierarchy and state come first, while expression lives in the outline, the hard shadow and the warm Maní stamp.

**Key Characteristics:**
- 2px outlines (`ManiBorder.regular`) on primary containers and controls; 1.5px (`ManiBorder.thin`) on inactive pills and internal dividers.
- Hard offset shadows (`2px`, `4px`, `6px`) with zero blur; they collapse when a control is pressed.
- Warm Maní palette: `#FED1B0` stamp fill, `#894C2F` roasted peanut accent, `#0065B3` cobalt blue operational info, `#EE1C25`/`#D61921` alert red, `#FFFFFF` card surface.
- Composed Dark Mode ("La ficha sellada nocturna"): warm roasted espresso surfaces (`#14110F` / `#1F1A17`), bone-cream 2px outlines (`#D6C2B2`), and `#FED1B0` stamps with dark `#1C1613` ink.
- Plus Jakarta Sans in heavy weights for titles and labels; medium for reading text.

## Colors

### Primary & Heritage
- **Stamp Peach (`#FED1B0`, `brand`)**: primary buttons, the active menu entry and tab, selected options, primary KPI/module icon badges, the logo square.
- **Pale Stamp (`#FFF2E8`, `brandSoft`)**: selected cards, secondary KPI badges, and highlighted rows.
- **Roasted Maní (`#894C2F`, `accent`)**: heritage warm brown accent for tenant badges, secondary status chips (`ManiTono.acento`), and on-brand secondary emphasis.

### Neutral (Light & Dark)
- **Espresso Ink (`#1C1613` light / `#F7F2ED` dark, `ink`)**: all primary text, outlines in light mode, focus rings.
- **Warm Muted (`#5C5049` light / `#C4B5AA` dark, `inkMuted`)**: secondary text, descriptions under titles.
- **Warm Subtle (`#665A52` light / `#9E8E83` dark, `inkSubtle`)**: hints, placeholders, tertiary metadata.
- **Warm Paper (`#FAF6F2` light / `#14110F` dark, `background`)**: the page ground behind every card.
- **Card Surface (`#FFFFFF` light / `#1F1A17` dark, `surface`)**: cards, fields, bars, dialogs.
- **Sunk Surface (`#F3ECE6` light / `#2B2420` dark, `surfaceMuted`)**: grouped backgrounds, secondary module cards, table headings.

### Semantic State (`ManiTono`)
- **Info (`#0065B3` / `#005294` on `#E0F0FF`)**: operational cobalt blue from the palette.
- **Danger (`#EE1C25` / `#D61921` / `#B01219` on `#FEE2E2`)**: destructive actions, errors, and open complaints.
- **Success (`#15803D` / `#166534` on `#DCFCE7`)**: completed services and active tenants.
- **Warning (`#B45309` / `#92400E` on `#FEF3C7`)**: pending reviews, late cancellations, and paused tenants.

### Named Rules
**The Stamp Needs Ink Rule.** Stamp Peach (`#FED1B0`) against the light paper ground is 1.4:1, so a brand fill always carries the 2px outline. Color alone never separates a brand surface.

**The Stamp Is Not Text Rule.** Stamp Peach is a fill, never a text color on light surfaces. On a brand fill, text is Espresso Ink (`#1C1613`, 11.9:1) and secondary text is On-Brand Muted (`#63341E`, 4.8:1).

**The Red Means Loss Rule.** Danger red is reserved for destructive or failed outcomes. A normal save is the primary stamp button, never red.
