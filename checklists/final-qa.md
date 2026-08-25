# Final QA — before saying it is finished

> **No project closes without this.** It does not replace the other gates: **it closes them.**

| Gate | What it looks at | The question it answers | Block |
|---|---|---|---|
| `audit-vs-source.sh` | their **code** | is a whole category missing? | step 10 |
| `audit.sh` | the **build** | is it generated correctly? | step 5 |
| fidelity | their text against ours | was content lost? | step 10 |
| **`qa-final.sh`** | **the PUBLISHED site** | **does it work for a visitor?** | **A** |
| **`measure-screens.js`** | how much room it takes and where the CTAs fall | can you act where you get convinced? | **A-bis** |
| **`structure-gate.js`** | whether the page **is laid out** | is it a blog article dressed as a page? | **A-ter** |
| **the CPL gate** | the width of the text column | can it be read without losing the line? | **A-ter** |
| **`linking-gate.pl`** | the link **graph** | does this page lead anywhere, and does anyone reach it? | **A-ter** |
| **B + C** | what no script sees | is it worse than before? what have I not looked at? | **B/C** |

The first three look at the build or the source. **None of them walks what is published**, and that
is how `og:image`, the entire measurement stack and 9 of 11 events escaped: **they were on nobody's
list and nobody was looking at the live site.**

And **none of the first six looks at LAYOUT**, which is why block A-ter exists. A site can pass all of
A while being a run of paragraphs: the content, measurement and delivery gates do not ask whether
there are sections.

---

## Block A · Automatic

```bash
bash gates/qa-final.sh https://domain.tld [/contact-path]
```

**Exit ≠ 0 = it does not close.** It covers delivery (certificate, `www`, sitemap at 200), content
(canonical, `og:image`, `alt`, titles), measurement (container, consent order, banner, events), contact
(where the form genuinely submits) and privacy (third parties loading, external fonts, a search action
with no search function, internal files exposed).

**Validated against three sites of known state:** 0 failures on the good one, **4 on the broken one —
and all 4 exactly the ones a manual audit had already found** — and 0 on the third. **A QA that does
not find what you already know is broken is worthless**; that is the test to repeat whenever it is
touched.

> **The script only sees what has been written into it.** That is why blocks B and C exist.

---

## Block A-bis · Density and calls to action

```
gates/measure-screens.js   → paste into the console, or run it through the browser harness
```

**VERDICT: FAIL = it does not close.** Four thresholds:

| Threshold | Why that one |
|---|---|
| No block **> 1 screen** | If it does not fit in one glance, it does not get read: it gets skimmed |
| The page within its **WORD budget** | 6 screens + 1 per 80 visible words past 400. **The fixed 6 failed the DENSEST page in the estate** |
| **≤ 2.5 consecutive screens with no CTA** | Somebody convinced at the bottom has to be able to act there |
| **≥ 2 CTAs** on the page | One at the top, one at the close, minimum |

**Measured at 1280 and on mobile.** On mobile everything stacks: a block that fits at 1280 can take
three screens at 390.

> **Why this gate exists.** *"The section overflow thing… you have not met it on any site, it is very
> important that you always keep it in mind, and the priority of CTAs and their distribution too."*
>
> That was right, and **the serious part was not the failure: it was that it had never been measured.**
> No gate asked how much room a section takes or where the buttons fall, **so no gate found it. A
> checklist that does not ask a question never finds its answer.**
>
> When it was finally measured: one site at **8.2 screens** with 2 overflowing sections and **all 3
> CTAs in the hero** · another at **17.9 screens** with 32 of 39 blocks with no CTA · a third at 3.2
> and complying.
>
> **And the root cause, which is the transferable lesson:** the third complies because it was built
> from a spec with defined sections. The second fails because **it reproduces the linear prose of its
> page builder.** Migrating preserves the CONTENT; **the layout gets rebuilt.** Fidelity to the text is
> not fidelity to the layout — and that confusion turns an 18-screen site into a "faithful migration".

---

## Block A-ter · Layout, readability and linking

> **Why they are a QA block and not a row in a reference table.** They existed for some time and **this
> document did not name them**: they lived in a table that is a **catalogue, not a step.** It is
> already written in the house rules: **a rule that nothing forces anybody to look at is not a system.**

All three run against the **published** site, after A and A-bis. Any of them at `FAIL` **does not
close**, with the single declared exception below.

### A-ter.1 · The structure gate — is it laid out, or is it prose?

```js
window.__GATE__ = { type:'guide' };   // optional; inferred from the URL if absent
// ...then paste the whole file
```

- **Run at 1440 AND 390**, on one page of each distinct type (a home, a service page, a guide…), not on
  every page.
- The first thing you read **is not the verdict: it is `innerWidth`.** If it is not what you asked for,
  throw the whole measurement away (headless Chrome on Windows clamps to about 500 px; hiding
  scrollbars does not give the 18 px back — for 1280 you ask for 1298).
- It returns two things and **both get reported**: the verdict, and whether it is a prose-page. **They
  are different questions** — a legal notice at 85 characters per line FAILS on width and is **not** a
  prose-page; a guide with a perfect column and 36 loose paragraphs **is** one, and that is the failure
  that motivated all of this.
- **It covers a blind spot of A-bis**, it does not repeat it: the density gate measures direct children
  of `<main>`, and in a prose-page every paragraph is one, so no block ever overflows and a 36-paragraph
  guide reports "0 blocks overflow" and PASSES.
- **Its notes can say "no role attributes: the anatomy by ROLE was not checked."** That is not a pass:
  it means the gate could only measure shape, not anatomy. **It goes into the report verbatim.**

### A-ter.2 · The CPL gate — can it be read?

Four thresholds: **0 paragraphs over 80 characters per line** · column **≤ 42 em** · **≤ 6** text steps
between 11 and 28 px with no jumps below 1.08 · section padding ÷ inner gap **≥ 2**.

Tested with positive **and** negative cases before publishing, which is the house rule: two live pages
**FAIL** (44 paragraphs, worst 116; and worst **182**) and two **PASS**. **A gate only ever seen green
proves nothing.**

### A-ter.3 · The linking gate — is the site a site?

```bash
perl gates/crawl-links.pl https://domain/ /tmp/link-cache /tmp/g.json 400
perl gates/linking-gate.pl /tmp/g.json      # EXIT 1 if anything FAILS
```

> **The crawler's cache is NOT the master gate's.** Both index by `md5(url)`, and this line once named
> the same directory the gate was given: one program's metadata was read by the other, and the
> measurements came from pages that program had never downloaded. Measured: a compression check
> reporting *"text served UNCOMPRESSED"* on a site that serves brotli.
> Since then **each one validates on read and discards what it did not write**, so sharing a directory
> no longer lies — it only makes them tread on each other and re-download.
> **Separating them is for efficiency; the validation is the guarantee.**

It is the only one that looks at the **graph**: click depth, orphans, children that do not link back,
descriptive anchors. **No other gate asks "does this page lead anywhere?"** — and that is why one blog
index listed 11 posts **without linking to any of them** with every gate green.

> **R0 is a gate on the instrument, and it aborts.** If the site paints its links with JavaScript, a
> static crawl returns **invented** orphans. When R0 fails, the rest of the report **is not read as
> findings**: you say the linking COULD NOT BE MEASURED. **A zero from a crawl is a non-match, not an
> absence.**

### The single declared exception

If a page fails **only** on the CTA threshold of A-bis and its primary interaction is buttons (a
configurator page — see the known limit at the end), it is a **false FAIL**: record it and move on.

> **You do not change the component's classes so the gate can see it** — that is flattering the
> instrument and it leaves the site worse than it was. **No other exception is declared: the rest get
> fixed.**

---

## Block B · Looked at — cannot be automated

Five things, with your eyes. Ten minutes.

1. **Open 3 pages and look at them**: the home, the one expected to get most traffic, and a detail
   page. Not audit them: **look at them.** Does any of them look broken? Is an image missing?
   > If the capture looks odd, **render the previous version with the same flags before believing the
   > defect**: it may be the capture method.
2. **Fill in the form for real** and check three things: the email arrives, the copy lands on disk, and
   **the conversion event fires.**
3. **Share the link on a messaging app** — to yourself. If a grey rectangle comes out, that page is
   missing its `og:image`. **It is the real recommendation channel for a local business.**
4. **See it on a real phone**, not just by narrowing the window. Headless Chrome on Windows crops to
   about 500 px: **the capture lies.** Print `innerWidth` before believing anything.
5. **Open the network panel** and look at what loads. It is the only thing that sees what a third party
   loads in turn — the script does not reach there.

---

## Block C · The questions that force you to think

The two biggest things in one migration **were found by no gate: they were found by the client
asking.** These are those questions, written down so they do not depend on somebody thinking of them.

1. **What did their site have that ours does not?** Not "is what I expected there?". Open their code
   and count. → that is how 13 images, the logo and the team surfaced.
2. **When somebody submits the form, what happens exactly?** Walk all three steps: thank-you page,
   email, event. → that is how a conversion measuring zero surfaced.
3. **How do people arrive today, and does it still work?** Phone, messaging, form, map, social. Each
   channel, tested. → that is how a floating call button missing from 17 pages surfaced.
4. **If the client pays for clicks tomorrow, what would they measure?** If the answer is not a specific
   conversion with a name, something is missing.
5. **What is on the site that is not true?** Schema for something that does not exist, a search action
   with no search, a generated image presented as their team, a form that says "thank you" and does not
   send.
6. **What would break silently?** Whatever fails while returning 200. A deleted mailbox, an expiring
   certificate, a cancelled CRM. **Is there any way to find out?**
7. **What have I NOT looked at?** Mobile performance, accessibility beyond alt text, content quality.
   **If it was not looked at, you say so**; you do not omit it.

---

## How it gets reported

```
FINAL QA · <domain> · <date>
Block A     : PASS / N failures            (paste the script's output)
Block A-bis : PASS / FAIL  ·  <N> screens · <N> CTAs · <N> blocks overflow
              measured at innerWidth=____ and ____
Block A-ter : layout    PASS / FAIL  ·  prosePage: yes / no
              per type: <home ok · service ok · guide FAIL…>
              measured at innerWidth=____ and ____
              reading   PASS / FAIL  ·  <N> paragraphs >80 CPL · worst <N>
              linking   PASS / FAIL  ·  R0 <valid / ABORTS> · <N> orphans  (EXIT __)
Block B     : 5/5 looked at                (what was seen, and with what)
Block C     : answered                     (what came out, even if "nothing")
NOT VERIFIED: <what is left out>
```

> **"NOT VERIFIED" is not optional.** A report that does not say what it left out reads as though it
> covered everything — **and that is what lets a failure through the gate.**

> **And the A-bis and A-ter lines carry the MEASURED `innerWidth`, not the requested one.** A layout
> verdict with no real width beside it is not a measurement: **it is a cropped screenshot in the shape
> of a report.** If the width is not what was asked for, the correct line is `NOT MEASURED`, not a PASS.

> **A missing line reads as a PASS.** If a gate could not be run — quota, the browser will not
> composite frames, R0 aborts — you write `NOT MEASURED` with the reason. **Zero measurements is zero
> knowledge, not zero problems.**

---

## Known limit of the gate: configurator pages

The density gate counts as a call to action anything with a button or CTA class, phone and messaging
links, submit buttons and forms. **It does not count the plain buttons that are a page's primary
interaction.**

Measured consequence: the gate returns **0 CTAs → FAIL** on a page that is a six-step configurator —
that is, *entirely* a conversion mechanism. Its buttons carry component classes.

> **Do not change the component's classes so the gate can see them.** That is flattering the instrument,
> and it leaves the site worse than it was. If a page fails only on the CTA threshold and its primary
> interaction is buttons, **the result is a false FAIL**: record it and move on.

Pending: also count buttons inside `<main>` with visible text and not disabled, **and re-verify that no
page changes verdict through over-counting.**
