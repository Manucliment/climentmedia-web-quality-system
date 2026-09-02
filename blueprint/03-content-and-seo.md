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
| A unique `<title>`, 15–65 characters | `SEO-01` length, `SEO-02` duplicates |
| A unique, self-contained `<meta description>`, 50–165 | `SEO-03` present, `SEO-03b` length, `SEO-02b` duplicates |
| **`<title>`, `<h1>` and description talking about the SAME thing** | `SEO-05`, `SEO-05b` — see below |
| `<link rel="canonical">` **to itself** | §3 |
| **Absolute `og:image` + `og:image:alt` + `twitter:image`** | §4 |
| A real `<html lang>` | `fr`, `es`, `nl-BE`… |
| `BreadcrumbList` | every page except the home |
| Real `<a href>` links | never JavaScript-only navigation |
| `alt` on every content image | `grep -o '<img[^>]*>' \| grep -vc 'alt="[^"]'` = 0 |
| **The client's favicon** | not a generic glyph |

And at site level: `robots.txt`, `sitemap.xml` and `llms.txt`, **all three from the same loop**
as the pages, with a gate that fails if they diverge.

### 2.1 · Five checks can all pass on a page that contradicts itself

Until 2026-09-01 the metadata checks were five, and every one of them measured a page **on
its own terms**: is the title the right length, is it unique, is there a description, is it
the right length, is there a canonical. A page could carry a perfect 58-character title, a
perfect 140-character description and a single unique `<h1>` — **and have all three talking
about different things.** It passed all five.

That is not hypothetical. This system's own history records a site that shipped
`<h1>hero</h1>`: valid HTML, correct length, unique, and nothing looked at it.

Two checks close it, and one of them was an outright asymmetry: **duplicate titles had been
checked since the beginning and duplicate descriptions never were**, even though the table
above had been promising unique descriptions the whole time. The first run of `SEO-02b`
across six real sites found one site with **two descriptions repeated over four documents**
— and one of the two was another page's promise, copied across.

| | What it asks | Level |
|---|---|---|
| `SEO-02b` | do two documents ship the same description? | **FAIL** |
| `SEO-05` | do the title and the `<h1>` share **at least one** significant word? | AVISO |
| `SEO-05b` | does the description share one with the title or the `<h1>`? | AVISO |

**The bar is an empty intersection, not a similarity score.** Zero words in common is a
strong signal; "not very similar" is noise, and a gate that guesses teaches people to walk
around the door.

**The brand words are measured, not listed.** A word appearing in the title of ≥60% of the
site's pages is that site's chrome — the brand and the template suffix — and it is discounted
before comparing. Deriving it from the site avoids a per-client list that would rot the day
somebody changes the suffix. Below five pages the frequency measures nothing and no filter is
applied. Without this, a page whose `<h1>` shares only the brand with its title would pass,
and the check would be useless on any site with a branded title — that is, on almost all of
them. The test bank pins exactly that case.

**What these two do NOT know**, said plainly so nobody reads more into them: they do not
compare against what the page says in its **body**, only the three surfaces against each
other. They compare bytes, so `auditoria` and `auditoría` are different words to them.
And they treat two words as the same if they share their first four characters, which is a
deliberately crude stemmer whose error direction is the cheap one — it can only turn a red
into a green, never the other way. It exists because `ships` and `shipping` were being
reported as a contradiction on a page that was perfectly written.

🟡 **Both start as AVISO, and that is the house norm, not timidity.** A gate that blocks on
its first false positive teaches everyone to bypass the door, which costs more than the
defect it catches. They are wired so they are **seen**, watched over a cycle on real sites,
and only then does the bar go up. `SEO-02b` is a FAIL from day one because duplication is a
fact, not a judgement.

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

### 5.1 · It is a ROUTER, not an index

A list of URLs tells a model **what exists**. It does not tell it **which one to open**, and
that is the difference between being crawled and being cited.

Measured 2026-09-02 on a component library that does this well, and on our own sites:

| | |
|---|---|
| A `>` line under the title | what the product *is*, in one sentence |
| **A `When to use` block** | *"prefer the block pages when the user asks for realistic page compositions rather than isolated components"*. Explicit routing between surfaces |
| A description **after every URL** | what that page is FOR, not its title again |
| Grouped by purpose | *Primary pages · Trust and contact · Developer entry points* |
| A closing **`Agent notes`** | which surface is the source of truth, and what to prefer for a given question |
| An explicit "no authentication required" | removes the commonest reason an agent gives up. Only relevant if you expose an API |

🔴 **We already required the descriptions and were not doing it.** §5 has said "the pages with
their descriptions" since it was written, and nothing checked. Measured across four live sites:
**30 of 30 · 32 of 40 · 12 of 16 · and 12 of 46 on our own.** Thirty-four bare URLs on the
site that sells this service.

✅ Now checked: **`S1.6b`** in `audit.sh` — every own URL in `llms.txt` and `AGENTS.md` carries
a description, or the audit fails and says how many of how many.

⚠️ **And a description being present does not make it right.** On the site that scores 30 of 30,
one of those descriptions is another page's, copied — the same duplicate that `SEO-02b` catches
in the HTML, propagated into the machine-readable file because it is generated from the meta
tag. **A generated description inherits the defect of its source.**

> The same idea applies to the **404**: the library's 404 offers Sitemap, `llms.txt`, Developers
> and OpenAPI. A 404 that routes instead of apologising — which is what `09 §2.11` already asks
> of ours ("what happened + 3–5 destinations"), stated there for humans and worth stating here
> for machines.

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

### 8.0 · WHERE each of these runs — and why two of them were running nowhere

> 🔴 **Written 28-aug-2026, after the omission cost a live defect.** For two days these
> gates existed, were tested, and were documented right here — and **nothing ran them**.
> A site's weekly routine deployed with every gate green and published two paragraphs
> opening on an orphan pronoun, one of them the very text corrected on another page of
> the same site hours earlier, copied in its old version. No gate failed. The one that
> could see it was not in the chain. It was caught by hand, after it was already served.
>
> **What was missing was not a check. It was this table** — nobody had written down at
> which moment of the cycle each gate belongs, so two of them belonged nowhere.

| Gate | When it runs | Where it is wired |
|---|---|---|
| `cannibalization.pl` | **Before writing.** Asks whether a page already fights for that term — useless once the page exists | the weekly routine, step 3.1 |
| `citable.pl` | **Before uploading**, on the candidate tree | the door, step `2-quinquies` |
| `ai-crawlers.pl` | **Before uploading**, on the tree's own `robots.txt` — here it can still be fixed | the door, step `2-sexies` |
| `coverage.pl` | **Never on a site.** It measures the *instrument*: how many checks have a test case | the battery, `run-all.sh` |

**Neither of the two in the door blocks yet**, following the rule the door itself carries:
*a gate touched this morning is wired so it is SEEN, watched for a few runs, and only then
is the bar raised.* They start blocking once six sites have passed without a new false
positive. And only `BLOCKS` counts — `WEAKENS` and `POLISH` are writing advice; if they
counted, no site would ship today and the door would be noise by tomorrow.

⚠️ **`coverage.pl` and `cannibalization.pl` were nearly wired into the door too**, on the
strength of a note that said "the four AEO gates are outside the chain". That note came
from grepping `deploy.sh` — which answers *"is it referenced here?"*, not *"is it wired
anywhere?"*. **A narrow question answered as if it were the broad one**: the fix would have
put an instrument-measuring tool and a before-writing gate into the upload path.

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

🔴 **It refuses to score a language it has no patterns for.** A gate that sweeps a
page it cannot parse and reports "0 findings" looks like coverage and is a hole, so it
reads `<html lang>` and returns `NOT MEASURED`. Covered today: English, Spanish, French,
Portuguese, which is every site this system currently runs.

**Adding a language is not mostly about the patterns you add. It is about the ones you
leave out.** Accents are stripped before matching, and a stripped word can collide with an
everyday word in the same language. French `il` and `elle` are impersonal half the time
(`il faut`, `il y a`, `il s'agit`), so they stay out; Portuguese acute-e strips to `e`, the
conjunction "and" that opens one sentence in two, and `nos` with an accent strips to `nos`,
the contraction "in the" -- both stay out. Every exclusion carries two tests: one proving it
stays quiet, and one proving the check around it is not dead. Without the second, a
deliberate exclusion and a broken check look exactly the same from the outside.

> **The lesson from building these three, and it is the one worth keeping.** The first real
> run of `citable.pl` reported 76 blocking findings. Half were not: `this page`, `these
> terms`, `that distinction` are a determiner with its noun — the subject *is* named. Only
> a following **verb** makes it an orphan pronoun. And a second check accused 19% of all
> paragraphs by demanding the brand name in every one of them, which is keyword stuffing
> the GEO study measures at **−10%**. **If a sweep says everything is broken at once, the
> broken thing is the sweep** — §3 of the agent rules, earned again.

**A normalisation can manufacture a finding, and it can hide one.** The extractor turned
every `&entity;` into a space. `It&rsquo;s recommended` therefore read as `It s
recommended`, which matched the orphan-pronoun pattern for a reason that had nothing to do
with the text -- and `That&rsquo;s the part that fails`, a real orphan, read as `That s`
and matched nothing at all. **One bug, both directions**, on the same site: one invented
finding and two hidden ones. Fixing only the fabricated half would have locked in the
silent half, so the apostrophe mapping and the contraction patterns had to land together.

**English has an impersonal `it`, and it is not a pronoun with a missing antecedent.** In
`It is recommended that you run the experiment for six weeks`, `it` points at nothing
because there is nothing to point at -- naming the subject is not possible, only different.
This is the same trap French `il faut` / `il y a` was deliberately guarded against; English
had it too, unguarded. Every language you add needs the question asked in both directions:
which words are pronouns here, and which only look like pronouns once accents are stripped.

**A quotation cannot be rewritten, so demanding it be rewritten is how a gate gets turned
off.** A quoted paragraph that opens with a pronoun is worth knowing about, but the action
is different -- give the context *before* the quote, or paraphrase and attribute -- so it
reports as `POLISH`, not `BLOCKS`.

> ⚠️ **And the second-order bug that fix nearly introduced.** With the entity mapping
> corrected, a leading quotation mark made the `^`-anchored pattern miss entirely, so
> quoted paragraphs became exempt **in silence** -- a blind spot worse than the false
> positive it replaced, because nothing in the output says so. The quote is now stripped
> *before* judging, and the paragraph is judged and then downgraded. **Exempt on purpose
> and exempt by accident look identical in a report and are not remotely the same thing.**
