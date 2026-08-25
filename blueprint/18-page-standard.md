# 18 · The PAGE standard (the 30 rules)

> **THIS FILE IS GENERATED. Do not edit it by hand.**
> `node gates/fold-page-standard.js` rewrites it from `gates/standard-rules.json`, which is
> where the rules live. Editing here creates a second place where the same truth lives, and
> that always ends in divergence.

These 30 rules used to live in a separate document **that no longer existed**: thirty rules
pointing at a deleted file, which is exactly why nobody looked at them while building a page.
They are folded in here.

| Mark | What it means |
|---|---|
| **gate** | An instrument measures it: if it fails, it goes red on its own |
| **partial** | The instrument sees part of it; a person looks at the rest |
| **human** | **No gate will ever measure this.** It goes to block B of the final QA |

## Before creating it

- **WPS-01** · human — Which lane does it belong to? If it fits none, it does not get created.
  <br>`no instrument`
- **WPS-02** · human — If it competes in search: MEASURED volume, with the source and the figure. No data, no page.
  <br>`no instrument`
- **WPS-03** · gate — Who is going to link to it from BODY copy? At least two. Navigation does not count.
  <br>`qa-master EST-08 (partial: NOT VERIFIED today) + linking-gate.pl R3`

## The head: what machines read

- **WPS-04** · gate — A unique `<title>`
  <br>`qa-master SEO-02`
- **WPS-05** · partial — A unique, self-contained `<meta description>`
  <br>`qa-master SEO-03 / SEO-03b`
- **WPS-06** · gate — `<link rel="canonical">`, absolute and pointing to itself
  <br>`qa-master SEO-04`
- **WPS-07** · gate — Open Graph + `twitter:card`, static
  <br>`qa-master SEO-07`
- **WPS-08** · gate — `og:image` ABSOLUTE, with `og:image:alt` and `twitter:image`
  <br>`qa-master SEO-06`
- **WPS-09** · gate — A real `<html lang>`
  <br>`qa-master A11Y-01`

## Navigation and accessibility

- **WPS-10** · gate — `BreadcrumbList` JSON-LD on EVERY page
  <br>`qa-master SEO-13 (WARN only)`
- **WPS-11** · gate — Real `<a href>` links, never JavaScript-only navigation
  <br>`qa-master SEO-14`
- **WPS-12** · gate — Descriptive `alt` on every content image
  <br>`qa-master SEO-10 / A11Y (A3)`
- **WPS-19** · gate — Interlinking: 2–4 siblings from the same cluster, with descriptive anchors
  <br>`linking-gate.pl R8 + qa-master EST-08 (NOT VERIFIED)`

## The body: what makes it quotable

- **WPS-13** · partial — A 40–60 word answer capsule immediately under the H1
  <br>`no instrument`
- **WPS-14** · partial — At least one comparison table with a verdict line per row
  <br>`no instrument`
- **WPS-15** · partial — At least one sourced figure, with `<blockquote cite>` and visible attribution
  <br>`no instrument`
- **WPS-16** · partial — An FAQ block at the end (5–8 Q&A) + `FAQPage` JSON-LD
  <br>`no instrument`
- **WPS-18** · gate — A visible datestamp with `<time datetime>`
  <br>`no instrument`
- **WPS-21** · human — An honest status (Live / Beta / In construction / Planned). Never oversell.
  <br>`no instrument`
- **WPS-23** · human — At least one original visual per pillar or comparison that EXPLAINS something
  <br>`no instrument`
- **WPS-24** · human — ZERO stock imagery
  <br>`no instrument`

## Structured data

- **WPS-17** · gate — `Article`/`TechArticle` with `datePublished` + `dateModified` (both mandatory) and a complete author
  <br>`qa-master SEO-11 (only checks that JSON-LD EXISTS)`
- **WPS-20** · gate — A hub emits `CollectionPage` + `ItemList` listing its children with position and url
  <br>`no instrument`
- **WPS-25** · gate — `Article` or `TechArticle`, NEVER both
  <br>`no instrument`
- **WPS-26** · gate — `author`: the complete canonical block (name, jobTitle, worksFor, sameAs)
  <br>`no instrument`
- **WPS-27** · gate — Do NOT use `SearchAction`, `Review`/`AggregateRating`, `LocalBusiness`, `Product`, `speakable` or `HowTo`
  <br>`qa-final.sh (SearchAction with no search function)`

## Weight and delivery

- **WPS-22** · gate — Each page's OWN `og:image`. Never leave the default on a content page.
  <br>`qa-master SEO-08`
- **WPS-28** · gate — Zero third-party resources (a rule for YOUR site, not the client's)
  <br>`qa-final.sh + qa-master REN-05`
- **WPS-29** · gate — The integrity and site auditors EXIT 0. Red does not deploy.
  <br>`audit.sh`

## And finally, the one nobody automates

- **WPS-30** · human — And after all of that passes: OPEN THE PAGE AND READ IT.
  <br>`no instrument`

---

**The split: 19 with a gate · 5 partial · 6 human.**

The human ones **are not a hole to be filled**: the standard says a person judges them. What
*is* a hole is counting them as passed.

> **Note on the marks, and it is the honest half.** A rule marked `gate` whose instrument
> column says `no instrument` is a rule that **can** be gated and is not yet. That
> contradiction is deliberate and left visible — it is the backlog, and hiding it would make
> the table lie.
>
> Counted against the source rather than by eye: of the 30 rules, **16 name an instrument and
> 14 do not.** So the marks say 19 are gated and the instrument column says 16 are. **Believe
> the instrument column** — a mark is an intention, a named check is a mechanism.
