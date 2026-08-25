# 13 · Performance and weight

> **Advice with no number attached cannot be failed.** Which is why *"WebP if it is heavy"*
> lived for months in the design document alongside a 2.3 MB PNG in production, without any
> gate noticing. Everything here has a number, and the number says where it comes from.
>
> Measured over **15 pages in production** (home + 2 interiors × 5 sites), with `curl` plus
> headless Chrome plus Perl.
>
> **This document does not yet have a gate.** The measurement is written and was proven over
> those 15 pages; what is missing is wiring it to an exit code. **Until then this is a
> specification with no gate — which is exactly the defect this document describes.**

---

## 0 · Why it exists: the hole, verified

It is not that performance was badly documented. **It was not documented at all.** A sweep
over the entire system:

| Term | Occurrences |
|---|---|
| `LCP` · `CLS` · `Core Web` · `lighthouse` | **0** |
| `srcset` · `avif` · `brotli` · `B/px` | **0** |
| `Cache-Control` | 1, and it was about cache-busting, not headers |
| `preload` · `font-display` · `loading="lazy"` | one document, in passing |
| `favicon` | present, **but only as an identity requirement** |

> The sweep's only false positive: `INP` matches inside `input`. **Every zero gets opened, and
> so does every positive.**

**What that hole let through onto live sites receiving leads:**

| Site | What | Found |
|---|---|---|
| Site B, catalogue page | **24 MB** on one page | first time it was ever measured |
| Site A | a **photograph in PNG**, 1536×1024, **2,283 KB**, 1.487 B/px | same |
| Site A | `favicon.png` at **320 KB**, 1080×1080, served on all **13** pages | same |
| Site D, a service page | **93%** of the weight is tags (711 KB of tags over 55 KB of site) | same |
| Site D | the **same** ads tag loaded twice (own snippet **and** tag manager) + a duplicated pixel | same |

**All five are on sites that had already passed every gate we had.** A checklist that does not
ask a question never finds its answer.

### The favicon: the case that teaches why a check can be worse than none

The standard demanded *"the client's favicon, not a generic glyph"*. The 320 KB PNG
**satisfies that check**: it is byte for byte the client's logo.

> **A check that measures the wrong dimension gives a green light with more authority than a
> missing check.** The identity requirement is correct and it stays; what was missing was
> asking how much it weighs.

---

## 1 · The thresholds

There is a deliberate distinction between what has an **external source** and what is
**calibrated against our own sites**. The second is not an industry standard: **it is the bar
our best site already clears.** That is defensible because it is checkable; an invented number
is not.

### 1.1 · Page weight — initial load, on the wire

Measured as the total **minus** images marked `loading="lazy"`.

| | Threshold | Where it comes from |
|---|---|---|
| **Fail** | **> 1,600 KB** | External: the standard total-byte-weight audit |
| **Warn** | **> 500 KB** | External: a "good" LCP ≤ 2.5 s at 1.6 Mbps, the usual simulated throttling |
| **Target** | **≤ 300 KB** | CALIBRATED: our lightest site runs at **19–28 KB** and another at **55–100 KB** |

Where the five sites fell (median of 3 pages each, on the wire):
**24 KB · 56 KB · 323 KB · 766 KB · 1,079 KB.**

### 1.2 · Image weight — by bytes per pixel

`bytes / (natural_width × natural_height)`. It is the only metric that **does not punish a
large image for being large**: a well-encoded 1680×1120 hero passes, and a badly exported icon
fails.

| | Threshold |
|---|---|
| **Fail** | **> 0.30 B/px** on photographic content · **or** any image over 500 KB |
| **Warn** | **> 0.15 B/px** · **or** any image over 250 KB |
| **Target** | **≤ 0.10 B/px** |

CALIBRATED: one site achieves **0.037–0.041 B/px** in WebP and another **0.058–0.101 B/px** in
JPEG, both at the quality the client accepted. External anchor: the standard "efficiently
encode images" audit compares against WebP at quality 85.

**Two judgement rules that travel with this, and are not about weight:**

- **Photographs NEVER in PNG.** PNG is for flat graphics with transparency. A `.png` that is a
  photo gets **re-encoded**, not copied. See §4.
- **`natural_width ≤ 2 × declared_width`** (headroom for a 2× display). One logo was 1080×1080
  declared at 40×40: **729× the pixels needed**, and the visitor pays for them.

### 1.3 · Fonts

| | Threshold |
|---|---|
| Families | **0 by default** — a system stack. Maximum 2. **Fail from 3** |
| Files the browser actually downloads for the first screen | ≤ 2 and ≤ 60 KB · warn above · **fail** over 4 or 200 KB |
| `font-display` | `swap`, mandatory |
| `preload` | **Only** the faces used above the fold |
| `Cache-Control` on fonts | **one year** |

CALIBRATED, and this is the number that changes the conversation: **one site serves the SAME
two families as another** in **2 files / 45 KB**, against **4 files / 254 KB.**

> The design document celebrates *"they are VARIABLE fonts: 4 files, not 16"*. **Our own best
> site runs on 2.** And a third loads none at all — a system stack, with the privacy reason
> written into its CSS — and it was **the only one of the five that passed the density gate
> first time.** Zero fonts cost it nothing in layout.

### 1.4 · Everything else

| What | Threshold | Who failed |
|---|---|---|
| Third-party bytes | **Fail** at > 50% of the weight **or** > 300 KB | one site at 66–93% (711 KB); another at 45% on its light pages |
| Duplicated measurement IDs | **Fail** on any analytics/ads/pixel loaded twice | one site: the ads tag and the pixel, both twice |
| Favicon | **Fail** over 10 KB · **target** an inline SVG data URI, **0 requests** | 320 KB on one site |
| `Cache-Control` | **Fail** if a sealed asset is served `no-store`/`no-cache` | one site: the CSS and all six JS modules |
| Compression | **Fail** if html/css/js ship without gzip/brotli/zstd | **none** — see §6 |
| Requests | **Warn** over 30 in the initial load | none: one page has 61, but 54 are lazy → 7 initial |

---

## 2 · How it is checked

```bash
# 1 · Bytes ON THE WIRE (not decoded) for one resource
curl --compressed -sS -o /tmp/f -w '%{size_download} %{content_type}\n' "$URL"

# 2 · The full resource list has to come from the RENDERED DOM, not the served
#     HTML: one catalogue page declares 0 images and serves 56.
```

**Mandatory headers on the `curl`** (a user-agent alone is not enough — see §3):
`Accept`, `Accept-Language`, `Referer`, `sec-ch-ua`, `Sec-Fetch-Dest`, `Sec-Fetch-Mode`,
`Sec-Fetch-Site`.

**Why not a full audit tool:** a gate that depends on a tool that is not installed **does not
fail: it never fires**, which is worse than not having it. This measures real transfer, not a
synthetic score.

---

## 3 · Traps in measuring this — all five already paid for

- **`size_download` ≠ `wc -c`.** With `--compressed`, `curl`'s size gives you the bytes **on
  the wire**; `wc -c` gives you the **decoded** ones. Verified on one home page: **5,059**
  against **17,657**. And requesting compression **without** `--compressed` leaves the file
  compressed on disk: parsing it measures rubbish.
- **A host returned a "checking your browser" interstitial** to `curl` with only a user-agent.
  Three different URLs gave **exactly** 3 requests and 54.3 KB each.
  **Identical numbers for different URLs means a broken measurement, not a finding.** I was
  about to attribute to the client a set of web fonts that *the challenge page* loads.
- **Chrome serialises attributes with entities**: `src="…&amp;cx=c"`. Requesting that URL adds
  phantom parameters and splits one request into two. Decode the entities before resolving.
- **Render-blocking can only be judged on the SERVED HTML.** Judged on the rendered DOM it gave
  a false positive: the script is injected by the tag manager at runtime, and a script inserted
  by JavaScript is async by definition. **It is the same error as the circular fidelity gate**:
  measuring something that has already been through a transformation.
- **ES module imports do not appear in the DOM.** One site looked as though it had no
  JavaScript of its own; it has **6 modules (~29 KB)** imported from an inline module script. A
  DOM parser will never see an `import`: you have to follow the graph.
- **An invented third-party pattern lies.** Mine included a social network's name and matched
  the site's own URL for a page about that network: 4 KB of "tags" on the site that makes
  **zero** third-party requests. Use an explicit host list, and open every zero by hand.

---

## 4 · What this breaks in a MIGRATION, and no gate looks at it

The source-inventory gate answers *"what did they have that we do not?"* **Not one line asks
"how much does what we kept weigh?"**

One migration inherited the source's binaries verbatim — the content hash in the filename
proves it. Among them, the 2.28 MB photograph. **The inventory counted it as present and passed
it.**

> **You preserve the IMAGE, not the FILE.** Same framing and same content, re-encoded to your
> standard.

It is the same distinction the system already learned for layout (*"you preserve the CONTENT,
not the layout"*) and that **was never applied to binaries.**

**And the mirror-image hole: assets left hanging off the origin.** An entire catalogue pointed
at the old site's upload directory; only five images were local. The migration moved the HTML
and left the binaries where they were: that page weighs 24 MB, of which **24.05 MB come from
the unoptimised original.** The system already warns about this for the CODE — *"the moment DNS
moves, their site stops existing"* — and **not for the ASSETS**: if that origin is switched off
or cleaned up, the shop loses its photographs.

---

## 5 · Where the rule does NOT apply — the edge cases

A threshold applied without branches is an instrument that accuses. These five are declared,
not failed:

1. **Lazy images below the fold do not count towards initial weight.** The 61-request page has
   **7** in its initial load. Failing it for 61 would be failing the instrument, not the page.
   *(That catalogue still fails on bytes per pixel: they are two different things.)*
2. **`unicode-range` means the browser does NOT download every face.** Counting all four files
   on one site overestimates its initial weight by about 141 KB. You count what is preloaded
   plus what matches by range, not what is in the `@font-face` block.
3. **A web font is justified, not forbidden.** Zero families is the **default**, not a dogma:
   if the client's brand has its own typeface, you load it — within the ceiling of 2 families /
   2 files / 60 KB, and with the reason written into the project's notes.
4. **A client photo at a quality they insisted on** does not get degraded to pass a threshold:
   you change **format** (WebP/AVIF), which is where 90% of the saving is. The threshold is
   bytes per pixel, not perceived quality.
5. **An internal `noindex` page** (a configurator, a dashboard) is allowed to weigh more: nobody
   shares it and nobody crawls it. It gets declared in the spec, not ignored quietly.

**And what this document does NOT measure, said out loud:** **real** LCP, CLS and INP — those
would need an instrumented browser and field data. What is measured here are the measurable
**causes**: bytes, requests, declared dimensions, `font-display`, caching. A site passing this
**does not tell you** its LCP is good.

---

## 6 · The one thing that comes out right, and is therefore dated

**All five sites serve `html`/`css`/`js` compressed** — one with zstd, the other four with
brotli. **None serves uncompressed text. And zero render-blocking scripts across all five.**

It is reported exactly like a failure, on purpose: without the check, *"it is surely enabled"*
is an assumption. **The host provides it, not us — if a host changes tomorrow, nobody would
notice today.**

---

## 7 · The five fixes, by bytes saved

> **Three of these sites are live and receive leads. None of this is deployed.**

| # | Action | Saving | Risk |
|---|---|---|---|
| 1 | Re-encode a catalogue to WebP and **bring it into the repo**. Three PNGs (one is an exported PDF) total 8.6 MB | **~20 MB** on one page | Live shop: the product data has to point at the new paths |
| 2 | A 2.28 MB portrait PNG → WebP | ~2.1 MB on the home page | Low: it is an asset, it does not touch layout |
| 3 | Remove a duplicated ads tag and a duplicated pixel | ~288 KB on **every** page | **Touches measurement: verify the conversion before and after** |
| 4 | A 320 KB favicon → SVG or a 32px PNG | ~320 KB × 13 pages | None |
| 5 | `Cache-Control` on CSS/JS: from `no-store` to a long max-age (they are already sealed) | ~43 KB per navigation | Requires the sealing to be **complete** — see the traps log |

---

## Links — what is not repeated here

| For | Go to |
|---|---|
| Typography: self-hosting, licences, `unicode-range` | `02-design.md §4` |
| Images: what gets generated and what does not, alt text, prompts | `02-design.md §5` |
| Partial cache-busting breaking ES modules | `../docs/traps.md` |
| Density, screens of scroll and calls to action | `../checklists/final-qa.md` · `11-measurements.md §5.3` |
| Contrast and accessibility | `14-accessibility.md` |
