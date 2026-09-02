# Motion: what moves, what never moves, and what it costs

> **This document exists because the repertoire was zero and nobody had noticed.** Measured
> 2026-09-02 across the twenty moulds: **0 `@keyframes`, 0 `animation:`, and `transition:` in
> four files.** Those four all declare their reduced-motion exit — so the *discipline* was
> perfect and the *vocabulary* was empty. A drawer of parts that never moves is a decision, and
> it had never been taken on purpose.
>
> The accessibility half is **not** repeated here: `14-accessibility.md §A16` owns it
> (`prefers-reduced-motion` cancels duration **and delay**). This document is the other three
> halves — what is worth animating, what it costs, and when a library is allowed.

---

## 1 · Where this came from, and the filter that survived it

Three references, looked at on 2026-09-02: two React component libraries and one animation
engine. **None of their code can be used here** — this system ships static HTML/CSS/JS with no
build step and no framework — so what follows is the part that transfers, and the part that
does not is written down too, because "we looked and rejected it" is worth more than silence.

| | What it is | What transfers |
|---|---|---|
| **cult-ui** | React + Tailwind + shadcn. 78 animated components, and a large second business in Next.js AI-agent templates | The **hover-reveal card** idea. Nothing else: it is a shadcn extension, and we have no shadcn |
| **Watermelon UI** | React. Catalogue of animated components, blocks and dashboards | The **motion vocabulary** below, and — unexpectedly — their `llms.txt`, see §5 |
| **GSAP** | Vanilla JS animation engine, framework-agnostic. **Free for everyone since Webflow's acquisition** | Genuinely usable, under the rule in §4 |

**Two things measured rather than assumed:**

- **Their catalogue is app UI, not marketing-site UI.** The animated components are named
  *Adaptive Slider · Card Swipe · Command Search · Continuous Tabs · Compose Email Card ·
  Budget Card · Aave Swap*. Those are dashboard and product-surface patterns. Our sites are
  clinics, kitchens, local services and lead-magnet landings. **Most of a 131-component
  animated catalogue is irrelevant to a physiotherapist's website**, and importing it would be
  the "card grid replaced thinking" failure from `10 §1` all over again with better easing.
- **The advertised number is not the real number.** The site says *"600+ free, open-source UI
  components"*; its own catalogue API returns **334 entries** (131 animated components, 189
  blocks, 11 dashboards, 1 template, 2 showcases). Nearly 2× overclaim, from the product's own
  machine-readable surface. Not a scandal — a reminder that **the marketing figure and the
  measured figure are different numbers**, including on sites we are learning from.

---

## 2 · The performance rule: only two properties

**Animate `transform` and `opacity`. Nothing else.** The browser composites those two on the
GPU without laying out or painting. Everything else — `box-shadow`, `width`, `height`,
`top`/`left`, colours — is repainted on the main thread, every frame.

| | |
|---|---|
| ✅ Free | `transform` (translate, scale, rotate) · `opacity` |
| ⚠️ Cheap enough for a hover | `border-color`, `background-color`, `color` — one element, short duration, not on scroll |
| 🔴 Never | `box-shadow` · `width` / `height` · `top` / `left` · `filter: blur()` on a large surface |

This was learned on a real site: a glow animated as `box-shadow` on a pulsing dot repainted
continuously; moving it to a `::after` with `transform` fixed it. **A halo animates by scaling a
pseudo-element, not by growing a shadow.**

### 2.1 · Above the fold, motion is CSS. Below it, it can be JavaScript

> **Anything visible in the first screen animates with CSS only.**

The pattern that breaks this: a reveal-on-scroll class that starts at `opacity: 0` and waits for
an `IntersectionObserver`. Above the fold **it holds the hero invisible until the script
executes**, which on mobile moves the Largest Contentful Paint to whenever the JS lands.
Measured on a real site: Speed Index 3.9 s, with the LCP insight pointing at the hero subtitle.

- Above the fold → a CSS class that animates from a **visible-by-default** state.
- Below the fold → observer-driven is fine; nobody is waiting on it.

### 2.2 · Reading `scrollY` or `offsetTop` in a scroll handler forces reflow

Read inside `requestAnimationFrame`, and touch the DOM only when the state actually changes.

---

## 3 · The vocabulary — what a marketing page is allowed to move

Ordered by how often it earns its place. Everything here is CSS-only and lands in
`transform`/`opacity`.

| # | Motion | Where | Why it earns it |
|---|---|---|---|
| 1 | **Hover lift** — `translateY(-2px)` + border colour | any clickable card | Tells you it is clickable before you click. Mould 20 uses exactly this |
| 2 | **Hover reveal** — hidden detail slides in under a card | catalogue, feature grid | The one idea worth taking from cult-ui. **Content must be reachable without hover**: on touch there is no hover |
| 3 | **Entrance on scroll** — 8–16px rise + fade, once | below the fold only | Marks the section boundary. Once. Never re-triggering |
| 4 | **Accordion open/close** | FAQ | The only one already in the drawer |
| 5 | **Focus ring transition** | every control | Not decoration: it is what makes keyboard use legible |

**And the ceiling:** *at most one moving thing per screen.* Two competing animations in one
viewport is how a page starts feeling like a demo instead of a business.

### What we do NOT do, and it is a decision

Parallax · text that types itself · counters that spin up · scroll-jacking · carousels that
advance on their own · anything that moves for longer than ~300 ms. All of them are in the
reference catalogues; none survive a page whose job is that somebody phones a clinic.

---

## 4 · When a library is allowed — the GSAP rule

**Measured, not estimated:** GSAP core minified is **71 KB**, ScrollTrigger a further **44 KB**.
For scale, an entire site stylesheet here is ~3.5 KB gzipped.

> **CSS by default. GSAP only when a NAMED effect cannot be done in CSS, self-hosted, and
> loaded only on the page that needs it.**

- **Self-hosted, never a CDN.** Not preference: on a site that declares zero third-party
  resources, a CDN request makes that declaration false on the first render.
- **It has to be named.** "It would look nicer with GSAP" is not a reason. "A scroll-linked
  timeline that scrubs three elements against progress" is, because CSS genuinely cannot.
- **It is now free.** The plugins that used to be paid no longer are, so an old note saying
  "ScrollTrigger is licensed" is out of date. That changed the rule; it did not remove it.

**What CSS already does, so nobody reaches for a library by reflex:** transitions, keyframes,
`scroll-timeline` where supported, `:has()` for state, `@starting-style` for entrances,
`view-transition` for cross-document moves. Reach for the 71 KB after those, not before.

---

## 5 · The finding that had nothing to do with motion: their `llms.txt`

Worth writing down because it is directly the AEO work in `03-content-and-seo.md §5`, and it is
better than ours.

Ours is a list of URLs mirroring the sitemap. **Theirs routes the agent:**

- A one-line `>` summary of what the product is.
- A **`When to use` block** — explicit guidance on *which surface answers which kind of
  question*, including when to prefer one page type over another.
- Every link carries **a description of what that page is for**, not just its title.
- Grouped by purpose: *Primary Pages · Trust And Contact · Developer Entry Points ·
  Authentication*.
- A closing **`Agent Notes`** section: which surface is the source of truth, and what to prefer
  when a user asks a specific kind of question.
- An explicit statement that the public endpoints need **no authentication** — which removes the
  single most common reason an agent gives up.

**And their 404 does the same job:** it offers Sitemap, `llms.txt`, Developers and OpenAPI. A
404 that routes instead of apologising — compare `09 §2.11`, where our own 404 anatomy is "what
happened + 3–5 destinations".

> 🔑 The general shape: **a machine-readable file is not an index, it is a router.** A list of
> URLs tells a model what exists. A description per URL plus a "when to use" tells it *which one
> to open*, and that is the difference between being crawled and being cited.

---

## 6 · What is enforced, and what is not

| | |
|---|---|
| ✅ **Enforced** | Any mould that declares `transition:`, `animation:` or `@keyframes` **must** declare `prefers-reduced-motion` — `roles.pl --gate`, check **I**. Wired 2026-09-02 with all twenty moulds green, which is when it costs nothing |
| ✅ Enforced | Contrast of every mould, including hover states — `measure-contrast.sh`, 20 files |
| ❌ Not enforced | *Which* properties are animated. Nothing stops somebody animating `box-shadow`; §2 is a rule a human keeps |
| ❌ Not enforced | The one-moving-thing-per-screen ceiling, and the `llms.txt` shape in §5 |

**Check I was wired while it was already green**, deliberately. A rule that everyone happens to
be following is exactly when a gate is free to add — the day somebody adds a `@keyframes`
without an exit, nothing else in this system would tell them apart.
