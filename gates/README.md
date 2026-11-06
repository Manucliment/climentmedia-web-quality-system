# The gates

46 programs and 42 test batteries. This file is the index: what each program is for,
how to run them all, which flags exist in English, and — the part most repositories
leave out — **what does not ship, and why.**

> Both figures are **derivable, and the recipe is here** so the next person can re-derive
> them instead of trusting the sentence above. Programs:
> `find gates -maxdepth 1 \( -name '*.pl' -o -name '*.js' -o -name '*.sh' \) ! -name '*selftest*' -type f | wc -l`.
> Batteries: the rows of `BANCOS` in `run-all.sh`.
> Until 2026-11-06 the recipe went into `hooks/` and counted `compliance-selftest.pl`, and gave
> 48 where `coverage.pl` (the count the documentation gate compares against) gave 46: the hook
> and the self-test are not programs of their own. Same lesson as the line below.
> It said **37 and 28** until 2026-09-01, and 37 matched no definition anybody could
> reconstruct — 35 counting `run-all.sh` itself, 34 without it. A count written by hand
> next to the thing it counts does not stay true; it just stops being checked.

Nothing here is a linter. Every one of these was written after something went wrong on a
real site, and each carries the case that produced it in its own header comment.

---

## Run everything

```bash
bash gates/run-all.sh
```

```bash
bash gates/run-all.sh --fast
```

`--fast` skips the fifteen slow batteries: the ones that need a browser, a host, or the network. On a clean
install the fast run is **1089 cases green, 0 red**, with the deploy-history bank reporting
`NOT MEASURED` because a fresh install has never deployed anything.

**The full run is a different number, and the file now says which run it came from.** On
a clean install it reads **1904 cases green, 0 red**, with **ten** banks reported as
`NOT MEASURED`: the eight that measure on a Linux host (`measure-screens`, `mobile-gate`,
`mobile-menu-gate`, `marca-gate`, `botones-gate`, `form-handler`, `banner-probe`, `consent-count`), the one that needs a client repository this public repository does not
ship (`compliance`), plus `extract-wordpress`, which needs a real `python3` (the Microsoft
Store shortcut on Windows does not count). (`qa-master` left that list on 2026-09-22 and
`structure-gate` later: see below.)

> **A machine with a measurement host reads more, and that is expected.** The eight host
> banks read the host from `gates/config/nav-host.local.conf` (copy the `.example`; it is
> gitignored, because a machine name has no place in a public repository). Where it
> exists they run, so on the machine these figures were taken from the full total is
> **2110**: 1904 plus 204 host cases plus the 2 of the deploy-history bank. `run-all.sh`
> counts all nine banks (the eight, plus deploy history) as *machine-dependent*, and the documentation gate accepts either
> figure.
>
> Until 21-sep-2026 those three banks looked for a placeholder host left behind when this
> repository was anonymised, so they reported `NOT MEASURED` **on every machine** —
> including the one that has the host. Nobody noticed because a declared hole is not a
> failure. Behind one of them sat a real red: the density bank looked for its moulds in a
> folder that stopped existing when the paths moved to English, and measured one phantom
> case called `[0-9]*`. It now counts the moulds before measuring them, and zero is a
> named failure.

> Until 28-aug-2026 those four exited `1` or `2` instead of `3`, so a run that had simply
> **failed to measure anything** was counted as four red banks — and the summary signed
> off with *"do not touch a website with the instrument in this state"*. Nothing was
> broken. A gate that forbids work over four declared holes is a gate somebody eventually
> switches off. They now exit `3`, on that path only: their real-failure `exit 1` is
> untouched, and the proof the fix is not a mute is that **the green count did not move** —
> 728 before and after, with red going 4 → 0 and `NOT MEASURED` 2 → 6. (728, not the 731
> above: the three D6 cases that prove this very fix were added afterwards.)
>
> The same day showed why the mode has to be recorded: `--fast` and a full run wrote very
> different totals into the *same* slot with no label, so the documentation gate compared
> the published fast-run figure against whichever run happened last — green after a fast
> run, red after a full one, with nobody having changed a line. `.ultima-bateria` now
> carries `modo: rapido|completo`.

**That number is a promise about a clean install, and the gate now knows it.** Once this
machine has deployed once, the deploy-history bank stops saying `NOT MEASURED` and starts
passing, so the total goes up: on the machine these numbers were taken from the fast run reads
1091, not 1089, because that machine has deployed. `run-all.sh`
therefore records two figures, `verde` and `verde-instalacion-limpia`, and the
documentation gate accepts either.

> The obvious fix was the wrong one. Raising the published number to 619 would have left
> the documentation gate **red for everyone who clones this repository and has never
> deployed** — a gate that demands the docs lie to other people in order to go quiet on
> your machine. When a check and a document disagree, ask which of them is making a
> promise about *your* machine and which about *any* machine.

Two more cases report `NOT MEASURED` out of the box, and both are deliberate. The
AI-crawler bank's redirect case needs a site of yours that redirects apex to `www` —
set `AI_CRAWLERS_REDIRECT_URL` and it runs; leave it unset and it says so rather than
passing. **This repository names no third-party domain**, for the same reason
`freeze-fixture.pl` exists: a bank that hardcodes somebody else's site exposes it and
sends it traffic every time a stranger runs the tests.

Read the last three lines. They are the only ones that matter — and note which run they
came from, because the two runs do not print the same total:

```
$ bash gates/run-all.sh --fast
  1089 casos en verde · 0 en rojo
  NO MEDIDOS: historial
```

```
$ bash gates/run-all.sh
  1904 casos en verde · 0 en rojo
  NO MEDIDOS: medir-pantallas gate-movil gate-menu gate-marca gate-botones conformidad historial form-handler banner-cookies contador-consentimiento
```

> **The very first run on a clean install also lists `doc-gate(skill)`**, whichever of the two
> it is. The documents publish the figures of both runs, and the case count of a bank that
> `--fast` skips; until both runs have happened on that machine, the documentation gate cannot
> tell a stale number from one nothing has measured yet, and it says `NO MEDIDO` instead of
> calling it stale. After the other run it drops off the list.

> **And a tenth time, on 2026-10-07 (1366 → 1386 on a full run, and 812 → 819 on `--fast`).**
> The quality gate, `qa-master.pl`, reused any download of its own it found in `--cache`,
> however old, and the improve-site path put that cache inside the repository, next to the
> BEFORE file. On one site it had been committed: a "production" measurement reported four FAILs at
> once, all of them about the site as it was seven weeks earlier. A download now carries its
> own date in a `.when` file and is reused only within the same run, or within
> `--cache-hours N`. Whatever is reused is declared in the header, in the JSON and by
> `qa-diff.pl`, and G11 in `receipt.pl` follows the same rule. Thirteen cases in
> `qa-master-tests/tests.sh` (371 → 384) and seven in `receipt-tests/tests-coverage.sh`; only
> the second bank runs on `--fast`. Which cases fail against the old programs, and why the
> rest do not, is in trap §88.

> **And a ninth time, the same day (1351 → 1366 on a full run; `--fast` still does not run
> the door's bank).** Step 2-ter of the door compares every page's words with what
> production serves, and until now it printed the losses and uploaded anyway. That day, on a
> site several sessions deploy, an upload from a branch cut *before* another session merged
> and uploaded its work put four of that session's pages, its sitemap and its `llms.txt` back
> to their previous version; the step said «5 con perdida» where the change touched one page,
> and G11 was green because it compares what is served with the receipt, not with what was
> there before. The history had 205 runs of the step since 26-aug: 58 with a loss (28%). So it
> is not a wall: a loss now **stops the upload before the line that uploads** unless it is
> declared with `--loses-text "the reason"`, which writes the pages, how many words and the
> reason into the history, like `--anyway`. Fifteen cases, ten of them seen red against the
> old door.

> **And an eighth time, the same day (1338 → 1351 on a full run; `--fast` does not run the
> door's bank, so it stays at 812).** Step 2-bis of the door said «La spec y el arbol NO
> cuadran» whenever the spec auditor did not exit `0` — and it exits `2` when it could not
> compare at all. Deploying a real site with no `_spec/`, the door said spec and tree
> disagreed, printed no detail (its filter ate the reason), and nothing had been compared. The
> receipt had it right (`SPEC sin veredicto (exit 2)`); the console did not. Now exit `2` reads
> `NO MEDIDO` with the auditor's own first line, any other code is named as such, and a site
> with no spec on purpose declares `SPEC_MODE=none` instead of asking every time for a
> comparison that cannot happen. Thirteen cases in the door's bank, eight of them seen red
> against the old door.

> **And a seventh time, the next morning (1324 → 1338, and 798 → 812 on `--fast`).** The table
> row of `gate-index.js` said «159 cases», and it was right; beside it, the same file quoted what
> that instrument prints («checks emitted 157», «with no rule claiming it 89») and nothing
> compared those — stale since the day they were written, at 158 and 90. D9 now compares what
> one instrument prints, and any bold «N cases» that sits in the same table row or list item as
> the file one bank runs, with the bank read from `run-all.sh`'s own list. Its first version cut
> blocks at blank lines only, so two list items naming two banks made one ambiguous block and
> the «371 cases» of `qa-master-tests/tests.sh` went unattributed: its fixture had no sibling
> item, the real file did. The index also printed a «62%» written into its own source, whatever
> the real figure was. And the documentation gate was **red on every fresh clone**: the documents
> quoted one of this machine's totals as a claim, and a figure from a run a machine had not made
> yet was called stale. Now every quoted total is a clean-install one, and a figure nothing has
> measured yet is `NO MEDIDO`. Fourteen cases, seen red first.

> **And a sixth time, the same night (1311 → 1324, and 785 → 798 on `--fast`).** The coverage
> figure had gone stale with nothing to catch it, so the documentation gate now compares it:
> `run-all.sh` records what `coverage.pl` prints — the total, its scope, each program's row — and
> D8 checks every coverage figure the three documents publish against that record. Its first run
> on the real documents found eight figures, five of them stale: besides the total, the scope
> quoted below the program table («88% … 4 programs of 28»), one program's row («25 of 25» where
> it measures 26) and the number of programs in three places («38», wrong the day it was written:
> there were 37 files, and one of them is a test battery). That last one came from `coverage.pl`
> itself, which still skipped test files by their names from before the rename to English. With
> no record to compare against, D8 says `NO MEDIDO` and the gate exits `3` — a warning would exit
> `0`, and `run-all.sh` reads only the exit code. Thirteen cases, seen red first, each red naming
> its own figure. And the battery line that printed the coverage discarded `coverage.pl`'s errors
> and filtered by two program names from before the rename: half of it had not printed for weeks.

> **And a fifth time, that night (1310 → 1311, and 784 → 785 on `--fast`).** The text-loss check
> (`same-text.pl`, step 2-ter of the door) printed its own separator encoded twice: «así x1 Â·
> trabajo x1». It writes UTF-8 but did not declare `use utf8`, so the `·` in its source was two
> bytes read as two letters and encoded again. The words, which come decoded from the pages, were
> fine — which is why no case saw it: none looked at the bytes of the output. One case now does,
> both ways (the separator once, an accented word once; the easy wrong fix, dropping the output
> layer, breaks the second half), seen red first. The fix changes nothing else: on two real pairs
> of trees the new output is the old one with each `Â·` replaced, byte for byte. `blocks.pl` had
> the same line and got the same fix; it has no bank, so it was compared before and after by hand.
> The coverage figure quoted above had also gone stale on its own (123 of 138): no gate compares it.

> **And a fourth time, later that evening (1297 → 1310, and 771 → 784 on `--fast`).** The Dutch run
> left two Spanish twins in plain sight: «Así trabajo hoy: …» and «De ahí salió una regla: …» mirror
> two paragraphs the gate blocks in English, and in Spanish they passed. Reading every Spanish
> paragraph on six sites (1417 of them) turned up two more holes of the same kind: `ese`/`esa` were
> missing from the demonstratives that count with a verb, and a `no` between the demonstrative and
> the verb hid it («Este no es un artículo…»). `así` now counts followed by any word except its
> connectors (`así que`, `así como`, `así pues`), and so do `de ahí` and `por eso`; the accented
> pronoun «él» stays out, because without accents it is the article. Thirteen cases — the six that
> must block seen red first, the seven that must not kept as guards — and the first real run, read
> finding by finding: six new blocks, all six genuine, none lost.

> **And a third time that evening (1280 → 1297, and 754 → 771 on `--fast`).** The citability
> gate (`citable.pl`) had no Dutch patterns, so a site with four `nl/` pages got all four reported
> `NOT MEASURED` — and two of their paragraphs carried exactly the defect it already caught in the
> English twins. Dutch is now measured, with one trap of its own: `het` is both the pronoun and the
> article of half the nouns, so it only counts with a verb after it, like `this` in English. The
> first real run, read paragraph by paragraph, found a third opener nobody had listed (`daar`, as
> in «Daar kwam een regel uit»). Seventeen cases, seen red first, and they count on any machine.
> The bank's «uncovered language» example moved to Italian, so the `NOT MEASURED` rule is still
> tested.

> **And again the same day (1277 → 1280).** A site with one home page per language (`/es/`,
> `/nl/`, each declared `tipo: home`) had its language homes measured on the root `index.html`:
> `audit-vs-spec` sent every `home` entity there, so a language home missing a section passed and
> its real page showed up as undeclared (`INV-01`). The type says which anatomy a page has; the slug
> says where it lives. Three cases in the `audit-vs-spec` battery, seen red first, and they count on
> any machine.

> **Why the full run moved on 2026-09-27 (1268 → 1277).** Two one-page sites failed four browser
> checks, and three of the four were the gates' ([trap §86](../docs/traps/86.md)): `ENLACES` asked for
> links to pages that do not exist, the `nosotros` variety floor sat above what the type's own
> template reaches, and `ANCHO-MIN` measured a band of figures as if it were cards. The structure
> battery gained nine cases (frontiers 7–9), and they count on any machine. The density battery
> gained three — a `<blockquote>` is now a stop, and two guards that it did not become an excuse —
> which count only where the measurement host runs, so a host machine reads 1331. The same pass
> fixed a defect a fresh clone would have hit: the structure battery composed its positive control
> into a folder git does not carry, and truncated a tracked fixture to zero bytes.

> **Why the full run moved on 2026-09-26 (1241 → 1268).** `qa-master`'s measurement lens
> learned to read the scripts a page loads from its own host, so it finds a container that
> lives in a first-party `consent.js` and checks the consent order by execution
> ([trap §85](../docs/traps/85.md), third round). The bank gained 26 cases, and one old case
> was rewritten into two because its `PASS` had been signed over zero pages. The fast run
> did not move: this bank is one of the slow ones.

> **Why the full run moved on 2026-09-22 (830 → 1139 on a clean install), and why
> `qa-master` is no longer in the NOT MEASURED list.**
>
> **First, +113: cases that already existed started running.** `qa-master` exited `3`
> without its frozen fixture, and it exited *early*: on line 260, after 18 cases. Everything
> below that line was skipped — including the five lens sections, EST-10/11/12, the deploy
> door, the fingerprint and the cache collision, which use only fixtures shipped in this
> repository. Each case is now classified **before** it runs, from its own arguments. That
> step ran 131 cases and named the other ~120 as unmeasurable **by anyone**: a capture of a
> client site that cannot be published, hosts anonymised to `*.example` (which never
> resolve), client repositories, and one site measured live (which fixes itself, and had
> already expired several of its own controls).
>
> **Then, +172: those ~120 now run against synthetic sites.** `qa-master-tests/fixtures-sites/`
> holds one invented site per host, written to reproduce exactly what its cases check, and
> `fake-production.pl` serves them as production through a local proxy — status codes,
> gzip, headers, each site's own 404. HTTPS is refused, so the bench never goes online, and
> its last block reads the server's log to prove no case asked for a host without a fixture.
> That step closed the bank at **303 OK · 0 MAL · 0 not measured, exit 0** on a clean clone.
> Each site was checked by breaking the property its cases detect and watching them go red.
>
> **Last, +24: gate fixes brought their own cases.** Building those sites found two defects
> in the gate itself, and fixing them exposed two more.
> The first: SEO-04 hashed the page *without comments* and the canonical target *raw*, so
> one HTML comment made a file differ from itself and a well-canonicalised variant was
> accused. The fix compares raw with raw, and ships two cases: the variant with a comment
> passes (red against the old gate), and a canonical to a *different* document is still
> accused (+2).
> The second: without `--contact` and without a URL naming a contact page, MEDICION looked
> for the form only in the FIRST URL of the list, so with the form on the home and the home
> listed second, MED-09/10/11 vanished from the report with no FAIL and no NOT MEASURED. It
> now searches the pages it read, in an order that does not come from the list, and says
> NOT MEASURED when none has a form, like the accessibility lens (+6: both orders give the
> same verdict, and the no-form site is NOT MEASURED; five of the six were red against the
> old gate).
> The third: the accessibility lens started from the FIRST URL of the list, not from the
> home, and named the home as the place even when the form came from another page; with a
> newsletter on the home and the lead form on the contact page, the two lenses judged two
> different forms in the same run. Both now take the page from one shared function, in
> that fixed order (+5: the same verdict in both orders, the right page named, and both
> lenses on the contact form; three were red against the old gate).
> The fourth: the SEO lens passed on ZERO pages read. A home that answers 404 with a body is
> not "no network", so with the home gone the lens skipped the page and signed fifteen
> PASS lines over nothing ("0 distinct documents"), exit 0. It now names the pages it could
> not read and, with none, is NOT MEASURED as a whole, like the accessibility and structure
> lenses; MED-01 stopped claiming "no measurement at all" without having read a page. A 404
> home does not switch the network off, on purpose: with the sitemap expanded, the other
> pages of that same site are read and their real failures still come out (+11, on a new
> synthetic site with no home; the six that fix something were red against the old gate).
> The bank now closes **327 OK · 0 MAL · 0 not measured, exit 0**.
>
> Running what had been hidden found three things wrong with the bench itself: the door
> block called a script renamed a month earlier (four cases at `exit 127`), ten cases had
> been passing for the wrong reason (a "must NOT contain" over an empty output, or a diff of
> two empty files), and one guard case exited `2` from the wrong guard. All three are fixed.
> The door block is also isolated from the machine's measuring host, the same way
> `receipt-tests/tests-door.sh` is: otherwise its local fixture would be sent to a real
> host over ssh, and still exit `0`.

> **Why the total moved from 795 to 810, and where the 15 came from.** The work is dated
> 2026-09-02 and reached `main` on **2026-09-16**; it sat on a rescue branch in between,
> which is a story told in that branch's commit. The fifteen are new, and they come in two
> halves of the same defect — a file that shipped to production without being sealed or
> checked. Measured bank by bank on 2026-09-16, before and after the merge:
>
> | bank | before | after |
> |---|---:|---:|
> | `receipt-base` — `SERVIDOS_PESE_A_EXCLUIR` | 68 | **76** |
> | `audit` — `S1.9` | 24 | **30** |
> | `gate-index` — the new rule now names an instrument | 158 | **159** |
>
> **Eight** in `receipt-base`, for `SERVIDOS_PESE_A_EXCLUIR`: the deployable tree now
> re-includes what a repo's `EXCLUIR` removes but the deploy actually uploads, so the file
> enters `ARBOL-HASH` and G11 asks for it. **Six** in `audit`, for `S1.9`: a hand-maintained
> machine file may not deny cookies, analytics or third parties while the tree ships a
> measurement loader. One of those six decided the granularity — a block-level check was
> measurably blind to an absolute sentence appended to an already-qualified bullet, which is
> the likeliest shape of the next drift — and another guards the false positive that showed
> up the first time it ran against a real site: a page inlining documentation *about* GTM is
> not a loader.
>
> ⚠️ **The branch's own note said seven in `audit` and did not mention `gate-index`. The
> measurement says six and one.** Both halves of that sentence were written by adding up
> cases somebody intended to write, not by running the banks. It is the reason this file
> asks for `run-all.sh` instead of arithmetic.
>
> **And 810 is not the number at the top of this file, because the same session added two
> more.** Merging that work meant reading the published counts, and the root README's was
> **85 cases stale and unwatched**: it published **593**, written in the English mirror of
> the Spanish wording, which is the one form none of D6's three patterns matched. The pair
> of cases that pins that wording took the full run to **812**. A gate that covers three
> documents and understands the language of two is worse than one that only claims two,
> because the third reads as watched.
>
> ⚠️ **And the first draft of this very paragraph turned the gate red**, because it quoted
> the stale figure next to the words that make the pattern. The text that explains a
> signature contains the signature. Written apart on purpose, not softened.

> **Why the total moved from 736 to 779 across 2026-09-01 and 02, and where the 43 came from.**
> **31 are genuinely new** — 15 for the metadata checks below, 18 for the `roles` bank that
> guards the role vocabulary and the per-type reference sheets. The other **ten already
> existed and were being thrown away**: the runner did `continue` the moment a bank returned
> 3, without reading its count,
> so a partially-measurable bank contributed **zero** greens. The same bank *failing* returns
> 1, falls through to the counting block, and its greens **were** counted — measured that day
> on `qa-master`: all green → 0 counted (total 736); one case red → 14 counted (total 750).
> **Fixing a failure made the green total drop.** A count that rewards red is not a count.
> A partial bank now contributes what it measured **and** is still listed as not measured:
> two different facts, both true. Only `qa-master` (15) and `structure-gate` (10) had
> anything to contribute; the other four measure nothing at all without their host.
>
> **And the last six are a battery that was running all along and counting for nothing.**
> `battery-layout` — collisions, AA contrast on every mould, the seven compositions at 1440 and
> at 390 — reported `0 casos`. Not because it was empty: the runner reads the **last** `n OK` in
> a bank's output, and the last one here belonged to **a column of widths** in the composition
> table (`0  OK` = 0 px of overflow). A layout measurement was being read as a case count, so an
> entire battery was invisible to the total and could only ever be noticed by going red. It now
> prints its own `OK n · MAL n`. **The separator is not decoration:** written with a space, the
> reader matches `[0-9]+ +MAL` against `6 MAL` and reports six passes as six failures — which is
> exactly what it did on the first attempt.


**`NOT MEASURED` is not a pass**, and the runner lists those banks by name in the summary
precisely so a hole cannot be silent. The exit codes are three-valued throughout:

| Code | Meaning |
|---|---|
| `0` | measured, and correct |
| `1` | measured, and wrong |
| `3` | **not measured** — say so, do not guess |

A `1` where a `3` belongs sends somebody hunting a defect that does not exist. A `0` where
a `3` belongs is worse: it lets a gap read as coverage.


### Coverage is two questions, and only one of them was being asked

`gate-index.js` has always answered *"does this rule name a check that exists?"* — 257 rules,
**162 with an instrument (63%)**, the other 95 listed with `--huecos` and split into
machine-measurable, partial, and human judgement. That half is well kept: the gaps are counted,
not hidden, and the report refuses to claim a ceiling of 100% because the standard itself marks
rules no machine will ever measure.

**It never asked the reverse: does this check that RUNS have a rule behind it?**

```
  checks emitted .......... 161
  with no rule claiming it .. 93   (58%)
```

**That is not a tidiness complaint.** A gate nobody's rule asked for is an opinion with
permission to block, and the defect is invisible from the side that *was* being measured — the
percentage above counts rules-with-gates, so a check with no rule cannot lower it. It is how `audit.sh` spent
months checking `AGENTS.md` while the standard described that file nowhere (`03-content-and-seo
§5.2`), and it is how three checks added this week arrived without anyone deciding they were
rules.

Most of them are two whole instruments the catalogue never represented: the **~35 site-auditor
checks** (`S1.x`–`S6.x`) and the **linking rules** (`R0`–`R9`).

⚠️ **An orphan is not automatically wrong.** `EST-12b…f` are sub-checks of `EST-12`, and naming
the parent is enough. That is exactly why this **reports and does not block**: the number gets
looked at, decided case by case, and only then does the bar go up. What it cannot do any more is
stay invisible — it prints without a flag, because a figure you have to ask for is a figure
nobody reads.

### The runner checks itself first

Before running anything it verifies that **every bank names a file that exists**. Two of
them did not, for weeks, and nobody noticed: both were marked slow, `--fast` never reached
them, and the fast run is the number anybody actually reads. A bank whose path is wrong
does not fail — it is never attempted, and the summary says "all green" over it.

It also takes a census of battery directories and refuses to stay quiet if it finds
**nothing to look at**. That guard went mute once by being renamed — its globs said
`*-pruebas` while the directories had become `*-tests`, so it matched zero of thirteen and
kept printing nothing, which reads exactly like "nothing is unwired". Zero findings and
zero subjects print identically; only one of them is good news.

---

## The two moments that are not optional

```bash
perl gates/qa-master.pl <URL> --repo DIR --candidate
```

```bash
bash gates/deploy.sh <REPO> --upload
```

The first measures the tree you are about to publish and writes `<REPO>/.qa-recibo`. The
second is the door: it refuses to reach the upload line without a valid receipt, and after
uploading it verifies that **what is served is what was measured**. Neither substitutes for
the other — without `--candidate` you measure production, and the receipt then seals a tree
whose verdict came from measuring a different object. **Since 2026-11-05 a production run
never overwrites a candidate receipt**: it says so and writes nothing (`--receipt FILE` keeps
it elsewhere). One site measured its production with `--repo` to count what already failed
there, and its candidate receipt was replaced by one the door would have accepted.

**Between the two, the door measures the candidate in a real browser (step 1-quater, since
2026-11-01).** It copies the tree to the measuring host and runs the gates there, through
`run-gate.js` in candidate mode:

- `structure-gate.js` at 1298. Since 2026-11-06 it also measures the contrast of the header,
  the breadcrumb and the footer, which it used to leave out with everything outside `<main>`
  (a breadcrumb at 3.6:1 on four pages of a shop, seen by nobody). That part **only warns**,
  as an `aviso:` line under the gate's verdict, until `deploy.conf` says `CROMO_GATE=para`;
  the door then passes `"cromo":"para"` to the gate and it is a failure like any other;
- `measure-screens.js` at 1298 and 390;
- `mobile-gate.js` at 360, 390, 1366 and 1440;
- `mobile-menu-gate.js` at 390;
- `marca-gate.js` at 1366 and 390 (since 2026-11-01). It **only warns** until the site's
  `deploy.conf` says `MARCA_GATE=para`, which the site sets once its brand file
  (`_diseno/MARCA.md`) is done: a door that stopped every site on day one, for something none of
  them had, would teach everyone to step around it.
- `botones-gate.js` at 1366 and 390 (since 2026-11-06), and then `botones-sitio.js` over all of
  its readings together, so a button that is coherent on each page and not across them is seen.
  It **only warns** until `deploy.conf` says `BOTONES_GATE=para`; `BOTONES_FAMILIAS` names the
  site's button families. Measured that day on ten home pages, three sites had one button class
  with two shapes (a smaller header call to action, a form button in another size or in Arial).

They run on every page in `URLS_NAVEGADOR` (`/` if none). And once per upload, on the home page:

- `banner-probe.js` at 1298 and 390 (since 2026-11-06), on the same tree, served by the same
  function as the gates (`servir` in `run-gate.js`). Before, it measured only what was
  online, so a change to the banner or to the footer that lost the way to reopen it was seen
  after the upload. It says how much it served from the tree; with 0 it is NOT MEASURED, never
  a pass. It **only warns** until `deploy.conf` says `BANNER_GATE=para`, and until then its
  NOT MEASURED (a consent platform inside an iframe, for one) is not a hole.

- **A FAIL stops `--upload`.** It goes through only with an `--anyway` that **names every red
  gate**.
- The door **rejects a reason that says the browser will answer** when the browser has just
  said FAIL, or has measured nothing.
- A site that declares `URLS_NAVEGADOR` and could not be measured also stops, unless the reason
  says "browser"/"navegador".
- `NO_BROWSER=1` stays a declared hole, as before.

Three `deploy.conf` keys tune it:

- `HOSTS_RESERVA` (or `BOOKING_HOSTS`): the booking platforms the site books on, besides the
  ones the gates already know. See `blueprint/20-external-booking.md`.
- `ECOMMERCE=1`: a shop. The first screen does not have to carry a contact.
- `NAV_PARALELO`: measurements at a time. The default is 3.

The step after the upload (6) still measures what the host actually serves, and records it
without blocking. Why the order changed is trap §89.

**Thirty-four more since 2026-11-05**, all from one week of real deploys:

- **A configurator page is not "0 CTA" (`measure-screens.js`).** A shop's made-to-measure
  page paints its steps with JavaScript as `<button class="choice">`: six choice buttons on
  the first screen and "only 0 CTA" here and in the design score, while `qa-master` already
  exempted it (EST-06b, the one declared exception of the final QA). The gate now counts
  the same visible buttons `qa-master` counts, minus the toggles its CTA selector leaves out
  on purpose (`aria-expanded`, `role=tab`, submit). With three or more and fewer than two
  CTAs, the two-CTA minimum does not apply and `reglasDeCTA` says why; the stretch without a
  CTA still counts. The mirrors: the same buttons as an accordion or as tabs still FAIL.
- **EST-06 judges page length with the door's rule (`measure-screens.js`).** On
  2026-08-19 `measure-screens.js` replaced the flat 6 screens with a word budget (6 + one
  screen per 80 visible words past 400, capped at 12); `qa-master` kept the 6. A home page
  measured at 390 with 8.1 screens and a door limit of 10.5 was a FAIL in the receipt and
  a PASS at the door. The snippet now copies `measure-screens.js`'s limit, its screens and
  its visible words, and EST-06 says which limit it used. A snapshot taken with an older
  snippet carries no limit: it is still judged against 6, and the line asks for a
  recapture.
- **An old FAIL that production already has does not stop an upload (`d057.pl`, D-057).**
  Five sites were stopped by FAILs their upload did not touch and the published site had
  the same, each with its dated row in the plan. `--anyway` is for what nobody looked at,
  `accepted.conf` for the client's decisions, so the rule that let old ones through was
  checked by the memory of the chat that uploaded. Now `qa-master` writes every FAIL and
  NOT VERIFIED into the receipt, under the seal, instance by instance, with how to measure
  production again (`QA-REPETIR`) and its own md5. When step 1 finds a receipt valid in
  everything but its verdict, the door runs `d057.pl`: it measures production now with
  the same `qa-master` and lets a finding through only if production has the same check
  in the same state with every candidate instance in it (fewer is fine: that is a tree
  that fixes part of it), and an open row in `_seo/BASE.md`, `_seo/plan*.md` or
  `_diseno/PLAN.md` names it with a date from today on and an owner. Not covered: the
  measurement lens, cookies and consent, and what is never acceptable. A site with no
  GA4 and no Ads by decision declares `NO_GA4_OR_ADS="reason"` and MED-13 is NOT
  APPLICABLE, after checking the tree carries no tag. What came from the browser snapshot
  (EST-05/06/07, REN-11) is compared only with production's own snapshot
  (`D057_PRODUCTION_DOM`: same page, width and height, under 12 hours old). Production
  that does not answer, another `qa-master` or an older receipt is NOT MEASURED, never
  "old" and never "new". Each finding let through is written to the history and the
  closing line signed "D-057", with how many production FAILs the upload removes.
- **The same rule for the browser gates of step 1-quater (`d057.pl --browser`).** A
  five-line change to the `<head>` of 89 pages passed step 1-D057 and was stopped by step
  1-quater: 5 FAILs of `structure-gate` and `mobile-gate` on 4 pages, all five the same on
  the published site and each with its dated row. D-057 only covered `qa-master`, so the
  browser was left with `--anyway`, which is not the uploading chat's to use. Now every
  FAIL of step 1-quater is measured again on production with the same gate, route, width,
  height and configuration, and `d057.pl --browser` lets it through only if production
  measured for real (the width asked for, the page and not a wall, not the candidate
  served), every candidate failure is in production with a number no higher (5 where
  production has 3 is 2 new; production in PASS is all new), and an open row with a date
  and an owner names the gate **and** the page: its whole route (`/a/` is not `/a/b/` nor
  `/es/a/`), its last segment standing alone (a row for a group of guides), or, for the
  home page, "`/`". A gate leaves the red list only when all of its FAILs pass; the
  history and the closing line name each one. The cookie banner probe is not covered:
  consent is a lens D-057 does not cover.
- **What the server answers to the AI bots (`ai-crawlers.pl --probe`, step 6-bis).** A
  shared host's CDN gave 429 with no `Retry-After` to the GPTBot signature on 7 of 10
  sites whose `robots.txt` let it in, and step 2-sexies said PASS on all 7: it reads the
  tree's `robots.txt`, not the server. The probe asks for `robots.txt` and the page with
  each bot's signature and Chrome's; bots that search, cite or train and receive
  something else are a warning, a 403 to a spoofed Googlebot or bingbot is expected, and
  Chrome not getting in is NOT MEASURED. After every upload, one line in the output and
  the history; it never stops anything.
- **A door for writing inside a live WordPress (`wp-door.sh`).** Options, redirections,
  mu-plugins and posts were written by hand, each batch with its own backup and undo
  written from scratch, and the upload door never saw them. A batch is now a committed
  folder, `_deploy/wp/<batch>/`, whose `tanda.sh` has three modes (`--medir` reads only,
  no flag writes, `--volver` undoes), plus an approval file outside it that names the
  folder's git tree. The door refuses an unapproved or changed tree, takes a lock on the
  host, uploads the committed tree to a temp folder (never a docroot) and measures before.
  With `--escribir` it applies, **proves the undo** (undo, measure: it must give the
  before, line by line), applies again and measures: a red that was not there before, or
  more reds than `ROJOS_DESPUES`, undoes it and says VUELTO or VUELTA-INCOMPLETA. One row
  per run in `_deploy/wp/historial.tsv`. Its bench runs on a fake host.

- **Upload lock (step 3-ter-0).** Two sessions holding permission for the same upload ran
  it twice, 11 seconds apart. The door now records each upload of a site in
  `~/.qa-receipts/subidas/` (or `QA_RECIBOS_DIR`). If **another** session uploaded the same
  site less than 15 minutes ago (`CERROJO_MIN`), it stops; `--again "reason"` goes through
  and the reason is recorded. The same session may repeat. The lock is written after the
  seal check and right before the uploader runs. Limit, declared: it only sees uploads
  made from this machine.
- **The pages this upload adds or changes must be served (step 4-0).** G11 exits 0 when
  files are *not found* (its route-to-URL mapping can be wrong on a whole site), and one
  deploy closed with "verified" while its two **new** pages answered 404. G11 now writes
  its full not-found list, with codes, to `G11_NO_HALLADOS`; the door crosses it with every
  page the upload adds or changes. A 404 or 410 there is a FAIL (exit 1, and the deployed
  list is not saved, so the next upload measures them again). Refused, unreachable or
  beyond G11's 400-file cap is NOT MEASURED.
- **One closing line (CIERRE), at the very end.** It says FAIL (linking or the browser on
  the served site in red), NOT MEASURED (the browser did not run, left a measurement
  blank, missed changed pages over its cap, linking could not crawl, or G11 could not
  look), or PASS. The word "verified" no longer appears about an upload. The exit code
  does not change: what is uploaded is uploaded.
- **The whole receipt again, right before the upload (step 3-ter).** Mid-door, another
  `qa-master` run on a different commit rewrote the receipt with a FAIL; the door only
  compared the tree with that new receipt (it matched: it was that receipt's tree) and
  uploaded a tree the reviewer had sent back. Now the receipt must be the same one step 1
  let through (its `SELLO`), and it is verified in full again, as in step 1: verdict, age,
  tree and seal.
- **A door that really stops, and says whether it uploaded (`--stop` / `--parar`).** On
  Windows, stopping the command that launched the door does not stop the door: its
  children went on and uploaded 13 minutes after the session wrote "stopped, production
  unchanged". While it runs, the door records who it is and where it is (`MEASURING`,
  `UPLOADING`, `UPLOADED`) next to the lock. `deploy.sh REPO --stop "reason"` leaves a stop
  order for that door and tells the truth: it had not uploaded and will not (0), it is
  uploading or already uploaded (3), or there was no door running (4, with this
  machine's last upload of the site). Right before the uploader the door checks for a stop
  order and whether the command that launched it is still alive: an orphaned door does not
  upload. Limits, declared: `--stop` kills nothing (an uploader cut halfway leaves a
  half-written docroot), so the door finishes the long step it is in and stops at the
  upload; and a door launched by a process outside this shell cannot be checked for
  orphanhood.
- **A form that goes step by step is measured step by step (`forms-gate.js`, `data-pasos`).**
  A quiz hides the steps that are not on screen yet, on purpose, so measured on load its
  required fields and its submit button "could not be seen": six forms of one site in a
  false F8 and F5 while the real submission worked. Declared with `data-pasos` on the
  `<form>` (a `[data-paso]` or a `<fieldset>` per step), the gate shows each step in turn,
  measures it and puts everything back; the real defects still fail (a shown step hiding a
  required field, a last step without the button), and so does the same quiz undeclared.
  `qa-master` MED-05 accepts that declaration and its two siblings (`data-envio-js`,
  `data-guarda-doble`) as gate vocabulary, by exact name: a near name (`data-envio`) is
  still an orphan.
- **MED-09 hears a retention period in English.** None of the trigger words was English,
  so "we keep them for 12 months" came out "no retention period".
- **SEO-13 does not ask the root for breadcrumbs, whatever type it declares.** A home that
  declares `data-tipo="nosotros"` or `"hub"` was asked for a `BreadcrumbList` it cannot
  have, since nothing sits above it. The exemption goes by the path; the same page at
  `/sobre/` still warns.
- **The consent counter keeps one row per day, with three totals (`consent-count.php`).**
  It wrote one line per choice, in arrival order. The host's access log keeps the IP and
  the time of every POST to the counter, in the same order, so line N was request N: the
  two files together said which IP chose what, though the counter stored no time. Now it
  keeps «date · accept · reject · partial», one row per day, rewritten under a lock; a file
  in the old format is folded into totals on the next choice. The bench sends twenty
  choices at once and loses none; against the old counter, eight of its cases go red.
  Each site copies the new `consent-count.php` to its `_deploy/` again.
- **MED-03 reads the triggers GTM reads.** A custom-event trigger set to "use regex
  matching" does not write the event name between quotes: it writes a pattern in a
  predicate on `{{Event}}`. A site whose container listened to its quote event through
  such a pattern was a FAIL. MED-03 now reads the predicates on the Event macro and
  applies each as GTM does (`_eq`, `_re`, `_cn`, `_sw`, `_ew`; a negated one does not
  count). A quoted mention elsewhere (a tag's settings, a URL predicate) no longer
  passes. If the patterns cannot be read, a name not written in the container is NOT
  VERIFIED, not "not listened". A name the container sends itself from another trigger
  (a GA4 tag with that `vtp_eventName`) is a WARN: it reaches GA4, and what the page
  pushes under that name nobody hears.
- **MED-03 reads `event:` without quotes, and names what it cannot read.**
  `dataLayer.push({ event: "x" })` was not read, so sites pushing three named events
  "emitted no named event" and were never crossed with their container. It is read now,
  only inside a `.push({ ... })`: a library's `{ event: ... }` is not a dataLayer event. A
  name the JS builds (`"cm_" + name`) is counted and named in the verdict, never crossed
  as its quoted fragment; when that is all a site emits, the WARN says so instead of "no
  named event".
- **REN-05's fingerprint is what was decided, not how it was measured (`CLAVE=`).** Its
  data line carries how many pages were measured, which came out worst and the exact KB,
  so the same site under the same decision gave three fingerprints with 1, 3 and 40
  pages. One of our sites needed two acceptances for one decision, and D-057, which
  compares instances, could never call an old REN-05 old: a candidate never weighs what
  production weighs. A check may now declare a `clave`, and that is its fingerprint.
  REN-05's is the hosts of the third-party resources that weigh (not every quoted URL:
  a WhatsApp link weighs nothing and came and went with the sample), the threshold it
  crosses and the weight in 100 KB tiers. One more host, or the next tier, fingerprints
  differently. An entry signed with the old `DATO= DONDE=` keeps matching while those
  hold. `config/accepted.conf.example` now names the labels as the report prints them.
- **The bench's acceptances are dated today.** The acceptance block wrote a fixed
  2026-08-11 with no expiry, and an acceptance lasts 90 days: four of its cases would have
  failed together on 2026-11-10 with nothing changed in the gate.
- **A form's privacy checkbox is not the cookie banner (`banner-probe.js`).** The probe
  took the first block, in document order, whose name says cookies or consent and whose
  text says cookies or privacy. A contact form's "I accept the privacy policy" row comes
  before the banner, which is painted at the end of the body: B2 FAIL on one of our
  contact pages, with its banner fine. Now the block with an Accept or Reject button wins;
  with none, the first one not inside a form; and when every one is inside a form there is
  no banner, so a page that measures is a B1 FAIL. The bench puts the checkbox before a
  full banner (red against the old probe), before a banner without Reject (still FAIL) and
  on a page with no banner (red against the old probe).
- **A form row is not a grid of cards (`structure-gate.js`, ANCHO-MIN).** Two fields side
  by side passed for two cards: the text of a field with a `<select>` carries all its
  options, and that reaches the 20 characters a card needs. A 704 px form was a "section
  WITH GRID" too narrow for the site, and the same form passed on another page only
  because its options were shorter. A cell that is a form control or holds one, and has
  no heading, is a field and not a cell. Its mirror: cards with a heading and an input,
  squeezed into 510 px, still FAIL.
- **The anatomy bench removes its whole temp root.** It removed only the copied gates and
  left its copy of `blueprint/09-page-types.md` behind, ignored by git, where a site
  generator reading this repository's disk published it as documentation.
- **A sitemap index is not a list of pages (`crawl-links.pl`).** A hosted shop serves a
  `<sitemapindex>` at `/sitemap.xml`, whose `<loc>` entries are other sitemaps. They were read
  as pages, and R2 called them unreachable and R4 orphaned. Each child is read now (one level,
  up to 50), and a child that cannot be read is counted: R2 is NOT VERIFIED until it is.
- **A link that redirects out of the site has no canonical of ours (`linking-gate.pl`, R7).**
  The shop's account icon goes to `/account`, which sends a visitor to the platform's sign-in on
  another host: R7 failed on every page. It is a named WARNING now; a redirect inside the site,
  `www.` or not, still FAILs, and wins when both are there.
- **The `ficha` of a program or an agent carries `SoftwareApplication` (`page-types.tsv`, PT-03).**
  PT-03 asked every `ficha` for `Product` or `ProductGroup`, and seven pages presenting agents
  and programs failed with the markup that describes them. `SoftwareApplication` and its
  subtypes count now; a `ficha` with only a `Service` still fails, because a service is a
  `servicio`.
- **A site with GA4 and no Ads campaign can close MED-13 (`qa-master.pl`, MED-13).** MED-13
  asked for a conversion in the Ads interface, which such a site never has: three sites had no
  honest way to sign it. `NO_ADS="reason"` in `deploy.conf` makes it measured in GA4 (the lead
  event is a key event and has been seen arriving), signed with the DATO the report prints. The
  tree is checked: an `AW-` id, `googleadservices.com` or `googleads.g.doubleclick.net` outside a
  comment makes it a FAIL. And a signature made on a DATO no longer counts for a check that
  carries none today, so the day the line is removed the GA4 signature stops counting by itself.
- **The cookie banner is measured before the upload (`banner-probe.js`, step 1-quater).** It
  only measured what was online, so a change that lost the way to reopen the banner was seen
  after the upload. It now runs on the candidate's home page at 1298 and 390, served by the same
  function as the other gates, and only warns until `BANNER_GATE=para`. No probe counts as a
  visit any more (the consent counter and GA4 hits are aborted, and counted), and a menu that
  "does not open" on a loaded host is measured once more, with the load next to it.
- **The home page of a language needs no breadcrumb (`linking-gate.pl`, R6).** `/es/` is one
  click from the root, so a site in two languages warned on every upload. A one-segment page
  that is an hreflang version of the root is left out; an inner page of the language still warns.
- **`d057.pl` stops filling the door's output, and reads the owner where it is written.** A row
  of a table outside `_seo/BASE.md` printed a Perl warning per row; and "espera X" anywhere in
  the Estado cell made an owner of "espera la". Only at the start of the cell now.
- **One visible variant price is enough for a `ProductGroup` (`page-type-gate.pl`, PT-06).** A
  shop whose variants carry their own URL and price shows the selected one; PT-06 asked for all
  of them on one page. A group with none visible still fails, and a plain `Product` is still
  checked offer by offer.
- **Four false findings on a hosted shop theme (`qa-master.pl`).** A 200 with an HTML page on
  `/.env` or `/.git/HEAD` is the host's catch-all page, not the file (MED-12); `data-tipo` takes
  the types and aliases of `page-types.tsv`, and a type with no anatomy says so (EST-02d, the new
  EST-02e); Portuguese number words count as a deadline (MED-09); a `data-*` read through a
  constant counts as read (MED-05).
- **Contrast over a CSS gradient is measured, and compared unrounded (`structure-gate.js`).** A
  gradient counted as a photo: a white-on-green lead button at 2.1:1 went through the door. The
  gate now reads the colour under the text on the gradient line, and 4.495 no longer prints 4.50
  and passes.
- **The header, the breadcrumb and the footer are measured too, opacity included
  (`structure-gate.js`, `deploy.sh`).** Nothing measured text outside `<main>`, and the gate
  ignored opacity: a breadcrumb read 13.9:1 where the eye sees 3.6:1. The chrome is measured
  with the same rule, apart from the verdict; the door prints it as an `aviso:` line, and it
  stops the upload once `CROMO_GATE=para`.
- **A legal page is prose, not a page without roles (`qa-master.pl`, EST-02f).** `anatomy.tsv`
  gives legal and 404 no roles, and EST-02 counted a legal page without `data-sec` as undeclared,
  so no site with legal pages could close it; marked with a role to get out, EST-02c called it
  complete. Neither counts them now, and EST-02f says how many. A type with no anatomy and no
  `data-sec` is out of EST-02 too (EST-02e names it); a service page without it is still NOT
  VERIFIED.

---

## What each program is for

### The two that gate a deploy

| Program | What it does |
|---|---|
| `qa-master.pl` | The master gate. Five lenses over a page or a tree, and it writes the receipt. |
| `deploy.sh` | The door. No valid receipt, no upload. Before the upload line it runs the browser gates on the candidate (step 1-quater) and a FAIL stops it, and it will not repeat another session's upload of the same site within 15 minutes; after, it checks what is served, page by page for the pages it added or changed, and closes with one line: PASS, FAIL or NOT MEASURED. |
| `receipt.pl` | Writes, verifies and records receipts; owns the deploy history. |
| `d057.pl` | The door's question for a red receipt of the CANDIDATE: is each FAIL and NOT VERIFIED old (the same in production, measured now with the same `qa-master`, instance by instance) and does a dated row with an owner fix it? PASS, STOP or NOT MEASURED, finding by finding, signed "D-057" (since 2026-11-06). With `--browser`, the same question for each FAIL of the browser gates in step 1-quater, against the same measurement on production. |
| `redirects-gate.pl` | The gate of a tree that only redirects: a retired domain whose docroot is a `robots.txt` and an `.htaccess` sending every mapped path to its new page and everything else to the home page, with 301. `--candidate` simulates the rules in order (RED-01..08: every WordPress and PHP path ends in a redirect, nothing it lets through is outside the tree, no rule is shadowed, the last one is an unconditional catch-all), asks every target for a 200 (RED-09) and writes a receipt of `TIPO: REDIRECCIONES` whose five page lenses read `NO APLICA`. `--served` asks the domain itself (RED-10); the door runs it after the upload (step 4-ter) and a wrong answer stops it. Declared with `ARBOL=redirecciones` (`TREE=redirects`) in `deploy.conf`. Fail-closed: `RewriteCond`, mod_alias and internal rewrites are failures, not warnings. |
| `wp-door.sh` | The door for writing INSIDE a live WordPress, which is not an upload: a committed batch (`_deploy/wp/<batch>/tanda.sh`, `--medir` · write · `--volver`) approved by its git tree in `_deploy/wp/<batch>.aprobado`. Dry run by default; `--escribir` measures before, applies, proves the undo, applies again and undoes it all if a new red appears; `--volver` undoes the last one without an approval. Lock on the host, one row per run in `_deploy/wp/historial.tsv`, a closing line: PASS, FAIL or NOT MEASURED. Reads `WP_HOST` and `WP_TMP` from `deploy.conf`. |

### Structure, layout and type

| Program | What it does |
|---|---|
| `structure-gate.js` | Is this laid out, or is it a wall of prose wearing a stylesheet? |
| `mobile-gate.js` | An action that **converts** whole on the first screen at 360, 390, 1366 and 1440 (a form, a phone, a message app, a booking platform, a contact path of the same site), and calls to action nothing covers. |
| `mobile-menu-gate.js` | The mobile menu at 390: the menu fits in one row or sits behind a button with `aria-expanded` that opens it; closed, its links are out of the Tab order; open, Tab never sends the focus to a page element the menu covers or that is off screen (WCAG 2.4.11), and Escape closes it when it is modal (`role=dialog`, a scroll lock, an inert page, or 60 % of the screen covered; a warning otherwise). Measures the menu half of `A11Y-13`, not the rest. |
| `marca-gate.js` | The brand, whole and alone: a logo in the header (a mark made of text and CSS warns), a tab icon in SVG and in PNG or ICO of 32 px or more, an `apple-touch-icon`, a manifest naming 192 and 512, all of them **loading**, `theme-color`, and no colour or typeface outside the site's brand file (`_diseno/MARCA.md`: the `#hex` under «## Colores», the backticked names under «## Tipos»). Without that file the two palette rules say `NOT MEASURED`. The social image is not measured here: S2.9, SEO-06 and SEO-08 already do. |
| `botones-gate.js` | One button, one look, on the page: the same group (its family from `BOTONES_FAMILIAS`, or its classes) keeps one **shape** everywhere (size, weight, typeface, case, radius, border, padding, with 1 px of size and 2 of padding as tolerance) and one **paint** on the same background (fill, text and border colour; the inverted button of a dark band is the same button). A button of one line keeps its height. With families, a button of none warns. Not hover, not focus. |
| `botones-sitio.js` | The same comparison (`compara`, exported by the gate: one copy of the rule) over the readings of several pages, by width; it reports only what appears when they are put together, and a reading that is not valid is named and left out. |
| `botones-barrido.sh` | Every page of the served sitemap (40 by default) through both, at 1366 and 390: the monthly design pass. |
| `measure-screens.js` | Density: how much page per screen, measured against the moulds. |
| `anatomy.pl` | One table of page anatomies, three consumers, and they must agree. |
| `roles.pl` | The role vocabulary (`roles.tsv` = 09 §1), and it generates one reference sheet per page type into `blueprint/moulds/types/`. `--gate` re-derives all thirteen and fails on any difference, so a sheet edited by hand does not survive a battery. |
| `fold-page-standard.js` | Folds the page standard into the rules the gates read. |
| `blocks.pl` | The layout primitives a page is actually built from. |
| `measure-contrast-on-photo.py` | Contrast of text sitting on an image, which no DOM query can answer. |

### Links, content and SEO

| Program | What it does |
|---|---|
| `crawl-links.pl` | Crawls the tree: orphans, breadcrumbs, dead ends. |
| `linking-gate.pl` | Internal linking, judged against what the site actually contains. |
| `same-text.pl` | Whether re-laying-out a page lost any of the client's words. Compares the *visible text* of two trees, page by page, by words rather than lines — the layout is meant to change, the content is not. Takes two directories: `same-text.pl <tree-before> <tree-after>`. The door runs it against what production serves, and since 2026-09-28 a page that loses words **stops the upload** unless it is declared with `deploy.sh --loses-text "the reason"`. |
| `qa-diff.pl` | What changed between two runs, by rule. |
| `ai-crawlers.pl` | Whether AI answer engines are allowed to crawl at all. Parses robots.txt properly: own-agent groups do not inherit `*`, longest path wins, empty `Disallow` allows. With `--probe`, also what the server answers to each bot's signature (the door's step 6-bis, a warning). |
| `cannibalization.pl` | Two pages fighting over one term. `--audit` finds existing exact H1/title collisions; `--keyword` gives NEW / UPDATE / CANNIBALIZES before a piece is written. |
| `page-type-gate.pl` | The markup of a page judged by its TYPE (`page-types.tsv`, 22 types): every block parses, every type and property exists in schema.org (`schemaorg-vocab.tsv`, generated from its release), what the type must carry and must not carry loose, the markup against the visible page (FAQ, price, product name, headline), `potentialAction` and the search string (`{q}` = `name=q`), and with `--sondear` whether the search answers a results page. Indexing by type. `blueprint/21-page-types-markup.md`. |
| `citable.pl` | Whether a paragraph survives being lifted out of the page. Six mechanical checks from citation-ready-check. Refuses to score a language it has no patterns for. |

### Forms

| Program | What it does |
|---|---|
| `forms-gate.js` | The form in the DOM: labels, consent, a real submit button, a visible honeypot. |
| `form-handler.php` | The reference handler the gate is written against. |
| `banner-probe.js` | The cookie banner as a first-time visitor meets it, on the measurement host: nothing tracks before the choice, Accept and Reject in the first layer with the same weight, no wall, the page's language, Reject really rejects and is remembered, and a way to reopen it outside the banner. It never clicks Accept. With `GATE_CANDIDATO` it measures a tree, as the door does. Outside its fixtures it aborts the banner's counter (`/consent-count.php`) and GA4's `collect` hits, so a probe that rejects is not counted as a visitor who did (2026-11-05: the first site with a counter). Bench: `banner-probe-tests/`, in its own folder on the host with this tree's `run-gate.js`. |
| `consent-count.php` | The anonymous accept/reject counter the banner calls with `sendBeacon`: one row per day with three totals, «date TAB accept TAB reject TAB partial», rewritten under a lock (one line per choice could be matched to the access log by its order), no cookie, no IP, no time of day, outside the docroot. Copied to `_deploy/` of each site. Bench: `consent-count-tests/` (on the measurement host). |

### Migration

| Program | What it does |
|---|---|
| `audit-vs-source.sh` | The new tree against the old one: what got lost. |
| `audit-vs-source-wordpress.py` | The same, when the source was WordPress. |
| `extract-wordpress.py` | Pulls content out of a WordPress export and counts it against the source: anything that does not add up exits 1. Its bench, `extract-wordpress-tests/tests.sh`, needs python3. |
| `audit-source.sh` | Reads the source repository before anything is touched. |
| `to-webp.sh` | Image conversion, with the sizes recorded. |

### The gates that watch the gates

| Program | What it does |
|---|---|
| `doc-gate.pl` | Every program, flag and id the documentation cites must exist — and every count it publishes of the battery (D6), of the coverage (D8) and of one instrument or one bank (D9) must be the last one measured. |
| `coverage.pl` | How many checks have a test case. Today: **149 of 156 (95%)**. |
| `gate-index.js` | The RULE → INSTRUMENT index, **and since 2026-09-02 the reverse**: which checks run that no rule claims. **162 cases.** See below. |
| `rule-instrument-index.pl` | Builds that index from the rules themselves. |
| `holes.pl` | What is missing and is not ours, declared out loud. |
| `history-gate.pl` | Every recorded failure must name the check that accused. |
| `pipefail-guard.js` | No script turns on `pipefail` and also pipes into `grep -q`: with `pipefail` that pipe returns 141 once the input passes ~64 KB, and a "red if it contains X" guard goes silently green. Measured 2026-11-03: 0 of 400 runs wrong without `pipefail`, 141 in 50 of 50 at 200 KB with it. Names file and lines; has its own self-test. |
| `compliance.pl` | The compliance matrix, and how far it reaches. |
| `compliance-selftest.pl` | Its own self-test. |
| `audit-vs-spec.pl` | The spec against the tree. **26 of 26 checks have a case.** |
| `audit.sh`, `qa-final.sh` | The site auditor, and the last look before publishing. |
| `run-gate.js` | The harness the browser gates run inside. With `GATE_CANDIDATO=<dir>` and `GATE_SITIO=<origin>` it serves that folder from disk under the production origin, which is how the door measures the candidate; `"candidato": N` on its first line counts what it served, and 0 means production was measured. In both modes, candidate and production, it aborts the same measurement hits as `banner-probe.js` (`"medicionAbortada": N`): the gates click the banner, and each click counted as a visitor on the site's counter and in its GA4. As a module it gives `servir` and `MEDICION`, so there is one copy of how a tree is served. |
| `nav-host.sh` | Where the measurement host comes from, read once for the door and the four host banks: `NAV_HOST`, then `config/nav-host.local.conf` (gitignored), then nothing — and nothing is reported as `NOT MEASURED`, never tried as a placeholder. Sourced, not run. |

The coverage figure has a scope you should know: **95% is measured over 5 programs of 46**,
not over everything. It is in the README of the repository root with the same caveat. A
number quoted without its denominator is how a partial measurement becomes a claim.

---

## English flags

The programs were written in Spanish and the option keys are the Spanish words — the parser
uses the captured flag name **as** the key. Renaming them would have meant a 5,241-line
refactor that could not be verified here, so instead every program takes **additive English
aliases**, which is the pattern the codebase already used. Both spellings work, everywhere,
and neither can break an existing invocation.

**`qa-master.pl`**

| English | Spanish |
|---|---|
| `--type` | `--tipo` |
| `--only` | `--solo` |
| `--thanks` | `--gracias` |
| `--contact` | `--contacto` |
| `--sample` | `--muestra` |
| `--receipt` | `--recibo` |
| `--hours` | `--horas` |
| `--candidate` | `--candidato` |
| `--no-network` | `--sin-red` |
| `--no-receipt` | `--sin-recibo` |
| `--single` | `--una-sola` |
| `--evidence` | `--evidencia` |
| `--container` | `--contenedor` |
| `--cache-hours` | `--cache-horas` |

**`receipt.pl`**

| English | Spanish |
|---|---|
| `--write` | `--escribir` |
| `--verify` | `--verificar` |
| `--served` | `--servido` |
| `--tree` | `--arbol` |
| `--history` | `--historial` |
| `--record` | `--anotar` |
| `--for-deploy` | `--para-desplegar` |
| `--list` | `--listar` |
| `--site` | `--sitio` |
| `--out` | `--salida` |
| `--receipt` | `--recibo` |
| `--hours` | `--horas` |
| `--instrument` | `--instrumento` |
| `--cache-hours` | `--cache-horas` |
| `--except-verdict` | `--salvo-veredicto` |

**`deploy.sh`**

| English | Spanish |
|---|---|
| `--upload` | `--subir` |
| `--served` | `--servido` |
| `--show-upload` | `--ver-subida` |
| `--anyway` | `--aun-asi` |
| `--again` | `--otra-vez` |
| `--stop` | `--parar` |
| `--loses-text` | `--pierde-texto` |
| `--hours` | `--horas` |

**The rest**

| Program | English | Spanish |
|---|---|---|
| `qa-diff.pl` | `--rule` · `--common` · `--force` | `--regla` · `--comunes` · `--forzar` |
| `d057.pl` | `--no-ga4-or-ads` · `--out` · `--production-dom` · `--production` · `--today` · `--browser` | `--sin-ga4-ni-ads` · `--salida` · `--dom-produccion` · `--produccion` · `--hoy` · `--navegador` |
| `audit-vs-spec.pl` | `--mode` · `--only` | `--modo` · `--solo` |
| `coverage.pl` | `--which` | `--cuales` |
| `run-all.sh` | `--fast` | `--rapido` |

Output messages are still largely Spanish. That is cosmetic and it is being worked
through; the flags, the file names, the documentation and the trap log are English.

---

## The deploy hook

`hooks/block-deploy-without-receipt.sh` is a `PreToolUse` hook that denies any command that
looks like writing into a document root, and tells the caller to go through the door
instead. **It is optional and it is not on by default.** Installation instructions are in
its own header.

Before turning it on:

```bash
bash gates/receipt-tests/tests-hook.sh
```

**85 OK · 0 BAD.** Run it again after any change: the number that matters is the one you
measure. Roughly half the cases are negatives — ordinary commands it must not block —
because a guard that blocks too much gets switched off, and then there is no guard at all.
Most of the negatives exist because this hook really did block them: downloading a file
from production, committing two scripts at once, renaming one, reading its own source.

Commands that fill several lines reach the hook with the line break written as a backslash
and an `n`. The hook normalises that once, at the top; the battery writes those cases the
way they travel, because every case on one line is how a hole stayed open.

**No exemptions ship.** Two existed upstream, both for scripts publishing assets no page
ever serves, and both named one particular estate. Section 6 of the hook carries the three
rules that made them safe, every one written after an exemption leaked.

**One exemption ships switched off.** A copy to a machine that serves no website is
measuring, not deploying, and the hook cannot know which machines those are. List them in
`config/tools-hosts.conf` and section 5b exempts an `scp` or `rsync` whose last argument
literally points at one of them, away from any production marker. Without the file it does
nothing.

> The hook and the door are coupled by a filename. That coupling is the point of the
> exemption, so it is also what breaks silently when somebody renames the door — and it did
> exactly that here. The exemption also needs the door to be **executed** as
> `gates/deploy.sh`, with no other upload in the command: naming it used to be enough, and
> that let an upload through behind it. The battery pins both halves.

---

## Configuration

Everything site-specific is a config file, never baked in. All are optional; the examples
say what happens without them.

| File | What it controls |
|---|---|
| `config/site-repos.conf` | Which site repositories the documentation gate also checks |
| `config/production-markers.conf` | Extra document roots and hostnames the hook treats as production |
| `config/tools-hosts.conf` | Machines serving no website, which the hook lets you copy to |
| `compliance.conf.example` | The compliance matrix's scope |

With no config the runner **prints a line saying so**. Printing nothing would read as
"checked, all fine", and that is the failure this whole system exists to stop.

---

## What does not ship, and why

Two fixture sets were **frozen byte-for-byte captures of real client sites**: 286 files of
HTTP capture triples (6.9 MB) and eight captured client pages (164 KB). Publishing somebody
else's website to make a test pass is not a trade this repository makes, so they are
excluded.

- **`qa-master-tests/tests.sh` no longer needs its capture.** Since 2026-09-22 every case
  that read it — and every case that measured an anonymised `*.example` host, a client
  repository, or a live site — runs against a **synthetic site** in
  `qa-master-tests/fixtures-sites/` (and `fixtures-repos/`), served as production by
  `fake-production.pl`. Its README says how to add one. On a clean clone the bank runs
  **582 cases** and exits **0**. A case that names a host with no fixture is still reported
  `NOT MEASURED` by name, and the bank then exits 3; a measured case that fails exits **1**,
  never 3 — a real defect must not come out dressed as a declared gap.
  How it got here: until 2026-09-01 it bailed on line 98 with `OK 0 · MAL 0`; until
  2026-09-21 it bailed on line 260 with 18; on 2026-09-21 it ran the 131 self-contained
  cases and named the rest as unmeasurable by anyone.
- `structure-gate-tests/battery.sh` marks the eight affected cases `NOT MEASURED`
  individually, counts them separately, and exits **3** if any were skipped and nothing
  else failed. To close that gap, freeze a page **you own** (its README says how):

```bash
# 1 · measure the page once, so it lands in qa-master's cache
perl gates/qa-master.pl <URL> --una-sola --sin-recibo --cache <cache-dir>
# 2 · copy that host's entries out of the cache into a fixture directory
perl gates/qa-master-tests/freeze-fixture.pl <cache-dir> <fixture-dir> <host>
```

(Until 2026-09-26 this block gave `freeze-fixture.pl <URL> <name>`, a signature the program
never had: it copies from a cache, it does not download.)

Everything else in both batteries is synthetic and ships intact. "Ships intact" is about the
files; whether they **run** is the paragraph above, and for `qa-master` the answer used to be
no.

---

## Adding a gate

Four things, and the fourth is the one people skip.

1. **The program**, with the real case that produced it in the header. Not a description of
   the rule — the incident, with its numbers.
2. **A test battery** at `gates/<name>-tests/`, with a positive case *and* negatives. A
   control that has only ever been seen green is not a tested control; the question is never
   *"does it pass?"* but **"what would have to happen for this to go red?"**
3. **Wire it into `run-all.sh`.** Writing a battery and wiring it in are two gestures, and
   only the first leaves a visible trace — a directory with tests in it looks like work done.
   Two batteries sat unwired for weeks. The census exists because of them.
4. **Say what it cannot see.** A check that stays silent when it did not run is
   indistinguishable from one that passed.

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md) for the rest, and
[`../docs/traps.md`](../docs/traps.md) before debugging anything.
