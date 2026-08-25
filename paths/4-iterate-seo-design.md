# Path 4 · Iterate SEO and design on a LIVE site

> **When you are here:** the site is published. You are going to write a new page, refresh
> an existing one, change a title, schema or links, or touch the layout. **This is not a
> migration** and it is not a site from scratch.
>
> **The rule governing this file: nothing here explains how to do anything.** Everything
> below is pointers, classifications and gates. The criteria are already written in
> `blueprint/`. If you find yourself drafting a criterion, stop: it lives somewhere else and
> what is missing is the link.

---

## 0 · The map: the loop has six stations, not four

Nobody had this map written down, and it was half the problem. When the automation was
finally enumerated, there were **six** roles in the loop, not the four everybody talked
about — the two missing ones were **the only station that publishes** and the off-page one.

| Phase | Role | Writes to | Publishes? |
|---|---|---|---|
| **INTAKE** | Weekly radar — harvests search data and the queue | `_seo/radar/RADAR-<date>.md` | no |
| **DECISION** | The page standard's "should this exist" step | nothing | no |
| **PRODUCTION** | Writes one piece, ticks the backlog | one piece + `content-backlog.md [x]` | no |
| **CATALOGUE** | Refreshes generated catalogue pages | the catalogue spec | no |
| **PUBLICATION** | The deploy queue watcher | `_deploy-queue.md` → `live` | **yes, the only one** |
| **RETURN** | Monthly performance verdict per piece | `_seo/performance/PERF-<month>.md` | no |
| **OFF-PAGE** | Distribution and reach | external | yes, outside the site |

**The loop, as it should run:**

```
  Saturday        Wednesday        (by hand)         day 3
  RADAR   ──────►  PRODUCE  ──✂──►  DEPLOY  ──────►  PERFORMANCE ──┐
  harvest          one piece    ✂   watcher          verdict       │
  search + queue   in the repo  ✂   → live           per piece     │
     ▲                          ✂                                  │
     └────────────────────────  ✂  ───────────────────────────────┘
        the verdict reorders next week's queue
```

The scissors mark the cuts. **The loop was open in two places**, and both of them were in
the stretch that goes from *written* to *measured* — exactly the stretch everything else
rests on.

> **And for client sites, none of the six exists.** Measured: four client repositories had
> **not one automation** between them, and only one had a site auditor. Iterating SEO on a
> client site has no intake, no production and no return: only the QA in this path. That is
> why this file lives in the system and not in one site's repository.

---

## 1 · The two broken links, and how each one hides

### 1.1 · Production → publication: **the traffic light can be walked around**

The same page, in three registers, in three different states:

| Register | What it said about one live page |
|---|---|
| the content backlog | *"Produced on the 5th, **pending approval to deploy**"* |
| the deploy queue | **no row at all** for that page |
| production | `curl -L` → **200** |

It was live. It shipped through a route the queue does not record, and the queue **is** the
approval gate. It is the earlier failure inverted: on another day the queue had six rows
saying `staged` that had been deployed for who knows how long; here there was a live page
**with no row whatsoever.**

> **A queue that can be bypassed is not a gate: it is minutes.** And incomplete minutes
> manufacture phantom work in both directions — things "pending" that are already done, and
> things live that nobody knows are live.

And the publication station **had no schedule at all**. The only one of the six that
publishes fired because somebody remembered.

### 1.2 · Publication → return: **the routine ran and evaporated**

The scheduler said it had run. A recursive search for its output files across the whole
repository returned **zero files.** The routine had no run log either.

**Two corrections worth stating, because both are the general case:**

1. It is not that *there is no record of it ever running*. **There is a record that it ran
   and left nothing.** That is worse, because a "last run" timestamp reads as *done*.
2. It was not the only one without a run log. Another was missing one too — it just showed
   less, because that one leaves its output files behind. Which is precisely the argument of
   §2.

**And where the run log did exist, it was empty.** One station produced a piece, its
scheduler recorded the run, the backlog was ticked — and its own step 6 said *"add an entry
to the run log"*, while the file still read *"none yet: the next one is Run 1."*

> **And that bites its own tail.** The station's probation mode is decided by **counting run
> log entries**, and probation forbids deploying. With zero entries, **every future run reads
> itself as Run 1 and returns to probation, forever.** The station can never reach normal
> mode. A counter nobody increments is not running slow: it is nailed to zero.

---

## 2 · The mechanism that closes the loop: **the artefact is the proof**

You do not need another document, or four new run logs. You need one rule and a three-line
sweep:

> **A routine ran if and only if its output file exists for that period.**
> A "last run" timestamp proves the trigger fired, not that there is any work. And a run log
> somebody has to remember to write has exactly the same failure mode as the rule this whole
> system exists to kill.

```bash
cd /path/to/your-site
SAT=$(date -d 'last saturday' +%F)
MONTH=$(date -d "$(date +%Y-%m-01) -1 day" +%Y-%m)     # the month that closes on the 3rd
[ -f "_seo/radar/RADAR-$SAT.md" ]        || echo "MISSING the radar for $SAT"
[ -f "_seo/performance/PERF-$MONTH.md" ] || echo "MISSING the close for $MONTH"
```

Zero dependencies — no `jq`, no Node, no Python. **A sweep that depends on something absent
does not fail: it never fires**, which is worse than not having it.

**Where it lives so that it actually runs — in something that already exists:**

- The weekly radar **already opens with a "what could and could not be verified" table.**
  The monthly-close line goes there. **The intake station watches the return station**,
  which is the one that leaves no trace. It is weekly, so a lost close is discovered in days.
- And the monthly close looks at the mirror image: count the radars for the month it is
  closing. Four or five, or one is missing.
- **The probation counter stops reading the run log and counts artefacts instead:** count
  the radar files, count the ticked rows in the backlog. Count what was **generated**, not
  what was **declared.** It is the same idea that makes the master gate exist: a catalogue is
  not a step.

---

## 3 · "Live ≠ ranking: about 60 days of measuring without touching", reconciled

**The rule:** after a structural change, leave a measurement window before touching the site
again, and take the first serious reading when a full month of search data exists.

**It broke immediately, and nothing warned.** In ten days of commit history:

| Change | Class |
|---|---|
| The main conversion page's **URL changed, mid-window** | **C** |
| A positioning claim withdrawn: 14 files corrected, 11 deployed | A |
| A complete pricing page — **in the repo and 404 in production** | C |
| An entire visual redesign proposed (unapplied, and it said so) | C |

**The problem is not that it was touched. It is that the rule does not distinguish classes
of touch, so it is unfollowable — and therefore it is not followed.** A "do not touch for 60
days" rule on your own business's site does not survive the first necessary correction, and
once it is broken once it stops governing anything.

**The reconciliation: three classes, and only one waits.**

| Class | What it is | Examples | Waits? |
|---|---|---|---|
| **A · Correction** | the site says something false, is broken, or is non-compliant | a claim contradicting your own machine-readable files · a 404 · a dead `og:image` · contrast below AA | **NO. Today.** |
| **B · Addition** | a new page that **changes no existing URL** | the weekly piece | **NO.** It is a new row, not a changed row: it does not contaminate the series |
| **C · Series alteration** | changes a URL, title, description, H1, canonical, the link graph, or the layout of a page **that already receives impressions** | a URL change · a redesign · merging two pages | **YES**, unless the exception is declared |

**The exception that always beats the wait: a broken click-through rate.** Rewriting a title
that sits at position 1 with zero clicks is class C and you do it anyway: waiting 60 days
with a page that is already telling you it does not work costs more than breaking that
series.

**The event log is NOT a new file.** Every class A or C touch is recorded in the
corresponding row of the deploy queue, which already exists, is already the approval gate,
and already carries a date.

> **A delta without a record of what was touched is not a measurement, it is an anecdote.**
> The monthly close will read the traffic of a page that changed URL mid-month. If that is
> not recorded, the per-piece verdict is noise in the shape of a table.

---

## 4 · When an SEO change forces you to re-run the LAYOUT gates

**The rule that summarises the table:** *does my change add, remove or move a **direct child
of `<main>`**?* If yes, the layout is re-measured. If it only changes text inside a block
that already existed, no.

It is phrased that way on purpose: the screen-density gate measures exactly that, and that
is why **it cannot see a prose-page** — where every paragraph is a direct child and no block
ever overflows. There the structure gate rules, with its prose-page answer. **Both, not one.**

| Change | Layout? | What you run |
|---|---|---|
| title · description · canonical · OG | no | `qa-master.pl --only seo` |
| Adding `og:image` + `og:image:alt` | no | `--only seo,performance` (the image is new weight) |
| JSON-LD / schema | no | `--only seo` |
| Rewriting a paragraph, changing a heading's text | no | `--only seo` |
| **Adding a section** (FAQ, capsule, comparison table) | **yes** | `measure-screens.js` + `structure-gate.js` (verdict **and** prose-page), **at 1440 and 390** |
| **Adding a table** | **yes** | the above + horizontal overflow at 390 |
| Internal links / changing a hub | **yes, the LINKING one** | `crawl-links.pl` + `linking-gate.pl` EXIT 0 |
| **Changing a URL / merging pages** | **yes, both** | linking + `--only seo` + check the 301 following redirects |
| Touching a shared stylesheet | **yes, on EVERY page that loads it** | full layout + `--only a11y` (contrast with computed style, **never read from a screenshot**) |
| Deploying only | no | `qa-master.pl --repo <dir>` → the repo-versus-production check |

> **Always at both widths, with the measured `innerWidth` written next to the result.**
> Headless Chrome on Windows clamps the window to about 500px: a capture "at 390" is a crop,
> and that alone cost two invented defects. **Measure from a Linux host**, with a probe that
> returns whether the width matched. A result where it did not match is not a result.
>
> **A gate that could not be run is written `NOT MEASURED` with the reason.** A missing line
> reads as a PASS — which is the whole reason the master gate distinguishes NOT VERIFIED
> from PASS.

---

## 5 · The path, step by step

| # | Step | Where it is written |
|---|---|---|
| **0** | **Consult before analysing.** The most recent radar and its queue section, the content backlog, the deploy queue, and your task board. **Do not reopen what is closed or duplicate what is open.** | `CLAUDE.md` |
| **1** | **Should this page exist?** The three questions: which lane · what justifies it (measured volume **or** a real catalogue entry) · who links to it from body copy (at least two; navigation does not count). | `blueprint/18-page-standard.md` |
| **2** | **Classify the touch: A, B or C.** If it is **C** inside a measurement window → you stop, or you declare the exception **with a name and a reason** in the deploy queue row. | §3 above |
| **3** | **Look at the mould before writing a component.** And the type's anatomy decides the fields, not the other way round. | `blueprint/10-layout-vocabulary.md` · `blueprint/09-page-types.md §2` |
| **4** | **Write / edit.** Head, schema and the GEO layer. | `blueprint/18-page-standard.md §1–3` · `blueprint/03-content-and-seo.md` |
| **5** | **Gates per the table in §4.** The ones that do not apply are not run; the ones that apply and cannot be run are written `NOT MEASURED`. | §4 above |
| **6** | **`qa-master.pl` — the single entry point.** 74 checks, 5 lenses, **EXIT 0 to deploy**. `--only <lens>` to avoid paying for all of it. `--repo <dir>` enables the repo-versus-production check. | `gates/qa-master.pl` |
| **7** | **OPEN THE PAGE AND READ IT.** The auditor tells you WHERE to look, not whether what is there makes sense: it once passed a page carrying a sentence that did not parse as English, an `og:image` that 404'd, and another page's `<title>`. | `blueprint/16-step-by-step-review.md` |
| **8** | **Publish through the queue, not the shortcut.** Row in the deploy queue **before** the deploy, and `live` **in the same batch**. If a `staged` row appears, check the URL before believing it. | §1.1 |
| **9** | **Verify production serves what the repo has.** The repo-versus-production check, then ping the index-now endpoints. | `blueprint/06-publishing.md` |
| **10** | **Record the touch** (class A or C) so the monthly close can read the delta, and **close your own ticket** in the same gesture. | §3 |

> **Red does not deploy.** It is written in several places, and it existed as a real gate in
> **2 of 5 repositories**. For the other three, the master gate is the gate and there is no
> other.

---

## 6 · The hole that remains

What this path does **not** cover, because it has no gate today. Enumerated so it does not
read as though it covered everything.

1. **Freshness.** The master gate does not look at `dateModified` or `lastmod` — zero
   occurrences. The radar looks at it by hand (over 90 days) but **an eye is not a gate.** It
   is the cheapest hole here to close.
2. **Redirect chains.** Nothing checks that a 301 arrives in one hop, or that there are no
   loops. With **34 live redirects** on one site, that is unwatched surface. The only thing
   written is the warning that `curl` without following redirects measures the body of the
   301.
3. **`hreflang`** can only emit **NOT VERIFIED**. It never fails.
4. **The page that exists in the repo and NOT in production.** The repo-versus-production
   check compares md5 of pages that exist on both sides. A pricing page was committed for
   over a week while production returned **404**: the check had nothing to compare, so **it
   said nothing.** The gate sees content drift, not **existence** drift.
5. **Citations in AI assistants.** This is the entire return leg and today it has neither a
   gate nor an artefact. It cannot be automated — it is 20–30 questions to three assistants —
   but it can be made impossible to forget, with the sweep in §2.
6. **Search Console with no credential.** Two weeks of radars with their first three sections
   empty, and a monthly close with nothing to give a per-page verdict from. The runbook was
   written; the missing step belonged to a human. While it is missing, the return leg can
   only be closed with the AI citations — which *can* be measured today, and which nobody
   else measures.
7. **Scheduled-task prompts drift and nobody owns them.** There are **two** files per
   routine: the skill in the repository, and the prompt the scheduler actually executes. One
   prompt, untouched for weeks, told the routine to measure a URL that had been renamed, to
   read a document that had been superseded as "the site's contract", and to check a count of
   "8 of 8" on a site with 45 pages. The radar had already flagged that it affected **four**
   prompts. **The skill gets updated when somebody works in the repo; the prompt only if
   somebody remembers** — and it is the prompt that governs the run.

---

## THE DOOR — the one step that cannot be skipped

> **This block is identical in all four paths.** If it changes, it changes in one place:
> four versions of the same step is how the duplicated-navigation mess started.
> `doc-gate.pl D5` fails if they diverge, or if a fifth path is born without it.

**Nothing is uploaded by hand. Ever.** Not a stylesheet, not an image, not "one line".

```bash
# 1 · measure THE TREE YOU ARE ABOUT TO UPLOAD, not the site already up there
perl gates/qa-master.pl https://your-domain.tld --repo DIR --candidate --max-urls 60

# 2 · dry run: writes nothing
bash gates/deploy.sh DIR

# 3 · upload, and verify that what is served IS what was measured
bash gates/deploy.sh DIR --upload
```

| | |
|---|---|
| **`--candidate` is not optional** | without it you measure PRODUCTION while the receipt seals the repository tree: two different artefacts wearing one face |
| **The receipt expires in 12 hours** | and is valid only for the exact tree it measured. Touch a file and it is measured again |
| **`NOT VERIFIED` is not a pass** | to ship with holes you sign them: `--anyway "the reason"`, which **gets written** into the history with the exact list of what was not measured |
| **There is another gate before uploading** | step 2-bis runs the spec auditor against the tree: is everything the spec says exists actually on disk? **It does not block yet** — it was wired in and produced three false positives the same day, since corrected — but its verdict **is recorded**. The mode is declared by the repo: `SPEC_MODE=migration\|greenfield` in `deploy.conf` |
| **After uploading, the door continues** | the served-equals-measured check compares md5 file by file, then it crawls the served site and runs the linking gate |

**If any of this fails, the deploy has not finished** — even though the files are already
up there. A red served-equals-measured means production is not serving what was measured,
and that has happened: a contrast fix sat in a repository for hours with every gate green
while production served the old stylesheet.

**Before touching the system itself** (a gate, a program, this documentation):

```bash
bash gates/tests/run-all.sh     # every battery + documentation + coverage
```
