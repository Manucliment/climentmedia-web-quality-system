# 16 · The review, step by step

> **What this is for.** It is not an audit: it is the **list of steps** followed in order, each with
> its check and its pass criterion. It is used the same way to review a site that already exists, to
> build a new one, and to accept a single page.
>
> It comes from a list of real defects somebody found by **looking at the sites**, not from theory.
> Every step carries **the defect that brought it.**
>
> **The column that matters most is "what checks it".** Where it says **BY HAND**, there is no
> program that looks at it today: that is the instrument's pending work.

---

## Order and criterion

The steps run **from the outside in**: first what repeats on every page (menu, footer, template),
then the page, then the detail. **Fixing a title before the template is throwing work away: the
template rewrites it.**

| Step | What is reviewed | What checks it | It passes when |
|---|---|---|---|
| **1** | **Menu** | the dropdown check + the menu-breadth rule + **BY HAND** the mould | One menu across the whole site, from the mould; no dropdown with fewer than 3 destinations; the chrome links <50% of the site |
| **2** | **Footer** | the footer checks (a–f) | It carries name/address/phone, legal links, a minimal map and **the authorship link** |
| **3** | **Template per page type** | the structure checks + the declared type | Every page **declares** its type and carries its anatomy's roles |
| **4** | **Sections** | the structure checks · the layout gate · **`same-text.pl`** | No service page is a wall of prose. **And not one word of the client's is lost when re-laying-out** |
| **5** | **Hero and what is visible without scrolling** | the density gate and the DOM probe | There is a call to action **above the fold**; no block taller than a screen; ≤2.5 consecutive screens with no CTA |
| **6** | **Brand**: logo, fonts, colour | **BY HAND** | The company's real logo on every page; system palette and type |
| **7** | **Title and meta description** | the SEO checks | Unique per page, within length, with the term that page pursues |
| **8** | **On-page SEO** | the SEO lens | Unique `h1`, heading order with no skips, canonical, an `og:image` that resolves, the type's schema |
| **9** | **Internal linking** | crawl + the linking gate | R0–R10 with no failures: zero orphans, visible breadcrumb, ≥20% content links |
| **10** | **Forms** | the forms gate (F1–F8) + **BY HAND** the email (F10) | They genuinely submit **and the email arrives**; minimum fields; no double submission; a visible error |
| **11** | **Measurement** | the measurement lens | Container, consent, events and **a conversion that arrived** |
| **12** | **Performance and weight** | the performance lens | No unoptimised images, no undeclared third-party resources |
| **13** | **Accessibility** | the accessibility lens + an external checker on the server | AA contrast, visible focus, labelled forms |
| **14** | **GEO / LLM** | **BY HAND** + `llms.txt` | Machine-readable files current and with no 404 URLs; quotable content |
| **15** | **The door** | `deploy.sh --upload` | A green receipt for the exact tree + **served equals measured** |

---

## 1 · Menu

**What is looked at:** that there is **one** menu, that it comes from the mould, and that no dropdown
is half empty.

**Defects that brought it:**

- A dropdown that opens with **2 links** — it was left that way after removing three items. **A
  chevron that promises a menu and delivers one link is worse than not having it.**
- *"The menu is not a menu, it takes you to a landing page with the services."*

**The rule that comes out:** a dropdown with **fewer than 3 destinations is not a dropdown**: it is a
link. If removing entries takes it below that, it collapses to a plain link **in the same batch.**

> **And the rule is now a program, not a reminder.** It counts **distinct** destinations inside each
> menu panel, and only looks at controls inside a header or nav — an FAQ accordion uses the same ARIA
> attribute and its panels have zero links, entirely correctly. The real case was **seen red against
> production** (6 of 18 panels) before the fix went up. See the trap log §30.

---

## 2 · Footer

**What is looked at:** that the footer does its SEO and network job.

- Name, address and phone where applicable, coherent with the schema.
- Complete legal links.
- A minimal map: the sections, not the whole site.
- **An authorship link** on every site you build.

**About that link, without dressing it up:** an identical footer link across five sites is a pattern
search engines recognise as a link network. What does hold up: **an authorship link**, with different
text per site, pointing at a page that genuinely explains who built the site. That is what studios do.

> **And this step now has a program.** It was one of four that nobody looked at.

| | What it looks at | Why |
|---|---|---|
| **a** | Every page has a `<footer>` | with no footer there is nowhere to put any of the rest |
| **b** | The footer links **≥2 legal pages.** Found **by path**, in all four languages of the estate | the link text changes with the brand; the path does not |
| **c** | **The footer's `tel:` is the schema's telephone** | |
| **d** | The authorship link exists (**warning**, not failure, until the sites declare it) | a check that goes red on all five at once teaches people to ignore the gate |
| **e** | The anchor is **not** the bare brand name | the same brand name repeated in five footers **is** the signature of a link network |
| **f** | It reports the anchor used, as **NOT VERIFIED** | one site cannot know whether it repeats on the other four: you have to look at all five |

> **The `tel:` check is the one worth most, and it is the same defect the breadcrumb rule catches:
> two lists for one fact.** The schema publishes one phone number and the footer shows another; when
> the number changes, one of the two places gets touched, and from then on the search engine hands out
> one number and the visitor sees a different one. **Both are valid HTML separately — which is why
> nothing looked at it.**
>
> They are compared **by the last 9 digits**: the country prefix gets written three different ways and
> that is not a discrepancy. And **with no telephone in the schema it accuses nobody**: with no two
> lists there can be no contradiction, and inventing the defect is what gets a gate switched off.

---

## 3 · Template per page type

**What is looked at:** that the page **declares** its type and carries its anatomy's roles. The table
lives in [`09-page-types.md`](09-page-types.md).

| Type | Required roles |
|---|---|
| service | hero · offer · qualification · process · objections · siblings · closing |
| city | hero · map · offer · objections · siblings · closing |
| hub | hero · catalogue · qualification · closing |
| detail page | hero · offer · proof · objections · siblings · closing |
| guide | hero · objections · siblings · closing |

> **The defect that brought it:** one page was **a service landing page in the format of a blog
> article.** And it was not an isolated case: **that site's pages generally did not use sections**,
> because they were migrated from a page builder dumped as linear prose.
>
> **Closed on that site:** the type attribute is now emitted by its **29 pages** (it was 0), and 29
> also declare the ROLE of each section — the first in the estate, which had **0 of 121.** The
> mechanism lives in the spec, and **the generator STOPS if a page has no type**: a hand-written map
> that cannot quietly fall short.
>
> **It is unchanged on the other three client sites**, which remain at zero. With no declaration the
> gate **infers the type from the path**, and a service landing shaped like an article goes unnoticed.

---

## 4 · Sections

**What is looked at:** that the content is **laid out**, not dumped.

A service page is not a long text with a button at the end. The house rule: **you preserve the
CONTENT, the layout gets rebuilt.**

**And there is a control that is NOT a gate, without which this does not ship:**

```bash
perl gates/same-text.pl <tree-before> <tree-after>
```

It compares the **visible text** of the two versions, word by word. A new layout that eats a
paragraph **raises no error anywhere**: the HTML is still valid and every gate is still green. On one
site it found **10 pages with loss, up to 207 words on one**, and all of it was the client's copy. It
runs **before** measuring the candidate: **if there is loss, there is nothing else to look at.**

> **The pattern to copy:** first the type declaration — **deployed on its own**, so the hole gets
> measured — and only then the layout. Declaring the type made an anatomy check go from silent to
> flagging **12 pages, six more than I had counted by hand.**

---

## 5 · Hero and what is visible without scrolling

**What is looked at:** that there is a call to action **without scrolling**, and that no block takes
more than the screen.

**Measured** with the density gate and the browser probe, at **1298×720 and 390×844**, checking
`innerWidth` before believing the number.

> **Defects that brought it:**
>
> - One contact page: the block is **taller than the screen**, which pushes the form and the calls to
>   action out of view.
> - One home page, measured at 390: **13.8 screens long and 4.4 consecutive screens with not one call
>   to action** (the threshold is 2.5).
> - **A hero video is gone.** Find out in which batch it disappeared before restoring it: restoring it
>   without knowing throws it away again.

---

## 6 · Brand

**What is looked at:** the real logo, system fonts and palette, on **every** page.

> **The defect that brought it:** one page **does not use the company's logo.**

**There is no gate for this today.** An image with a correct `alt` passes every check even if it is
the wrong logo.

---

## 7 · Title and meta description

Unique per page, correct length, and the term that page pursues. The "description too short" warnings
come from here.

---

## 8 · On-page SEO

The whole SEO lens: unique `h1`, heading order with no skips, canonical, an `og:image` that
**resolves** (not that merely exists), and the page type's schema.

---

## 9 · Internal linking

```bash
perl gates/crawl-links.pl https://DOMAIN/ /tmp/ce /tmp/g.json 200
perl gates/linking-gate.pl /tmp/g.json
```

**The door runs it on its own** after uploading, and its verdict is recorded in the history.

---

## 10 · Forms

**What is looked at:** that the form **genuinely submits and the email arrives** — not that it returns
a redirect.

**This step has a program**, run by the door on what has just been served, at both widths.

| | What it looks at | Where it comes from |
|---|---|---|
| **F1** | The page that declares one **has** a form | a contact page that lost its form |
| **F2** | Every field with a real label — `label[for]`, `aria-label`, `aria-labelledby` or wrapping. **A `placeholder` does NOT count**: it disappears as you type | |
| **F3** | **The honeypot field is not visible.** Looked for three ways (name, its label's text, hiding markup) and visibility is **measured**, not deduced from the markup | one form carried a class that was also the stylesheet's *standfirst* class, so it looked styled. With no CSS of its own the honeypot rendered with its "do not fill in" label showing |
| **F4** | The action resolves: not empty, not a fragment, not **`mailto:`** | one original site submitted by `mailto:` |
| **F5** | A real submit button, not a div with a click handler | you cannot submit with a keyboard |
| **F6** | A consent checkbox that **links** the policy, if personal data is requested | naming it without linking it is not informing |
| **F7** | It collects some way to reply (email or phone) | |
| **F8** | No **invisible** required field: the browser refuses to submit and does not show why | |

**And two things the gate CANNOT know, and says so instead of passing them:**

- **F9 · the double-submission guard.** Measuring it properly means submitting twice, and on a live
  site that is **two real emails to the client and one extra conversion in their ads account.** If the
  form has it, it is declared with an attribute and the gate stays quiet.
- **F10 · that the email ARRIVES.** No DOM gate can see it. It is closed by hand: **an end-to-end test
  per declared channel** (form, messaging, phone), with the message received.

> **Why F10 stays mandatory and manual:** one form **showed success** with its destination CRM
> cancelled. Asking the client does not count, and a redirect is not proof either.

**The repo declares where they are** in its deploy configuration. Without that line, step 10 **is not
measured**, and the door records it as such — **an unmeasured form is not a correct form.**

---

## 11 · Measurement · 12 · Performance · 13 · Accessibility

All three are covered by the master gate's lenses, plus external checkers on the server. **Run both,
not one**: on one site an accessibility checker gave 0 issues and another found 2.

---

## 14 · GEO / LLM

Machine-readable files current, with no 404 URLs — **they break without warning because they are not
HTML and a grep for `href` does not cover them.**

---

## 15 · The door

```bash
perl gates/qa-master.pl https://DOMAIN --repo . --candidate --max-urls 60
bash gates/deploy.sh . --upload
```

A green receipt for the exact tree, the upload, and **served equals measured.**

---

## What this order does NOT solve

Steps **2, 5 (the video), 6, 10 (the email) and 14** depend on looking today. There is no program that
fails them. While that holds, **they are a promise, not a guarantee**, and the way they stop being one
is the usual one: **a red case, a green case, and the gate wired to the door.**

Step 1 already yields half a guarantee: the dropdown check fails on its own if a panel does not
distribute, and the breadth rule if the chrome links half the site. **What is still looking is whether
the menu comes from the mould** — no number says that.
