# Page types and their markup: what each type carries, what it must not, and the search string

> The SECTIONS of each page type live in `09-page-types.md` §2 and `gates/anatomy.tsv`. This file is
> the other half: the **markup** (schema.org JSON-LD) each type carries, whether the type is indexed,
> and the actions a page may declare. Its machine-readable twin is `gates/page-types.tsv`; the gate
> is `gates/page-type-gate.pl`. Written 5-nov-2026.

**Why it exists.** Until now the only markup check was "is there any JSON-LD" (`qa-master SEO-11`),
and it gave green to any block. Every markup defect that cost us sat inside a block that existed:
an `areaServed` naming two towns nobody covered, FAQ questions in the markup that were nowhere on
the page, a `SearchAction` on a site with no search. And the rule often depends on the type of the
page: a product listing must not carry its products as loose `Product` nodes; a search results page
should not be indexed; a product page with `noindex` is lost. The type was only ever used to judge
sections.

```bash
perl gates/page-type-gate.pl https://site.example/product/x/ --tipo pdp
perl gates/page-type-gate.pl https://site.example/ --tipo home --sondear   # also fills in the search
perl gates/page-type-gate.pl --tabla                                        # the table against anatomy.tsv
```

The type comes from `data-tipo` on `<main>` or `<body>`, or from `--tipo`. Without either, the
type-dependent checks say NOT VERIFIED: declaring "the nearest type" would pass a check that was
never made.

---

## 1 · The catalogue: 22 types

Fifteen come from `anatomy.tsv` and have measured sections. Seven are new on 5-nov-2026 and have
**no measured anatomy yet** (column "Sections"): their markup and indexing are judged, their
sections are not, until four pages of other businesses are measured for each, the rule of 09 §2.

| Type | Also called | Sections | Page node | Indexed | Must carry |
|---|---|---|---|---|---|
| `home` | portada | 09 §2.1 | WebPage | yes | `WebSite` + `Organization` |
| `servicio` | | 09 §2.2 | WebPage | yes | `BreadcrumbList` + `Service` |
| `ciudad` | zona | 09 §2.3 | WebPage | yes | `BreadcrumbList` + `Service` or `LocalBusiness` |
| `ficha` | pdp, producto | 09 §2.4 | ItemPage | yes | `BreadcrumbList` + `Product`, `ProductGroup` or, for a program or an agent, `SoftwareApplication` (a `Service` is a `servicio`) |
| `hub` | | 09 §2.5 | CollectionPage | yes | `BreadcrumbList` + `CollectionPage` or `ItemList` |
| `guia` | blog, articulo | 09 §2.6 | WebPage | yes | `BreadcrumbList` + `Article` (or a subtype) |
| `comparativa` | | 09 §2.6 | WebPage | yes | `BreadcrumbList` + `Article` |
| `precios` | | 09 §2.8 | WebPage | yes | `BreadcrumbList` + `Service`, `Product` or `SoftwareApplication` |
| `contacto` | contact | 09 §2.9 | ContactPage | yes | `Organization` (a reference by `@id` counts) |
| `gracias` | thank-you | 09 §2.10 | WebPage | **no** | nothing |
| `legal` | | 09 §2.11 | WebPage | free | nothing |
| `404` | | 09 §2.11 | WebPage | **no** | nothing; served with status 404 |
| `landing` | quiz | 09 §2.12 | WebPage | free | nothing |
| `nosotros` | about | 09 §2.13 | AboutPage | yes | `Organization` |
| `empleo` | careers | 09 §2.14 | WebPage | yes | nothing (`JobPosting` only for real offers) |
| `plp` | listado, categoria | **not measured** | CollectionPage | yes, not its filters | `BreadcrumbList` + `CollectionPage` or `ItemList` |
| `pcp` | categoria-padre | **not measured** | CollectionPage | yes | `BreadcrumbList` + `CollectionPage` or `ItemList` |
| `carrito` | cart | (P1 of the `cro` skill) | WebPage | **no** | nothing |
| `checkout` | pago | **not measured** | CheckoutPage | **no** | nothing |
| `faq` | preguntas | **not measured** | FAQPage | yes | `FAQPage`, every question on the page |
| `busqueda` | search, resultados | **not measured** | SearchResultsPage | **no** | nothing |
| `perfil` | autor, profile | **not measured** | ProfilePage | yes | `Person` or `Organization` |

**PLP and PCP, the difference.** A PLP is the grid of products with filters and sort (one category
or a search of the catalogue). A PCP is the parent category above them: it lists subcategories, often
with an editorial block, and few or no product cards. Both are `CollectionPage`; the PCP's `ItemList`
lists subcategories, the PLP's lists the products that are visible.

**Why `ItemList` is not required on a PLP.** Google documents no feature that reads an `ItemList` on
a category page; asking a shop to install a plugin to pass our gate is the defect of design-E4. The
listing must say it is a listing (`CollectionPage` or `ItemList`), and an `ItemList` is recommended
when it lists what the page shows.

---

## 2 · What to review on each type, beyond its sections

| Type | Review |
|---|---|
| every indexed type | one `h1`; its own title and description; self canonical; `BreadcrumbList` with the visible crumb (`linking-gate R6`); the markup parses and only describes what is on the page |
| `home` | `WebSite` with `name` and `url` (it is what gives the site name in Google); `Organization` with `@id`, logo, `sameAs` that answer 200; a `SearchAction` **only** if the site has a search, and probed (§4) |
| `ficha` / pdp | `Product` with `name`, `image`, `offers`; the price in the markup is the price on the page; variants as `ProductGroup` + `hasVariant` + `variesBy`, each variant with its own URL and price (the page shows the selected one, so the gate asks for at least one variant price on the page, not all of them); shipping and returns at `Organization` level (`hasMerchantReturnPolicy`, `hasShippingService`) unless a product overrides them; an `AggregateOffer` carries `lowPrice` |
| `plp` / `pcp` | products only as items of the `ItemList`, never loose `Product` nodes (Google's product markup is for one product, not a list); filter and sort URLs are not indexed; page 2 of a series is its own canonical, never page 1 |
| `faq` | each `Question` in the markup is on the page; Google no longer shows FAQ results to anyone (7-may-2026), so this is description, not a win |
| `contacto` / `nosotros` | the `Organization` is the same one as the home's (same `@id`), not a second copy that drifts |
| `carrito`, `checkout`, `busqueda`, `gracias` | `noindex`: they have nothing to rank and spend crawl; no rich markup |
| `404` | status 404, not a 200 with "not found" (`receipt EST-03` checks the host) |

---

## 3 · The markup: what schema.org says, and what Google reads

The vocabulary used by the gate is generated from schema.org's own release file
(`schemaorg-current-https.jsonld`) into `gates/schemaorg-vocab.tsv`: 961 types, 546 enumeration
members and 1,538 properties of the core, each with its supertypes or domains and whether it is
`pending` or superseded. Regenerate it with `--vocab-desde` when schema.org publishes a release.

**A type is anything with a superclass, not only what is declared `rdfs:Class`.** 22 medical entries
(`Physiotherapy`, `Dermatology`, `Pediatric`…) are members of the `MedicalSpecialty` enumeration
*and* subtypes of `MedicalBusiness`. The first vocabulary read them only as members, and the gate
called `"@type":"Physiotherapy"` a type that does not exist, on a physiotherapist's own service page
(5-nov-2026). `Dentistry` is only a member: as a `@type` it still fails.

Four facts the rules rest on, each checked at the source on 5-nov-2026:

1. **Google: AI Overviews and AI Mode need no special markup.** Its page on AI features says
   there is no special schema.org structured data to add. Markup is for describing the page and for
   the rich results Google still documents, not a lever for being cited.
2. **What Google still documents** (its search gallery, 25 features): article, breadcrumb, carousel,
   course list, dataset, discussion forum, education Q&A, employer rating, event, image metadata,
   job posting, local business, math solver, movie, organization, product, profile page, Q&A,
   recipe, review snippet, software app, speakable, paywalled content, vacation rental, video.
   **Not there any more:** FAQ, HowTo, the sitelinks search box.
3. **The sitelinks search box was retired on 21-nov-2024.** Google said the `WebSite` /
   `SearchAction` markup can stay and does no harm; `WebSite` itself stays supported for site names.
4. **For shops, shipping and returns can be declared once**, on the `Organization`, and an offer
   overrides them only when it differs (Google, merchant listings). Price and currency are required
   on every offer; a past `priceValidUntil` hides the listing.

The WebPage subtypes schema.org defines, and the type that uses each: `AboutPage` (nosotros),
`CheckoutPage` (checkout), `CollectionPage` (hub, plp, pcp; with `MediaGallery` below it),
`ContactPage` (contacto), `FAQPage` (faq), `ItemPage` (ficha), `ProfilePage` (perfil),
`SearchResultsPage` (busqueda), plus `MedicalWebPage` and `QAPage`, which no type here needs yet.

**Two traps of the vocabulary itself, both found while building this:** `BreadcrumbList` is a subtype
of `ItemList`, so "has an ItemList" is true of a page that only has crumbs; and `AggregateOffer` is a
subtype of `Offer`, so a rule written for `Offer` (it needs `price`) wrongly fails an
`AggregateOffer` (it needs `lowPrice`). The gate judges a node by its most specific rule, and a node
named by its own type in one group of a row does not count for another.

---

## 4 · Actions, and the search string

`potentialAction` says what can be done with a thing. schema.org defines more than a hundred
`Action` types; **one** has had a documented consumer on the web, `SearchAction` on the `WebSite`
of the home, and its consumer (the sitelinks search box) is gone. (Gmail reads some actions, but in
emails, not on web pages.) So:

- **Declare a `SearchAction` only if the site has a search, and only on the home's `WebSite`.**
  Elsewhere it warns: nobody documents reading it.
- **Any other action warns** (`ReadAction`, `ViewAction`, `BuyAction`...): valid schema.org, no
  documented reader. Not a failure, not a win.
- `Offer.checkoutPageURLTemplate` (a URL template for checking out an offer) exists in schema.org;
  no search engine documents reading it. Noted, not used.

**The search string, wired right.** The `target` of a `SearchAction` is an `EntryPoint` with a
`urlTemplate` (RFC 6570), and the input is declared as `query-input`, the `-input` annotation of
schema.org's actions document: its short form is `"required name=q"`, and `{q}` in the template is
that **name**, not the property. The classic break is copying `{search_term_string}` from an example
and writing `name=q`: the URL is built with the braces still in it. The gate checks both ways (every
`{x}` has its `name=x`, every `name=x` has its `{x}`), that the template is absolute and on the same
host, and that it has a gap at all.

**Wired right is not working.** With `--sondear` the gate fills the template with a word from the
page's `h1` (or `--termino`) and asks for it. It fails if the answer is not 200, ends on another
host, redirects to the home without the search, or does not show the word searched; it warns if the
results page can be indexed. A host that answers 429, 403 or 503 to the probe is NOT VERIFIED: a
shop that rate-limits a client asking fast says nothing about its search.

---

## 5 · What this does not judge, said out loud

- Whether the markup **helps**: Google says the AI features need none.
- Whether `sameAs` URLs answer 200 (needs one request per profile; social networks refuse bots).
- The **sections** of a page: that is `structure-gate.js` against `anatomy.tsv`.
- Anything painted only by JavaScript: the gate reads the served HTML, as a crawler that does not
  run JavaScript would.
- The anatomies of `plp`, `pcp`, `checkout`, `faq`, `busqueda` and `perfil`: declared as types,
  their sections **not measured**. Measuring them is four pages of other businesses each.
