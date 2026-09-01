# Page types: the anatomy of each one, and the architecture of a large site

> **This file is not about SEO.** The machine layer — the `<head>`, schema, the answer capsule,
> what gets marked up and what does not — has its own single source and is not duplicated here.
> This is the layer that was missing: **which sections the BODY of each page type has, in what
> order, with which layout primitive, and what breaks when one is absent.**
>
> The failure that motivates it, measured and not opined: **42 of the 45 pages on one site did not
> have a single `<section>`.** The `<main>` of a guide was a flat run of paragraphs hanging
> directly off the wrapper. That is not a site with bad layout: it is a site **without** layout.

---

## 1 · The missing piece: a section is a ROLE, not a background

**Why none of this was checkable before.** Looked at in the two generators that do produce
sections:

- One spec gave every section a background field, and its only four values across 13 pages were
  hero, plain, surface and soft. **That is paint, not function.** A testimonials section and a
  pricing section are both "plain".
- Another emitted five sections **in a fixed and correct order**, but with no names. The order
  lives in the code, so no gate can say "this page is missing its proof section".
- The only attribute that did name places was a measurement one. On one site its 105 measured
  calls to action broke down as **90 in the chrome** (footer 36, topbar 18, header 18, floating
  18), 9 in the form, **3 in the hero and 1 in a section.** As far as measurement was concerned,
  **the body of the site did not exist.**

**The rule, and it is what makes everything else checkable:**

> Every body section carries `data-sec="<role>"`. The role comes from the list below. The
> background is a decision about visual rhythm and **is not mixed in** with the role.

```html
<section class="section" data-sec="qualification"> … </section>
```

It costs one attribute and unlocks three things that are otherwise impossible: checking a type's
anatomy, measuring conversion by section role instead of by button colour, and detecting the
prose-page — **a page with headings and ZERO roles is prose by definition.**

### The role vocabulary

| Role | The job it does | Default primitive |
|---|---|---|
| `hero` | Locates, promises, and offers the first action | hero |
| `proof` | Gives a reason to keep reading: figures, logos, years, volume | data band |
| `offer` | What this is exactly and what it includes | feature grid or alternating pair |
| `qualification` | Who it is for and who it is not. **It filters, and that is a function** | checklist |
| `process` | What happens after you click | numbered steps |
| `catalogue` | This hub's children, with their label and status | feature grid |
| `evidence` | Cases, testimonials, screenshots, before/after | alternating pair |
| `alternatives` | What else exists and why this | comparison table |
| `objections` | What stops the decision, answered | FAQ accordion |
| `siblings` | Lateral links within the same cluster | **no mould yet** |
| `context` | Who is behind it. Authority, not biography | alternating pair |
| `map` | Where, areas covered, how to get there | **no mould yet** |
| `form` | The form and only the form | **no mould yet** |
| `resource` | The quiz, video, form or download a landing hands over. **It is not a section of the page: it is the page** | choice cards |
| `closing` | The last call. It is never optional | closing CTA |

**Twelve of the fifteen have a mould**, with its "when NOT to use this" and its behaviour at
390 px. **They get opened before anything is written** — it is a step, not a suggestion.

> **This table is also `gates/roles.tsv`**, the same way §2 is also `gates/anatomy.tsv`. Not a second
> source: `roles.pl --gate` compares them row by row, by name and by default primitive, and the
> "eleven of the fourteen" above is **derived** from the data — it used to be written by hand here
> and again in 10 §6, so it could go stale in two places at once.
>
> Crossed with §2 it produces **one reference sheet per page type**, generated:
> `blueprint/moulds/types/<type>.html`. Open the one for the type you are building — it lists the
> roles in order, the mould for each, and that mould's own "when / when not". See
> [`10-layout-vocabulary.md §6.1`](10-layout-vocabulary.md) for why a *generated* sheet is allowed
> where a hand-written composition table was deleted.
>
> ⚠️ `evidence` and `context` are in this vocabulary and **in no anatomy**: nothing requires them
> today. Marked `SOLO-VOCABULARIO` in `roles.tsv` rather than quietly dropped — adding a role to an
> anatomy changes what every site must carry, and that decision belongs in §2.

> **Three roles have no mould yet, and all three are mandatory in some anatomy** — `siblings`
> (required in 5 of the 11), `map` (city and contact) and `form` (contact). They exist in
> production already, unextracted. They are registered here **before** being extracted, for the
> same reason the mould index exists: **a component that exists and is not in the index gets
> rewritten from scratch.** Meanwhile the role **is still required**: with no mould you lay it out
> by hand, you do not skip it.
>
> A note here once claimed *"two roles have no mould, and the second is mandatory in eleven of the
> eleven anatomies."* **Both halves were false**: that mould does exist, and it is required in
> **9 of the 11** — not in contact (where the form closes) and not in legal or 404 (which have no
> calls to action on purpose). **A count nobody re-derives drifts.**

---

## 1-bis · What each type is FOR — site objective × page intent

> 🔴 **Added 28-aug-2026, and the gap it closes was real.** Everything below §2 says *which
> sections a type carries*. Nothing said **what the site is for**, so nothing could catch the
> commonest brief failure there is: *"the site exists to sell and you wrote me an informational
> page."* Measured that day: **not one of five live sites declares an objective anywhere** — not in
> its spec, not in its deploy config, not in its audit config.
>
> The document already *reasoned* about intent — «objections are answered on the service page,
> where intent is already formed» — but as prose for whoever reads it, **not as a property anything
> can check.** And what cannot be checked drifts.

**Two declarations, and the page is the product of both.**

**1 · The SITE declares its objective.** One per site, and it does not change with the page:

| Objective | The site exists to… | The page that serves it |
|---|---|---|
| `sell` | close a transaction on the site itself | product, pricing, category hub |
| `capture` | obtain a qualified contact | service, city, lead magnet, contact |
| `inform` | be the reference on a subject (media, docs, institution) | guide, comparison, hub |

**2 · The TYPE declares its intent.** This is fixed and universal — it does not depend on the site:

| Intent | Types | What the visitor is doing |
|---|---|---|
| **transactional** | `product` · `pricing` · `service` · `city` | deciding, or about to |
| **capture** | `quiz` · `contact` | handing over their details, or not |
| **navigational** | `home` · `hub` | choosing where to go |
| **informational** | `guide` · `comparison` | learning, and not buying yet |
| **utility** | `thanks` · `legal` · `404` | neither of the above |

### The rule that comes out of crossing them

> **A page whose intent does not match the site's objective is legitimate only if it ROUTES to
> the layer that does.** It is not banned — it is *conditional*.

On a `sell` site, a guide that ends without a way through to the product is not a bad page: it is
**someone else's page, published on your domain**. It earns traffic that leaves.

🔑 **And the system already half-enforces this without saying so.** `guide` and `comparison` both
carry `siblings` as REQUIRED — a link to the pages of the same cluster. That requirement *is* the
routing rule, written as an anatomy and never explained. Naming it turns a section that gets filled
in out of obedience into one that gets filled in on purpose.

### Voice follows from intent, not from the brand

The brand sets the register — how formal, how dry, how much humour. **The intent sets what the
sentence is doing**, and mixing them is how a shop ends up sounding like a wiki:

| Intent | The sentence… | Ships badly as |
|---|---|---|
| transactional | speaks in the second person, about the outcome and the cost of not acting | a specification sheet |
| capture | says what you get, when, and what happens to your data | a sales pitch — here the objection is trust, not price |
| informational | explains, cites, and is willing to say "it depends" | a disguised advert, which is what burns the citation |
| navigational | orients in the fewest possible words | prose |

⚠️ **None of this is enforced by a gate today, and saying so is the point.** It lives here as a
contract because the shape was decided (site × type) but not the rollout: no site declares its
objective yet. **Wiring it means an `objective` field per site and an `intent` column in
`anatomy.tsv`** — and that column is not free: `anatomy.pl` parses the table with `split /\|/, $_, 6`,
so a seventh field lands silently inside `note`, and five programs consume it. It is a schema change
with five consumers, not a line.

🟢 **One corner of it IS enforced since 2026-09-01, and only one:** `SEO-05` / `SEO-05b`
(`03-content-and-seo §2.1`) check that a page's `<title>`, `<h1>` and description share at least one
significant word — that the three surfaces are talking about the same thing. That is **coherence**,
not intent: the gate cannot tell a transactional page from an informational one, and it never will
without the `objective` field. What it does catch is the failure that comes free with a template — a
title written for the search result and an `<h1>` written for the visitor, drifting apart until they
promise two different pages. Do not read it as the voice contract being live. It is not.

## 2 · The twelve anatomies (13 types: legal and 404 share §2.11)

> **THE SINGLE SOURCE of "which sections each page type carries."** There is no other. Another
> document once gave a second table, by primitive instead of by role, and **it disagreed with this
> one**: it missed a role in the home, two in service, two in guide, and one of them appeared in
> none of its seven compositions. **It was deleted.** If a composition table ever reappears in
> another file, this one wins and the other goes: **a question with two answers is worse than one
> with none.**

> **And this table has a machine-readable twin: `gates/anatomy.tsv`.** It is not a second source —
> it is this one, in a format the gates can read, and the anatomy gate checks it by counting the
> required markers of each subsection here. Before that, the table was copied by hand into three
> programs "on purpose", and **seven of twelve types had diverged**: see the trap log §44. Touch a
> row here and the gate goes red until the table is touched, and vice versa.

How to read each table: **the row order is the order on the page.** `REQ` = required. `OPT` =
optional, with the condition that justifies it.

> **THE VOCABULARY HAS HOLES, AND THEY ARE MEASURED.** Going to declare the type of 13 pages on
> one site, **three did not fit any of the eleven that existed then**: an about page, a partner page, and a careers
> page. Those are not exotic — every service business has them.
>
> The house rule is *"if something does not fit a type, you EXTEND the type."* **But extending this
> table touches every site and every gate: it is a DECISION, not a fix made in passing.** Until it
> is decided, those pages stay undeclared — and **declaring them as "the nearest type" would be
> worse**, because it would pass a check that was not actually performed.

### 2.1 · Home

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` | REQ | With no action above the fold, the 60% who only see this have nothing to do |
| 2 | `proof` | REQ | The hero promises and nobody corroborates. This is the section that buys permission to scroll |
| 3 | `offer` | REQ | The visitor does not know what you sell. **Maximum 3–6 items: it is an index, not the catalogue** |
| 4 | `process` | REQ | "And what happens if I write?" goes unanswered, and that stalls conversion |
| 5 | `evidence` | OPT — if there is real material | — |
| 6 | `qualification` | OPT — if many off-profile leads arrive | — |
| 7 | `context` | OPT — if the brand is a person | — |
| 8 | `closing` | REQ | Somebody convinced at the bottom has nowhere to act |

**FORBIDDEN on the home:** more than one conversion goal · more than one feature grid · an FAQ
(objections are answered on the service page, where intent is already formed) · nine headings and
four calls to action, which is exactly the state one restructure came out of.

### 2.2 · Service / commercial landing

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` | REQ | — |
| 2 | `offer` | REQ | What is included. Without it the page is a brochure |
| 3 | `qualification` | REQ | All the filtering falls on the call. **It is the section that saves time most cheaply** |
| 4 | `process` | REQ | Pre-form anxiety is not lowered with adjectives, it is lowered with steps |
| 5 | `evidence` | OPT — with written permission | — |
| 6 | `alternatives` | OPT — if it competes with something nameable | — |
| 7 | `objections` | REQ | The same 8 questions by email, forever |
| 8 | `siblings` | REQ | The page is a dead end and the cluster does not hold together |
| 9 | `closing` | REQ | — |

**FORBIDDEN:** a run of paragraphs acting as the offer · repeating the same call to action six
times without changing the argument · starting with the process (nobody wants to know how you work
before knowing what you do).

> **This anatomy exists and is verified in production.** One generator emits hero → prose → FAQ →
> siblings → closing across 31 pages. It is the only one of our sites that passed the density gate
> first time (3.2 screens, 0 overflows, 4 calls to action distributed). It is missing
> `qualification` and `process`.

### 2.3 · City / local page

Same anatomy as 2.2 with **three differences that are not cosmetic**:

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` **with the place name in the H1** | REQ | See the failure below |
| 2 | `map` | REQ | The only question that brings the visitor — *"do you come to my town?"* — goes unanswered |
| 3 | `offer` | REQ | — |
| 4 | `evidence`, **local** | OPT | — |
| 5 | `objections`, **at least one local** | REQ | — |
| 6 | `siblings` = neighbouring cities + the areas hub | REQ | Each city is an island and the hub distributes no authority |
| 7 | `closing` | REQ | — |

**FORBIDDEN:** the same H1 across several cities · identical content with the name swapped (that is
not a page, it is a duplicate with a self-canonical, which is the worst possible combination: you
are asking the search engine to index N copies).

> **Our cleanest failure to verify.** Five area pages had correct per-city `<title>` tags and **all
> five shared the same H1** — the same as the hub's. The place name dropped to a subheading. **No
> audit caught it because the titles are unique and the gate looks at those.**

### 2.4 · Product detail page (catalogue)

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` = image + name + price + action | REQ | — |
| 2 | `offer` = specifications | REQ | Returns caused by badly set expectations |
| 3 | `proof` = shipping, guarantee, lead time | REQ | Cart abandonment is decided here, not at checkout |
| 4 | `evidence` | OPT | — |
| 5 | `objections` | REQ | — |
| 6 | `siblings` = same family | REQ | Zero cross-selling and an exit with no way back |
| 7 | `closing` = repeat the action | REQ | On mobile the hero's button is three screens up |

**FORBIDDEN:** an H1 that is not the product's name · a `<title>` shared between detail pages ·
rendering the page only with JavaScript.

### 2.5 · Hub / index

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero`, short, with no commercial action | REQ | — |
| 2 | `catalogue` = **all** the children, with a type label and status | REQ | It is the entire page |
| 3 | `qualification` = how to choose between them | REQ | The hub is a list, not a guide. **This is what distinguishes it from a menu** |
| 4 | `closing` | REQ | — |

**FORBIDDEN:** a hub with fewer than 4 children (see §4.2) · a child that does not link back ·
listing children that do not exist yet.

### 2.6 · Guide / pillar, and 2.7 · Comparison

**Content, capsule, table, source, FAQ, dates and schema live in the page standard and are not
repeated here.** What is added is the layout, and that is where it fails:

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` = H1 + 40–60 word capsule + visible date | REQ | — |
| 2..n | an alternating pair, one per idea | REQ | **This is where it fails.** Without it, it is a blog article |
| — | a comparison table | REQ in a comparison · ≥1 in a guide | — |
| — | a data band every ~3 sections | OPT | With no breathing room, it gets abandoned halfway |
| n-2 | `objections` | REQ | — |
| n-1 | `siblings` = 2–4 from the same cluster | REQ | — |
| n | `closing` | REQ | — |

**FORBIDDEN:** a heading as the only separator between runs of paragraphs — **a heading is a label,
not a section boundary** · exceeding the height budget (6 screens plus one per 80 visible words past
400) · more than 2.5 consecutive screens with nothing to click.

> **The real state, counted.** One guide had **36 paragraphs as direct children** of the wrapper and
> zero sections. Another had 37; another, 30; another, 27. They satisfy the entire content layer —
> capsule, table, FAQ, article schema, dates — and are prose anyway. **Satisfying the content layer
> does not produce a layout.**

### 2.8 · Pricing

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` with the model in one sentence | REQ | — |
| 2 | `offer` = plans in parallel | REQ | — |
| 3 | `proof` = what **every** plan includes | REQ | The comparison is made on differences and the cheap one gets over-valued |
| 4 | `process` = what happens on signing, how to cancel | REQ | The real objection is not the price, it is the commitment |
| 5 | `alternatives` | OPT — if the market has a reference price | — |
| 6 | `objections` | REQ | — |
| 7 | `closing` | REQ | — |

**FORBIDDEN:** an amount hand-written in the HTML when a single source exists · "from X" without
saying what it depends on.

### 2.9 · Contact

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero`, short, with the preferred channel already visible | REQ | — |
| 2 | `form` | REQ if there is a form | — |
| 3 | `proof` = response time and opening hours | REQ | People send blind and duplicate their enquiries |
| 4 | `map` | REQ if there is a physical location | — |
| 5 | `objections` = 2–3, no more | OPT | — |

**FORBIDDEN:** a phone number that is not a `tel:` link · asking for fields you will not use · being
the only page with the phone number on it.

### 2.10 · Thank-you / post-conversion

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` = a literal confirmation of what just happened | REQ | — |
| 2 | `process` = what happens now, and **when** | REQ | They get contacted on another channel two hours later and the lead is duplicated |
| 3 | `closing` = **the next step, not the same one** | REQ | A dead end on the one page where trust is highest |

**REQUIRED and outside the layout:** `noindex` **and** the conversion event firing here. On one
site the conversion fires from a pageview of a specific path: **if that path ever changes,
measurement stops without anything failing.**

**FORBIDDEN:** repeating the call to action that was just completed.

### 2.11 · Legal and 404

- **Legal:** no anatomy and no calls to action. Prose on purpose, a heading per article, a visible
  last-updated date. **Touched as little as possible** — on one site they hold up an app
  verification.
- **404:** a single block — what happened, a search box if one exists, and **3–5 links to the most
  requested destinations**, not to the home page. `noindex`.

### 2.12 · Landing — the whole type is three things

**A landing is not a short page: it is a page with one job and no second one.** The type carries an
H1 that says the message, one line saying why, and **the resource** — the quiz, the video, the form,
the download. Everything else that normally goes on a landing is what the visitor scrolls past on
their way to deciding, and it is where the page starts arguing with itself.

| # | Role | | If it is missing |
|---|---|---|---|
| 1 | `hero` = the H1 **and** the one line of why | REQ | A landing you have to scroll to find out what it gives you has already lost the half that arrived from an ad |
| 2 | `resource` = the quiz, the video, the form, the download | REQ | **The resource is not a section of this page, it is the page.** Same rule as the table on a comparison page |
| 3 | `proof` | OPT — a logo band or one quote, no more | — |
| 4 | `context` | OPT — if the offer is signed by a person | — |

**FORBIDDEN:** a second call to action competing with the resource · a hero that does not say what
you get · sections added because a landing "usually has them" · **and promising a delivery the
receiver does not actually make** — that one is not a style rule, it is measurable, and the
measurement lens already asks it.

⚠️ **When the resource is a form that takes personal data, the consent line is part of the form, not
an extra section.** Dropping `objections` from this anatomy drops a persuasion section; it does not
drop a legal duty. The reference measured below puts it inside the form, as a labelled checkbox, and
that is the right place for it.

> 🔴 **THIS SECTION SAID SOMETHING ELSE ON THE MORNING OF 2026-09-01, and the correction is worth
> more than the rule.** It required **seven** roles: hero, form, offer, qualification, process,
> objections and closing. That anatomy was derived honestly — read off the lead-magnet landing we
> already run — and that is exactly what was wrong with it. **Reading a type off one example we
> built ourselves does not measure the type; it measures our own habit.** A maximal page produced a
> maximal anatomy, and the anatomy would then have required every future landing to be as long as
> the one page it was copied from.

#### What three commercial funnel templates actually do — measured, 2026-09-01

Three references, measured in the browser at 1280×720 and at 375×812, not read off a screenshot:

| | quiz landing | VSL landing | lead-magnet landing |
|---|---|---|---|
| Above the fold | eyebrow 16px → headline 56px → why 20px → **two image choice cards** | headline 56px → why 20px → **video 896×504** | avatar + name 14px → **headline that is a customer quote** 48px → why 20px → form (2 fields) |
| Page height | 8671px | 4632px | 4498px |
| DOM nodes | 1581 | 800 | 808 |

**All three put the same three things above the fold and nothing else**, and on a 375px screen the
quiz's two cards still land entirely above it (156×174 each, top 486, bottom 660, fold 812). That is
the whole rule, and it is the same rule on both widths. What follows the fold is 4000–8000px that
only somebody who has *not* decided will ever see — and the page was built to make them decide in
the first screen.

**Three things worth taking:**

1. **The type scale**, measured off the elements: eyebrow 14–16 · headline 40 (mobile) → 56 (desktop)
   · why 20 · choice label 24 · body 16/24. The headline is the only thing that moves with width.
2. **The choice as two image cards, not a radio list.** Extracted as
   [`moulds/20-choice-cards.html`](moulds/20-choice-cards.html), with its markup rebuilt — see below.
3. **The lead-magnet headline is a customer quote**, with the attributed face above it. The proof
   *is* the headline instead of sitting in a band underneath.

**And the reason none of the markup was copied.** All three ship **zero `<h1>`** — measured,
`h1count: 0` and `role="heading"` 0 on each. Every headline is a `<strong>` at 56px, so to a screen
reader and to an indexer those pages have no headings at all. The quiz's choice is a
`<div role="button" tabindex="0">`, which works but has to reimplement Enter and Space by hand; the
lead-magnet's two inputs have **no `<label>` and no `autocomplete`** — the same defect `A11Y-09`
catches on our own sites. They are conversion machines with no document underneath.

> 🔑 **The lesson that generalises: take the composition, never the markup.** A reference is
> evidence about what to put where and in what order. It is not evidence that the HTML underneath it
> is sound, and these three are the clearest case of that split this system has measured — excellent
> at the first question, indefensible on the second.

## 3 · The hard rule for the home: a hero that converts, not one that links

**The rule:** *the hero must contain the conversion goal, not just navigation.*

Verified across five heroes: three converted, one converted but had **only three calls to action in
the whole page** (8.2 screens, 7 consecutive with nothing to click), and one had **two, both pure
navigation.**

### What distinguishes one from the other

A hero that converts has **one primary action and only one**, named by what the visitor receives
(*"See it on your own accounts — free"*, *"Book an assessment"*), not by what the site does
(*"View the shop"*, *"Learn more"*), and it comes with **the sentence that removes the fear** —
price, commitment, timeframe.

A hero that links has two or three buttons of the same visual weight pointing at sections. **The
visitor picks the cheapest one, which is leaving.**

**The two honest exceptions:**

1. **E-commerce.** Navigating to the catalogue *is* the funnel. But then **the obligation is
   inherited**: the catalogue page has to carry the conversion. On one site that inheritance broke —
   the catalogue serves a skeleton wrapper and builds the shop with JavaScript: **no H1, no
   sections, and not one product link in the HTML.** The conversion chain runs through a page that,
   to anything that does not execute JavaScript, is empty.
2. **A secondary action** is fine if it is **lower commitment** and visibly so. Two buttons of the
   same weight are not that.

---

## 3-bis · The MOBILE fold, and what gets put on top of it

> **This section exists because the defect was found by a human opening the site on their phone,
> not by any gate.** And that was not carelessness: it was impossible for them to see it. The layout
> gates are about **presence** (counting calls to action), **colour** (contrast) and **geometry**
> (touch target size). All three answer "yes". **None of them asks whether something is on top.**

### 3-bis.1 · The three rules

**M1 · Every page that asks for an action has an action ABOVE THE FOLD at 390×844.**
Not new: it is the `hero` row of §2.1 said as a measurable quantity. And §3 above had already
measured one site as *"8.2 screens and 7 consecutive with nothing to click."* **It was written down
and it was still broken**: the textbook case of the 102 rules with no gate.
> It counts only what is INSIDE `<main>`. A button in a sticky header is above the fold on every
> page equally: counting it would make them all pass and the gate would say nothing.

**M2 · ZERO calls to action covered by floating chrome.** A button that exists, contrasts and
measures 44×44 but has a banner on top of it **is not a button.** Measured with `elementFromPoint`,
which is not a rectangle heuristic: it is the engine's own answer, and it is exactly what decides
where a finger lands.

**M3 · Floating chrome should not eat more than a third of the screen.** This is a **WARNING, not a
failure**: that 33% is common sense, **not a figure measured against references.** An invented
threshold that blocks is a gate somebody switches off.

### 3-bis.2 · The four traps of measuring it, and all four bit

1. **The DOM says it is at the top and the screen says it is covered.** The first measurement gave
   *"first CTA at 0.6 screens, above the fold."* True in the DOM, false on screen. **Position is not
   visibility.**
2. **What covers it appears LATE.** One popup fires at 1,800 ms, and after consent it took a
   measured **3,189 ms.** A gate that measures at load **never sees it.** The first version of the
   gate fell exactly there: it reported "stable" at 911 ms and signed off a PASS over the popup.
   Hence a **waiting floor**, and the report declares at what millisecond each thing appeared.
3. **There are TWO visitors and they see different screens.** First visit → cookie banner. Somebody
   who already accepted → the popup the banner was covering. **The real defect was in the second
   one.** The gate measures the first by default and **says so**; the second requires clicking
   accept, which is an action, and a gate that runs on every deploy should not be accepting consent
   on its own.
4. **A 404 and a page with no buttons give the SAME zero.** A loop of mine requested a URL with a
   trailing slash, the server returned 404, and the gate counted it as a layout failure: the page was
   perfect. It now declares **NOT MEASURABLE**, which is neither a pass nor an accusation. It also
   covers JavaScript shells and anti-bot walls.

### 3-bis.3 · The exemption that lets the gate survive

**M1 does not apply to `legal` or `thanks`.** One legal page had its first call to action at **15.5
screens** and was correct: a privacy policy does not carry a call to action. Without this exemption
the gate would accuse every legal page on every site, and **a gate that accuses falsely twice
degrades itself.** The page declares it with its type attribute; failing that it is inferred from
the path, and the report says it inferred.

### 3-bis.4 · What surfaced while fixing it: **the piece existed and was in the wrong place**

All five sites failed, and in the three generated ones the cause was the same class of thing:

| Site | The cause | Where the action was |
|---|---|---|
| A | the hero buttons guarded by an "is home" condition | on **1 page of 18** |
| D | detail pages had it; hubs and fixed pages did not | on 29 of 40 |
| our own | every page emits its buttons in the closing section | **fifteen screens further down** |
| C | blog entries build their hero through another branch | only on the detail pages |
| B | a CSS ordering rule put the image BEFORE the headline on mobile | the visitor saw a photo and nothing to click |

**None of them needed a new piece.** In all five, the button the site already emitted was reused. And
in one, the generator's own comment already quoted the instruction: *"the home must convert and have
its goals clear in the hero ON EVERY SITE"* — **the intent was written down and had been implemented
only for the home page.**

> **Twice the fix created the next defect, and the gate caught both:** on one site the third button
> fell under the consent banner; on another the call to action went behind the article image and
> dropped from 15.75 to 2.12 screens — better, and **still below the fold.** The action goes attached
> to the headline, not at the end of the hero.

### 3-bis.5 · Rules for the next landing page

1. **The hero carries the action, and it goes attached to the headline** — not after the image, not
   at the end of the section.
2. **A call to action is not linked to the page you are already on.** On a contact page that would be
   the hero's only button, and it is not an action: it is noise.
3. **Floating chrome sits flush to the bottom edge with a height cap**, never as a card floating 12 px
   off the edge: that is where the buttons are.
4. **It is measured at 390×844 on a Linux host**, with `innerWidth` verified.
5. **Before accusing, check it is a page.** Zero calls to action can be a 404.

---

## 4 · Architecture of a large site

### 4.1 · Three levels, and the third is justified

```
/                         level 0 · home            1
/<lane>/                  level 1 · hub             3-6
/<lane>/<child>/          level 2 · working page    n
```

**Level 3 only if the child has real children** (product variants, sub-areas). Every extra level moves
away from the home and dilutes internal linking.

Measured across five sites: three at depth 2 (fine), one **flat with 29 pages hanging off the home**,
and one at depth 0 with everything in the root **and the catalogue not in the HTML.**

### 4.2 · When a topic deserves a hub with children, and when one page will do

| | Hub with children | One page with anchors |
|---|---|---|
| Number of subtopics | **≥ 4 real ones today** | 2–3 |
| Search | each child has **its own measured demand** | only one has it |
| Visitor's decision | they choose between them | they read them all |
| Cost | n pages to maintain and link | one |

**The threshold is four, and it comes from our own errors in both directions.** Below: two folders had
**one page each** — *a page is not a section* — and were merged. Above: one hub gathered 12 products
of which **4 did not exist**, and the four planned ones had zero body links each.

**The rule that avoids both:** a hub opens when there are 4 children **written**, not planned. While
there are 3, they live inside the parent with anchors. And a child that does not exist **does not get
a page**: it gets a line in the hub with its honest status.

### 4.3 · How they link (the minimum that makes a site a site)

Three rules. All three are checkable with grep, and we have broken all three.

1. **Parent → all its children**, from the body. A hub that does not list a child leaves it orphaned.
2. **Child → parent**, with the breadcrumb **and** a body link back.
3. **Child → 2–4 siblings** with a descriptive anchor (= the destination's keyword, not "here").

**The navigation does not count.** It is identical on every page, so it says nothing about any of them.
This was already written down — *"at least two, the navigation does not count"* — and **the newest page
on the site broke it**: it appeared on 20 pages and all 20 times it was the same navigation line. Zero
body links. It was in the sitemap at the highest priority after the home, and **the hub of its own lane
linked to its six siblings and not to it.**

### 4.4 · The type has to be visible, or the taxonomy does not exist

One project declared that a section is a single taxonomy where *"the type is a label, not a folder."*
That is the correct decision. **But it was not implemented:** the hub listed its 14 children **without a
single type label**, and on the pages the visible category was a topic, not a type.

Measurable consequence, not theoretical: of the 14, **6 had no table, no FAQ and no visible date.** They
might be downloads and field notes — which do not require those — or incomplete guides. **There is no way
to tell from the page, and therefore no way to gate it.**

→ **The type goes in the HTML** and shows as a label on the hub's card. **A type that only lives in a
project note is not a taxonomy: it is an intention.**

### 4.5 · A new role does not open a new directory

Before creating a first-level folder: is there a lane? Without one, it does not get created. **Seven
sibling directories with no hierarchy** was the state one restructure came out of.

---

## 5 · Cannibalisation: two pages answering the same question

**Symptom:** two URLs whose answer to *"which search does this page exist for?"* is the same sentence.
The text does not have to be identical.

**The four fixes, in order of preference:**

| Situation | What you do |
|---|---|
| Same intent, same quality | **Merge** into one, redirect from the other |
| Same intent, one wins | The loser gets a redirect, or a canonical to the winner |
| Intents that only *look* the same | **Differentiate the H1 and the capsule**, and link them to each other |
| Two domains, same catalogue | **Decide before indexing** |

**What you do not do:** leave both and wait. The search engine picks one, almost never the one you want,
and the internal linking splits between them.

> **The live case.** One shop was entirely `noindex, nofollow` **on purpose** — both the header and the
> meta tag — because the parent domain had **51 indexable pages of the same catalogue**, and those 51 in
> turn had **58 of 67 pages with no H1 and 50 with an identical `<title>`.** Publishing the new shop
> without deciding this would have put two catalogues with the same owner in competition with each other.
>
> **The transferable lesson:** cannibalisation is decided **before** the second page is indexed.
> Afterwards it is no longer an architecture decision, it is a migration with 51 redirects.

**The case resolved well, to copy the shape:** two language pages that **are not twins and carry no
`hreflang`**: they attack different keywords for different markets, and they link to each other from the
body. The decision is written down with its reason. Copy that: **one sentence saying which search each
page exists for, written at the moment it is created.**

---

## 6 · Contrast: which of our own sites satisfies its own anatomy

| Site | Sections | Anatomy by type | Linking | Density | Verdict |
|---|---|---|---|---|---|
| **D** | 5 per page, fixed order | missing two roles | hub → 31 pages → siblings | 3.2 screens · 0 overflows | **The only one that complies.** And it complies because it was generated from a spec with sections |
| **ours** | **42 of 45 pages with 0 sections** | hubs and landings fine; **guides are prose** | one page with 0 body links | **never measured** | The site that teaches how it is done, without doing it |
| **A** | 4–10 per page | **5 cities with the same H1** | fine | 8.2 screens · 3 CTAs, all 3 in the hero | Structure yes, local anatomy no |
| **C** | 1 section per page | inherited linear prose | **5 city pages with 0 inbound links** | 17.9 screens · 32/39 blocks with no CTA | The worst, and the diagnosis was already written |
| **B** | 7 on the home | catalogue and detail pages with no HTML | — (`noindex`) | home 5.93 at 390 px, 63 px from the limit | Well built, badly distributed |

### The three new findings from that sweep

1. **42 of 45 pages with no sections.** The three that had them were **exactly the three the project's
   own notes declared as outside the generator.** That is: **the hand-made pages have layout and the
   generated ones do not.** The template emits headings and paragraphs loose under the wrapper. It is
   not anybody's oversight: it is what the generator produces, **which is why it happens on 42 pages at
   once and not on one.**
2. **Five city pages were genuine orphans.** Each is in the sitemap and **none receives a single link
   from any page on the site** — not from the navigation, not from the blog, not from each other. They
   are good pages, with H1 and headings differentiated per city, **and nobody can reach them by
   navigating.**
3. **The density gate has a blind spot for the prose-page, and it is the case that matters most.** It
   measures direct children of `<main>`. In a prose-page every paragraph is a direct child: no "block"
   exceeds one screen, so the overflow threshold **always passes.** A 36-paragraph guide can report
   "0 blocks overflow" and be exactly what we are looking for. The height threshold only catches it if
   it is long, and since the word-counting change not even that. **So prose has to be caught by its
   SHAPE, not by its height.**
   → **The missing check, and it is one line:** a page with headings in the body and **zero** role
   attributes is prose, without looking at heights or opening a browser. **It is the only one of these
   that works without rendering.**

---

## 7 · How a page gets checked before it is called done

In order, and none substitutes for the next:

1. **Should it exist?** Lane, justification, **≥2 committed body links**, with the names of the pages
   that will link to it.
2. **Does it have its anatomy?** The table in §2 for its type. All the required roles present and **in
   order**. Each with its role attribute.
3. **Is it not prose?** The structure gate, and you read the prose-page answer **as well as** the
   verdict: they are two different questions. Zero sections with headings in the body = FAIL, no further
   discussion.
4. **Does it fit and can it be clicked?** The density gate at 1280 **and** 390. Print `innerWidth` and
   confirm it is what you asked for, or declare it **not verified**.
5. **Can it be read?** The CPL gate. Zero paragraphs above 80 characters per line.
6. **Is it linked?** Crawl and the linking gate, which looks at the whole graph. By hand: grep its path
   **inside the `<main>`** of the others — a result that only appears in the navigation line is a zero.
7. **And you open it and read it.** The auditor tells you where to look, not whether what is there makes
   sense.

> **The four gates in points 3–6 are the layout blocks of the final-QA checklist, and that is where they
> get REPORTED.** This list is the mental order; that one is the step that closes the project. If a page
> has not been through both, it has not been through: **for a long time these gates existed and the
> document that closes the project did not name them**, which is the exact shape of having a written rule
> that changes nothing.

---

## What this file leaves open, said out loud

- **Three REQUIRED roles still have no mould:** `siblings`, `map` and `form`. They exist in production,
  unextracted, and they need pulling out into the moulds folder.
- **The role attribute is a convention proposed here, and it is on no page yet.** Until it is applied,
  point 3 of §7 cannot be automated on existing sites — only on new ones.
- **One generator template is the cause of the 42 prose pages.** Fixing it is a repository task, not a
  task for this file, and it touches 34 deployed pages at once.
- **The density of one site has never been measured.** There is no figure anywhere; the ones in §6 for
  the other four are from an earlier sweep and **were not re-measured.**
