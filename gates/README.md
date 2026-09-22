# The gates

38 programs and 30 test batteries. This file is the index: what each program is for,
how to run them all, which flags exist in English, and — the part most repositories
leave out — **what does not ship, and why.**

> Both figures are **derivable, and the recipe is here** so the next person can re-derive
> them instead of trusting the sentence above. Programs:
> `find gates -name '*-tests' -prune -o \( -name '*.pl' -o -name '*.js' -o -name '*.sh' \) -type f -print | wc -l`.
> Batteries: the rows of `BANCOS` in `run-all.sh`.
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

`--fast` skips the ten batteries that need a browser, a host, or the network. On this
machine the fast run is **682 cases green, 0 red** — **680** on a clean install, where the
deploy-history bank reports `NOT MEASURED` because a fresh install has never deployed anything.

**The full run is a different number, and the file now says which run it came from.** On
a clean install it reads **1123 cases green, 0 red**, with **five** banks reported as
`NOT MEASURED`: the three that measure on a Linux host (`measure-screens`, `mobile-gate`,
`form-handler`), the one that needs a client repository this public repository does not
ship (`compliance`), plus `structure-gate`. (`qa-master` left that list on 2026-09-22: see
below.)

> **A machine with a measurement host reads more, and that is expected.** The three host
> banks read the host from `gates/config/nav-host.local.conf` (copy the `.example`; it is
> gitignored, because a machine name has no place in a public repository). Where it
> exists they run, so on the machine these figures were taken from the full total is
> **1174**: 1123 plus 49 host cases plus the 2 of the deploy-history bank. `run-all.sh`
> counts all four banks as *machine-dependent*, and the documentation gate accepts either
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
682, not 680, because that machine has deployed. `run-all.sh`
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
  680 casos en verde · 0 en rojo
  NO MEDIDOS: historial
```

```
$ bash gates/run-all.sh
  NO MEDIDO structure-gate   layout: prose vs laid out             (10 of its cases WERE measured)
  1123 casos en verde · 0 en rojo
  NO MEDIDOS: measure-screens structure-gate mobile-gate compliance form-handler
```

> **Why the full run moved on 2026-09-22 (830 → 1123 on a clean install), and why
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
> **Last, +8: two gate fixes brought their own cases.** Building those sites found two defects
> in the gate itself. The first: SEO-04 hashed the page *without comments* and the
> canonical target *raw*, so one HTML comment made a file differ from itself and a
> well-canonicalised variant was accused. The fix compares raw with raw, and ships two
> cases: the variant with a comment passes (red against the old gate), and a canonical to a
> *different* document is still accused (+2).
> The second: without `--contact` and without a URL naming a contact page, MEDICION looked
> for the form only in the FIRST URL of the list, so with the form on the home and the home
> listed second, MED-09/10/11 vanished from the report with no FAIL and no NOT MEASURED. It
> now searches the pages it read, in an order that does not come from the list, and says
> NOT MEASURED when none has a form, like the accessibility lens (+6: both orders give the
> same verdict, and the no-form site is NOT MEASURED; five of the six were red against the
> old gate). The bank now closes **311 OK · 0 MAL · 0 not measured, exit 0**.
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
**159 with an instrument (62%)**, the other 98 listed with `--huecos` and split into
machine-measurable, partial, and human judgement. That half is well kept: the gaps are counted,
not hidden, and the report refuses to claim a ceiling of 100% because the standard itself marks
rules no machine will ever measure.

**It never asked the reverse: does this check that RUNS have a rule behind it?**

```
  checks emitted .......... 157
  with no rule claiming it .. 89   (57%)
```

**That is not a tidiness complaint.** A gate nobody's rule asked for is an opinion with
permission to block, and the defect is invisible from the side that *was* being measured — the
62% counts rules-with-gates, so a check with no rule cannot lower it. It is how `audit.sh` spent
months checking `AGENTS.md` while the standard described that file nowhere (`03-content-and-seo
§5.2`), and it is how three checks added this week arrived without anyone deciding they were
rules.

Most of the 89 are two whole instruments the catalogue never represented: the **~35 site-auditor
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

The first measures the tree you are about to publish and writes `<REPO>/.qa-receipt`. The
second is the door: it refuses to reach the upload line without a valid receipt, and after
uploading it verifies that **what is served is what was measured**. Neither substitutes for
the other — without `--candidate` you measure production, and the receipt then seals a tree
whose verdict came from measuring a different object.

---

## What each program is for

### The two that gate a deploy

| Program | What it does |
|---|---|
| `qa-master.pl` | The master gate. Five lenses over a page or a tree, and it writes the receipt. |
| `deploy.sh` | The door. No valid receipt, no upload — then checks what is served. |
| `receipt.pl` | Writes, verifies and records receipts; owns the deploy history. |

### Structure, layout and type

| Program | What it does |
|---|---|
| `structure-gate.js` | Is this laid out, or is it a wall of prose wearing a stylesheet? |
| `mobile-gate.js` | Action above the fold, and calls to action nothing covers. |
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
| `same-text.pl` | Whether re-laying-out a page lost any of the client's words. Compares the *visible text* of two trees, page by page, by words rather than lines — the layout is meant to change, the content is not. Takes two directories: `same-text.pl <tree-before> <tree-after>`. |
| `qa-diff.pl` | What changed between two runs, by rule. |
| `ai-crawlers.pl` | Whether AI answer engines are allowed to crawl at all. Parses robots.txt properly: own-agent groups do not inherit `*`, longest path wins, empty `Disallow` allows. |
| `cannibalization.pl` | Two pages fighting over one term. `--audit` finds existing exact H1/title collisions; `--keyword` gives NEW / UPDATE / CANNIBALIZES before a piece is written. |
| `citable.pl` | Whether a paragraph survives being lifted out of the page. Six mechanical checks from citation-ready-check. Refuses to score a language it has no patterns for. |

### Forms

| Program | What it does |
|---|---|
| `forms-gate.js` | The form in the DOM: labels, consent, a real submit button, a visible honeypot. |
| `form-handler.php` | The reference handler the gate is written against. |

### Migration

| Program | What it does |
|---|---|
| `audit-vs-source.sh` | The new tree against the old one: what got lost. |
| `audit-vs-source-wordpress.py` | The same, when the source was WordPress. |
| `extract-wordpress.py` | Pulls content out of a WordPress export. |
| `audit-source.sh` | Reads the source repository before anything is touched. |
| `to-webp.sh` | Image conversion, with the sizes recorded. |

### The gates that watch the gates

| Program | What it does |
|---|---|
| `doc-gate.pl` | Every program, flag and id the documentation cites must exist. |
| `coverage.pl` | How many checks have a test case. Today: **123 of 138 (89%)**. |
| `gate-index.js` | The RULE → INSTRUMENT index, **and since 2026-09-02 the reverse**: which checks run that no rule claims. **159 cases.** See below. |
| `rule-instrument-index.pl` | Builds that index from the rules themselves. |
| `holes.pl` | What is missing and is not ours, declared out loud. |
| `history-gate.pl` | Every recorded failure must name the check that accused. |
| `compliance.pl` | The compliance matrix, and how far it reaches. |
| `compliance-selftest.pl` | Its own self-test. |
| `audit-vs-spec.pl` | The spec against the tree. **25 of 25 checks have a case.** |
| `audit.sh`, `qa-final.sh` | The site auditor, and the last look before publishing. |
| `run-gate.js` | The harness the browser gates run inside. |
| `nav-host.sh` | Where the measurement host comes from, read once for the door and the three host banks: `NAV_HOST`, then `config/nav-host.local.conf` (gitignored), then nothing — and nothing is reported as `NOT MEASURED`, never tried as a placeholder. Sourced, not run. |

The coverage figure has a scope you should know: **88% is measured over 4 programs of 28**,
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

**`deploy.sh`**

| English | Spanish |
|---|---|
| `--upload` | `--subir` |
| `--served` | `--servido` |
| `--show-upload` | `--ver-subida` |
| `--anyway` | `--aun-asi` |
| `--hours` | `--horas` |

**The rest**

| Program | English | Spanish |
|---|---|---|
| `qa-diff.pl` | `--rule` · `--common` · `--force` | `--regla` · `--comunes` · `--forzar` |
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

**35 OK · 0 BAD · 2 known false positives, pinned.** Sixteen of those cases are negatives —
ordinary commands it must not block — because a guard that blocks too much gets switched
off, and then there is no guard at all. Three of the negatives exist because this hook
really did block them: downloading a file from production, uploading a measuring script to
a tools server, and reading its own source.

The two pinned false positives are real and unfixed: copying or renaming a deploy script to
another deploy-ish name reads as executing it. They are recorded rather than hidden, and
each pins the verdict the guard gives **today**, so that fixing the guard turns the pin red
and forces the note to be updated. The damage is bounded — they block work that is safe,
never allow a deploy — which is the cheap direction.

**No exemptions ship.** Two existed upstream, both for scripts publishing assets no page
ever serves, and both named one particular estate. Section 6 of the hook carries the three
rules that made them safe, every one written after an exemption leaked.

> The hook and the door are coupled by a filename. That coupling is the point of the
> exemption, so it is also what breaks silently when somebody renames the door — and it did
> exactly that here. Two cases in the battery now pin both halves.

---

## Configuration

Everything site-specific is a config file, never baked in. All are optional; the examples
say what happens without them.

| File | What it controls |
|---|---|
| `config/site-repos.conf` | Which site repositories the documentation gate also checks |
| `config/production-markers.conf` | Extra document roots and hostnames the hook treats as production |
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
  **311 cases** and exits **0**. A case that names a host with no fixture is still reported
  `NOT MEASURED` by name, and the bank then exits 3; a measured case that fails exits **1**,
  never 3 — a real defect must not come out dressed as a declared gap.
  How it got here: until 2026-09-01 it bailed on line 98 with `OK 0 · MAL 0`; until
  2026-09-21 it bailed on line 260 with 18; on 2026-09-21 it ran the 131 self-contained
  cases and named the rest as unmeasurable by anyone.
- `structure-gate-tests/battery.sh` marks the eight affected cases `NOT MEASURED`
  individually, counts them separately, and exits **3** if any were skipped and nothing
  else failed. To close that gap, freeze a page **you own** (its README says how):

```bash
perl gates/qa-master-tests/freeze-fixture.pl <URL> <name>
```

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
