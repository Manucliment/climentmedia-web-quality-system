# Path 3 · Add a page to a site already published

> **The most frequent job, and the one nobody had written a path for.** Which is exactly
> how the prose-page gets in: the content sections of a site are rarely the original
> landing pages — they are **the pages added afterwards.**
>
> This is **not new documentation**: it is the ORDER in which you open the references that
> already exist, plus the checks no gate performs today. Everything asserted here lives
> written somewhere else and is linked. If anything here contradicts a reference document,
> **the reference wins** and this line gets corrected.

## Are you on this path?

| | |
|---|---|
| **Yes** | adding a page to a live site · a new child to a hub · a new guide, comparison or note · a service, city or product page · splitting a section out into its own page |
| **No** | building or migrating the whole site → **path 1** · redoing an existing page → **path 2** · changing the architecture (opening a new top-level lane or a hub) → `blueprint/09-page-types.md §4` **before** coming back here |

**Precondition.** The site is already published, so **every step here touches something
that already works.** The new page is not the only artefact that changes: so do the hub
that links to it, the sitemap, `llms.txt` and the link graph. They ship **in the same
batch** (step 6) or the page is born an orphan.

---

## The rule that orders this path

> **The TYPE decides the anatomy; the anatomy decides the layout; the layout is written
> BEFORE the text.**

Inverting that order is literally how a prose-page is manufactured: if the text comes
first, the layout goes "wherever it fits" and what comes out is a blog article with
headings.

**The seven steps, and what closes each one:**

| # | Step | Where it is written | Closes with |
|---|---|---|---|
| 0 | Should it exist? | `blueprint/09-page-types.md §4.2, §4.5, §5` · `blueprint/18-page-standard.md` | the sentence "which search does this exist for" + 2 named linkers |
| 1 | **Decide the TYPE** | `blueprint/09-page-types.md §2` (the twelve anatomies, 13 types) | the type written into `data-tipo` and passed to both gates |
| 2 | **Layout spine BEFORE the text** | **`blueprint/moulds/types/<type>.html`** — the generated reference sheet for that exact type: roles in order, the mould for each, and its "when / when not". Then `10-layout-vocabulary.md §5` for the prose that is left over | grep for `data-sec` (a manual step: **no gate fails on it**) |
| 3 | Linking decided before writing | `blueprint/12-internal-linking.md §4` · `09 §4.3` | grep for the path inside other pages' `<main>` |
| 4 | Head, schema, images, measurement | `blueprint/18-page-standard.md §1–§3` · `03` · `04` | `qa-master --only seo` |
| 5 | Gates on the new page | `checklists/final-qa.md §A-bis and §A-ter` | all five, with `innerWidth` written next to each |
| 6 | Ship the BATCH and back-propagate | `blueprint/06-publishing.md` · `12 §4.7` | verify in production, not in the repo |

---

## Step 0 · Should it exist?

The three questions — which lane, what justifies it, who links to it from body copy — are
in the page standard and are not repeated here. What is added for a site **already
published**, which is where it gets decided before it becomes expensive:

- **Cannibalisation.** If another page on the site answers the same question, resolve it
  **now**: merge, redirect, or differentiate the H1 and the opening capsule.
  *Later it is no longer an architecture decision, it is a migration with 51 redirects.*
- **Is it a child of a hub that does not yet have four children?** With three or fewer, it
  lives inside the parent with anchors. A hub opens with four children **written**.
- **Does it need a new top-level folder?** Without a lane, it does not get created, and
  that is a decision for whoever owns the site's architecture. You stop here.

**Check:** one written sentence — *"this page exists for search X"* — and **two pages,
named**, that will link to it **from body copy**. The navigation does not count. Without
both, you do not move to step 1.

---

## Step 1 · Decide the TYPE — and getting it wrong invalidates everything after

The type determines three different things that cannot be reconciled later: **which
sections it carries**, **which schema**, and **which profile the gates judge it with.**

| type | anatomy | gate profile |
|---|---|---|
| `home` `service` `city` `product` | `09 §2.1–2.4` | ≥4 primitives · ≥3 links · hero required · closing required |
| `hub` | `09 §2.5` | ≥3 primitives · **≥4 links** · no commercial hero |
| `guide` `comparison` | `09 §2.6` | ≥4 primitives · ≥3 links · **structure REQUIRED** |
| `pricing` | `09 §2.8` | ≥4 primitives · ≥2 links |
| `contact` | `09 §2.9` | ≥2 primitives · no closing |
| `thanks` `legal` `404` | `09 §2.10–2.11` | **structure exempt** — see the edge case |

**Two instrument traps, verified by reading both files:**

1. **If you do not tell it the type, it infers one from the URL — and the URL lies.**
   The structure gate routes anything containing `learn|blog|guide|article|notes|resources|
   insight|academy|docs|help|support` to `guide`. A commercial landing page under
   `/resources/` gets judged as a guide. **The type is always declared**, and it is also
   written into the HTML (`data-tipo`): a type that only exists in the head of whoever ran
   the gate is not a taxonomy.
2. **The two gates do not call the same type by the same name.** One accepts `product`; the
   other accepts `ficha`. Passing the wrong one **raises no error**: the anatomy lookup
   misses, the requirement count falls to zero, and the anatomy heuristic **never fires.**
   A silent failure that reads as a pass.
   > This is open debt in this repository, and it is named in the "what this path leaves
   > open" section below. Until it is fixed in one of the two files, check the accepted
   > list in each gate's `--help`.

---

## Step 2 · The layout spine, BEFORE the text

**This is the step that prevents the prose-page.** Three gestures, in this order, and none
of them writes a sentence of content:

**2.1 · Copy your type's anatomy in as an EMPTY skeleton.** Open the anatomy for your type
and pour its required rows, **in order**, in as empty sections:

```html
<section class="section" data-sec="hero">…</section>
<section class="section" data-sec="offer">…</section>
<section class="section" data-sec="qualification">…</section>
…
<section class="section" data-sec="closing">…</section>
```

The `data-sec` is not decorative: it is what makes the anatomy checkable. The background
treatment **is not mixed in** with the role.

**2.2 · From role to primitive, and open the mould.** The default primitive for each role
is in the roles table. The mould is in the moulds folder — **you open it and copy it; you
do not write a component without checking whether it already exists.**

```bash
grep -i "<what I need>" <your-component-index>
ls  blueprint/moulds/
```

> **Three roles still have no mould** — siblings, map, form. Known debt.
> **Without a mould you lay it out by hand, you do not skip the role**: siblings is
> required in 5 of the 11 anatomies.

**2.3 · Now write the text INSIDE the primitive.** Every leftover paragraph goes through
the prose-to-primitive table. Its last row is the one that matters: *"none of the above →
it probably should not be there."*

**The two ceilings:** ≥4 **distinct** primitives, and **at most one** feature grid —
*it is the piece that replaced thinking.*

### The step-2 check — and why it is manual

**No gate fails for a missing `data-sec`.** Verified in both: one puts it in its notes and
says explicitly that it **does not count towards the verdict**; the other emits it as
`NOT VERIFIED`, and NOT VERIFIED does not change a verdict. That is a deliberate and
correct decision — a warning that fires on 100% of the population is noise — but it leaves
exactly the hole a new page walks through.

So the check belongs to the path, not the gate, and **it needs no browser**:

```bash
# declared roles vs the required roles for your type
grep -o 'data-sec="[a-z-]*"' <page>.html | sort -u

# the prose-page signature, in one line:
#   headings in the body + ZERO data-sec = prose by definition
echo "h2=$(grep -c '<h2' <page>.html)  data-sec=$(grep -c 'data-sec=' <page>.html)"
```

If it comes back `h2=6 data-sec=0`, the page is prose **before you open a browser** and you
do not move to step 3. It is the only one of these checks that works without rendering.

### 2-bis · If the page comes from a GENERATOR, the spine goes in the TEMPLATE

Measured on a real site: the top-level template opened `<main>` and the document template
emitted loose headings and paragraphs — **not one `<section>`.** Result:
**42 of 45 pages with no `<section>` at all**, and the 3 that had one were exactly the
three the project's own notes declared **outside the generator.**

> Fixing the new page by hand leaves the defect alive for the next one. **You extend the
> template** — which is also the project's own written rule: *"if something does not fit a
> type, you extend the type, you do not improvise a layout"* — and then the fix reaches all
> N pages at once. That is step 6.

---

## Step 3 · Linking is decided before writing

The eight rules for a new site are in the linking document. What changes when you add to a
site **already published**:

1. **Who links to it** — the two linkers from step 0, and they are **edits to existing
   pages**. They ship in the same batch.
2. **What it links to** — its parent (**visible** breadcrumb, plus a body link back) and
   **2–4 siblings** with descriptive anchors equal to the destination's keyword, never
   "here".
3. **If it is a child of a hub, the hub is edited in the SAME batch.** This is the exact
   cause of the two measured islands: one zones hub linking to none of its five children,
   and five city pages receiving **zero links from the entire site**.
4. **The URL shape is decided by the site, not by you**: with or without a trailing slash,
   with or without `index.html`. Inventing it manufactures redirects that do not exist —
   14 false positives on one site — and linking to `/index.html` leaves the canonical at
   zero, which was a live defect with **41 links to the non-canonical form**.

**Check, no browser needed:** grep the new path **inside the `<main>`** of the other pages.
*A result that only appears in the navigation line is a zero.*

---

## Step 4 · Head, schema, images, measurement

This layer is written in full elsewhere and is not repeated: the page standard's base
section, what your type adds, images, schema and what is forbidden. Measurement has its own
document.

Only three reminders, because all three have failed in production and **on a new page they
cost nothing**:

- **`og:image` + `og:image:alt` + `twitter:image`.** Mandatory, and **4 of 5 sites at 0%,
  including the site where the standard lives.** Fixed on one site and it never left. No
  HTML gate detects it: the page validates just as well without it.
- **`BreadcrumbList` on every page** — and a **visible** breadcrumb, or the linking rule
  fails. On one site 36 pages emitted the structured data and **none of them painted it.**
- **If it is a thank-you page**: `noindex` **and** the conversion event here. On one site
  the conversion fires from a pageview of a specific path: if that path ever changes,
  measurement stops **without anything failing.**

---

## Step 5 · The gates, on the new page

**Run against the published page, cheapest first.** Thresholds are in the final-QA
checklist; here is only what changes because this is **one page** and not a site.

| # | Gate | How | What gets reported |
|---|---|---|---|
| G1 | the greps from steps 2 and 3 | no browser, 30 seconds | `data-sec` vs required roles · body links |
| G2 | `structure-gate.js` | set the type, paste the file. **At 1440 AND 390** | verdict **and** whether it is a prose-page — two different questions · and the notes verbatim |
| G3 | `measure-screens.js` | at 1280 and 390 | screens · calls to action · blocks that overflow |
| G4 | CPL | same, at both widths | 0 paragraphs over 80 characters per line |
| G5 | `qa-master.pl` | `--type <t> --only seo,structure[,measurement]` | EXIT 0. **EXIT 2 ≠ PASS** |
| G6 | linking | `crawl-links.pl` + `linking-gate.pl` **after** shipping the batch | it is a GRAPH gate: it cannot run on a single page |

**The first thing you read is NOT the verdict: it is `innerWidth`.** If it is not what you
asked for, throw the whole measurement away — headless Chrome on Windows clamps to about
500px, and for 1280 you have to ask for 1298. **The measured `innerWidth` gets written next
to every number**, or the number does not count.

**A gate that could not be run is written `NOT MEASURED` with the reason.** A missing line
reads as a PASS.

**Red does not deploy.** That rule **only exists where the gate exists**: on one set of
five repositories, the site auditor was present in two. On the other three, this line was
the only thing holding it up.

---

## Step 6 · Ship the BATCH, and back-propagate

**You do not deploy a page: you deploy a batch.** In the same upload:

- the new page,
- **the hub and the two pages that link to it** (step 3),
- `sitemap.xml` and `llms.txt` — **from the same criterion, or they diverge**: one site's
  `llms.txt` published 11 URLs that 404 because it emitted a different URL shape from the
  sitemap,
- the CSS, **if the page introduces new classes**: the stylesheet ships in the same batch as
  the page that uses it, and you force a cache break before believing a computed style.

**Then: verify in PRODUCTION, not in the repo.** The repo can differ from what is served
without anyone noticing — that was live on one site, with a fix in the repository for hours
while production served the old file. The master gate with `--repo DIR` compares md5
between repo and production.

### Back-propagate — the step nobody does

If adding this page meant touching **a template, a mould, a token or the CSS**, the fix is
no longer about this page: it is about **N**. Before closing:

1. Say **how many pages** inherit the change (`grep -rl` for the class or the generator).
2. Run the structure gate on **one of the inherited pages**, not only on the new one.
3. If the fix transfers to another of your sites, **write it where the rule lives**, not in
   a comment in one repository's CSS. The lightness table that fixes one site's contrast
   lived in a comment in its stylesheet; another site shared the token, had the defect live,
   and did not have the fix.

---

## The edge case · a legitimately textual page

**A legal notice and a 404 ARE prose on purpose** — no anatomy and no calls to action.
Accusing them is the false positive that gets a gate switched off.

**How it is declared, in all three places:**

```js
window.__GATE__ = { type:'legal' };          // the structure gate
```
```bash
perl gates/qa-master.pl <url> --type legal   # the master gate
```
```html
<main data-tipo="legal">                     <!-- and in the HTML -->
```

The three exempt types are **`legal`, `404` and `thanks`**. The HTML matters as much as the
flags: without the attribute, the next person to audit infers from the URL again and
accuses again.

**What the exemption does NOT cover — and it is the half people forget.** It switches off
the anatomy and variety requirements, **not the rest**: width and CPL, links, hero and
contrast are all still judged. *A legal notice at 85 characters per line **fails on width**
and is **not** a prose-page* — the two answers come out separately on purpose and **both get
reported.** And a 404 still requires **≥3 live internal links and its own h1**: on one site
it served 796 bytes **without a single link.**

### A long guide is NOT an edge case

`guide` and `comparison` are structurally judged **on purpose**: they are exactly the case
that motivated the gate. What legitimises a long page **is not the topic or the length, it
is the layout** — alternating pairs per idea, a data band every few sections, an index to
give a map, an FAQ accordion for objections. And there is still a ceiling, but **it counts
words**: six screens of slack plus one screen for every 80 visible words past 400. The
report says so itself, quoting the limit it computed for that page's word count.

> **What you never do:** declare a page `legal` so the gate goes quiet. That is
> flattering the instrument, and the QA checklist already says it for the other case:
> *"you do not change a component's classes so the gate can see it — that leaves the site
> worse than it was."* Across the whole QA there is **one** declared exception, and **it is
> recorded, not silenced.**
>
> **A real exception is declared like this:** one line in the project's own notes with a
> date and a reason, and it appears in the report as `DECLARED EXCEPTION`, never as `PASS`.
> What is not declared, gets fixed.

---

## Check sheet — pasted into the report and filled in

```
NEW PAGE · <path> · <site> · <date>
P0 exists    : lane <…> · justification <measured volume | catalogue entry>
               body linkers: 1)<…>  2)<…>              [navigation does NOT count]
               cannibalisation checked against: <…>
P1 type      : <type> · anatomy §2.<n> · declared in data-tipo: YES/NO
P2 spine     : data-sec present: <…> / required roles: <…>
               distinct primitives: <n> (min 4) · feature grids: <n> (max 1)
               grep h2=<n> data-sec=<n>                [h2>0 and data-sec=0 = STOP]
P2bis        : from a generator? YES/NO · if yes, spine in the template? YES/NO
               pages inheriting the change: <n>
P3 links     : inbound body links <n> · parent <…> · siblings <…>
               URL shape used: <the site's>
P4 head      : og:image+alt+twitter Y/N · BreadcrumbList Y/N · breadcrumb VISIBLE Y/N
G1 greps     : PASS / FAIL
G2 structure : 1440 innerWidth=<…> VERDICT=<…> prosePage=<…> notes=<…>
               390  innerWidth=<…> VERDICT=<…> prosePage=<…>
G3 screens   : 1280 <n> screens · <n> CTAs · <n> overflow   / 390 same
G4 CPL       : 1440 paragraphs>80CPL=<n>  / 390 <n>
G5 qa-master : EXIT <0|1|2> · FAIL <n> WARN <n> NOT VERIFIED <n>
G6 linking   : after shipping · R0 <…> · orphans <n> · hub→children <…>
P6 batch     : page + hub + <n> linkers + sitemap + llms.txt + CSS
               verified in PRODUCTION: yes/no · md5 repo↔prod: <…>
               back-propagated to: <…>                 [or "nothing to back-propagate"]
NOT MEASURED : <gate> — <reason>                       [never omitted]
```

---

## Exactly which step would have prevented the prose-page epidemic

**Step 2, and more precisely 2-bis.** The detail matters, because naming the wrong step
produces the wrong fix.

What was measured on a real repository:

| | |
|---|---|
| the guides section | **14 of 14** pages with **0 `<section>`** · 3–13 headings each · up to **44 paragraphs** |
| the products section | **7 of 7** pages with **0 `<section>`** · 6 headings each |
| the whole site | **42 of 45** without a single `<section>` · **0 files** with `data-sec` |
| the 3 that had one | all three declared **outside the generator** |

**It did not fail 21 times: one template failed, 21 times.** Every new page came out prose
**by construction**, whatever the person writing it did.

- **Step 2 would have caught it** on the specific page: the anatomy as an empty skeleton of
  `data-sec` **before** a sentence is written. The one-line grep says it without opening a
  browser.
- **Only 2-bis actually fixes it.** Hand-inserting sections into page 22 leaves the 21
  before it and page 23 just as broken. The spine goes in the template.
- **And step 4 would not have caught it, however perfectly done.** This is the finding not
  to forget: those 14 pages **satisfied the entire content layer** — capsule, table, FAQ,
  article schema, dates — **and were prose anyway.** *Satisfying the content layer does not
  produce a layout.* A path that starts with SEO arrives too late.

**Why no gate stopped it, said plainly:** the gates that catch it were written *after* those
21 pages. And the check that is genuinely cheap — a declared `data-sec` — **neither of them
fails on**: one puts it in notes saying it does not count, the other emits NOT VERIFIED, and
NOT VERIFIED does not change a verdict. **That is why `data-sec` is a check belonging to
this path and not a promise made by a gate**: today, if nobody verifies it by hand at step
2, nobody verifies it.

---

## What this path leaves open, said out loud

- **No generator here emits `data-sec`** (0 of 121 pages measured). While that holds, step 2
  depends on a person, which is exactly what this system exists to kill. The open decision
  is stated in the master gate's own source: *either the generators emit the role, or the
  gate infers it another way.*
- **`product` vs `ficha`** — two names for one type across the two gates. It gets fixed in
  one of the two files, not here.
- **Three required roles with no mould** — siblings, map, form.
- **No gate was run while writing this.** What was verified here are the counts of
  `<section>`, headings, paragraphs and `data-sec` over a local repository, the cited lines
  of the two gates and the generator, and the fact that NOT VERIFIED does not change a
  verdict. The density, CPL and linking figures come from their own documents and **were not
  re-measured.**

---

## THE DOOR — the one step that cannot be skipped

> **This block is identical in all four paths.** If it changes, it changes in one place:
> four versions of the same step is how the duplicated-navigation mess started.
> `doc-gate.pl D5` fails if they diverge, or if a fifth path is born without it.

**Nothing is uploaded by hand. Ever.** Not a stylesheet, not an image, not "one line".

```bash
# 1 · measure THE TREE YOU ARE ABOUT TO UPLOAD, not the site already up there
perl gates/qa-master.pl https://your-domain.tld --repo DIR --candidate --max-urls 60

# 2 · dry run: writes nothing
bash gates/deploy.sh DIR

# 3 · upload, and verify that what is served IS what was measured
bash gates/deploy.sh DIR --upload
```

| | |
|---|---|
| **`--candidate` is not optional** | without it you measure PRODUCTION while the receipt seals the repository tree: two different artefacts wearing one face |
| **The receipt expires in 12 hours** | and is valid only for the exact tree it measured. Touch a file and it is measured again |
| **`NOT VERIFIED` is not a pass** | to ship with holes you sign them: `--anyway "the reason"`, which **gets written** into the history with the exact list of what was not measured |
| **There is another gate before uploading** | step 2-bis runs the spec auditor against the tree: is everything the spec says exists actually on disk? **It does not block yet** — it was wired in and produced three false positives the same day, since corrected — but its verdict **is recorded**. The mode is declared by the repo: `SPEC_MODE=migration\|greenfield` in `deploy.conf` |
| **After uploading, the door continues** | the served-equals-measured check compares md5 file by file, then it crawls the served site and runs the linking gate |

**If any of this fails, the deploy has not finished** — even though the files are already
up there. A red served-equals-measured means production is not serving what was measured,
and that has happened: a contrast fix sat in a repository for hours with every gate green
while production served the old stylesheet.

**Before touching the system itself** (a gate, a program, this documentation):

```bash
bash gates/run-all.sh     # every battery + documentation + coverage
```
