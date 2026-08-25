# Internal linking

> An internal link does three things at once: it **takes a person** to the next page, it
> **tells a search engine** which pages matter and what they are about, and it is **the only
> way** a crawler without JavaScript discovers that a page exists. All three break on the same
> defect, and none of them is visible by looking at the page.
>
> Measured across three real sites: 42 pages, 16 pages and 67 pages.
> **All three FAIL the gate**, each for a different reason.

---

## 1 · The model: hubs and spokes

A site is not a list of pages: it is a tree of **topics**, and every topic has one page in
charge.

| | What it is | How many links leave | To where |
|---|---|---|---|
| **Home** | the root | to each hub + the 3–5 money pages | hubs |
| **Hub** (pillar) | the page covering a whole topic | **to ALL its spokes, without exception** | spokes + sibling hubs |
| **Spoke** (leaf) | answers ONE question in the topic | 3–8 | **1 to the hub** (mandatory) + 2–5 siblings + 1 to conversion |

The model's three rules:

1. **A hub that does not link to all its children is not a hub, it is a cover page.** It is the
   most common defect and the most expensive: on one site the areas hub named all five cities
   in its copy and **linked to none of them.**
2. **Every spoke links up.** Without the link back to the hub, the topic does not exist as a
   group: it is N loose pages competing with each other.
3. **Spokes cross to siblings, not across topics.** Linking from a spoke of one topic to a
   spoke of another without a reason dilutes the signal.

### Contextual vs structural

| | Where it lives | What signal it sends | How much it weighs |
|---|---|---|---|
| **Structural** | nav, footer, breadcrumb, "related" cards | "this exists and it is at this level" | little, and **it is spread across every page** |
| **Contextual** | inside a paragraph of the copy | "this page is about THIS, and here is the proof" | a lot |

**The menu is not a linking strategy.** A link that appears on all 42 pages distinguishes
none of them. If 100% of the links to a page come from the menu, that page is not
*recommended* by any other: it is only *listed*. On one site **85% of internal links were nav
and footer.**

### Anchor text

The anchor is the only thing that tells the destination what it is about **before** it is
visited.

- **Good**: descriptive and varied. Five pages linking with five different anchors is a signal
  that the link was written, not pasted.
- **Bad**: generic ("here", "read more", "this article"), empty (an image with no `alt` or
  `aria-label`), or **always identical** — 40 links with the exact same anchor looks like a
  template, because it is one.
- **Worst**: an anchor promising something the page does not deliver.

---

## 2 · The rules, and the gate that checks them

```bash
perl gates/crawl-links.pl https://domain/ /tmp/link-cache /tmp/g.json 400
perl gates/linking-gate.pl /tmp/g.json     # EXIT 1 if anything FAILS
```

> **The cache directory is not decorative**: it must be a *different* cache from the master
> gate's. Both index by `md5(url)`, and they used to share one directory.

| # | Rule | Threshold | Severity |
|---|---|---|---|
| **R0** | **The crawl measured something** | if more than a third of pages have no links at all, or nav/footer is 0 → **the instrument is invalid** | **ABORTS** |
| R1 | Click depth from the home | ≤3 (<100 pages) · ≤4 (<1000) | FAIL |
| R2 | **Every sitemap URL is reachable by navigating** | 0 exceptions | FAIL |
| R3 | Inbound **content** links per page | ≥1 (outside nav/footer) | WARN |
| R4 | Hard orphans (0 inbound) | 0 · if it is live and unlinked, **`noindex` is mandatory** | FAIL |
| R5 | **The hub links to ALL its children** | 0 children unlinked from their parent | FAIL |
| R6 | **VISIBLE breadcrumb** where there is a hierarchy | `BreadcrumbList` with no breadcrumb on screen = FAIL | FAIL |
| R7 | Links point at the **canonical URL** | 0 to `index.html`, 0 to URLs that redirect | FAIL |
| R8 | Descriptive anchors | 0 generic, 0 empty | FAIL |
| R9 | % of content links over the total | ≥10% FAIL · <20% WARN | FAIL/WARN |
| R10 | The menu does not link half the site | ≤15 destinations, and never ≥50% of pages | FAIL |

**R0 is first for a reason.** Without it, this same analysis declared **64 orphans out of 67**
on one site. There were zero: the site paints its links with JavaScript and the served HTML of
its catalogue page weighed 1,574 bytes with **zero `<a href>`.** A static crawl over a
JavaScript site does not give a bad result, **it gives an invented one.**

### How you actually find an orphan

**A crawl NEVER finds an orphan**: if it has no inbound links, there is no way to reach it by
following links. You need three sources:

1. the crawl from the home page (what is reachable),
2. the `sitemap.xml` (what is declared),
3. **the repository tree** (`find . -name '*.html'`), testing each URL live.

Orphan = it is in (2 ∪ 3) and not in (1). What appears **only** in (3) is what no crawler in
the world will ever find.

---

## 3 · What was measured on three real sites

| | Site 1 | Site 2 | Site 3 |
|---|---|---|---|
| Pages at 200 / in sitemap | 42 / 35 | 16 / 12 | 67 / 67 |
| Max depth | 3 | 1 | **not measurable** |
| Nav+footer links / content links | 1373 / 235 | 421 / 41 | **not measurable** |
| **% content** | **15%** | **9%** | — |
| Inbound per page (median) | 38 | 15 | — |
| …**content only** (median) | **4** | **1** | — |
| Generic anchors | 0 | 0 | — |
| `BreadcrumbList` / visible breadcrumb | **36/42 / 0** | **11/16 / 0** | **0 / 0** |
| Verdict | FAIL (4) | FAIL (5) | FAIL R0 |

### Site 1 — the defect is where the links point

**All 41 internal links to the home point at `/index.html`, not at `/`.** The menu uses a
relative path ending in `index.html`. The canonical URL `/` receives **zero** internal links;
`/index.html` receives 41, returns 200 (it does not redirect) and is not in the sitemap. The
canonical tag and the breadcrumb data both say `/`: **the visible HTML and the structured data
do not say the same thing.** The same one level down.

- 36 pages emit breadcrumb structured data and **not one paints a breadcrumb.**
- The main hub receives 41 links and **none from the body copy** of another page.
- The home page **does not link to one of its own top-level sections** — the word does not
  appear in its HTML. A first-level page sitting at depth 2 with 2 inbound links.
- The menu carries **31 links per page** (24 destinations): it links nearly the whole site
  from everywhere, which is the same as ranking nothing.
- **Good**: 0 generic anchors and genuinely varied ones · 0 broken links · all 35 sitemap URLs
  reachable · max depth 3.

**The three orphans found earlier: confirmed, and NOT a defect.** A thank-you page and two
internal tools were live, with 0 inbound links and outside the sitemap — but all three carry
**`noindex`**, which is exactly right. What *is* a defect, and was not in that earlier report:
a pricing page that exists in the repository and returns **404 in production.**

### Site 2 — an island of five pages

**Five area pages: in the sitemap, returning 200, and NOT reachable by navigating from the
home.** The only links they receive come from **each other** (a "nearby areas" block). Nothing
from outside enters the island.

The cause is exact and one line long: **the areas hub links to none of its five children** —
zero `href`, confirmed by opening its HTML — although it names all five in the copy. The
search engine knows them from the sitemap; they receive no internal strength at all, and for a
crawler without a sitemap they do not exist.

Also: 6 pages reachable only through the menu · the menu carries 29 links on a 16-page site ·
4 live legal pages outside the sitemap (linked from the footer, so not orphans).

### Site 3 — the best architecture, and it is invisible

**Not measurable by static crawl.** Measured in the rendered DOM:

- The catalogue page has 62 product cards plus 7 categories — 65 content links.
- A product page links up to its category, crosses to **4 siblings**, and hands off to the
  configurator **with the model preloaded**.

That is hub-and-spoke done properly. **The problem is that it only exists after JavaScript
runs.** Search engines render; most AI crawlers generally do not. To a crawler without
JavaScript this site has **3 linked pages, not 67** — and the sitemap declares URLs with query
parameters that are only discoverable by link. If the goal includes being cited by AI
assistants, **the entire graph is invisible.**

---

## 4 · A new site: linking is decided BEFORE writing

**The order matters and it is almost always done backwards.** If the pages get written first,
the links get added at the end "wherever they fit": that is how islands appear, and hubs that
do not link downwards. The link structure **is** the information architecture; writing is
filling it in.

1. **Topics before pages.** 3–6 hubs. If two hubs overlap, it is one hub.
2. **Each hub, its list of spokes**, with the question each one answers. That list **is** the
   hub's contract: the day it publishes, it has to link to all of them. A spoke with no hub
   does not get written.
3. **Draw the sibling crossings** (2–5 per spoke) *before* writing. A crossing is a promise
   that the copy will have somewhere sensible to put it.
4. **Fix the menu**: hubs plus conversion only. **Never spokes** — that is what the hub is
   for. The 24–31 destinations on two of our sites come from skipping this.
5. **Decide the URL shape and do not change it**: with or without a trailing slash, with or
   without `index.html`. It goes in the project's notes and **the generator always emits that
   shape.** The `/index.html` defect above is this, undecided.
6. **Write.** The contextual links already have destinations, so they get written inside the
   sentence instead of being pasted into a "related" block.
7. **Publish hub and spokes in the same batch.** A spoke published before its hub is born an
   orphan, and nobody ever goes back to fix it.
8. **Pass the gate.** Crawl, then the linking gate, EXIT 0.

> **The rule that summarises all eight:** the sitemap declares what exists; **the links declare
> what matters.** If something is only in the sitemap, you have said it exists and that nobody
> cares about it — including you.

---

## 5 · Traps already paid for while measuring this

- **`curl` without following redirects measures the body of a 301.** Always follow, and keep
  the effective URL.
- **Inventing the trailing slash manufactures redirects that do not exist.** One site serves a
  path and **301s** to its slashed form. My normaliser added the slash: the gate reported
  **14 "links to a URL that redirects"**, and all 14 were mine. **The site decides the URL
  shape**: the normalised form is for deduplication, but you request the URL exactly as it is
  written in the HTML.
- **A JavaScript site gives zero links and does not error.** Before believing a zero, open the
  served HTML and count the anchors. If the HTML has no navigation, you are not measuring the
  site. → R0.
- **In Perl, do not name a variable `$b`**: inside a `sort` block it shadows the comparison
  variable and the medians come out wrong **silently**. It happened twice; the only reason it
  was caught is that warnings were on. With warnings off, false medians would have been
  published.
- **"In prose" can never exceed "content links".** If it does, the prose flag is set per URL
  rather than per position: a menu link that also appears in a paragraph gets counted as
  contextual. A free consistency check.
- **Every zero from `grep` is a non-match, not an absence.** Before saying "nothing links to
  this", run the same pattern against something that **is** linked.
- **One host returns 403** to any request carrying `Accept-Encoding` and **no** `Accept` header
  (a web application firewall rule). A real browser always sends `Accept`, so it does not break
  users — it breaks crawlers. `curl --compressed` triggers it.
- **An `index.html` is not a child of its own directory.** Counting it as one makes the hub
  rule report a false positive on every hub.

---

## 6 · Files

| | |
|---|---|
| `gates/crawl-links.pl` | The crawler. `curl` plus Perl, no dependencies. Produces the graph, depth, zone (nav/footer vs content vs prose), anchors and sitemap |
| `gates/linking-gate.pl` | The gate. **R0 aborts if the instrument is invalid.** EXIT 1 if anything FAILS |

These run in the layout block of the final QA, alongside the screen-density gate: one measures
the layout and the other measures the graph. **Neither of them is covered by anything else.**
