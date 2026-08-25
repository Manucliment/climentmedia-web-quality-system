# Path 2 · Improve a site that already exists and is yours

> **When this path applies.** The site is published and you built it, and something has to
> change: fix a defect, apply a new rule from the standard, add pages, work the SEO, or
> redo part of the design.
>
> **When it does not.** If the starting point is the client's own site and it has to be
> migrated, or the client has no site at all → **path 1**. There, "their code wins" and the
> source-inventory gate rules. Here there is no origin to compare against: **the contract
> you measure against is the standard, not the client.**

**Why it exists.** The whole system was built around *migrating a site once*. Nobody had a
procedure for **coming back** to a site already published, and that is why five sites each
drifted their own way: `og:image:alt` was fixed on one site and never left it — four of
five at 0%, including the site where the standard itself lives. The lightness table that
solves the contrast problem lived in **a comment inside one project's CSS**; another site
shares the same token, has the defect live, and does not have the fix.

---

## THE THREE RULES THAT GOVERN THIS PATH

1. **Nothing gets touched before the baseline measurement exists.** Without a `BEFORE.json`
   you cannot demonstrate that the improvement improves anything, and you cannot tell your
   own regression from a defect that was already there. A change with no prior measurement
   **is not improvable: it is a deployed opinion.**
2. **NOT VERIFIED is not a pass, and that is where the expensive things live.** The most
   expensive defect on record — a conversion that never reached the ads platform — comes
   out as `MED-13 · NOT VERIFIED`, not as a FAIL. An ordering of "worst first" that reads
   only the FAILs **never reaches it.**
3. **A fix that does not ask "who else has this?" CREATES the drift** in the same gesture
   that removes a defect. Step 5 is not optional: it is the main disease.

---

## The five steps

| # | Step | Comes out with |
|---|---|---|
| 1 | **Diagnose before touching** | `BEFORE.json` with the full instrument |
| 2 | **Prioritise** | A queue ordered by `(D × W) / C`, written down |
| 3 | **Touch it (a live site)** | Named backup, pasteable rollback, one lens per deploy |
| 4 | **Demonstrate** | `qa-diff.pl` EXIT 0 against production |
| 5 | **Back-propagate** | `--rule <ID>` green everywhere, or a written reason why not |

---

## Before step 1 · what makes the rest fail

**Shared state:** check your task board for this site, so you do not reopen something
closed or duplicate something in progress. Work runs across several sessions and none of
them sees the others.

**And check nobody else is touching that repository right now.** If another session has a
background task on a file, that file is not touched: two writes at once and one is lost
without a warning.

**The route table — write yours, and do not assume it follows a pattern:**

| Site | Repo | `--thanks` | `--contact` |
|---|---|---|---|
| `<domain>` | `<repo>` — *may not follow your naming convention* | `/thank-you/` | `/contact/` |
| `<domain>` | `<repo>` | `N/A — none` | `N/A — external scheduler` |
| `<domain>` | `<repo>` | `N/A — cart` | `/contact.html` |

> Real repositories do not follow the pattern you would guess. In one set of five, two of
> the repository names did not match their site at all, and one of those matched a
> *different* site's name. Write the table out.
>
> An `N/A` is **written down**, with its reason. **A missing line reads as a PASS.**

---

## STEP 1 · DIAGNOSE BEFORE TOUCHING

**Hard rule: not one file gets edited until `BEFORE.json` exists.**

| | |
|---|---|
| **What** | The baseline photograph of the site **in production**, with the whole instrument |
| **Command** | below |
| **Gate** | `BEFORE.json` exists · it was run **with `--repo`** · `EST-09` is not NOT VERIFIED |
| **What breaks** | With no BEFORE there is nothing to compare against: every later number is an assertion. Without `--repo`, the repo-versus-production check and one measurement check stay **NOT VERIFIED** — and the repo-versus-production check is *the gate that makes every other gate useless when it fails*. On a real site a contrast fix sat in the repository for hours while production served the old stylesheet. You would have logged as an improvement something the visitor never saw |
| **Pointer** | `gates/qa-master.pl --help` · `checklists/final-qa.md` |

```bash
REPO="/path/to/<site>-web"
mkdir -p "$REPO/_qa"
perl gates/qa-master.pl https://<domain> \
  --repo "$REPO" --thanks /thank-you --contact /contact \
  --cache "$REPO/_qa/cache" \
  --json "$REPO/_qa/BEFORE-$(date +%Y%m%d-%H%M).json"
```

- **The JSON lives in the repo (`_qa/`), not in a scratch directory**: scratch dies with
  the session, and then next month there is no BEFORE to compare against.
  **`_qa/` goes on the deployment deny-list**, like `*.md` and `_spec/` — one live site
  ended up serving its own internal notes file with a 200.
- **`--thanks` is not decorative.** The most expensive defect on record lived on the one
  page the gate never visited.
- Expect a `VERDICT: FAIL`. **That blocks nothing here** — this is the diagnosis, not the
  publication gate. The publication gate is step 4.

### 1b · Complete the instrument — NOT VERIFIED does not get left

What the master gate cannot measure by itself gets measured **now**, not later: BEFORE and
AFTER must carry **the same instrument**, or the diff is not evidence — and `qa-diff.pl`
rejects it with exit 2.

| | |
|---|---|
| **What** | The DOM half (density, calls to action, the ragged last row, LCP/CLS) and the link graph |
| **Command** | `qa-master.pl --snippet > qa.js` → paste it in the console **at 1440 and at 390** → `--dom qa.json` · plus `crawl-links.pl` and `linking-gate.pl` |
| **Gate** | Two structural checks stop being NOT VERIFIED · the measured `innerWidth` written next to the result |
| **What breaks** | This is the blind half. One check is the only gate that looks at the **graph**: on one site a zones hub linked to none of its five cities, and on another five city pages received zero links from the entire site while sitting in the sitemap. No other gate sees that |
| **Pointer** | `blueprint/12-internal-linking.md` · `blueprint/11-measurements.md §7` · `blueprint/13-performance.md` |

> **Measure from a Linux host, not from Windows.** Headless Chrome on Windows clamps the
> window width to about 500px: a capture "at 390" comes out cropped and looks broken —
> that alone produced two invented defects. Use a probe that returns `innerWidth` and
> whether it **matched what you asked for**; a mismatch is garbage, not a result. And if
> the browser harness will not composite frames, you write **NOT MEASURED with the
> reason** — you do not fill it in by eye.

---

## STEP 2 · PRIORITISE

With 13–15 FAILs and 10–13 NOT VERIFIEDs per site, "worst first" is not a criterion, it is
a preference. This one is a criterion, and it gets written in the order it will be executed.

### The order, in three tiers

**P0 · What invalidates the measurement. Before everything else.**
The repo-versus-production check. While that fails, everything you measure in production
tells you nothing about what you are editing, and everything you measure locally never
reaches the visitor. It is fixed, or explained, **before anything is touched.**

**P0-bis · Damage 4: what is losing money NOW.** It does not enter the formula — it gets
opened today whatever it costs — because a queue ordered by cost leaves it dripping for
weeks. If the fix depends on the client or on an access you do not have, **what gets opened
today is the request**, not the fix.

**P1 · Turn NOT VERIFIED into measured.** You cannot prioritise what nobody has looked at,
and a NOT VERIFIED can be a hidden damage-4: the check that a conversion actually
**arrived** was NOT VERIFIED on both sites measured, and on one of them the conversion was
genuinely dead. Measuring is cheap; finding out late is not.

**P2 · Everything else, by score.**

### The score

```
        D × W
score = ─────
          C
```

| **D · damage** | |
|---|---|
| **4** | Losing measurable money right now: the conversion never arrives, the cart breaks, the form does not deliver, live legal exposure |
| **3** | Blocks traffic: orphan page, catalogue with no links, a 404 with no way out, an accidental `noindex` |
| **2** | Degrades the visitor: contrast below AA, density, ragged last row, page weight |
| **1** | Hygiene: a missing `og:image:alt`, a missing breadcrumb |

| **W · sites affected** | |
|---|---|
| **1–N** | Literal, from the command below. **Not estimated** |

| **C · cost** | |
|---|---|
| **1** | Fixed in the **generator or in a token**: one edit, N pages |
| **2** | In the generator, but content has to be decided per page (metas, alt text) |
| **3** | By hand, page by page, or the layout has to be redone |
| **4** | Requires a client decision, or an access you do not have |

**W comes from a command, not from intuition:**

```bash
perl gates/qa-diff.pl --common ../*/_qa/BEFORE-*.json
```

> **A glob that assumes a naming convention will quietly measure fewer sites and call them
> all.** One pattern missed the site whose repository did not end in `-web`, so it measured
> four and reported five. And if you also add the current repo's own path, that repo enters
> **twice** and `W` inflates exactly in the number the whole priority hangs on.
> `qa-diff.pl` deduplicates by site and **prints how many it loaded**: if it does not say
> the number you expect, it is not that number.

| | |
|---|---|
| **Gate** | The queue is **written down** with its `D · W · C` before the first file is touched |
| **What breaks** | Without it you fix whatever is in front of you. That is how one site passed density first time and has a dead conversion, while another is the worst on layout and the best on weight: **each site won one lens and lost another. "Our best site" does not exist** |

### What the formula forces you to see

A defect of **damage 2 on 5 sites fixed in a token** (2×5/1 = **10**) goes **before** one of
**damage 3 on one site that needs the layout redone** (3×1/3 = **1**). It is
counter-intuitive and it is correct: what shows up on four or five sites is almost never a
defect of that site — **it is a defect of the skeleton they all came from**, and fixing it
there back-propagates by construction. One default skeleton carried a primary colour below
AA and a 320 KB favicon: every new site was born with both.

### Two queue rules

- **Never open two lenses at once.** If step 4 comes back with a regression, with one lens
  you know what caused it. With three, you do not.
- **If you fix something no gate looks at, record which gate is missing in the same gesture.**
  There are around 102 rules in the standard with no gate at all. A fix with no gate undoes
  itself and nobody notices: it is literally the failure this path exists to kill.

---

## STEP 3 · WHAT CAN AND CANNOT BE TOUCHED ON A LIVE SITE

This is where the real fear lives. **These sites are live and several of them receive
leads.** The worst deploy on record produced no error at all: an unsealed `.js` was
uploaded, the page loaded **11 modules instead of 6** with two parallel carts, and
"add to cart" wrote into a cart the header was not listening to — **zero console errors,
zero warnings, the page looking perfect.** A later audit found it.

### 3a · Before mutating: the rollback is NAMED, not assumed

| | |
|---|---|
| **What** | A dated backup **outside the web root**, and the restore command written out **before** anything is touched |
| **Gate** | The backup **exists and has been listed** (not "the command was launched") · the rollback line is written down |
| **What breaks** | A backup inside the web root is **downloadable over the web**. And a rollback written after you have broken something gets written badly |
| **Pointer** | `blueprint/06-publishing.md` |

### 3b · What does not get touched

| Not touched | Why |
|---|---|
| **Anything outside your own root** | On one host, outside our folder lived a **live, paid** WordPress and WooCommerce install |
| **A file another session is touching** | Two writes at once means one is lost, silently |
| **Legal text, prices, medical claims** | The client decides those. You open a request, you do not edit |
| **Their measurement IDs and event names** | Preserved literally. Renaming an event switches off its conversion |
| **A generator or spec somebody just changed** | |
| **`*.md`, `_spec/`, `_migrate/`, `_qa/`, `.claude/`** | Deployment uses an **allow**-list, not a deny-list |

### 3c · The set-level invariant: cache-busting

| | |
|---|---|
| **What** | If the site seals its assets, the file you upload carries **the same seal as the rest** — and that includes **every internal `import` inside the `.js` itself**, which is the one everybody forgets |
| **Command** | Read the seal from the equivalent **live** file and use that one. Do not invent it, and do not bump it for a single file |
| **Gate** | In the page, list resources whose URL lacks the seal → must be **empty**, **and the total module count must equal what it was before.** If it went up, you have duplicates |
| **What breaks** | ES modules are cached **by URL**: `./x.js` and `./x.js?v=1` are two different modules with two parallel states. A syntax check does not catch it, nor a 200, nor a correct md5: the uploaded file is perfect. What is wrong is **who it shares state with** |

**It generalises:** any URL-based invalidation has this failure mode. The question is not
"is this file right?" but **"do they all still agree?"** And if the sealing is ever removed,
it is removed from **all** of them at once.

### 3d · One deploy, one lens. And the CSS ships with its page

| | |
|---|---|
| **What** | The stylesheet goes out in the **same batch** as the page that uses it |
| **Gate** | The project's production smoke test |
| **What breaks** | Otherwise the site has the new HTML and the old CSS, or the reverse: **it looks broken without being broken**, and somebody "fixes" something that was fine |

> **The cache lies about your deploy.** A stylesheet linked unversioned with a 24-hour
> `Cache-Control` will serve the old sheet for up to a day. **Break the cache before you
> believe a computed style**, or you will conclude nothing was uploaded. And `curl` without
> following redirects measures the body of a 301.

---

## STEP 4 · DEMONSTRATE THE IMPROVEMENT

| | |
|---|---|
| **What** | The **same** measurement, against **production** (not the build), with **the same flags** |
| **Gate** | **`qa-diff.pl` EXIT 0** · and the master gate with no new FAILs. **Red does not deploy** |
| **What breaks** | The FAIL counter goes down just as readily because a check **stopped being emitted**. Testing this gate, a change with 1 fix, 1 regression and 1 vanished check produced `FAIL 15 → 14`: **the summary improved and the site was worse** |

```bash
# 1 · measure again, SAME flags as the BEFORE
perl gates/qa-master.pl https://<domain> \
  --repo "$REPO" --thanks /thank-you --contact /contact \
  --json "$REPO/_qa/AFTER-$(date +%Y%m%d-%H%M).json"

# 2 · the diff
perl gates/qa-diff.pl "$REPO"/_qa/BEFORE-*.json "$REPO"/_qa/AFTER-*.json
```

**What `qa-diff.pl` blocks, and why each one:**

| Classification | What it means |
|---|---|
| `FIXED` | Was wrong, now passes. The only thing that counts as an improvement |
| `NOW MEASURED` | Was NOT VERIFIED, now there is a number. Counts, and it is the P1 work |
| **`REGRESSION`** | **HARD FAIL.** A fix that breaks something else is not a fix, it is a change |
| **`VANISHED`** | **HARD FAIL.** Either the change deleted what was being measured, or you measured with less instrument. Both are reasons not to close |
| *different instrument* | **exit 2, no comparison.** A BEFORE without the DOM half against an AFTER with it produces a difference that **is not an improvement**. `--force` stamps it as non-evidence |
| *empty diff* | Warning: either it was not deployed (check the repo-versus-production result), or you are measuring cache |

---

## STEP 5 · BACK-PROPAGATE

**This is the main disease.** The only site where the alt-text rule is correct is the
migration **the rule came from**. It was fixed there and it never left.

| | |
|---|---|
| **What** | For **every** check you turned green, ask the other sites |
| **Command** | `perl gates/qa-diff.pl --rule <ID> ../*/_qa/BEFORE-*.json` |
| **Gate** | **EXIT 0** = fixed everywhere. If not: every remaining site gets a ticket **with the check ID in it**, or a written line saying why it does not apply |
| **What breaks** | Without this, every fix increases the divergence between your sites. Verified with the real command: one SEO check passed on one site and failed on another, from the same skeleton |

### Where the fix has to live for it to propagate

| If the fix lived in… | Then… |
|---|---|
| **A token or the generator** | Copy it to the others **with its reason**. A shared token with the fix on one site only is guaranteed drift |
| **A single page** | **It goes into the generator first**, then it propagates. Otherwise it comes back on the next regeneration |
| **A threshold or a measurement table** | It goes into the **document that owns the rule** — accessibility for contrast, performance for weight — **not into a comment in one project's CSS**. That is exactly where the lightness table lived while another site shared the token, had the defect live, and did not have the fix |
| **Something no gate looks at** | Record **which check is missing from the master gate**. A written rule that nothing forces anyone to read is not a system, it is an archive |

> **And the rule gets wired in both directions:** the check carries a pointer to the
> document it came from, and the document gains the id of the check that watches it.
> Specification and gate disconnected is the meta-pattern that produced all of this: one
> page type was fully specified in the anatomy document while the QA checklist mentioned it
> **zero times** — and the site served 796 bytes with no links on it.

---

## Closing path 2

- [ ] `BEFORE.json` and `AFTER.json` in `<site>-web/_qa/`, same instrumentation, and
      **excluded from deployment**
- [ ] The queue prioritised, written, with its `D · W · C`
- [ ] Dated backup taken and **listed**, rollback line written out
- [ ] `qa-diff.pl` **EXIT 0** — 0 regressions, 0 vanished
- [ ] The master gate against **production** with no new FAILs
- [ ] `--rule <ID>` run for **every** fix, and whatever is left has a ticket
- [ ] **Blocks B (look) and C (the questions) of `checklists/final-qa.md`.** No script finds
      what nobody wrote into it: the three worst defects of one migration were found by
      **looking**, with every gate green
- [ ] **What was not verified, said by name.** A report that does not say what it left out
      reads as though it covered everything

> **And a published site is never "finished" again.** This path runs in full every time a
> page is added or a rule changes. It is cheaper than it sounds: today's BEFORE is last
> time's AFTER, and it is already in `_qa/`.

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
