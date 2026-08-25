# 17 · From content to layout — the mechanism, not the advice

> **What this is for.** `09-page-types.md` says **which roles** each page type carries.
> `10-layout-vocabulary.md` says **which pieces** paint each block. What was missing was the
> one in between: **how you get from a pile of inherited text to a page with sections and
> roles, without losing a single word of the client's.**
>
> This is not theory: it is what was done in one day across the 29 pages of a real migration,
> with its four defects and the controls that caught them. Before that day, the section role
> was emitted by **0 of 121 pages** across five sites, and the anatomy-by-role check had never
> once run.

---

## 1 · The rule everything comes from

> **You preserve the CONTENT. The layout gets rebuilt.**

Migrating **does not reproduce the source's structure**: a WordPress dumped as it stands gives
you a page that is a wall of prose with one button at the end. What you preserve are **their
words**; how those are distributed across the screen is our work.

And from that comes the only check that actually protects it:

```bash
perl gates/same-text.pl <tree-before> <tree-after>
```

**This is NOT optional and it is not just another gate.** It compares the visible text of the
two versions **word by word.** A new layout that eats a paragraph **raises no error anywhere**:
the HTML is still valid, the integrity check is still green, the receipt is still green, and
the page publishes with less text than it arrived with. On that one day it found **10 pages
with losses, up to 207 words on a single one**, all of it the client's copy.

It runs **before** you measure the candidate. If there is loss, there is nothing else to look
at.

---

## 2 · The three rungs, and why in this order

### Rung 1 · The page DECLARES what it is

```html
<main data-tipo="service">
```

Without this the gate **infers the type from the URL**, and a service landing page shaped like
an article goes unnoticed — which is literally what happened to one page until a human noticed
it by looking at the site.

**Where it is declared:** in the spec, not by hand in the HTML.

```json
"types": {
  "by_slug": { "love-tarot": "service", "blog": "hub" }
}
```

**What can be derived without inventing:** `home`, `contact`, `thanks`, `404` and blog entries.
**Everything else is declared.**

**And the generator STOPS if a page has no type.** This is the part that keeps the mechanism
from ageing: without the throw, a new page ships without the attribute, the gate goes back to
inferring from the URL, and nobody notices — which is the state you came from.

```
throw "Page '$slug' has no type. Declare it in types.by_slug."
```

**The vocabulary is NOT written twice.** The valid types are the keys of the anatomy table in
the master gate. A second list went out of date on day one: one type was in the table and not
in the list, so the pages declaring it were rejected and went back to being inferred.

### Rung 2 · You declare the type **and ship that on its own**

**Before touching the layout.** It looks like a detour and it is the opposite:

> When the types were declared on that site, the anatomy check went from silent to flagging
> **12 pages** below their anatomy — **6 more than I had counted by hand.**

Declaring first turns the hole into a **measured number** before you start fixing it. If you do
both at once, there is no way to know whether the layout fixed what was there or what you
thought was there.

### Rung 3 · The layout cuts the content into sections with roles

```json
"layout": {
  "<slug>": [
    { "role": "hero", "primitive": "hero", "from": 0, "to": 2,
      "anchor": "The exact headline of block 0" }
  ]
}
```

Four properties, and all four earned their place:

| | What | Why |
|---|---|---|
| `role` | What that block DOES | It comes out in the HTML as `data-sec` and is what the anatomy check reads |
| `primitive` | What paints it | — |
| `from`/`to` | Indices into the extracted blocks | The cut is over the original array: **nothing is rewritten** |
| `anchor` | The text that MUST be at `from` | Indices move if you re-extract. If the anchor does not match, **you do not lay out blindly**: it falls back to flat and warns |

**Two controls that run on their own, and abort the whole page before writing:**

1. **Total coverage** — every block is in exactly one section. Not one outside, not one in two.
   An orphan block is the client's content disappearing.
2. **The anchor matches** — or it does not get laid out. **Half a layout is not half right: it
   is a section carrying another section's text**, and no validator detects that.

**The cuts are NOT written by hand when there is more than one page.** On that site it was 5
city pages × 7 sections = **35 indices and 35 anchors**, and the 5 **do not share indices**
(two carry an extra block). You compute them with a program that looks for each section's
**text markers** and derives the indices from those. A wrong index does not error: it gives you
a section with another section's text.

---

## 3 · Two libraries of pieces, and they are not the same thing

This has confused people before, so it goes in writing:

| | **Moulds** (HTML files) | **Primitives** (in the generator) |
|---|---|---|
| **What it is** | HTML ready to **copy and adapt** | Functions that **cut existing content** |
| **When** | A **new** page, written by us | **Inherited** content that has to be re-laid-out |
| **Chosen** | By looking at the catalogue | In the spec's layout block |
| **Where** | `blueprint/moulds/` | Each site's generator |

**They do not compete: they are used at different moments.** A new site is written with moulds.
A migration is cut with primitives. And a migrated site that gets a page added later uses
moulds for that page.

### The primitives that exist, and what each one does

| Primitive | For | What must not be forgotten |
|---|---|---|
| `hero` | h1 + standfirst + action | **The h1 stays an h1.** A band primitive would demote it to h2 and the page would end up with no h1 |
| `alternating-pair` | Text one side, image the other | — |
| `grid` | Cards (3–6) | See the warning below: **it was eating content** |
| `stair` | Numbered steps or price tiers | — |
| `aside` | Highlighted block, "who this is NOT for" lists | — |
| `accordion` | Questions and answers | Recognises numbered questions **and** paragraphs ending in a question mark |
| `band` | Closing call to action | Emits its headline as an h2 |

**Every new primitive has to answer this before it is used:**
**what does it do with a block that does not fit its shape?** The correct answer is *"it emits
it anyway, even as a plain paragraph."* The answer that cost 10 pages was *"it discards it
silently"*: the grid primitive only started a card at an image or a level-3 heading — and those
pages titled with level-5 headings — so it deleted the cards with no title, which is exactly
what a testimonial is.

---

## 4 · What you never invent

Three things shipped in one day by skipping this, and no gate saw any of them:

1. **A headline.** If the content brings no headline for that section, **the section ships with
   no `<h2>`.** A role is OUR vocabulary, not the client's copy: falling back to the role name
   published `<h2>qualification</h2>` in ten places and `<h1>hero</h1>` in one.
2. **An `h1`.** If the extracted blocks do not carry one — which happens when the theme painted
   it outside the content — you take it from the page's title, and **if there is none, you
   STOP.**
3. **A hierarchy.** "Related links" **is not** "parent". If one table serves both, you get
   breadcrumbs where a menu page hangs off a blog post. Two rules: **it is only a hierarchy if
   the parent is in the menu**, and **a menu page hangs off the home page and nothing else.**

---

## 5 · The complete sequence, to copy

```bash
# 0 · photograph of the BEFORE (without this, step 4's control cannot exist)
cp -r <repo>/*.html /tmp/before/

# 1 · declare types in the spec, generate, and SHIP ONLY THAT
<your generator>
perl gates/qa-master.pl <URL> --repo . --candidate --max-urls <N>
bash gates/deploy.sh . --upload

# 2 · read the number that just appeared
#     the anatomy check now says how many pages are below their anatomy

# 3 · cut the layout of those pages (computing the indices, not by hand)
<your generator>

# 4 · THE CONTROL: not one word fewer
perl gates/same-text.pl /tmp/before .

# 5 · the door
perl gates/qa-master.pl <URL> --repo . --candidate --max-urls <N>
bash gates/deploy.sh . --upload
```

**When it is done:** the anatomy-complete check PASSES, and the text comparison reports **0
pages with loss.**

---

## 6 · What this document does NOT solve

- **The vocabulary has holes.** Three pages on one site **do not fit any type** in the anatomy
  table. The house rule is *"if something does not fit a type, you EXTEND the type"* — but
  extending it touches all five sites: **that is a decision, not a fix.**
- **A headline repeated across several city pages is still copywriting.** Five area pages on
  one site share an H1 — the explicit prohibition in the page-types document — and rewriting
  them means touching a client's public text.
- **None of this measures whether the page is GOOD.** It measures that it has the roles its
  type requires. Whether the content of each role does its job is what the density gate says
  and, in the end, what looking at it says.
