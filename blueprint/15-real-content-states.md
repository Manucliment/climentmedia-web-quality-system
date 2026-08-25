# 15 · States and real content

> **The 19 moulds are drawn with ideal content: 3 rows, 6 cells, 4 figures, 3 plans. Real content
> almost never is.** This document covers the day the client has **5 services instead of 6**, a
> 90-character title, a four-figure price, or no photographs at all.
>
> Measured with a states probe over **27 live pages across 5 sites, at 1280 and 390**, with
> `innerWidth` verified. Supporting structural census: 121 pages.
>
> **The probe exists and returns only anomalies; the verdict and the fixtures are missing. Until
> then this is a specification without a gate.**

---

## 0 · Correction on entry: the moulds DO document states

This is the first thing to say, because I was about to write the opposite. Opened one by one, the
moulds already carry this written down:

| Mould | What state it already documents |
|---|---|
| feature-grid | *"With 2 items, a grid of 2 is a pair"* · *"With 5 or 7 you get a ragged last row… an empty gap in the last row is the most visible tell"* · *"Very different text lengths between cells: the grid wobbles"* |
| comparison-table | 1 option → use the spec table · more than 4 columns → split by family · *"limit ~6 words per cell"* |
| social-proof | *"If there is only one. A single testimonial reads as the only one there is"* |
| pricing-tiers | *"With more than 3 plans: nobody picks the fourth"* |
| alternating-pair | one side empty → a different primitive · more than 5 rows → split |
| gallery · nav · index | 2 images → inside an alternating pair · 5 destinations → flat links · fewer than 4 sections → the index is surplus |

*(Line numbers for those citations were verified one by one. I had taken them before an edit shifted
the files, and **five of the eight were wrong.** A line quoted from memory sends the next person to
the wrong place and makes them believe the rule is not there.)*

> **The defect is not that it is unwritten: it is that it is written in prose inside 19 HTML files,
> and there is not one gate that measures it.** Which is why 18 grid gaps are still live in
> production with the rule written down.

**Nothing from that is copied here.** It is gathered into a comparable table (§2.1), the arithmetic
no mould states is added (§2.2), and the four states that appear nowhere at all (§3–§6). The detail
of each primitive still rules in its own mould: **pointers both ways, content in one place.**

---

## 1 · The six states

| State | What is required |
|---|---|
| **n = 0** | An explicit message **and a way out.** Never an empty grid, never the full list as if nothing happened. And the URL that provokes it has to exist (§6) |
| **n = 1** | If the primitive needs ≥ 2, **change primitive.** One item in a grid of 3 is a layout error, not a data point |
| **n % columns ≠ 0** | Either adjust n, or change primitive, or stretch the last row. **Never leave the gap** (§2.2) |
| **large n** | The primitive **changes**: grid → catalogue with filters; flat nav → two-list nav; timeline over 8 milestones → group by year |
| **long text** | A character budget **per field, measured**, not estimated (§3). And no last line of a single word |
| **missing media** | What fills the gap, declared. Never a broken image, never a block that collapses (§5) |

---

## 2 · The budget for N

### 2.1 · Per primitive — the table that did not exist, gathered

`M` = its mould says so · `P` = **provisional**, derived and not yet measured.

| # | Primitive | min | ideal | max | Out of range you… | |
|---|---|---|---|---|---|---|
| 01 | hero | — | 1 block | — | max **2 buttons**; an `h1` over ~10 words breaks onto 5 lines at 390 and **pushes the CTA below the fold** | M |
| 02 | alternating-pair | 1 | 3–4 | **5** | with 6+, split into two sections each with its own heading | M |
| 03 | feature-grid | **3** | 3 · 4 · 6 | 12 | with 2 → alternating pair; **5 or 7 leaves a ragged row**; over 12 → catalogue with filters | M / P |
| 04 | comparison-table | 2 options | 3 × 4–8 criteria | **4 columns** | 1 option → spec table; over 4 → split by family | M |
| 05 | numbered-steps | 3 | **4** (closes 2×2 and 4×1 with no gaps) | **5** | over 5 it stops being a process and is a manual; with 2 there is no sequence → prose | M / P |
| 06 | data-band | **4** | 4 | 4 | with 2 → move to the hero as proof; **with 3, find the fourth figure or drop it** (at 2×2 the gap is half the band) | M / P |
| 07 | checklist | 3+3 | 5+5 | **6 per column** | over 6 it is an index, not a check; **6 against 2 between columns breaks it** | M |
| 08 | faq-accordion | 4 | 6–8 | 12 | with 1–2 it is a paragraph, not an accordion; over 12 group by topic | P |
| 09 | social-proof | **2** | 3 | 6 | **with 1 it is not a section**: the quote goes inside another | M |
| 10 | pricing-tiers | 2 | **3** | **3** | nobody picks the 4th plan and it casts doubt on the others; with 1 it is not a ladder | M / P |
| 11 | closing-cta | 1 | 1 action + 1 alternative | 2 | 3 actions break it; the alternative goes as a link, not a button | M |
| 12 | aside-note | 1 | 1 | 1 per section | **three asides in a row are prose with a border** | M |
| 13 | index-with-leaders | **5 sections** | 6–10 | — | with fewer than 4 sections the index takes more room than what it indexes | M |
| 14 | flow-chain | 2 | 3 | **3** + the grid | more stops being readable at a glance and is a diagram | M |
| 15 | spec-table | 4 rows | 6–9 | ~10 ungrouped | with 10 in a row you **mark the group**; if every row has the same verdict, the column is surplus | M |
| 16 | gallery-with-counter | **3** | 3–6 | 9 | with 2 → inside an alternating pair; with no real photos, it does not exist | M / P |
| 17 | timeline | 3 | 5–6 | **~8 milestones** | more → group by year **and the year becomes the milestone** | M |
| 18 | before-after-compare | **2** | 2 | 2 | it admits no other number: that is the primitive | M |
| 19 | two-list-nav | **12 destinations** | 12–20 | — | with 5 it is surplus: those are 5 flat links | M |

**What this table makes visible and loose prose does not:** eight primitives have **a hard maximum**,
and not one of the five sites checks it anywhere.

### 2.2 · The arithmetic no mould states: `n % columns`

The grid mould calls the ragged row *"the most visible tell"* and **no gate counts columns.**
Measured live, grouping children by their top offset (6 px tolerance) — **real columns, not the CSS
declaration**:

| Grid | Items | Columns | Last row | Gap |
|---|---|---|---|---|
| a service grid | 10 | 3 | 1 | **2** |
| another | 13 | 3 | 1 | **2** |
| a card grid | 14 | 4 | 2 | **2** |
| size chips | 8 | 5 | 3 | **2** |
| format choices | 6 | 4 | 2 | **2** |
| gallery thumbs | 6 | 4 | 2 | **2** |
| area chips | 11 | 5 | 1 | **4** |
| a card grid | 7 | 4 | 3 | 1 |
| a post list | 11 | 3 | 2 | 1 |
| a 3-column grid | **5** | 3 | 2 | 1 ← the case the mould **literally forbids** |
| a product grid | 50 | 3 | 2 | 1 |

**18 cases across the 5 sites.** And the uncomfortable datum:

> **The site that passed the density gate first time has the two biggest content-grid gaps.** A gate
> that does not ask a question never finds its answer, even on the good site.

**Two precisions that avoid an unfair gate:**

- **The defect is the arithmetic, not the quantity.** 50 products in 3 columns leaves 1 gap; **with
  51 it would leave none.** Failing "for having 50 items" would be failing the wrong thing.
- **Measure at 1280 AND at 390.** At 390 almost everything collapses to one column and the gap
  disappears. **A gap that only exists on desktop is still a gap**, and conversely: one chip list only
  has 5 columns on desktop.

```js
// The core of the check, 15 lines. REAL columns by offset top, not by CSS:
// an auto-fitting grid does not tell you how many actually fit.
const rows = [];
for (const k of [...cont.children].filter(vis)) {
  const t = Math.round(k.getBoundingClientRect().top);
  const f = rows.find(x => Math.abs(x.t - t) <= 6);
  f ? f.k.push(k) : rows.push({ t, k: [k] });
}
const cols = Math.max(...rows.map(f => f.k.length));
const last = rows.at(-1).k.length;
if (cols >= 2 && rows.length >= 2 && last < cols) FAIL(cols - last);
```

---

## 3 · Long text: a budget per field, **measured**

### 3.1 · The widow — 53 live cases, across 4 of the 5 sites

A last line with **a single word** is the most repeated text defect we have, and it is neither
documented nor measured anywhere.

| Where | Cases |
|---|---|
| one guides section | **11 of its 14** catalogue headings |
| one blog index | titles of 3 and 4 lines ending in one word |
| two other sites | card headings and closing headings |

Measured examples: a 19-character title breaking onto **2 lines** in a four-column cell; a
48-character one onto **3** with the last a single word; a longer one onto **4**.

**The fix is not shortening the title: it is not leaving the last word alone.**

```html
<!-- a non-breaking space between the last two words of the heading -->
<h3>What is a good&nbsp;ROAS</h3>
```

> **Vocabulary — do not call it "orphan".** In this system `orphan` already means **a page with no
> inbound links**. Two meanings for the same word in the same repository guarantee a
> misunderstanding. Here it is a **widow**.

### 3.2 · The budget is measured, not estimated

**There is no universal number**: it depends on the font, the size and the width of the project's
cell. It is measured with two lines, on the real page:

```js
// Real characters per line of a heading (not estimated from its length)
const rg = document.createRange(); rg.selectNodeContents(h);
const tops = [...rg.getClientRects()].filter(r => r.height > 2)
  .map(r => Math.round(r.top)).filter((v,i,a) => a.indexOf(v) === i);
// tops.length = real lines. Then walk the last line word by word: if only one
// word falls on the last top, it is a widow.
```

**PROVISIONAL references** — these come from our own sites, not from a standard — for sizing before
measuring:

| Context | Measured width | Provisional budget |
|---|---|---|
| **4-column** grid cell at 1440 px | 233–265 px | ~11–13 characters per line: **a heading over ~22 characters will break.** Plan for 2 lines, not 1 |
| **3-column** cell | 331–384 px | ~18–20 chars/line |
| **2-column** cell | 471–622 px | ~26–32 chars/line |
| Reading column | 34em | 45–90 CPL, and **only here**: applying that range to grid cells widens them wrongly |
| Comparison-table cell | — | **~6 words.** What does not fit goes in a note underneath |
| Text side of an alternating pair | — | **~60 words.** If it does not fit, there are too many ideas |

**And the floor that does not get lowered: about 260 px per content column.** Below that, a card with
a title and two lines **starts breaking words.**

---

## 4 · Figures and long names

### 4.1 · The four-figure price

Three things break at once when a price goes from 3 to 4 digits, and all three have a one-line fix:

- **The amount and its symbol NEVER split across lines.** Use a non-breaking space or a no-wrap span.
  Splitting a price across two lines is the cheapest defect to fix and the worst to look at.
- **Follow one locale convention and reuse it.** Decide where the thousands separator starts and stick
  to it; reuse the convention the rest of your interface already uses instead of inventing another.
- **The unit goes underneath by design, not by accident.** "/month", "excl. VAT" or "from" on its own
  line at its own size — if it lands there through overflow, it reads as a bug.

> And the warning the pricing mould already carries, which is bigger than all of this: **do not write
> the amount by hand if a source of truth exists.**

### 4.2 · The long name

A long name does not break a paragraph: it breaks **pills, chips, tabs and header cells**, which are
the places nobody looks at. Measured:

- A chip list: **11 chips in 5 columns** leaves a gap of 4. With one long place name they drop to 4
  columns and the gap changes on its own.
- One band at 390 px collapses to **2 columns of [166 px, 108 px]**. **A 108 px column holds nothing**:
  it is the only broken collapse across the five sites.

**Rule:** every fixed-width or narrow-grid container is tested with **the longest name in the client's
real catalogue**, not the mould's. Pull it from the spec:

```bash
# the real worst case, from the spec, before laying anything out
perl -ne 'print length($1)," $1\n" if /"(?:name|title)"\s*:\s*"([^"]+)"/' \
  _spec/site.json | sort -rn | head -5
```

---

## 5 · Missing media

The probe flags **46 blocks over 120 px tall with no image, SVG or background** across the 27 pages;
12 of them in one section alone.

**What each primitive does without its media — two already have it solved in their mould:**

| Primitive | Without an image |
|---|---|
| alternating-pair | **change primitive.** *"One side empty or padded"* is worse than prose |
| gallery | **it does not exist.** With stock it is worse than not having it; with a generated image of a team, premises or result it is **forbidden** |
| social-proof | ships without a photo: initials or nothing. **Never a generated photo of the author** |
| feature-grid | ships without an icon rather than with a generic library icon: *"they add nothing and give the template away"* |
| hero | a single-column, centred hero. You do not leave the photo's gap |

**The three hard rules:**

1. **Never a broken image.** The probe flags a loaded image with zero natural width.
2. **Never a block that collapses** to an absurd height when the media is missing. The container
   carries its aspect ratio or its minimum height.
3. **And never an invented `alt` to paper over it.** An empty `alt` is correct if it is decorative.

> **This is a NOTE, not a failure.** An FAQ, a legal page or a block of prose with no image is fine.
> The no-image flag exists to ask *"does this whole page have nothing to show?"*, not to demand a photo
> per section.

---

## 6 · n = 0, and the record that does not exist

**The empty state appears nowhere in this system.** Verified: "empty state", "no results" and "not
found" return **zero** across every reference document.

**One site has thought about it**, and it is the only one with a catalogue: a filter with no results
renders an explicit empty state, and a non-existent record renders *"model not found · back to the
shop"* with a way out.

> It is a **blind spot with good luck**, not a solved problem: if that site stops being touched, the
> next site with a listing repeats the failure from scratch. That is why it is promoted here.

**And the nuance that makes it usable as a gate:** requesting that catalogue with a non-existent
filter **ignores the filter and shows all 50.** So its own empty state **is not reachable by URL.**

> **An empty state you cannot reach is not tested.** If the gate cannot provoke it with a URL, it does
> not exist for QA.

**The 404 belongs to this family**, and it sits in the same hole: the page-types document specifies it
completely and the final-QA checklist **does not mention it once.** What was measured:

| Site | H1 | Body links |
|---|---|---|
| C | "This page does not exist" | **5** ← the **only** one of 20 pages measured that **passes** the layout gate |
| ours | "This page doesn't exist" | 2 |
| B | "This page does not exist" | 2 |
| A | "Page not found" | 1 · 0 CTA |
| **D** | "404" (**from the web server**) | **0** · 0 CTA · contrast 2.16:1 |

One repo is **the only one of the five with no `404.html`.** In production a missing URL returns 796
bytes **without a single link**: a dead end on a live 40-page client site that pays for clicks.

---

## 7 · How it gets checked

The probe returns **only anomalies. Silence = no broken state detected.** It is run at 1280 **and** at
390, with `innerWidth` printed and checked next to the result.

It returns eight lists: `gridGap` · `unequal` · `only1` · `overflow` · `truncated` · `widow` ·
`noImage` · `brokenImage`.

> **Rule for promoting it to a gate.** It ships with **one fixture that HAS to come out RED and one
> that has to come out GREEN.** A gate nobody has seen fail proves nothing. The fixtures are cheap
> here: a grid of 5 in 3 columns, and one of 6.

---

## 8 · False positives of the instrument — already measured

**If the sweep says many things are broken at once, the broken thing is the sweep.** The four that came
out:

- **`only1` flagged icon wrappers.** 50 warnings, and most were a 10 px item inside a 22 px container.
  **Those are not one-item lists.** → The check now requires a container **≥ 240 px wide** and a child
  with text. With that filter the real ones remain, and they are the ones that matter: a three-column
  grid with **1 card of 384 px inside 1,216 px.**
- **`overflow` gave 35 positives and ZERO real overflows.** All 27 documents measured exactly 390.
  They were: tables inside an auto-scrolling container, a decorative glow element (deliberately
  extending past the edges) and a honeypot positioned off-screen. → Measure **the document**, and skip
  scrollable ancestors and hidden elements.
  > **With one real exception:** two pages **do** overflow at 390 (460 against a client width of 351)
  > and the third column — *"what this means for you"*, the one that sells — runs off with no signal at
  > all. **The comparison-table mould is correct and the live page does not use it.** Nobody ever
  > checks that a page actually applies its mould.
- **`unequal` flagged a split hero with a form.** 271 against 537 px in 5 pages: that is a two-column
  hero with the form in one. **Not a defect**, it is the primitive. The real case was **707 against
  7,556 px**: 6,800 px of empty filter column beside a catalogue.
- **`noImage` cannot tell an FAQ from an empty home page.** It goes to notes, never to failures.

> And the rule that holds all of this up: **an instrument that cannot measure is not an accusation.
> "Not measurable" is not a fail, and it is not a pass either.** One gate counts *"median CPL not
> calculated"* as a warning and with that fails 10 of 15 pages: **half of its failures have an "I could
> not measure this" inside them.**

---

## 9 · Where the rule does NOT apply

1. **`n % columns == 0` exonerates any n.** 51 products in 3 columns have no gap. You do not fail for
   quantity.
2. **A one-word last line in a large hero heading, on purpose**, with the word as the punchline, is not
   a widow: it is a decision. Declare it in the spec; what is not acceptable is it happening in 11 of
   14 cards by accident.
3. **The maximums for N are for content pages**, not for catalogues or configurators: the two-list nav
   requires ≥12 destinations precisely because it is the primitive for the large case. **A catalogue
   with filters is not a hub**, and judging it with a hub's anatomy demands things that do not apply.
4. **A block with no image in a legal page, a 404 or an FAQ is correct.**
5. **At 390 px almost everything collapses to one column**: there the grid-gap and one-item checks do
   not apply by definition. What gets measured on mobile is **height** — a page becomes 1.4–2.0× longer
   — and real overflow.
