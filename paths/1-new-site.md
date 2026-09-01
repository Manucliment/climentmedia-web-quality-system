# Path 1 · Build a site

> **This is not a document to read: it is the sequence you execute.**
> It does not explain how to do things — that is what `blueprint/` is for, and it is not
> repeated here. It says **which step comes before which, what closes each one, and what
> broke the last time somebody skipped it.**
>
> **A step is not done until its gate is green.** If a step has no gate, it says so in
> as many words (`NO GATE`) and names the risk. A step with no declared gate reads as
> covered, and that is the failure this whole system exists to kill: the standard existed
> and it was not followed.

**The two entrances, and where they actually differ:**

| | **MIGRATION** (they have a site) | **GREENFIELD** (they do not) |
|---|---|---|
| The real inventory | **their code** | **the spec + the anatomy table** |
| The typical failure | **losing things** (13 images, 9 of 11 events) | **inventing things and not saying so**, shipping with holes |
| Gate at step 10 | `audit-vs-source.sh` **+** `audit-vs-spec.pl --mode migration` | `audit-vs-spec.pl --mode greenfield` |

Only steps **1a/1b** and **10** fork. Everything else is identical.

---

## Step 0 · Shared state

- **WHAT** · Look at what is open or closed for this client before touching anything.
- **HOW** · Your shared task board, filtered to the area that covers web work. Open the
  site repository's own `CLAUDE.md` **if the repo already exists**.
- **NEW BUSINESS: the step is not skipped, the question changes.** There are no tickets
  for a client that does not exist yet, so this stops being "what is open for them" and
  becomes **"what is open about the process"**: read the whole list — it is few rows —
  looking for instrument debt that is about to bite you. Then open a ticket for the new
  business, so the next session knows this exists.
  A step 0 that cannot be executed protects nothing, and that was exactly how it failed:
  it filtered by a category that is empty for a new business, so **it silently skipped
  itself.**
- **GATE** · `NO GATE — risk: reopening something already closed elsewhere, or duplicating
  work in progress.` Work runs across several sessions and none of them sees the others.
- **IF YOU SKIP IT** · It has already happened: the rule was written down and the failure
  happened anyway, because nothing forced anyone to look.

## Step 1 · Intake — blocking in both cases

- **WHAT** · Gather the eight facts without which nothing gets generated, and the real
  destination of the leads.
- **FILE** · `_spec/site.json` (`brand`, `nap`, `form.to`, `approver`).
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode greenfield --repo <site-repo> --only intake
  ```
  Threshold: `INT-01` all eight fields of block A · `INT-02` a real mailbox declared.
  **EXIT 0.**
- **IF YOU SKIP IT** · These projects do not die in the design. They die halfway through
  because nobody knows the opening hours or who approves copy. And one site's contact form
  spent months submitting to a CRM that had been cancelled — **a form that fails by
  returning 200 tells nobody.**
- → `blueprint/00-intake.md` (§A blocking · §C technical · §D if they have no copy)

## Step 1a · MIGRATION — copy their code TODAY

- **WHAT** · Copy their `src/` into `_migrate/source` **before** anybody touches DNS.
- **HOW** · `bash gates/audit-source.sh`
- **GATE** · `audit-source.sh` EXIT 0. Threshold: their inventory is captured.
- **IF YOU SKIP IT** · The moment DNS moves, **their site stops existing.** Copying their
  code on day one is the only thing that makes an audit possible afterwards, and without
  it step 10 has nothing to compare against, permanently.
- → `blueprint/01-source.md` (**two families**: a JS/TS app and a WordPress site are not
  alike and are not extracted alike)

## Step 1b · GREENFIELD — clone the skeleton

- **WHAT** · Which skeleton you start from **is decided by the table in
  `blueprint/02-design.md §1`, by case.** Open it. Do not copy a row of that table into
  here.
- **A row of that table used to be copied here, and it had drifted.** This step said to
  start from one skeleton and its own arrow pointed at a document that named a different
  one. Somebody following the path and somebody following the document ended up in
  different places **without either of them skipping anything.** A table copied by hand
  does not diverge *if* someone gets careless — it diverges. The table is the source.
- **You clone the GENERATOR and the SPEC, not the STATE.** What each skeleton has solved
  is in that table; what it has **broken** travels in the copy if nobody looks, and that
  is what the gate below is for.
  > A fact this step used to assert became false while nobody was watching: it claimed one
  > skeleton was the only one missing a `404.html`. When it was finally checked, all of
  > them had one. It had been fixed and the path kept the old photograph — which is
  > precisely why a gate is not justified by quoting a measurement, but by being run.
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode greenfield --repo <site-repo> --only skeleton
  ```
  Threshold: `ESQ-01` a `404.html` exists · `ESQ-02` favicon ≤ 50 KB · `ESQ-03` the
  primary colour token is outside the lightness band that fails AA contrast. **EXIT 0.**
- **IF YOU SKIP IT** · You clone the holes. The one that stayed alive and measured: a
  favicon of **320,221 bytes served on 13 pages**, which `ESQ-02` catches.
- → `blueprint/02-design.md §1` · **it is the source, not a supporting note**

## Step 2 · Design — so they are not the same site

- **WHAT** · Move the five levers (palette, typography, hero shape, card treatment,
  section order), and **open the component index before writing anything.**
- **HOW** · In this order, and **with full paths**, because a name without a path does not
  get opened:
  ```bash
  cat <your-design-doc>            # what is ugly here, and why
  cat <your-component-index>       # every primitive and mould you already own
  ls  blueprint/moulds/            # the ones shipped with this system
  ls  blueprint/moulds/types/      # one reference sheet per page type -> START HERE
  ```
- **Open `blueprint/moulds/types/<type>.html` for the type you are about to build**, before the
  folder listing above. It is generated from the anatomy and the role vocabulary, so it already
  answers "which blocks does *this* page need, in what order, with which mould, and when is that
  mould the wrong choice". The bare `ls` above answers none of those — it hands you the whole
  drawer and hopes. That is exactly the failure described in the next bullet, and this is the fix for it.
- **The design document goes FIRST, and it is where "what is ugly here" is written.**
  Measured: it appeared twice in the entire system, both times inside another document and
  only to note that its header was out of date. The word for the house's main aesthetic
  prohibition appeared **zero times** across all four paths and every reference, and this
  step — the design step — did not name it. The test site broke **three** of its
  prohibitions at once before anybody opened it.
  > Not all of it transfers to a client. The half that describes *your* palette is not
  > copied; the half that is general craft is. Decide which is which and write the split
  > into the client repository's own notes.
- **The component index, with its path.** This step used to say "the library index"
  without saying where. On a real build somebody opened the moulds folder and **never the
  index**: thirteen components were written by hand with nineteen primitives and twelve
  registered moulds sitting right there. It is literally the failure that index describes
  in its own first line, repeated for the same reason: **nothing forced anyone to look.**
  When it was finally opened — with the site already built — three more primitives were
  adopted and **one was discarded on the strength of its own "when NOT to use this"**
  field. That field paid for itself.
- **GATE** · `ESQ-03` covers the token's contrast. For the rest:
  **`NO GATE — risk: two client sites recognisable as siblings.`** Nothing measures whether
  two of your sites look alike — and it has already happened: two client repositories, a
  dental clinic and a home-visit physiotherapist in different countries, declared the
  **same primary colour token, literally.**
- **IF YOU SKIP IT** · Somebody wrote a numbered-steps component from scratch with an
  approved one sitting in the canon. And a hero badge ended up on 17 pages because nobody
  read its "when NOT": it was for the home page only.
- → `blueprint/02-design.md §3` (the five levers) · `blueprint/10-layout-vocabulary.md`

## Step 3 · Architecture and linking — decided BEFORE writing

- **WHAT** · Declare in the spec who is a child of whom: every entity with its
  `category`/`hub`, and no hub with fewer than four children.
- **FILE** · `_spec/site.json` (`categories[]`) and `_spec/*.jsonl` (`category`).
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode <mode> --repo <site-repo> --only linking
  ```
  Threshold: `ENL-01` every child declares its parent · `ENL-02` every hub has ≥ 4
  children. **EXIT 0.**
- **IF YOU SKIP IT** · On one site, five city pages received **zero links from the entire
  site** while sitting in the sitemap and indexable; on another, the zones hub linked to
  none of its five cities. If the parent is not in the spec, no loop emits the link — and
  fixing it afterwards means regenerating the whole site.
- → `blueprint/12-internal-linking.md §4` · `blueprint/09-page-types.md §4.2`

## Step 4 · Anatomy — the generator emits the section role

- **WHAT** · Every `<section>` in the body comes out of the generator carrying its **role**:
  `<section class="section" data-sec="qualification">`.
- **FILE** · your generator.
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode <mode> --repo <site-repo> --only anatomy
  ```
  Threshold: `ANA-01` every page declares `data-sec` · `ANA-02` **all** the mandatory roles
  for that page type are present, per the anatomy table. **EXIT 0.**
  > In `--mode migration`, `ANA-01` returns **NOT VERIFIED**, not PASS: you inherit the
  > generator and fix it in the next round. It is not a pass and it is written into the
  > receipt as exactly what it is.
- **HOW you get there** · **`blueprint/17-content-to-layout.md`.** This step *requires*
  `data-sec`, and for a long time nothing said **how** you get from inherited content to
  sections with roles. That document is the mechanism: the type declaration that
  **aborts** if it is missing, anchored splitting with total coverage, the primitives, and
  the check that not one word is lost.
- **IF YOU SKIP IT** · The anatomy rule existed for weeks with **0 of 121 pages**
  declaring a role, which meant the rule that depends on it could never fail. The first
  site to close it did 29 of 29 pages and the structural check passed — the first time on
  any site. It costs **one attribute now** and 121 pages later.
- → `blueprint/17-content-to-layout.md` (the mechanism) · `blueprint/09-page-types.md §1`
  (the roles) and **§2** (the anatomies — single source)

## Step 5 · Spec, and generate

- **WHAT** · Fill in the spec and generate **pages + sitemap + robots + `llms.txt` from the
  same loop.**
- **HOW** · your generator, **then** the site auditor:
  ```bash
  <your generator>
  bash gates/audit.sh
  ```
- **WHICH generator language, with a criterion and not a preference.** The spec auditor
  accepts any of them, so none of them blinds a gate. The rule is one and it is
  measurable: **if the site's language has accented characters, do not use PowerShell.**
  PowerShell 5.1 reads `.ps1` files as ANSI and a generator with accents mojibakes itself —
  in French there is an accent on nearly every line. If you inherit one, either port it or
  put **all** the text through HTML entities; half-way is not an option, because the
  mojibake appears on 42 pages at once.
- **GATE** · `audit.sh` EXIT 0 (`FAIL: 0`). Threshold: `[FAIL]` breaks the build;
  `[skip]` says **why** and does not count as a pass.
  > **When you copy an auditor into a new repo, you copy its defects. Check it after
  > copying.** Measured: three copies of the same auditor existed, two of them byte for
  > byte identical, **none of them in a shared source** and **none of them with a test
  > battery**. One of its checks resolved the whole `href` against the disk, so a
  > stylesheet sealed with a cache-busting query — which another rule *requires* — did not
  > exist as a file: **12 FAILs, all 12 false.** It had to be fixed in three places at once.
  > After copying it, run it and **read the FAILs one by one** before believing any of them.
- **IF YOU SKIP IT** · The four failures that produced this step were **system failures,
  not page failures**: an `llms.txt` publishing 11 URLs that 404, zero `Cache-Control`
  headers, an indexable page with no inbound links and no `noindex`. **No single page was
  wrong.**
- → `blueprint/09-page-types.md §2` decides the spec's fields **before** you write it

## Step 6 · Content and SEO

- **WHAT** · The SEO/GEO/AEO layer per page type: canonical, `og:image` **and
  `og:image:alt`**, honest schema, `llms.txt` free of HTML entities.
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode <mode> --repo <site-repo> --only images,pages
  ```
  Threshold: `IMG-02` every image in the spec has an `imageAlt` · `PAG-03` the sitemap
  lists no URL that does not exist. **EXIT 0.** The rest of the SEO layer is closed by
  `qa-master --only seo` at step 12, against what is published.
- **IF YOU SKIP IT** · `og:image:alt` became mandatory and sat at **0% on four of five
  sites — including the site where the standard lives.** It was fixed on one site and
  **never left it**: if the alt text is not a field in the spec, it gets written by hand
  and forgotten.
- → `blueprint/03-content-and-seo.md` · `blueprint/18-page-standard.md`

## Step 7 · Measurement

- **WHAT** · Container, Consent Mode v2, banner, events with **their literal names**, and
  the conversion actually firing.
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode <mode> --repo <site-repo> --only measurement
  ```
  Threshold: `MED-01` **every `data-*` the generator writes has a reader in the runtime** ·
  `MED-02` the thank-you page carries `noindex` **and** the conversion marker · `MED-03`
  the container is on every page. **EXIT 0.**
- **IF YOU SKIP IT** · This is the most expensive failure in the whole system and it has
  been live: a generator emitted `<body data-thanks="page_view_thanks">` and grepping the
  runtime for `data-thanks` returned **0**. Three conversion tags that nothing fires: zero
  conversions, zero analytics, zero click ids — on a clinic paying for clicks. **Verified
  by opening both files.**
- → `blueprint/04-measurement.md` · `blueprint/09-page-types.md §2.10` (the thank-you page)

## Step 8 · Forms

- **WHAT** · **Count them ALL**, not just the one that hurts. Email **and** a copy on disk.
- **GATE** ·
  ```bash
  perl gates/audit-vs-spec.pl --mode <mode> --repo <site-repo> --only forms
  ```
  Threshold: `FOR-01` no `mailto:` · `FOR-02` the receiver leaves a copy on disk.
  **EXIT 0.** Real submission is tested by hand at step 12 (block B.2).
- **IF YOU SKIP IT** · On one migration **an entire form was lost** — the job-application
  one — and no gate caught it. The client found it by asking. Email is what breaks
  silently; the copy on disk is the only proof the lead ever existed.
- → `blueprint/05-forms.md` · `gates/form-handler.php`

## Step 9 · Legal

- **WHAT** · Legal pages carrying the client's **real, approved** text.
- **GATE** · `--only legal`. Threshold: `LEG-01` no pending-work markers, and a real body.
  **EXIT 0.**
- **IF YOU SKIP IT** · **All three** legal pages on one live site served a literal
  "Pending legal review" heading — underneath a form collecting free text for a dental
  clinic.
- **A distinction that cost a whole round** · **publishing** the text they already had and
  had already approved is not *writing* it. Writing a new one is the client's job.
- → `blueprint/00-intake.md §B`

## Step 10 · INVENTORY AGAINST INVENTORY — the step that forks

- **WHAT** · Answer the question no checklist answers. A checklist says *"is what I expect
  here?"*; this says **"what is missing that I never thought of?"**

**MIGRATION — both, and they do not substitute for each other:**
```bash
bash gates/audit-vs-source.sh                                   # against THEIR code
perl gates/audit-vs-spec.pl --mode migration --repo <site-repo>
```
- **GATE** · both EXIT 0. The first enumerates from **their** side (whole categories that
  were on nobody's list); the second checks anatomy, measurement and linking against the
  spec, **which the first does not look at.**
- If the source is **WordPress**, `audit-vs-source.sh` exits on its first line — it assumes
  a JS/TS source tree. Use `audit-vs-source-wordpress.py`.

**GREENFIELD — the tick is no longer impossible:**
```bash
perl gates/audit-vs-spec.pl --mode greenfield --repo <site-repo>
```
- **This closes the hole that made the greenfield flow unexecutable.** The checklist
  demanded a gate that compares against the client's code; a client with no site does not
  have any, so the tick was **impossible to satisfy** and the only options were to lie or
  to skip it silently. The spec auditor asks the same class of question — enumerate from
  outside my own head — using the only source that exists when there is no origin: **the
  spec and the anatomy table**. And it adds the direction the other one does not need:
  **site → spec**, because in greenfield the failure is not losing things, it is
  **inventing** them.
  **In greenfield, write `N/A — greenfield` in the receipt for the source gate, with the
  spec gate named beside it as the substitute.** Do not leave it blank.
- **IF YOU SKIP IT** · On one migration **every gate was green** while these went missing,
  one after another: 13 of 19 images including the logo, all 5 team profiles, `og:image`
  on 18 pages, the entire analytics and ads stack, and 9 of its 11 events.
- → `README.md`, "Why a checklist is not enough"

## Step 11 · Publish

- **WHAT** · **A valid certificate on the destination BEFORE anybody touches DNS.** Verify
  by IP first, and without disabling certificate checks afterwards.
- **GATE** · `NO GATE beforehand — risk: moving DNS to a destination with no certificate
  and leaving the site in browser-red.` Checked by hand on **day one**, not on switch day.
- **IF YOU SKIP IT** · The error window cannot be undone: during propagation the client's
  site is down for everyone who already resolved the new record.
- → `blueprint/06-publishing.md §1`

## Step 12 · THE MASTER GATE — the single entry point

- **WHAT** · The five lenses over **the tree you are about to upload**: SEO · performance ·
  accessibility · measurement and legal · structure.
- **HOW** ·
  ```bash
  perl gates/qa-master.pl https://your-domain.tld \
       --repo <site-repo> --candidate --max-urls 60 \
       --thanks /thank-you/ --contact /contact/
  ```
  > **`--candidate` is not cosmetic.** This step once said "the five lenses over the
  > published site" and the command had no flag: that measures **production** and seals a
  > receipt for the **repository** — two different artefacts wearing one face. With that,
  > one site returned FAIL for the eleven defects the deploy existed to fix; and in the
  > other direction, a tree with a *new* defect came out green because what was measured
  > was the site already online.
- **GATE** · **EXIT 0 to deploy.** `FAIL` blocks · `WARN` gets looked at ·
  **`NOT VERIFIED` is not a pass** and goes into the receipt as itself.
  **Exit 2 = could not run, which is not the same as PASS.**
- **What the master gate cannot see on its own, and you have to hand back to it:**
  ```bash
  perl gates/qa-master.pl <url> --snippet     # prints the probe
  # paste it in the console AT 1298 (for 1280) AND AT 390, save the JSON, come back:
  perl gates/qa-master.pl <url> --dom dom-1280.json
  ```
  > **The first thing you read is not the verdict: it is `innerWidth` and `innerHeight`.**
  > If they are not what you asked for, throw the whole measurement away. On Windows,
  > headless Chrome clamps to about 500px — **measure from a Linux host**, and use a probe
  > that returns whether the requested width matched.
- **The three that are still separate, and have to be run alongside:**
  | Gate | Command | Why it is not inside |
  |---|---|---|
  | Link graph | `perl gates/crawl-links.pl <url> /tmp/c /tmp/g.json 400` then `perl gates/linking-gate.pl /tmp/g.json` | The inline check can only say NOT VERIFIED. `R0` **aborts** if the site paints links with JavaScript: a static crawl there **invents** orphans |
  | CPL | the script in `blueprint/11-measurements.md §7`, at both widths | not in the master gate |
  | Layout by type | `structure-gate.js`, at 1440 **and** 390 | returns a verdict **and** whether the page is a prose-page: two different questions |
- **IF YOU SKIP IT** · None of the build gates walks what is published, and that is how
  `og:image`, the entire measurement stack and 9 of 11 events escaped. And the three worst
  defects on one migration were found by **looking**, with every gate green.
- → `checklists/final-qa.md` (the five blocks: A · A-bis · A-ter · **B looked at** ·
  **C the seven questions**)

## Step 13 · Receipt

- **WHAT** · Put in writing what was measured, at what width, and **what was not looked at.**
- **GATE** ·
  ```bash
  perl gates/receipt.pl --repo <site-repo>     # written by the master gate
  perl gates/history-gate.pl                   # and the log names the accuser
  ```
  The format is defined by `gates/receipt.pl`, in its own header, and verified by three
  test batteries. How you report it to a human is in `checklists/final-qa.md`.
  > This step used to say its gate was "pending another path" — and that path was never
  > written. **A gate pending elsewhere is a step that never runs and looks like it does**,
  > and this one in particular is the one that records what was *not* measured. That is,
  > the only thing standing between you and a missing line reading as a pass.
- **IF YOU SKIP IT** · **A missing line reads as a PASS.** A report that does not say what
  it left out reads as though it covered everything.

---

## Gate count

| | |
|---|---|
| Entries in this path | **16** (0, 1, 1a, 1b, 2 … 13) |
| **With an executable gate and an expected exit code** | **12** — steps 1, 1a, 1b, 3, 4, 5, 6, 7, 8, 9, 10, 12 (step 12 chains four commands) |
| **`NO GATE`, declared, with its risk** | **3** — step 0 (shared state) · step 2 (so they are not the same site) · step 11 (SSL before DNS) |
| **Gate pending elsewhere** | **0** |

**No step closes without a gate or without `NO GATE` written down.** The three without one
are not an oversight: they are named debt. Step 2's is the only one **nobody knows how to
measure today**; the other two are one-off human checks, not automation that was skipped.

## The three gates that today can only say NOT VERIFIED

They are not covered, which is why they are here rather than inside a green step:

| | What goes unlooked-at |
|---|---|
| `EST-08` | the link **graph** — covered by running the linking gate by hand at step 12 |
| `MED-13` | that a conversion **arrived** at the ads platform. Checked in the account, not on the site |
| `A11Y-13` | a real **keyboard** walkthrough. Needs a person |

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
bash gates/run-all.sh     # every battery + documentation + coverage
```
