# Content and the SEO / GEO / AEO / LLM layer

> "It looks the same" is not a measurement. **How many of their strings are in ours** is.
> Threshold: **≥90%**, and every missing string explained.

---

## 1 · The text fidelity gate

An extractor that loses data **does not error: it delivers less.** The first serious
measurement on one migration came back at **54%**, and behind it were four real losses no
HTML audit would ever have seen: 7 FAQ questions, 6 more on another page that **were not even
in their structured data**, the entire footer wrong (across 17 pages) and a form that did not
exist. With all four fixed: **91%**.

```bash
txt(){ tr -d '\000' \
  | perl -0777 -pe 's{<script.*?</script>}{}gs; s{<style.*?</style>}{}gs; s{<!--.*?-->}{}gs' \
  | sed 's/<[^>]*>/\n/g' | sed -f norm.sed \
  | sed 's/^[ \t]*//;s/[ \t]*$//' | grep -v '^$' | awk 'length($0)>25' | sort -u; }

curl -s "https://source$u" | txt > orig.txt
cat "$f"                   | txt > mine.txt
while IFS= read -r l; do grep -qxF "$l" mine.txt && k=$((k+1)); done < orig.txt
```

**Three things are mandatory, and I got all three wrong first:**

1. **Strip their `<script>` blocks with a multi-line regex.** A line-based `sed` does not
   remove them, and the consent-mode boilerplate gets counted as their "text".
2. **Normalise HTML entities on both sides** (`&#x27;` ↔ `'`, `&amp;` ↔ `&`). Without this,
   half the content in any accented language fails to match.
3. **`awk 'length>25'`**, so you are not measuring navigation noise.

### Reading the result: a non-match is NOT an absence

| What you see | What it is | Real? |
|---|---|---|
| Starts with a zero-width space | deliberately cleaned | **no** — declared in `overrides` |
| A sentence split into pieces | their DOM splits it with an inline link | **no** — artefact |
| "1. Title. Text." run together | captured concatenated | **no** — formatting |
| An FAQ question | their accordion was not extracted | **YES, real** |
| Footer or menu text | structure is wrong | **YES, real, and ×N pages** |

**Group by number of pages affected**: what is missing on 8 of 8 is systematic and is worth
eight times what is missing on one.

```bash
sort allmiss.txt | uniq -c | sort -rn | head -20
```

---

## 2 · What every page carries, without exception

| | How it is checked |
|---|---|
| A unique `<title>` | `grep -h '<title>' *.html \| sort \| uniq -d` → empty |
| A unique, self-contained `<meta description>` | same |
| `<link rel="canonical">` **to itself** | §3 |
| **Absolute `og:image` + `og:image:alt` + `twitter:image`** | §4 |
| A real `<html lang>` | `fr`, `es`, `nl-BE`… |
| `BreadcrumbList` | every page except the home |
| Real `<a href>` links | never JavaScript-only navigation |
| `alt` on every content image | `grep -o '<img[^>]*>' \| grep -vc 'alt="[^"]'` = 0 |
| **The client's favicon** | not a generic glyph |

And at site level: `robots.txt`, `sitemap.xml` and `llms.txt`, **all three from the same loop**
as the pages, with a gate that fails if they diverge.

---

## 3 · Canonical: it points to ITSELF

The most expensive defect found on a client site, and it came from the factory: five city
pages all declared their canonical as the hub. They were in the sitemap and simultaneously
telling the search engine not to index them.

```bash
for f in *.html; do echo "$f -> $(grep -oP '(?<=rel="canonical" href=")[^"]+' "$f")"; done
```

> **It travels with the content.** Fixing the canonical on N duplicate pages is worse than
> leaving it: you have just told the search engine to index N duplicates. **Either both, or
> neither.**

---

## 4 · `og:image`: the one no gate detects

**An entire site** shipped without it. The page validates perfectly; it is just that every
time somebody shares the link on a messaging app, a grey rectangle comes out. For a local
business, that app **is** the recommendation channel.

```bash
for f in *.html; do grep -q 'og:image' "$f" || echo "NO og:image: $f"; done
```

Absolute · with `og:image:alt` and `twitter:image` · the page's own if it has one · **and if
the client already had one, it is preserved.** On one migration theirs existed and had been
lost: that was a regression, not an omission.

---

## 5 · `llms.txt` is PLAIN TEXT

Titles and descriptions come out of their HTML with entities inside. In HTML they are
necessary; in a `.txt` they stay literal and a model reads
**`Besoin d&#x27;un kinésithérapeute`**.

```bash
grep -o '&[a-zA-Z]\+;\|&#x\?[0-9a-fA-F]\+;' llms.txt   # must come back empty
```

Minimum contents: the name, one line on what they do and where, phone and hours, the pages
with their descriptions, and the services. **The same URLs as the sitemap**, verified by the
gate.

---

## 6 · Schema: what to emit

| Type | Where | Why |
|---|---|---|
| `LocalBusiness`, or its real subtype | every page | name/address/phone + areas served + hours |
| `BreadcrumbList` | every page except the home | best value for the cost |
| `FAQPage` | wherever there is a **visible** FAQ | only if it is visible |
| `ItemList` + `Person` | the team | if there are real photos and names |

**Honesty beats completeness.** Marking up something that does not exist subtracts. If the
client was already emitting correct schema, **it is preserved**: migrating is not redoing what
worked.

> **`FAQPage` with no visible FAQ is what they had**: three questions per city in the markup
> that were not visible anywhere. You paint the accordion **and** emit the schema.

---

## 7 · What no gate measures, and what actually decides

That the answer is **better formulated than the competitor's.** Markup helps a machine
understand; what gets you quoted is the content.

---

## 8 · The AEO layer, and the three gates added on 2026-08-26

For a long time this document was the whole SEO/GEO/AEO layer, and it only covered the
**machine** half: canonical, `og:image`, `llms.txt`, schema. A sweep of the 34 gates that
day found `GPTBot` **0**, `PerplexityBot` **0**, `ClaudeBot` **0**, `AI Overview` **0**.
We were building for answer engines and measuring none of it.

### 8.1 · Can the engines get in at all — `ai-crawlers.pl`

```bash
perl gates/ai-crawlers.pl --url https://example.com/
```

First thing to check, because if the bots cannot crawl, nothing else on this page matters.
Ten required agents, three advisory.

**It is not a `grep`, and that is the whole point.** A `grep -c GPTBot robots.txt` is wrong
in the four cases that actually occur, and all four have a case in the bank:

1. **An agent with its own group stops inheriting the `*` group entirely.** `User-agent:
   GPTBot` followed only by `Crawl-delay` does **not** inherit `Disallow: /` from `*` — so
   it is allowed. And the reverse: its own group can block it while `*` allows everything.
2. **The longest path wins**, not the first or the last. `Disallow: /` plus `Allow: /learn/`
   allows `/learn/x` and still blocks the root.
3. **An empty `Disallow:` allows everything.** A grep for "Disallow" counts it as a block.
4. Agent names are **case-insensitive**.

`Google-Extended` and `Applebot-Extended` are **advisory, never a failure**: they do not
crawl, they only govern use in Gemini and Apple Intelligence, and blocking them does not
remove you from search. Treating a legitimate decision as a defect is how a gate starts
getting in the way and ends up switched off.

### 8.2 · Two pages fighting over one term — `cannibalization.pl`

```bash
perl gates/cannibalization.pl --repo DIR --audit                    # collisions that exist
perl gates/cannibalization.pl --repo DIR --keyword "<term>"         # before writing
```

`--audit` is exact: identical H1 or `<title>` between indexable pages. No heuristic.
`--keyword` returns NEW / UPDATE / CANNIBALIZES / REVIEW **with the evidence** — which
page, with which H1, how many words overlap. `noindex` pages do not compete and are
excluded.

The first real run found **six pages of one client site sharing one `<h1>`** — the zones
hub and five city pages — while their `<title>` tags **were** differentiated per city.
Someone separated the title and forgot the H1. City pages are where this defect lives; it
is the same family as the canonical defect in §3.

**What it does not know:** it does not read rankings. Two pages can compete without
resembling each other, and only Search Console sees that. This catches the **declared**
collision, which is the one you can avoid before writing.

### 8.3 · Does a paragraph survive being lifted out — `citable.pl`

```bash
perl gates/citable.pl --repo DIR --brand "Your Brand"
```

An answer engine does not read the page, it extracts a chunk. So every paragraph has to be
read **as if it were the only thing on the page**. Six mechanical checks: orphan pronoun in
the opening, backward reference, subject never named, over-hedging, relative date, and more
than five sentences in one paragraph. Severity is `BLOCKS` / `WEAKENS` / `POLISH`, and there
is deliberately **no numerical score**.

**Two block sizes, and this document only had one.** A 40–60 word capsule serves the
featured-snippet surface. The citation surface is **134–167 words, self-contained**. Those
are different surfaces, and a page can be excellent at one and absent from the other.

🔴 **It refuses to score a language it has no patterns for.** The patterns are English and
Spanish. A gate that sweeps a French page it cannot parse and reports "0 findings" looks
like coverage and is a hole — so it reads `<html lang>` and returns `NOT MEASURED`.

> **The lesson from building these three, and it is the one worth keeping.** The first real
> run of `citable.pl` reported 76 blocking findings. Half were not: `this page`, `these
> terms`, `that distinction` are a determiner with its noun — the subject *is* named. Only
> a following **verb** makes it an orphan pronoun. And a second check accused 19% of all
> paragraphs by demanding the brand name in every one of them, which is keyword stuffing
> the GEO study measures at **−10%**. **If a sweep says everything is broken at once, the
> broken thing is the sweep** — §3 of the agent rules, earned again.
