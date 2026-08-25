# 11 · THE MEASUREMENTS — widths, line length, type scale, spacing, breakpoints, grids

> **Why it exists.** *"You don't actually know the width thing."* That was correct, and it is
> the cheapest hole to close, because these are **numbers**. This file does not have opinions:
> every value here comes from a measurement with its source beside it.
>
> **Method.** Headless Chrome **on a Linux server**, driven over the debugging protocol from
> Node, at **1440×900** and **390×844**. The server was chosen on purpose: headless Chrome on
> Windows clamps the window width to about 500px and the capture comes out cropped.
> **`innerWidth` is printed on every measurement and matched what was asked for in all 38** —
> if it had not matched, the number would be worthless. 12 reference sites plus 5 of our own
> (home and one interior page each).
>
> **A caveat that changes how these numbers are read.** The measuring server **did not have the
> intended UI font installed**, and our sites **do not load a web font** (a zero-third-parties
> rule). Everything of ours was measured **rendered in a wider fallback face.** Effect: on a
> machine with the intended font the real column is **narrower** than measured, so **the
> characters-per-line figures below are the ceiling, not the floor.** The conclusion (we run
> too wide) is conservative; the exact magnitude is not.

---

## 1 · Container width and line length

### 1.1 The measurement that matters is not the container, it is the TEXT COLUMN

A 1200px container is not a defect. A 1200px **paragraph** is. They are different things and
our sites confuse them: they fix the container and leave the paragraph loose inside it.

**The correct unit is `em`** (width ÷ font size), not px: it is independent of the type size
and therefore comparable between sites using different ones.

| Reference site | Container | Text column | In `em` | Real CPL |
|---|---|---|---|---|
| gov.uk | 960px | 630px @19px | **33 em** | 74 |
| a marketing site | 1040px | 541px @16px | **34 em** | 72 |
| a SaaS site | 1440px | 543px @16px | **34 em** | 78 |
| stripe.com | 1266px | 791px @22px | **36 em** | 81 |
| basecamp.com | 1257px | 682px @19px | **36 em** | 78 |
| a health charity | 1120px | (cards) 320px @20px | 16 em | 42 |
| linear.app | ~1440px | 566px @24px | 24 em | 52 |
| anthropic.com | 1285px | 344px @18px | 19 em | 41 |
| tailwindcss.com (docs) | 1440px | 752px @16px | 47 em | 101 |
| developer.mozilla.org | 1440px | 752px @16px | 47 em | 102 |
| web.dev (article) | — | 854px @16px | 53 em | 124 |
| nngroup.com (article) | 1480px | 868px @20px | 43 em | 99 |

> **Sites with well-resolved prose cluster at 33–36 em.** The ones outside that band are
> technical documentation — a different page type, with a different reader, and they get
> criticised for it anyway. **It is not our model.** The 16–24 em group is not prose: those are
> cards and short blocks.

### 1.2 Where we fell — measured at 1440px

| Our site | Page | Column | In `em` | **CPL** | Verdict |
|---|---|---|---|---|---|
| Site D | home | 438px @13.1 | **33 em** | 67 | in range |
| Site C | home / interior | 578px @17 | **34 em** | 67 / 69 | in range |
| Site B | home | 502px @15 | 33 em | 72 | in range |
| Site B | catalogue | 518px @14.1 | 37 em | 82 | just outside |
| **our own site** | **home** | 640px @16 | **40 em** | **89** | **fail** |
| **our own site** | **hero note** | 900px @16 | **56 em** | **126** | **fail** |
| **our own site** | **a guide page** | 796px @16 | **50 em** | **111** (median) | **fail** |
| **Site A** | **a services page (FAQ)** | 1214px @14.4 | **84 em** | **182** | **fail** |

**The two culprits have a name and a line number:**

1. **A container rule setting `max-width: 860px` with no limit on `p` at all.** Result:
   **44 of 44 paragraphs** on one guide page above 80 CPL, median 111. That is **the content
   page type** — the one with the most text, and the only one where line length decides whether
   it gets read.
2. **`.prose > p { max-width: 46rem }`.** The combinator **`>` means direct child**, so a `<p>`
   inside a `<details>` inside a wrapper **escapes the limit** and inherits the whole container
   (1214px). The rule exists, it is well thought out, and **it does not apply where it is most
   needed.** A pure silent failure: nothing breaks, it is just unreadable.

### 1.3 The limit, calibrated (not deduced)

`ch` is not a character: it is the width of the glyph "0". Measured in a real render,
**1ch = 0.556 em** in the fallback face, and about 0.50 em in the intended one. An average
character of running text measures **0.47–0.55 em** depending on the language. So `65ch` does
not give you 65 characters. Empirical calibration at 16px:

| Declared | Width | EN | ES | FR | PT |
|---|---|---|---|---|---|
| `max-width: 50ch` | 27.8 em | 55 CPL | — | — | — |
| **`max-width: 65ch`** | **36.2 em** | **66** | **77** | **69** | **66** |
| `max-width: 75ch` | 41.7 em | **82** fail | 77 | — | — |

> **`65ch` is the right ceiling: it lands at 66–77 real CPL in all four languages we use**, and
> stays under the accessibility ceiling. **`75ch` already overshoots in English** (82).

**The sources for the limit** (this is not taste):

- **WCAG 2.1, SC 1.4.8 "Visual Presentation" (level AAA):** *width is no more than 80
  characters or glyphs* (40 for CJK). The same criterion requires line spacing of **at least
  1.5** within a paragraph, and paragraph spacing at least 1.5× the line spacing.
- **Butterick, *Practical Typography*:** aim for an average line length of 45–90 characters,
  including spaces.

**House rule:** target **34 em (~65ch, 65–75 CPL)**, hard ceiling **42 em (80 CPL)**.

> ### WRITE THE RULE IN `em`, NOT IN `ch` — and why the table above can mislead you
>
> On one site `max-width: 65ch` resolved to **36.1 em** and produced **83 CPL** — above the hard
> ceiling. The table says 36.2 em → 66–77 CPL, so the width matched and the CPL did not.
>
> **The cause was not the table: it was that the font was not the one I thought.** `1ch` is the
> width of the "0" glyph **of the font that actually renders.** The site declared one face
> (0.50 em) and did not load it, so it painted in the system UI face (**0.555 em**) — the
> fallback number from the table. A `ch` from one font and a CPL from another.
>
> → **`ch` is a unit that depends on a file that may never arrive.** `em` depends only on the
> font size, which is always there. **The rule is written in `em`; `ch` is indicative.**
>
> → **And before calculating anything with `ch`, check which font is actually painting**, by
> measuring the width of the "0" glyph with the declared stack and comparing it against the
> font you believe you have. An empty font registry in production is the cheap signal: there is
> no self-hosted font at all.

---

## 2 · Type scale

### 2.1 What gets measured: not how many sizes there are, but how many are DISTINGUISHABLE

Two metrics, and the second is the one that hurts:

- **Steps in the text band (11–28px)** — where the eye distinguishes about 4–5 levels.
- **Jumps below 1.08×** — an 8% difference is **imperceptible**. Every one of them is a level
  that costs maintenance and communicates nothing.

| | Steps in band | Jumps <1.08 |
|---|---|---|
| gov.uk | 3 | **0** |
| a health charity | 3 | **0** |
| a SaaS site | 4 | **0** |
| vercel.com | 5 | **0** |
| stripe.com | 7 | **0** |
| anthropic.com | 7 | 2 |
| tailwindcss.com | 8 | 3 |
| linear.app | 7 | 3 |
| **Reference median** | **5** | **0** |
| — | | |
| our own site, home | 7 | 2 |
| our own site, a guide | 6 | 3 |
| Site D | 9 | 5 |
| Site C | 11 | 7 |
| Site A | 11 | **10** |
| **Site B** | **18** | **15** |
| **Our median** | **10.5** | **7** |

> **The median reference has 5 text steps and ZERO imperceptible jumps. We have 10.5 and 7.**
> One site reaches **18 steps** with ratios of 1.013 — `.9rem`, `.92rem`, `.94rem`, `.95rem`,
> `.96rem` coexisting. **Nobody chose that: it accumulated.** In that stylesheet there are
> **162 font-size declarations with 44 distinct values**; in another, 61 declarations with 37
> values.

**The only one of ours near the range is the only one with the scale actually applied.**
Correlation, not coincidence.

### 2.2 A caution about documents that say "not applied"

Two of our own documents said the type scale was *"proposed, not applied"*. **Both were out of
date**: the tokens were declared and **41 of 46 font sizes used them (89%)**.
**A document saying "not applied" about something that is applied makes the next person apply
it again.**

---

## 3 · Spacing scale

### 3.1 Our problem is not the base value, it is that there is no base

Adherence to a grid, measured at runtime over values used twice or more:

| | multiples of 4 | multiples of 8 |
|---|---|---|
| **References, range** | **54–85%** | **38–62%** |
| **Ours, range** | **20–52%** | **20–33%** |

Read in the source CSS, the mechanism is obvious — **distinct `rem` values in padding, margin
and gap**:

| | distinct values |
|---|---|
| our own stylesheet | **43** (0.1, 0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55…) |
| Site A | **38** |
| Site D | **32** |
| Site B | **32 values in px** (including 5, 7, 9, 11, 15, 34, 82, 84) |

> **Our own site declares five spacing tokens and still uses 43 loose values.** Having the scale
> and not using it is worse than not having it: it makes people believe the problem is solved.
> **That is the finding of this section, not the base number.**

### 3.2 The base: 4px

Adopted from the common utility-framework base (`0.25rem`), compatible with what two of our
sites already do in practice — plus the government design system's idea that **large steps
shrink on mobile**, which is exactly what we were missing.

### 3.3 Section padding vs spacing between elements

Two numbers that have to be looked at together, because what fails is the **relationship**:

| Site | Section padding (1440) | On mobile (390) | Ratio | Largest inner gap | **Padding ÷ gap** |
|---|---|---|---|---|---|
| Site D | 88px | 48px | 0.55 | 32px | **2.75** ok |
| our own | 120px | 72px | 0.60 | 18px | 6.7 (loose) |
| Site B | 60px | 24px | 0.40 | 28px | 2.1 ok |
| gov.uk | 60px | 28px | 0.47 | — | — |
| **Site A** | **40px** | **40px** | **1.00** fail | **32px** | **1.25** fail |
| **Site C** | **0px** | **0px** | — | 36px | **0** fail |

**Two different failures, both ours:**

- **Site A:** the separation between sections (40px) is almost the same as the gap between
  cards inside a section (32px). **If the space between groups does not clearly exceed the
  space within a group, the eye does not group**, and the page reads as one continuous list.
  And the padding **does not shrink on mobile** (40→40).
  > Note where it came from: that value was reduced to fix 8.2 screens of scroll.
  > **It fixed the density and broke the grouping.** The right move was not to shrink
  > everything, it was to **increase the contrast** between the two rhythms.
- **Site C:** padding **0/0 on all 29 "sections"** of the home page. It is not that the spacing
  is wrong: **there are no sections.** They are 29 direct children of `<main>` with no
  structure — linear prose inherited from a page builder. It is the prose-page problem showing
  up as a number.

**Rule:** section `padding` **≥ 2× the largest `gap` inside it**, and on mobile **50–60% of the
desktop value.**

---

## 4 · Breakpoints

Measured, two reference sites use exactly a standard framework set. Ours:

| Site | Declared breakpoints | Count |
|---|---|---|
| Site C | 560, 820, 900 | 3 |
| our own | 620, 640, 760, 1000 | 4 |
| Site D | 544, 860, 832, 900 | 4 |
| **Site A** | 34, 40, 44, 48, 52, 56, 62, 68, 80rem + 860px | **10** |
| **Site B** | 420, 480, 560, 620, 640, 700, 720, 820, 860, 900, 940, 980 | **12+** |

> **Not one of the five uses the same set.** And one mixes `rem` and `px` in the same
> stylesheet, which makes it impossible to reason about the order they apply in. Another has
> **12 cut points**, almost all tailored to one specific component: each one is a place
> something can break with nobody watching.
>
> One site also **declares the same width token twice in the same file.** The last one wins,
> silently. **A duplicated token raises no error.**

**Rule: 3 breakpoints, in `rem`, the same in every project.** 640 / 1024 / 1280. Three points
cover phone → tablet → desktop, which are the three layout decisions we actually make. If a
component needs a fourth, what it usually needs is an auto-fitting grid, **which costs no
breakpoint.**

---

## 5 · Grids: how many columns, and at what width they collapse

### 5.1 The floor: about 260px per content column

A card with a title and two lines below about 260px starts breaking words. **No reference site
has a content grid of 5 or more columns.** The ones that appear with 12 or 20 columns are
layout scaffolds, not content grids — a different thing, not counted here.

### 5.2 Mobile (390px) — this is where we really fail, and it is NOT the columns

- **Collapse: correct almost everywhere.** Four of five have **no multi-column grid** at 390px.
  The only broken collapse is one band dropping to two columns of **[166px, 108px]** — a 108px
  column holds nothing.
- **Line length on mobile: healthy everywhere.** 41–49 CPL for ours, 43–57 for the references.
  **Line width is an exclusively desktop problem** — at 390px the viewport already imposes the
  limit. This inverts the intuition: **the page that looks fine on the phone can be the
  unreadable one on the laptop.**

**What does fail on mobile is HEIGHT:**

| Page | Screens @1440 | Screens @390 | Factor |
|---|---|---|---|
| Site D home | 2.6 | 4.1 | ×1.58 |
| Site B home | 4.2 | 5.9 | ×1.40 |
| our own home | 4.6 | **6.6** | ×1.43 |
| Site A services | 5.0 | **9.8** | ×1.96 |
| our own guide | 9.8 | **16.7** | ×1.70 |
| Site C home | 14.9 | **16.4** | ×1.10 |

> **A page becomes 1.4–2.0× longer on mobile.** The density gate put the limit at 6 screens and
> said to measure at both widths — but in practice it was measured at 1280. **At 390px, 4 of 6
> pages broke it, and two of those passed on desktop.**

### 5.3 The density limit counts WORDS, not screens

**The fixed limit of 6 was replaced.** It is now 6 screens of slack **plus one screen for every
80 visible words past 400.**

Both numbers are measured, not chosen: the marginal cost of a word comes from two pages of the
**same** site — 12.4 px/word (68 per screen) and 8.8 (96) — and 80 keeps both within 20%. The
slack of 6 is what the header, hero and footer cost, plus some content.

**What the change exposed:** under the fixed 6, the page that failed — 13.3 screens — was **the
DENSEST of the four measured**: 87 words per screen against 51 for the page that anchored the
threshold with 206 words. **The 6 was not measuring layout: it was measuring how much text the
page carries**, which is the client's editorial decision.

> And the earlier contrast still holds, for a different reason: **the fixed 6 described the
> archetype "marketing home page"** (3.6 · 5.1 · 5.4 · 5.5 · 5.9 across five references), not a
> long product page and not a guide. The earlier conclusion — *"the limit should be per page
> TYPE"* — fell short: the type is a proxy for the text the page carries. Counting words
> measures what actually takes up space, with no type table to maintain.

---

## 6 · TOKENS — to paste

```css
:root{
  /* ---------- WIDTHS ----------------------------------------------------
     --wrap     general container. 1120px is what three of our sites measure.
     --measure  THE TEXT COLUMN. In `em`, not px, so it scales with the size
                of the paragraph itself. 34em ~= 65ch = 66-77 real characters
                in EN/ES/FR/PT IN THE CALIBRATION FONT. Outside it, this
                changes: see the warning below.
     --measure-max  NOT "the 80-character ceiling". It is a CONTAINER ceiling
                in `em`, and `em` does not know how many characters fit: the
                font decides that. The gate itself caught three pages BELOW
                42em and ABOVE 80 CPL. Measured in a browser whose system face
                is narrower than the calibration font, a prose container at
                34em produced 81 CPL, not the 66-77 in the table.
                -> THE CPL IS MEASURED, in the site's real font. The `em` is
                   so the column scales with the text, not a certificate.     */
  --wrap:          1120px;
  --wrap-wide:     1280px;   /* grids and media only, NEVER running text */
  --measure:       34em;     /* prose target                            */
  --measure-max:   42em;     /* hard ceiling: 80 CPL                    */
  --measure-lead:  28em;     /* standfirsts: shorter on purpose         */

  /* ---------- TYPE — 7 steps, ratio 1.20-1.33 --------------------------
     Reference: 5 steps in the 11-28px band and ZERO jumps below 1.08.    */
  --fs-display: clamp(2.6rem, 7vw, 5rem);      /* h1        ~42-80px */
  --fs-title:   clamp(1.9rem, 4.2vw, 3rem);    /* h2        ~30-48px */
  --fs-section: clamp(1.4rem, 2.4vw, 1.75rem); /* h3        ~22-28px */
  --fs-lead:    1.2rem;                        /* standfirst  19.2px */
  --fs-body:    1rem;                          /* body        16px   */
  --fs-small:   0.875rem;                      /* captions    14px   */
  --fs-micro:   0.75rem;                       /* labels      12px   */

  /* Line height: WCAG SC 1.4.8 wants >=1.5 in a paragraph. Headings go
     lower because at 48px a 1.5 separates far too much.                 */
  --lh-body: 1.6;  --lh-lead: 1.5;  --lh-title: 1.15;  --lh-display: 1.05;

  /* WEIGHT is hierarchy too. We had 4 roles sharing 800, which flattens
     the page even when the sizes are right.                             */
  --fw-body: 400;  --fw-medium: 500;  --fw-bold: 700;  --fw-black: 800;

  /* ---------- SPACING — base 4px, 8 steps ------------------------------
     8 values are enough: the references with the best adherence do not
     use more.                                                           */
  --space-1:  0.25rem;  --space-2:  0.5rem;   --space-3:  0.75rem;
  --space-4:  1rem;     --space-6:  1.5rem;   --space-8:  2rem;
  --space-12: 3rem;     --space-16: 4rem;

  /* ---------- SECTION RHYTHM -------------------------------------------
     Rule: section padding >= 2x the largest inner gap, or the eye does
     not group (one site: 40 vs 32 = 1.25x, and it reads as a list).
     On mobile, 50-60% of the desktop value.                             */
  --section-y:     clamp(2.5rem, 5vw, 4.5rem);  /* 40px mobile -> 72px desktop */
  --section-y-lg:  clamp(3.5rem, 7vw, 6rem);
  --grid-gap:      clamp(1rem, 2vw, 2rem);
}

/* ---------- BREAKPOINTS: THREE, in rem, the same in every project ------ */
@media (min-width: 40rem) { /* 640px  — portrait tablet */ }
@media (min-width: 64rem) { /* 1024px — landscape tablet / laptop */ }
@media (min-width: 80rem) { /* 1280px — desktop */ }

/* ---------- APPLICATION: this is what was missing, not the tokens ------ */

/* 1. The limit goes on the PARAGRAPH, with a DESCENDANT selector.
      `.prose > p` (direct child) is the bug: a <p> inside <details>
      escapes and inherits 1214px = 182 characters per line.              */
.prose p, .prose li, .prose dd { max-width: var(--measure); }
.prose .lead                   { max-width: var(--measure-lead); }

/* 2. Headings, grids and media DO take the full width. Narrowing the whole
      container leaves a column floating in the middle of the page.       */
.prose h1, .prose h2, .prose h3,
.prose .grid, .prose figure, .prose table { max-width: none; }

/* 3. Grids that collapse BY THEMSELVES: no breakpoint spent, and never
      below 260px, the measured floor where a card starts breaking words. */
.grid-auto { display: grid; gap: var(--grid-gap);
             grid-template-columns: repeat(auto-fit, minmax(min(260px, 100%), 1fr)); }
```

---

## 7 · Verification — the number is worthless without checking the width

Paste into the browser console. **It prints `innerWidth` first on purpose:** if it does not
match what you asked for, throw the measurement away. That trap has eaten two diagnoses.

```js
(() => {
  const cvs = document.createElement('canvas'), ctx = cvs.getContext('2d');
  const bad = [];
  for (const p of document.querySelectorAll('p, li')) {
    const t = (p.innerText || '').trim();
    if (t.length < 90 || p.closest('nav,header,footer')) continue;
    const r = p.getBoundingClientRect(); if (r.width < 60) continue;
    const s = getComputedStyle(p);
    ctx.font = `${s.fontStyle} ${s.fontWeight} ${s.fontSize} ${s.fontFamily}`;
    const m = t.replace(/\s+/g, ' ').slice(0, 400);
    const cpl = Math.round(r.width / (ctx.measureText(m).width / m.length));
    if (cpl > 80) bad.push({ cpl, em: +(r.width / parseFloat(s.fontSize)).toFixed(1),
        sel: p.tagName.toLowerCase() + '.' + (p.className || '-'), txt: t.slice(0, 40) });
  }
  bad.sort((a, b) => b.cpl - a.cpl);
  return JSON.stringify({
    innerWidth,                              // <-- CHECK THIS ONE FIRST
    VERDICT: bad.length ? 'FAIL' : 'PASS',
    paragraphsOver80CPL: bad.length,
    worst: bad.slice(0, 5)
  }, null, 1);
})()
```

**Tested before publishing, with positive AND negative cases** (house rule: a gate that has
only been seen green proves nothing). Run exactly as written, at 1440px:

| Page | Verdict | Paragraphs >80 CPL | Worst |
|---|---|---|---|
| our own guide page | **FAIL** | 44 | 116 CPL (49.8 em) |
| Site A services page | **FAIL** | 4 | **182 CPL** (84.3 em) |
| Site D home | **PASS** | 0 | — |
| Site C interior | **PASS** | 0 | — |

**Gate thresholds** (all four, at both widths):

| Check | Limit | Where it comes from |
|---|---|---|
| Paragraphs over 80 CPL | **0** | WCAG 2.1 SC 1.4.8 (AAA) |
| Text column | **≤42 em** | equivalent to 80 CPL (§1.3) |
| Text steps (11–28px) | **≤6**, and **0** jumps below 1.08 | reference median is 5 and 0 |
| Section padding ÷ inner gap | **≥2** | measured: 2.75 passes, 1.25 fails |

---

## 8 · Summary: where we fall outside

| # | What | Where | Fix |
|---|---|---|---|
| 1 | **182 CPL** in an FAQ | a `.prose > p` rule | `>` → descendant selector |
| 2 | **111 CPL median**, 44/44 paragraphs | a container rule with no limit on `p` | add `max-width: var(--measure)` to `p`/`li` |
| 3 | **126 CPL** in a hero note | same | same |
| 4 | **18 text steps**, 15 imperceptible | 162 declarations, 44 values | propagate the seven type tokens |
