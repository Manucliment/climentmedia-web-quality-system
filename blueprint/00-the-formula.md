# The formula — how a site gets built and verified here

> Distilled from an analysis of the documented traps, five repositories and the gate itself: 175
> findings with evidence, 64 proposed rules, **39 survivors** after a refutation pass.
> What is marked verified was checked by hand, not by an agent. **What cannot be known with what
> exists is said in those words.**

---

## 1 · The diagnosis

**Of 110 documented defects with evidence, 41 belong to the INSTRUMENT that measures, not to the
sites.** It is by far the most populated family, and every one of them arrives dressed as a site bug:
81 failures from assuming relative links · 78 from the trailing slash · 64 orphans of 67 that were
zero · 628 of 628 elements "failing" contrast · one check giving FAIL at 56% with 1 page and PASS at
8% with 40, **over the same numerator.**

The next two families are just as silent: **16 of extraction** — the program finishes, prints its
count and delivers less without a single error (100 of 129 media items, 43 of 61 testimonials, 32% of
a site's text while the gate reported ">=90%") — and **14 of served-versus-measured**, where what was
measured and what is served are different objects.

**And none of that is stopped by the door.** Verified by hand:

| Verified | Where |
|---|---|
| **1 of 6 gates was wired to the deploy.** Only the receipt. The master gate came out in an `echo` as advice; three others were never invoked | the deploy script |
| **The "ship anyway" flag was NOT saved.** The line was an `echo` and nothing else. The script's own header promises three times that *"it stays in the history with your reason next to it"* | the deploy script |

That second one hurts most: three reasons signed that day — naming one by one the 11 checks that had
not been measured — **were printed on screen and lost.** There is no way to count how many times the
same thing has been signed off, **which is exactly the fact that needed seeing.**

---

## 2 · The CMS hypothesis: it is right, and the fix is cheaper than it looks

**The part that is right**, and it is measured in our own tree: blocks, templates and a core attack
three families totalling **21 of 110** (reproduced layout 7, two-sources-one-truth 8, CSS cascade 6).

And the proof is not theoretical:

> The three client repositories **generated 100%** have their chrome **identical on every page, with
> no gate watching it.** The **6 header variants and 4 footer variants** all live in the one repo with
> a half-finished generator. (I counted **21 of its pages** with the header copied by hand, and one of
> them had lost the product's pricing page along the way.)

So the exact diagnosis **is not "a CMS is missing"**. It is:

> ### Finish generating what is already generated.

**From a CMS you copy the shape of the SOURCE, never the runtime.** A CMS does not avoid bugs by
executing code on every request: it avoids them because it makes certain defects **impossible to
write.**

| From | What transfers |
|---|---|
| A template partial | You cannot duplicate the chrome: the template does not contain it, it calls it |
| The content loop | The index, the sitemap and the machine-readable file come from the same walk: **a page cannot be in one and missing from another** |
| A permalink function | You cannot type a URL: the site decides its shape |
| A declared block schema | A declared field arriving empty **invalidates the block**, instead of rendering less and staying quiet |
| A theme checker | It reads the THEME, not the rendered page |

**The other half, which the hypothesis does not see:** a CMS does not fix a gate that accuses falsely,
and today the instrument produces more "new bugs" than the five sites put together. Of ~149 checks,
**only 13 act before the HTML exists** — one prevention for every ten detections. Of the master gate's
75, **exactly one reads source code.** There is not one output snapshot in any repository. And
**50 of those 75 have never been seen red.**

**Both halves are mandatory.** Starting with the renderer without fixing the instrument guarantees
that no defect in the migration can be attributed to anything.

---

## 3 · The process, step by step

Steps **0–4** only on a new site or a migration. **5–12** on every batch, even a single page.
Each step: who · input · output · **gate** · **proof**.

| # | Step | The gate you do not skip | How it is demonstrated |
|---|---|---|---|
| 0 | **Intake.** Three answers: who approves, **which inbox the leads reach and who reads it**, and who holds the domain | No HTML gets generated without the intake file | A test lead **through each channel**, with the email received. Asking does not count: one form reported success with its CRM cancelled |
| 1 | **Certificate and DNSSEC of the destination, on day 1** | DNS is not touched without that line | An SNI check (it needs no DNS) plus the delegation record |
| 2 | **Copy THEIR code and THEIR measurement** before touching anything, including the public tag container | Nothing gets generated without the source copy and the measurement spec | The extractor prints source count against extracted count **per field and per page**, and exits non-zero if they differ |
| 3 | **Declare the site's shape**: flat or hierarchical, trailing slash, file-to-URL map, the type of every page | Generator **and** gates read that file. **No gate infers** | A declaration chooses *how a thing is measured*, or it leads to NOT VERIFIED. **Never to a pass** |
| 4 | **Linking decided before writing** | Hub and spokes publish in the same batch | The crawl and the linking gate, and **their verdict enters the receipt** |
| 5 | **Generate. Everything deployable comes out of the generator** | Zero hand-written HTML except with a name and a reason | The generator **aborts** if any HTML it did not write remains; and the chrome hash gives **one single variant per repo** |
| 6 | **Inventory against inventory**: what did they have that we do not, by name | The source gate exits 0 | It enumerates categories, never "N/A". **It is the only step that sees what did not occur to me** |
| 7 | **Measure the whole candidate** | No valid receipt, no upload | The receipt declares its **scope**; a derisory scope is not a green |
| 8 | **Close the browser holes** | Without the DOM data, those checks count as a hole | `innerWidth` and whether it matched; a mismatch is NOT MEASURED, **never PASS and never FAIL** |
| 9 | **The looking**, only what a census cannot do | — | The list comes from the census, not from your head. **Before believing a defect seen in a screenshot, look for it in the HTML** |
| 10 | **The door + served-equals-measured** | `deploy.sh --upload` | A served line with N of N compared |
| 11 | **The three questions of the next ten minutes** | — | Compression and cache measured **without the candidate flag** · modules with no version query = `[]` · the N URLs one by one after a domain change |
| 12 | **Every FAIL goes into one of three boxes** | No FAIL without a box at closing | **1** our defect → fix it · **2** a decision → the accepted file, signed and expiring · **3** a false positive → **fix it in the gate, never in the accepted file**, and then ask where else it applies |

> **Of these 13 steps, only 1 is genuinely mandatory today** — step 10, because it is the only one a
> program executes. Steps 6, 9, 11 and box 3 of step 12 **leave no artefact**, so they can be skipped
> with nobody noticing and the receipt comes out just as green. **Cheap fix:** have all four write a
> line with a date and a tree hash, and have the receipt validator require them.

---

## 4 · The rules, by the defects that kill

`[R]` renderer · `[I]` instrument

| # | Rule | Kills | Where it applies |
|---|---|---|---|
| 1 | `[R]` **Inventory against the SOURCE**, at entry and at exit. Enumerated from THEIR code, not from their published site, **which lies by omission** | 11 | Entry gate + exit gate |
| 2 | `[R]` **Single emission with a guard.** Menu, footer, sitemap, machine files, indexes and breadcrumbs come from ONE loop, and the generator **aborts if the derived outputs diverge** | 10 | Build assertion |
| 3 | `[R]` **Only what the generator wrote gets deployed.** Served HTML is a compiled artefact, not an editable file. No stream editing over HTML | 9 | Exit gate + an **allow**-list |
| 4 | `[R]` **Nothing leaves the flow, and no program of ours reads HTML with a regex.** Images, citations and buttons go on their list **and** stay where they were. **Parser, not regex** | 9 | Extractor contract |
| 5 | `[I]` **No check ships without a red and a green fixture, frozen**, seen red with your own eyes, and including **a case using somebody else's conventions** (root-relative, no trailing slash, painted by JavaScript, a page that QUOTES schema) | 9 | Golden master of the gate |
| 6 | `[I]` **No probe writes the property it is about to read.** Any visual measurement only counts if the requested width matched | 8 | Startup guard |
| 7 | `[R+I]` **What was measured and what is served are the same object, or there is no verdict** | 8 | Served-equals-measured |
| 8 | `[R+I]` **The URL shape is declared by the spec; no program deduces it** | 7 | File + linter |
| 9 | `[I]` **No threshold looks at a variable that depends on the instrument.** Ratios go **per page and worst case**, never over the union of what was measured | 6 | Framework assertion |
| 10 | `[I]` **A green cannot mean "I did not look."** A whole lens NOT VERIFIED ⇒ exit non-zero | 4 | Exit gate |
| 11 | `[R+I]` **No measurable figure is written by hand.** A ratio in a comment gets **deleted**, not generated | 4 | Source linter |
| 12 | `[I]` **The "anyway" flag gets written**: date, site, reason and the exact list of unlooked-at ids | — | 3 lines in the deploy script |

> **Three of these twelve (4, 8 and 11) point at a "source linter" that DOES NOT EXIST** and that no
> batch has budgeted. Until it is written, those three are **intent, not mechanism** — and that is
> exactly the category of rule that has already failed before. **It is said here so it does not read
> as done.**

---

## 5 · Order

**Batch 0 — the instrument, before touching a single generator.** Rules 5, 6, 9, 10 and 12. It does
not touch a byte of HTML. **Without it, any defect in batch 1 is indistinguishable from a false
positive.**

| | Status |
|---|---|
| **Rule 12 · the "anyway" flag gets written** | **done.** Only on a real upload. 6 new cases, **seen red** by sabotaging the recorder so it said it recorded without writing |
| **The gates enter the door** | **done for linking.** A new step: crawl what was served, run the gate, print and **record** the verdict. It does not block, and the reason is written down. 3 new cases, seen red |
| Door battery | 28 → **37 PASS · 0 FAIL** |
| **One runner for ALL the batteries** | **done.** There were 10 batteries in 5 folders and nowhere to run them from. **BASELINE: 365 cases green, 0 red** |
| **A gate for the DOCUMENTATION** | **done**, over the system **and** the five client repos — all six green. It caught 3 promised programs that did not exist, an ambiguous sentence written an hour earlier, and **me writing a dead path inside the trap that documents that error** |
| **Every trap declares what catches it** | **done.** All of them declare it · some with a mechanism, some saying `nobody` on purpose. **That ratio is the number that has to go up** |
| **The paths name the door** | **done.** None of the four mentioned the deploy script, and one told you to measure without the candidate flag. Same block in all four, and the documentation gate **fails if they diverge or if a fifth is born without it** |
| **Rule 10 · an unmeasured lens is not a PASS** | **done.** Three states per lens, the verdict carries it, and the door distinguishes "did not run" from "ran and measured nothing" |
| **Rule 5 · inventory of checks with no fixture** | **done.** A counter prints it on every run of the runner. It does not block: **a gate that is red from day one gets switched off** |

> **What running the batteries together for the first time exposed** (trap log §26): a test had been
> red for a long time with nobody looking, and splitting it in two — positive *and* negative —
> surfaced **a real hole in the deploy hook**: the exception for publishing attachments was entered
> **by the script's name**, when its own comment said it was entered by what the script does. **Any
> file with the same name in another repo walked straight in.** Closed.

> **And two of the three "verified corrections" the analysis brought were false, and the repository
> itself refuted them.** One claimed a missing HTTP header; fifteen measured requests said otherwise.
> The other claimed a flag overwrote the receipt; the validator already rejected a partial receipt.
> **An agent's report is an assertion, not evidence.** Both fell to a two-minute grep, before anything
> was touched.

**Batch 1 — your own site. This is where 80% of the benefit is.** It is yours, it is the only repo
with version control (rollback = one commit), zero risk to third parties. Its hand-written pages move
to the generator and the copies are deleted in the same batch. **All the measured duplication defects
live there.**

**And then you stop.** You do not touch a client repository without a real defect the rule would have
prevented. In the inventory of 110, **there is not one in a client repo that a shared core would have
prevented and that finishing the generation does not already prevent.**

> **One site never gets migrated, and this is the reason.** Its chrome is assembled by JavaScript, its
> detail page renders twice, and underneath is the code that produces the variant id — that is, the
> charge. **It is the only one where a bug costs sales the same day.**

---

## 6 · What is NOT done

- **A CMS or any runtime.** Everything that does work today — served-equals-measured, the file-by-file
  md5 comparison — depends on what is served being an identifiable static file.
- **A new template engine, a visual editor, a database as the source.** Specs in version control are
  strictly better: diffable, and they survive the server.
- **Plugins and extension points.** A filter hook is the mechanism by which a theme stops being
  predictable.
- **A live shared core across client repositories.** It turns one bug into a simultaneous incident on
  three sites.
- **Cascade layers over live stylesheets, or re-laying-out published pages.** It changes the appearance
  of client sites, and visual verification is the least reliable ground there is.
- **A byte-for-byte golden master of the real pages.** Every content edit would be a diff, and the
  diffs would be approved blind within a week.
- **Wiring the linking gate to the door as a blocker**: one site paints its graph with JavaScript and
  would never deploy again. It enters as a visible lens, not as a block.
- **New documentation as the answer.** Measured in this very system: with the rule written in front of
  you, non-compliance is 44% against 59% for rules written afterwards. **Writing it improves things by
  fifteen points and nothing more. What changes the number is wiring the gate to the door.**

---

## 7 · The number

The metric that genuinely answers *"is the process working?"* is **of every 10 FAILs the instrument
calls, how many are real defects.** The only measurement that exists: **0 of 8** (3 false positives, 5
decisions already taken).

> **But that number is NOT measurable today, and it has to be said:** the false positives have no file,
> the denominator **depends on how many pages get measured** — lowering coverage lowers the FAIL count,
> which is exactly what rule 9 forbids — and the five receipts were measured against **four different
> versions of the standard.**

**What can be counted today, with nothing new written, and cannot be flattered:**

| Measure | Today |
|---|---|
| Gates wired to the door | **3 of 6** |
| "Anyway" signatures with the reason saved | **3** |
| Deployable HTML written by hand | 37 of 151 |
| Pages that declare their type AND their section roles | **37** — one check had **0 of 121** verifiable since the anatomy table existed |
| **Checks WITH a case** | **64 of 124 (51%)**, re-measurable — it replaces an earlier "50 of 75" that nobody could re-derive |
| Identical NOT VERIFIED holes across the five sites | **11** |
| Receipt coverage | 114 URLs of 185 |

**The first three are monotonic, cheap, and measure exactly what this formula promises to fix. Start
there.**

---

## Rule 13 · A new gate is measured against the LIVE estate before it is switched on

**Passing the fixtures is not enough: the fixtures are written by whoever wrote the check, and share
its assumptions.** Before turning a check into a `FAIL`, run it against every **live site** and look
**case by case at whether it is right.**

Measured the day one check was written: of its three rules, one accused **2 of 3 sites falsely** — it
treated a field hidden off-screen as visible, which is the correct way to hide it and **cannot be seen
by reading the HTML.** That rule was not thrown away: it moved to the lens that measures with a
browser. After the trim, **5 sites, 5 passes, zero false positives.**

**Why it is a rule and not advice:** a gate that accuses two of every three correctly-built things
**switches itself off** — and then it does not catch the real one either. It has happened three times,
and the first two were discovered **after** switching it on.

**The cost is minutes:**

```bash
for s in <your live sites>; do
  perl gates/qa-master.pl "$s" --only <lens> --no-receipt --max-urls 8 | grep <NEW-ID>
done
```

**And if it comes out red on several at once, the suspect is the check**, not the estate.
