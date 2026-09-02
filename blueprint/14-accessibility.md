# 14 · Accessibility

> **The irony that justifies this document:** the site that is *"the worst on the layout gate"*
> (27.7 screens of scroll) is **the best of the five on accessibility** — 0 failures out of 709
> elements, worst pair 8.89:1, complete autocomplete. The site that is *"the only one that
> passed the density gate first time"* has **38 failures, including its primary button.**
>
> **Passing the gates we had says nothing about accessibility**, because none of them measures
> it. That is the hole.
>
> Measured over 5 sites, locally, with headless Chrome serving each repo over HTTP and
> injecting a probe: **36 composed pages** (a real 1280 desktop plus a real 390 mobile via an
> `<iframe>`) and **148 pages** in a static sweep.
>
> **This document does not yet have a gate wired to the door.** Until it does, this is a
> specification without a gate.

---

## 0 · The hole, verified

A sweep over the entire system before this was written:

| Term | Where it appeared |
|---|---|
| `WCAG` | Two documents, **and only** to cite the line-length criterion |
| `aria-` | One document, and it was about naming a `<nav>` |
| `aria-live` · `autocomplete` · `focus-visible` · `skip link` · `landmark` · `lang=` · `44x44` · `24x24` | **0** |

The final QA checklist named it once, and that was to say it had **not** been looked at. That
is honest, and it is exactly where blind spots hide: **a "not looked at" list that never gets
updated stops being a warning and becomes an alibi.**

---

## 1 · A1–A16: what is required, and where the five sites stood

The thresholds come from **what was measured**, not from theory. Every row carries its WCAG
criterion so it can be argued with the standard open, not with an opinion.

| # | Check | WCAG | Threshold | State across 5 sites |
|---|---|---|---|---|
| **A1** | Text contrast, **whole page** (including nav, header, footer) | 1.4.3 AA | ≥ 4.5:1 · ≥ 3:1 at ≥ 24 px or ≥ 18.66 px bold | **149 failures of 3,225 measured.** 98 · 38 · 13 · 0 · 0 |
| **A2** | Contrast of control boundaries (border **or** fill, whichever is better) | 1.4.11 AA | ≥ 3:1 | **84 of 118 measured below.** One site 22/22 |
| **A3** | `alt` on every `<img>` | 1.1.1 A | 0 missing the **attribute** · `alt=""` only if decorative | **0 on all five.** See §5 |
| **A4** | Inline SVG: decorative marked hidden, informative named | 1.1.1 A | 0 unmarked inside a link or button | **184** inside actions on one site (214 unmarked in total). The other four, 0 |
| **A5** | Accessible name on links and buttons | 2.4.4 / 4.1.2 A | 0 unnamed | 0 |
| **A6** | A label on every field — **a `placeholder` is NOT a label** | 3.3.2 A | 0 without a label | 0 on all five, and 0 placeholder-only |
| **A7** | `autocomplete` on name, email and phone | **1.3.5 AA** | 0 missing | **18 of 63 fields on one site · 3 of 28 on another** |
| **A8** | A live region for form errors | 3.3.1 A | ≥ 1 `aria-live`/`role="alert"` per form | **0 on three of five.** Somebody who cannot see the screen never learns the submission failed |
| **A9** | Visible focus indicator | 2.4.7 AA | 0 focusable elements with no visible change | 0 of 1,289 tested — **but see §4: that was programmatic focus, not tabbing** |
| **A10** | Touch target at 390 px | **2.2 SC 2.5.8 AA** | ≥ 24×24 **or** the spacing exception | **0 failures on all five.** See §5: 44×44 is AAA and **is not failed** |
| **A11** | Landmarks | 1.3.1 A | 1 `<main>` · 1 `<h1>` · named `nav` if there is more than one | 3 static pages with no `<main>` on one site |
| **A12** | Heading order without skips | 1.3.1 A | 0 skips | **10 real on one site** · 1 each on three others |
| **A13** | Skip link to content | 2.4.1 A | present, with an existing target | **7 of 8 measured pages missing it on one site.** The other four have it |
| **A14** | `lang` declared and correct | 3.1.1 A | always | correct on all five |
| **A15** | Zoom not blocked | 1.4.4 AA | no `user-scalable=no`, no `maximum-scale=1` | 0 across 148 pages |
| **A16** | `prefers-reduced-motion` cancels duration **AND DELAY** | 2.3.3 AAA / house habit | see the traps log | **two sites cancel duration and not delay** |

**The honest total:** 149 text failures over 3,225 measured elements, with **167 not
measurable** (text over a photo or a gradient) and **1,094 skipped as invisible.** Read §4
before using any of these numbers.

---

## 2 · The failure that is worth all the others: ONE token, not 136 pages

**100% of the contrast failures on two sites — 136 elements, 2 colour pairs on one and 6 on
the other — come from ONE variable.**

Both stylesheets carry the same palette block **character for character, comments included**:

```css
--primary:            oklch(0.58 var(--brand-c) var(--brand-h));  /* 4.84:1 on white */
--primary-foreground: oklch(0.99 0.005 var(--brand-h));
```

**The comment is false.**

| pair | real ratio | the comment says | verdict |
|---|---|---|---|
| primary on white | **4.11:1** | "4.84:1" | fails AA for normal text |
| foreground on primary | **4.01:1** | (no comment) | **it is the primary button on both sites** |

**And the irony has to be read to the end:** that stylesheet warns, two lines above its own
palette — *"the contrasts below are MEASURED in a browser, not calculated… do not trust a
comment for a colour"* — and **carries, directly underneath, a comment for a colour that is
wrong**, copied into two client sites in production.

### The rule

> **A palette is not inherited: it is re-measured on the destination site, and the number is
> written by the gate, not by a person.**

**The three pairs that always matter**, because they are where it always fails:

1. `primary` / `primary-foreground` — **the button.**
2. `primary` / white — brand text on a light background.
3. The eyebrow over its tinted background — it is born small (12–14 px) and in brand colour, so
   it is the first to fall. The four worst pairs on one site were exactly that: 3.80, 3.94,
   3.73 and **3.59:1**.

### The method: a lightness sweep — the most transferable thing in this document

One stylesheet carries, next to the token, the entire sweep that was done to fix it:

| L in `oklch(L 0.09 210)` | ratio against the foreground | verdict |
|---|---|---|
| 0.58 | **4.02:1** | FAIL |
| 0.56 | 4.40:1 | FAIL |
| 0.55 | 4.59:1 | borderline |
| **0.54** | **4.79:1** | **PASS** ← chosen |

*(4.02 here and 4.01 from the probe: that is rounding, the two measurements agree.)*

With a note that saves the next iteration: **making the text pure white would NOT have been
enough** (4.11:1). The problem was the lightness of the background, not the text.

**You move a single variable and check the five selectors that depend on it.** That sweep is
the only measured procedure we have for choosing a brand colour that meets AA, and until this
document it lived **in a comment in one repository.** If that repo stops being touched, it is
lost.

> **State at the time of measuring:** one site was fixed **in the repo** while **production was
> still serving the old value** (verified by byte count: 20,648 served against 21,769 in the
> repo). The other site was **not fixed anywhere.**

---

## 3 · How it is measured, and why that way

### 3.1 · A probe does NOT write to the page it is measuring

The gate we already had resolved colour **by writing into a `<span>`** and reading the computed
style. With the flags **our own guidance requires**, that breaks **silently**:

1. The page carries the reduced-motion escape hatch `*{transition-duration:0.01ms!important}` —
   and `transition-property` defaults to `all`, so **any style write becomes a transition.**
2. It is measured with a virtual time budget, which **freezes time near t=0.**

Result: it reads the colour **from before**, serialised in a colour space the parser did not
expect, and the parser divides the numbers by 255 → **`#010000` for EVERYTHING.** On one site
it reported **628 of 628 elements failing** with foreground equal to background. Another site
escaped **because it used `0.001ms` instead of `0.01ms`**: the gate worked or did not depending
on an irrelevant detail of the site being measured.

> **General rule for any future probe:** if it has to write in order to measure, what it reads
> back may be the value from before. **Measure by canvas, by calculation, or through a
> read-only property.**

### 3.2 · Two pieces of infrastructure that solve traps already paid for

- **Serve over HTTP, do not open with `file://`.** Three of the five write their assets with
  **absolute paths**: from `file://` that resolves to the filesystem root, the page composes
  **with no CSS at all**, and any colour measurement is rubbish. Also, from the same origin the
  probe **can read the stylesheets** — cross-origin throws a security error.
- **Real mobile through an `<iframe width=390>`.** Headless Chrome on Windows **clamps the
  window to about 500 px.** Verified in this sweep: desktop reports `innerWidth` 1280 when
  asked for **1298**; inside the iframe, a genuine 390.
  **Print `innerWidth` and confirm it matches, always**, before believing any measurement.

### 3.3 · A zero from a CSS walk gets cross-checked with a grep

`if (rl.cssRules) { recurse(...); continue; }` **skips every style rule** now that Chrome
supports CSS nesting: an ordinary style rule also exposes an (empty) rule list. It counted
**0** focus-visible rules in a stylesheet that has 2. A control grep over the file caught it,
not the probe.

---

## 4 · "Not measurable" is not "passed" — how it gets reported

**Every accessibility result is given with three numbers: failing / measured / skipped.**
Without all three, a zero means nothing.

| Site | failing | measured | skipped as invisible | not measurable (over photo) |
|---|---|---|---|---|
| 1 | 0 | 601 | 272 | 35 |
| 2 | 38 | 427 | 150 | 4 |
| 3 | 0 | 709 | **58** | 18 |
| 4 | 98 | 708 | **449** | 40 |
| 5 | 13 | 780 | 165 | 70 |

**Site 3's zero and site 4's 98 are not comparable without the third column:** one skipped 449
elements and the other 58. Site 4's 98 failures are real and sit among the measured, so that
comparison holds — but **site 3's zero covers far more of its surface than any zero of site
4's.**

**The 167 elements over photos or gradients are NOT measured.** The tool exists — it renders
with the text hidden and measures the **worst** pixel — and it has not been run. They are
declared; they are not passed by omission.

**And the 1,094 skipped are almost all mobile menus and closed accordions the probe does not
open.** On one site at 390 px only **27** focusable elements were tested against 185 on
desktop: mobile is measured four times worse than desktop, and that has to be said before
anybody gives a mobile verdict.

---

## 5 · Where the rule does NOT apply — five false positives already caught

A check that produces false positives **trains people not to read its output**, and that is
worse than not having it. All five are measured:

1. **`alt=""` is NOT a missing `alt`.** It is the **correct** value for a decorative image. The
   check as first written counted it as an absence and produced **165 false positives.** The
   real count is **0 images with no `alt` attribute across all five sites.** You fail on a
   **missing attribute**, never on an empty value.
2. **44×44 px is AAA, not AA.** Between 94 and 208 targets per site fall below it, and **that
   is not a defect**: the applicable criterion (WCAG 2.2 SC 2.5.8, **24×24**) is passed by all
   five with **0 failures.** Keep 44 as a reference target, **not as a fail.** And implement the
   **spacing exception**: without it, one home page alone produced 16 false failures.
3. **The anti-spam honeypot trips the "hidden element with focusable descendants" check.** The
   honeypots are **correctly built**: they carry `tabindex="-1"` and autocomplete off. The check
   has to exclude `[tabindex="-1"]` **on the element itself**, not only in the selector.
4. **A decorative SVG marked hidden is correct**, not a naming failure. What you fail is the
   SVG **left unmarked inside a link or a button**, which a screen reader announces as noise or
   as nothing: the 184 on one site.
5. **Heading skips inside a `<footer>` or a third-party widget** are not the page's. Of one
   site's 14 "skips", **10 are real** and in the body; the rest come from the chrome. Count
   inside `<main>` and declare the rest separately.

---

## 6 · What is still UNLOOKED-AT, and needs a human

**Measured is not all of A1–A16. What remains is this, and it gets said:**

- **A real keyboard walkthrough.** A9 was measured with programmatic focus, and that **is not
  tabbing**: it says nothing about the real **order**, nor about focus traps in the cookie
  banner and the mobile menu, nor about whether you can get out of them.
- **A real screen reader.** None of the five has ever been listened to.
- **200% zoom** (WCAG 1.4.4) and **reflow at 320 px** (1.4.10).
- **The contents of mobile menus and closed accordions**: 1,094 elements.
- **Text over photos**: 167 elements, tool available, not run.
- **The REJECT branch of the cookie banner.** The state has been checked before choosing and
  after **accepting**; rejection has never been looked at on any site.

---

## Links — what is not repeated here

| For | Go to |
|---|---|
| How a colour is really measured (canvas, not computed style) | `02-design.md §3` and §3.1 above |
| Text over a photo | `gates/measure-contrast-on-photo.py` |
| `prefers-reduced-motion` without cancelling the delay | `../docs/traps.md` |
| What is allowed to move at all, and what it costs | `19-motion.md` — A16 is the accessibility half; that document is the rest |
| Line width (WCAG 1.4.8) and the CPL gate | `11-measurements.md §1` and `§7` |
| `autocomplete`, an accessible honeypot, a live error region | `05-forms.md` |
| Weight, images and fonts | `13-performance.md` |
| Real-content states (ragged grid, long text) | `15-real-content-states.md` |
