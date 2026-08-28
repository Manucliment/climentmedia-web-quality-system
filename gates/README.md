# The gates

37 programs and 28 test batteries. This file is the index: what each program is for,
how to run them all, which flags exist in English, and — the part most repositories
leave out — **what does not ship, and why.**

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
machine the fast run is **630 cases green, 0 red**, with the deploy-history bank reported
as `NOT MEASURED` because a fresh install has never deployed anything.

**The full run is a different number, and the file now says which run it came from.** It
reads **734 cases green, 0 red** — **732** on a clean install — with **six** banks
reported as `NOT MEASURED`: the four that need a host or a client repository this public
repository does not ship (`measure-screens`, `mobile-gate`, `form-handler`, `compliance`)
plus `qa-master` and `structure-gate`.

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
passing, so the total goes up: on the machine these numbers were taken from it reads
632, not 630, because two sites went out that day. `run-all.sh`
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
  630 casos en verde · 0 en rojo
  NO MEDIDOS: historial
```

```
$ bash gates/run-all.sh
  734 casos en verde · 0 en rojo
  NO MEDIDOS: qa-master measure-screens structure-gate mobile-gate compliance form-handler
```

**`NOT MEASURED` is not a pass**, and the runner lists those banks by name in the summary
precisely so a hole cannot be silent. The exit codes are three-valued throughout:

| Code | Meaning |
|---|---|
| `0` | measured, and correct |
| `1` | measured, and wrong |
| `3` | **not measured** — say so, do not guess |

A `1` where a `3` belongs sends somebody hunting a defect that does not exist. A `0` where
a `3` belongs is worse: it lets a gap read as coverage.

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
| `coverage.pl` | How many checks have a test case. Today: **119 of 134 (88%)**. |
| `gate-index.js` | The RULE → INSTRUMENT index has no dead references. **158 cases.** |
| `rule-instrument-index.pl` | Builds that index from the rules themselves. |
| `holes.pl` | What is missing and is not ours, declared out loud. |
| `history-gate.pl` | Every recorded failure must name the check that accused. |
| `compliance.pl` | The compliance matrix, and how far it reaches. |
| `compliance-selftest.pl` | Its own self-test. |
| `audit-vs-spec.pl` | The spec against the tree. **25 of 25 checks have a case.** |
| `audit.sh`, `qa-final.sh` | The site auditor, and the last look before publishing. |
| `run-gate.js` | The harness the browser gates run inside. |

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

Two fixture sets are **frozen byte-for-byte captures of real client sites**: 286 files of
HTTP capture triples (6.9 MB) and eight captured client pages (164 KB). Publishing somebody
else's website to make a test pass is not a trade this repository makes, so they are
excluded.

The batteries that depend on them do not pretend otherwise:

- `qa-master-tests/tests.sh` exits **3 — NOT MEASURED** when the frozen fixture is absent,
  naming what it could not cover.
- `structure-gate-tests/battery.sh` marks the eight affected cases `NOT MEASURED`
  individually, counts them separately, and exits **3** if any were skipped and nothing
  else failed.

To close the gap, freeze a site **you own**:

```bash
perl gates/qa-master-tests/freeze-fixture.pl <URL> <name>
```

Everything else in both batteries is synthetic and ships intact — 92 files in one, 35 in the
other.

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
