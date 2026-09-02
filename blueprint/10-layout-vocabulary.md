# Layout vocabulary — 20 primitives with a renderable mould

> **This is not a document about good design. It is a drawer of parts.**
> If you are reading it to "understand how to lay things out", you are using it wrong.
> You use it like this: look at what job the block has to do, find the primitive in the table,
> **open the mould and copy it.**
>
> ```bash
> ls  blueprint/moulds/
> grep -il "compare\|table" blueprint/moulds/*.html
> ```

> **THERE ARE TWO DRAWERS OF PARTS AND THEY ARE NOT THE SAME.** Written down because it has
> already confused people:
>
> | | **moulds** — what this document is about | **generator primitives** |
> |---|---|---|
> | What it is | HTML ready to **copy and adapt** | Functions that **cut content that already exists** |
> | When | A **new** page, written by us | **Inherited** content that has to be re-laid-out |
> | Chosen | By looking at the catalogue here | In that site's spec |
>
> **They do not compete: they are used at different moments.** A new site is written with moulds; a
> migration is cut with primitives; and a page added later to a migrated site is written with
> moulds. The cutting mechanism is in [`17-content-to-layout.md`](17-content-to-layout.md).

---

## 1 · Why it exists, with the numbers in front

*"You do not know which sections each page type has to have, and even when you design them you
often DO IT IN PLAIN TEXT AS IF IT WERE A BLOG ARTICLE."*

It was measured before anything was written. A census of **35 pages** plus a contrast of 57 of our
sections against 10 from somebody else's template:

| signal | ours | reference template |
|---|---|---|
| pages without a single `<section>`/`<article>` | **33 of 35 (94%)** | — |
| % of text living in loose paragraphs (median) | **0.692** | 0.303 |
| sections with no image or svg at all | 73.7% | 50% |
| sections with no repeated group **and** no 2D layout | 38.6% | 20% |
| elements per section (median) | 12 | 20 |
| line length (median, 35 pages) | **109 characters** | 74–134 |
| pages outside the readable 45–90 range | **34 of 35** | — |

**The nuance that matters, and that changes where this applies:** the failure is NOT uniform. Per
page, the share of prose-sections ran 53.8 · 37.5 · 28.6 · 27.3 · **0 · 0 · 0.**
**The commercial landing pages do not fail. The long informational pages fail.**

And the underlying diagnosis: prose (26.3%) + card grid (17.5%) = **44% of all sections.** The
effective variety was **2 primitives across 5 of 7 pages.** It is not that the layout is bad: **the
repertoire was two pieces.** This folder is twenty.

> **"Variety" on its own is NOT a usable metric.** The worst page in the batch had 6 distinct
> primitives. It has to be crossed with the share of prose.

---

## 2 · The three rules of use

1. **Before writing a component, check whether it already exists.** This is the same rule that
   governs the design document and the component index, and it was broken by writing a
   numbered-steps component from scratch with an approved one already in the canon.
2. **You preserve the CONTENT, you rebuild the LAYOUT.** Migrating does not reproduce the source's
   structure. That is how one site ended up with 17.9 screens of scroll and 32 of 39 blocks with no
   call to action at all: a page builder dumped as linear prose.
3. **A page cannot have fewer than 4 distinct primitives.** That is the number separating a
   laid-out page from a list of cards. And **at most one feature grid**: it is the piece that
   replaced thinking.

---

## 3 · The measurement contract

> **A scale table that used to live here was deleted.** It was a SECOND scale, invented the same day
> another document declared its own *"already in production, NOT to be reinvented"*: different token
> names, `62ch` against `34em`, 6 fixed sizes against 7 with `clamp()`, 17px body against 16px, an
> 8px base against 4px, 2 breakpoints against 3. **And it contradicted itself**: the comment said
> `68ch` and the value was `62ch`. **[`11-measurements.md §6`](11-measurements.md) rules**, and
> `moulds/_tokens.css` is its implementation — same names, same values. If they ever differ, the
> broken one is the stylesheet.

**How the contract reaches each mould:** with two links, not copied inside.

```html
<link rel="stylesheet" href="_tokens.css">   <!-- the measurements and the brand -->
<link rel="stylesheet" href="_base.css">     <!-- the section chassis, buttons, … -->
```

Each mould used to carry the root block **copied in**, "so each file opens on its own". It sounded
good and it was the bug: fifteen moulds also defined the inner wrapper, **with five different
widths**, and pasting two into the same page meant the last one won. Measured: **4 of 7 sections on
a home page at 568 px instead of 1120**, and a six-cell grid in columns of 188.7 px against a floor
of about 260. **The page raised no error: it was just narrower.**

**The four widths are MODIFIERS, not redefinitions.** A mould that needs a different width adds a
class in the HTML; nobody rewrites the wrapper:

| class | width | for |
|---|---|---|
| `sec__in` | 1120px | default |
| `sec__in--text` | 34em ≈ 544px | prose: FAQ, asides, index |
| `sec__in--flow` | 48rem = 768px | chain, timeline, comparator |
| `sec__in--spec` | 58rem = 928px | specification table |
| `sec__in--wide` | 1280px | grids and media. **Never prose** |

**Three things that are not obvious and cost one measurement each:**

- **`ch` is calculated with the ELEMENT's font, not the container's.** A container at `62ch` whose
  inner text is smaller gives more characters per line than it looks: **88 characters** measured
  inside a container "of 62". **Every text block carries its own ceiling.**
- **The 45–90 range governs READING columns, not grid cells.** A four-column step cell at 33
  characters is fine: it is a label, not a paragraph. Applying the rule to everything widens cells
  that should not be widened.
- **Every text block needs an explicit `max-width`.** Four of the nineteen moulds slipped through
  without one and produced 96, 126 and **172** characters per line. **You cannot see it by looking:
  you have to measure it.**

---

## 4 · The catalogue

| # | primitive | what job it does |
|---|---|---|
| 01 | **hero** | locates the site and puts the first action above the fold |
| 02 | **alternating-pair** | **the prose-to-layout translator.** One idea = one row with its evidence beside it |
| 03 | **feature-grid** | N comparable capabilities at a glance. Variant `--detalle`: a second-order detail folded away behind hover/focus, normal flow content wherever there is no fine pointer |
| 04 | **comparison-table** | N options × M criteria |
| 05 | **numbered-steps** | a sequence: what a PERSON does over time |
| 06 | **data-band** | breaks a long run with 4 figures that are also proof |
| 07 | **checklist** | qualifies: who it is for and who it is not |
| 08 | **faq-accordion** | 8 answers in the height of 2, without hiding them from the indexer |
| 09 | **social-proof** | what the page cannot say about itself |
| 10 | **pricing-tiers** | turns "how much does it cost?" into a decision |
| 11 | **closing-cta** | catches the convinced reader — closes the CTA gap at the bottom |
| 12 | **aside-note** | the escape valve: where to put 3 sentences that do not fit |
| 13 | **index-with-leaders** | gives a map and anchors to a long page |
| 14 | **flow-chain** | what goes in, what happens, what comes out (a SYSTEM, not a person) |
| 15 | **spec-table** | one thing across M fields, **with a verdict column** |
| 16 | **gallery-with-counter** | shows real work without becoming a catalogue |
| 17 | **timeline** | facts over time **with their status** |
| 18 | **before-after-compare** | compared visual evidence, keyboard-operable |
| 19 | **two-list-nav** | "where I am going" separated from "what I do" |
| 20 | **choice-cards** | two options as image cards, side by side, above the fold. The first question of a capture landing |

**Eleven of the twenty come from an existing component library**; eight were written from scratch, and one (20) was extracted from a commercial funnel template with its markup rebuilt — see 09 §2.12.

> **Motion lives in [`19-motion.md`](19-motion.md), not here.** A mould says how a block is
> BUILT; that document says what it is allowed to MOVE, what the movement costs, and when a
> library is permitted. Measured when it was written: of these twenty moulds, four animate
> anything at all — the vocabulary was empty and nobody had noticed.

Each mould carries **in its own header** its `WHEN`, its `WHEN NOT`, its `WHAT BREAKS IT` and its
behaviour at 390 px. **That is not duplicated here**: pointers both ways, content in one place.

---

## 5 · From prose to primitive — the table that actually gets used

When there is a block of plain text and you have to decide what it is:

| if the paragraph… | the primitive is |
|---|---|
| explains an idea and there is something to show beside it | **02 alternating-pair** |
| lists conditions ("this is for you if…") | **07 checklist** |
| lists capabilities with no order | **03 feature-grid** |
| describes a time order the READER performs | **05 numbered-steps** |
| describes an order the SYSTEM performs | **14 flow-chain** |
| describes an order the OWNER performed | **17 timeline** |
| compares two or more options | **04 comparison-table** |
| describes ONE thing field by field | **15 spec-table** |
| answers an objection | **08 faq-accordion** |
| quotes somebody | **09 social-proof** |
| gives a figure | **06 data-band** |
| is a warning, a source or a definition | **12 aside-note** |
| asks something of the reader | **11 closing-cta** |
| is none of the above | **it probably should not be there** |

**The last row is the important one.** Almost every paragraph that fits no primitive is a paragraph
doing no work.

---

## 6 · Which sections each page type carries → **it is in [`09-page-types.md §2`](09-page-types.md)**

**There is no table here, and that is deliberate.** This section used to give 7 compositions "by
primitive" while the other document gave 11 anatomies "by role". **They did not match.** A question
with two answers that disagree is worse than one with no answer: **each reader takes whichever is in
front of them, and both look canonical.**

| type | the anatomy requires | the table that used to be here said |
|---|---|---|
| home | `process` **REQ** | did not include it |
| service | `qualification` and `siblings` **REQ** | neither of them |
| guide | `hero` and `siblings` **REQ** | started at the index, and no siblings |
| *any* | `siblings` **REQ in 5 anatomies** | **appeared in none of its 7** |

It was also **redundant**: the roles table already assigns a default primitive to each role, so the
composition derives itself from the anatomy. **Two sources for the same thing can only do one thing,
and that is diverge.**

### 6.1 · And because it derives itself, it is now DERIVED — one reference sheet per type

> **`blueprint/moulds/types/<type>.html` · 13 sheets · generated by `gates/roles.pl --plantillas`**

What §6 refused was a second composition table **written by hand**. A sheet *computed* from the two
sources that already exist is not a second answer to the question — it is the same answer, assembled:

| what it needs | where it comes from | who guards it |
|---|---|---|
| which roles the type carries, **in order** | `gates/anatomy.tsv` (= 09 §2) | `anatomy.pl --gate` |
| which mould each role uses | `gates/roles.tsv` (= 09 §1) | `roles.pl --gate` |
| when to use that mould, and when not | **the mould's own header**, read at generation time | — |

**The sheet does not contain the mould's markup, deliberately.** Copying it in would be the same
mistake wearing different clothes, and worse: the day a mould gets fixed, the sheet would still be
showing the defect. It assembles and points. Editing a sheet by hand does not survive one battery —
`roles.pl --gate` re-derives all thirteen and fails on any difference. The test bank pins that both
ways: a hand edit goes red, and regenerating brings it back to green.

`roles.tsv` also closes an edge that did not exist before: `anatomy.pl` reconciles the table against
the document by **counting REQ markers**, so renaming a role on either side kept the count intact and
nobody saw it. The roles are now compared **by name and by default primitive**. Counting is weaker
than comparing, and this is where it showed.

⚠️ **Two roles are in the vocabulary and in no anatomy at all** — `evidence` and `context`. Found by
that gate on the day it was written. They are marked `SOLO-VOCABULARIO` in `roles.tsv` with the
reason, because putting a role into an anatomy changes what **every** site is obliged to carry: that
is a decision for 09 §2, not for a gate. Declared, not silently dropped — and the gate fails if the
declaration is removed.

What still rules here: **§5** (loose paragraph to primitive) and **rule 3 of §2** (minimum 4 distinct
primitives per page, maximum one feature grid). Plus the two constants of every page: **it starts
with 01 hero and ends with 11 closing-cta** — that is what guarantees the ≥2 calls to action the
density gate requires, and what avoids 32 of 39 blocks with no CTA.

### Known debt: three REQUIRED roles that still have no mould

Not a silent hole: it is counted. Of the **15 roles**, **12 have a mould here and 3 do not**, and all
three are required in some anatomy.

| role with no mould | where it is required | what is used meanwhile |
|---|---|---|
| `siblings` | service · city · product · guide · comparison (**5**) | a loose list, or a borrowed feature grid |
| `map` | city · contact (if there is a location) | area chips + a static image by hand |
| `form` | contact (if there is a form) | nothing |

They are registered **before** being extracted for the same reason the component index exists: **a
component that exists and is not in the index gets rewritten from scratch on the next project.** And
while there is no mould, **the layout gate still requires the role**: the debt is in the repertoire,
not in the anatomy. **A role with no mould gets laid out by hand; it does not get skipped.**

---

## 7 · Mobile — the hard case, solved

**A comparison table at 390 px is NOT made scrollable: it turns into cards.** Horizontal scroll hides
exactly the column that matters (the last one is usually "us"), forces the reader to remember the
header while scrolling, and competes with the page's own scroll gesture.

The mechanism: each row becomes a grid and each cell shows its column with `content: attr(data-col)`
in a pseudo-element. **The name travels in the HTML once**; there are not two layouts to maintain.

> **Grid display on table rows and cells DESTROYS table semantics** in every major browser. Without
> explicit `role="table"/"row"/"cell"` at ALL levels, at 390 px a screen reader announces a list of
> loose strings and the comparison disappears for anybody who cannot see it. **Removing a single role
> breaks the chain.**

Other mobile decisions that are not obvious:

- **02 alternating-pair**: the media ALWAYS goes below the text, including in the "reversed" rows.
  Alternation is not perceptible without two sides; all it achieves is half a dozen rows starting
  with an image and no context. And it alternates with `order`, never with a reversed flex direction:
  otherwise the DOM stops matching what is seen.
- **06 data-band**: 2×2, not 1×4. Four stacked figures take nearly a whole screen and stop reading as
  a block.
- **10 pricing-tiers**: the highlighted plan goes FIRST. On desktop it stands out by being in the
  middle; stacked, the middle means nothing.
- **13 index-with-leaders**: the leader dots disappear below 640 px. At 390 the title already fills
  the width and the leader is 6 px of noise.
- **16 gallery-with-counter**: the hover indicator **does not exist on touch.** So the "+N" count is
  always visible and depends on no state.
- **19 two-list-nav**: the dropdown panel does not exist; a flat list in a disclosure element.

---

## 8 · What is verified and what is not

**Verified.** All 19 moulds rendered in headless Chrome, at two widths, **with `innerWidth` printed
and checked across all 38 measurements**: 1422 px on desktop and **exactly 390 px** on mobile.

> The 390 px are real, not a crop. Headless Chrome on Windows **clamps the window to about 500 px**,
> so asking for 390 would have given a 390-wide PNG of a page composed at 504. The mould loads inside
> an `<iframe width=390>`: there the measured document's `innerWidth` **is** 390 and the media queries
> evaluate against it.
>
> (And it needs local file access enabled: without it a `file://` iframe is an opaque origin and the
> probe returns empty — **it gave me 19 blank measurements before I saw it.**)

Result: **0 of 19 with horizontal overflow** at either width, and maximum characters per line ≤ 76 on
all of them after fixing four missing `max-width` declarations.

### And the check that makes it repeatable

Everything above re-runs with **one command**, and it fails on its own:

```bash
bash gates/tests/moulds.sh
```

It includes a collision check — that no mould overrides another or the chassis — **with 6 negative
controls, one per rule, all seen red as they should be.**
