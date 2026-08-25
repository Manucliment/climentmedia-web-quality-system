# The extractor — what gets reused and what gets written every time

> **There are TWO families of source, and they are nothing alike.** The first half below
> (parsing TypeScript) is for app-builder projects with a real `src/`. If the client brings a
> **WordPress**, skip to the WordPress section: the content is not in source files, it is in
> a database read over an API.

---

## The split

| Reused as is | Written per client (~1 h) |
|---|---|
| A value split across two lines by their formatter | The **field mapping** of their model |
| The two shapes an array can take (inline / multi-line) | The **shape** of the container |
| Template literals interpolating constants | Which constants they have |
| Shared constants that expand | Which ones |
| Image identifiers → real paths | Where the imports are |
| **Reconciling totals against the source** | What gets counted |

**There is no universal extractor, and forcing one would be worse.** Every project has its
own model. What gets reused is the set of solved traps.

## The shapes we have seen

```ts
// a flat array
export const SERVICES: Service[] = [ { slug: "...", ... }, ... ]

// a Record indexed by slug
export const CITIES: Record<City["slug"], City> = { citya: { ... }, ... }

// a Record of string arrays
export const ZONES_BY_PROVINCE: Record<ProvinceName, string[]> = { "Region": [...] }
```

An array is walked with `/^  \{/` … `/^  \},?/`.
A `Record` with `/^  [a-z-]+: \{/` — and you have to **flush the previous one** when the next
opens **and** when the object closes (`/^};/`), or you lose the last entry.

## The reconciliation block — not optional

**An extractor that drops data does not fail: it delivers less, and that does not show.**
So the script ends by printing, against the source:

```
  services    TS:6   JSONL:6
  bullets     TS:18  JSONL:18
  faq         TS:15  JSONL:15
  localities  TS:57  JSON:57
  postcodes   TS:59  JSONL:59
```

> **And the reconciliation can be wrong too.** Three of four "discrepancies" on one migration
> were counting errors of mine, not extraction errors:
>
> - `grep -oc` counts **lines**, not matches — the `-c` cancels the `-o`
> - Counting every string in an object JSON includes the **keys**
>
> **If the reconciliation says data is missing, check the reconciliation before touching the
> extractor.**

## The extractor copies, it does not fix

If the source carries rubbish — zero-width spaces, duplicates, identical titles — **it gets
extracted as is.** The correction goes into the spec's `overrides`, with its `why` field.

Reason: the extracted files **get regenerated.** A fix written there is lost on the next
extraction. And the client has a right to see what we changed relative to what they approved.

---

# WordPress as the source (proven on a 33-URL migration)

There is no `src/` to parse. The content lives in a database and comes out through the REST
API, which is open on most installations.

## What you capture on day ONE

```bash
for ep in pages posts media categories; do
  curl -s "https://SITE/wp-json/wp/v2/$ep?per_page=100&page=N&context=view" -o api/$ep.json
done
```

**ALWAYS PAGINATE.** `per_page=100` without paging delivered **100 of 129** media items with
no error at all. It does not fail: it delivers less. You count against the source.

And separately: the served pages (for the metadata), the CSS, and **the entire media
library**. If the original hosting is cancelled when the domain moves, that copy is all that
is left.

## Where each thing lives

| What | From | The trap |
|---|---|---|
| Content | the rendered content field | With a page builder it arrives as one big wrapper div: **it is complete, valid HTML**, not empty |
| `title` and `description` | **the served HTML** | The SEO plugin **does not always expose its JSON head**. On one site: 0 of 21 and 0 of 12. Check it, do not assume it |
| Image `alt` | the media endpoint | The `alt` on the `<img>` in the content and the one in the library can differ |
| **The `h1`** | **may NOT be in the content** | The **theme** supplies it. On one migration, **14 pages** came out with no `h1` — the 12 blog posts among them. If the content does not carry it, emit it from the title |
| FAQ | `<details>`/`<summary>` | The answer **is not always a paragraph**: one was a list. Pairing only paragraphs lost the entire answer |

## Parser, not regex

On one migration I broke **four sweeps in a single day** using `grep` over HTML and JSON:

- `<p[^>]*>` matches `<path` in an SVG
- `[^"]` stops at the first escaped quote in JSON
- An unescaping `sed` does not unescape inside a heredoc sent over `ssh`
- `grep -oc` counts lines: the `-c` cancels the `-o`

**Extractors go in files and get copied across** — never embedded in an `ssh` heredoc,
because the outer heredoc has already consumed stdin and the interpreter reads an exhausted
stream.

## What the extractor does NOT see, and you have to census separately

**Visual page builders emit buttons as text.** Extracting only the text leaves loose fragments
in the middle of the page: one call to action repeated four times on a home page, "Read more »"
twelve times in a blog index.

**No gate detects it**: it is valid HTML. You see it by looking at the published page.

- Census them with a script **before** writing the rule that handles them. I saw 2, and there
  were **41 across 12 pages**.
- **They do not get deleted: they get turned back into buttons.** They were the client's calls
  to action.
