# The trap log — 81 traps, read before debugging

Every one of these cost real time on real work. They are numbered **§1–§81** and the numbers are
stable: other documents cite them, so nothing is ever renumbered. Within each part they keep their
original order, which is **by how much they cost**, not by when they happened.

| Part | File |
|---|---|
| §1–§19 | [`traps/1-19.md`](traps/1-19.md) |
| §20–§40 | [`traps/20-40.md`](traps/20-40.md) |
| §41–§59 | [`traps/41-59.md`](traps/41-59.md) |
| §60–§76 | [`traps/60-76.md`](traps/60-76.md) |
| §77–§81 | [`traps/77-81.md`](traps/77-81.md) |

---

## The maintenance rule

**Every trap declares what catches it now** — a check id, a test battery, or `nobody`. `nobody` is a
valid and honest answer, and it is the most common one. The documentation gate **fails** if a trap
does not declare it.

Not quoted — **derived by a program you can run**:

```bash
perl gates/doc-gate.pl --lista D4
```

Today it reports: **81 traps · all 81 declare what catches them · 31 say `nobody` on purpose.**

That last ratio is the number that should go up. **It only goes up by writing a mechanism, never by
writing more prose** — which is the measured finding the whole repository rests on. The five most
recent traps moved the total from 76 to 81 and left `nobody` at 31, because each shipped with the
check that catches it. That is what adding a trap is supposed to look like.

> **Use the gate's number, not a hand count.** Counting the whole declaration paragraph by hand gives
> 34 rather than 31, because a few traps carry the word on a following line. Both are defensible
> readings; only one is re-derivable. **A number you cannot re-derive is a number somebody will
> eventually quote wrongly** — and this repository has a trap about exactly that (§52).

---

## The seven things that keep happening

If you read nothing else, read these. Nearly every trap below is one of them wearing different
clothes.

1. **If the sweep says everything is broken at once, the broken thing is the sweep.** A verification
   tool with an undeclared assumption does not fail: **it accuses**, and it accuses in bulk. Its
   mirror image is just as reliable: **if a guard suddenly permits everything, it is not running.**
   *(§5 · §14 · §23 · §34 · §60 · §75 · §80)*
2. **A gate that measures presence can never contradict another that measures presence.** Green over
   nothing is the most common way a check lies. **A sweep that reports by exception must publish its
   denominator**, or "no problems found" and "I found nothing to examine" arrive as the same
   sentence. *(§18 · §29 · §44 · §67 · §72 · §77 · §78)*
3. **A mutation must assert how many it MADE**, not how many it found — and must check **what it
   leaves**, not the absence of what it removed. *(§22 · §30-bis · §33 · §70 · §72)*
4. **Two copies of one rule do not diverge "if" somebody gets careless. They diverge.** The only
   question is when. *(§24 · §44 · §46 · §60 · §68)*
5. **A control that only ever went green is not a tested control.** The question is never *"does it
   pass?"* but **"what would have to happen for this to go red?"** *(§17 · §25 · §40 · §64 · §72 ·
   §74)*
6. **A false positive discovers itself, because it is annoying. A false negative annoys nobody: it
   comes out green.** *(§43 · §65)*
7. **Knowing the trap does not avoid it.** One of these was written in the morning and reintroduced
   the same afternoon, in the same file, by the person who wrote it. **The only thing that avoids it
   is a mechanism.** *(§54)*

---

## By family

Families overlap; each trap carries the tag that best describes **why it was expensive.**

### A · The instrument lies — it accuses in bulk, or measures the wrong dimension

| | |
|---|---|
| §5 | Root-relative vs relative links: 81 failures on a correct site |
| §11 | `grep -P` with a length bound counts BYTES, not characters |
| §14 | The auditor carried an assumption about URL shape: 78 failures |
| §16 | Two programs, one cache, and not a single error |
| §20 | A check that decides with a number that depends on how much you measure |
| §21 | A rule demanded the home page link to half the site, and it was arithmetic |
| §23 | A rule counted repetitions and claimed "it links half the site" |
| §27 | A gate cannot know whether a path is "mine" or "one I am talking about" |
| §34 | The spec auditor: three accusations, all three false |
| §37 | A new gate is measured against the LIVE estate before it is switched on |
| §48 | CSS reads attributes too |
| §50 | The layout gate ignored the declared type: it audited the wrong anatomy |
| §52 | The coverage counter published 100% of a rule it had never looked at |
| §59 | Two sites cannot be measured with a browser, and the gate was failing them |
| §75 | `if (r.cssRules)` no longer distinguishes a group rule |

### B · Green over nothing — it passed without looking

| | |
|---|---|
| §17 | A positive control anchored to a LIVE site expires the day you fix the site |
| §18 | A whole lens NOT VERIFIED and the verdict said PASS |
| §19 | Measuring a site overwrites its deploy receipt |
| §25 | The door promised to leave a record, and it was an `echo` |
| §26 | Ten test batteries and nowhere to run them from |
| §29 | A gate with 24 checks and zero tests was DEAD |
| §30 | I removed 3 menu entries and left a dropdown with two |
| §35 | The verdict said it and the exit code was still 0 |
| §36 | A check said "does not apply" from the day it was written, and passed |
| §40 | The runner skipped 5 batteries of 8 and kept saying "all green" |
| §41 | The process was written end to end and its gates had never been seen to fail |
| §42 | Writing the case found two gates that could not see what they measure |
| §43 | An HTML comment could PASS a compliance check |
| §45 | The form template passed the exam it came to set |
| §51 | 727 FAIL runs over real sites, and not one says what failed |
| §53 | A battery written and never plugged in points at a real defect, in a vacuum |
| §61 | A check that only emits on failure cannot distinguish fixed from not-run |
| §62 | Two instruments sabotaging each other |
| §65 | A check that is not emitted reads as covered |
| §72 | A replacer function does not expand a capture reference |
| §74 | An honesty guard wired to ONE value declares "not a result" |
| §77 | A sweep for unwired batteries went mute when they were renamed |
| §78 | A discovery step conditional on an ABSENCE, disarmed by adding one file |
| §80 | Porting a construct by copying the line `grep` showed me |
| §81 | The census counted directories, so a battery hid inside a wired one |

### C · Silent loss — it delivered less and reported success

| | |
|---|---|
| §1 | The same field in two shapes — made twice |
| §3 | The zero-width character you cannot see |
| §8 | A paragraph pattern also matches an SVG path |
| §9 | Emission order: the card ends up with no text |
| §10 | Iterating an awk array in undefined order |
| §12 | The published site lies by omission |
| §22 | A one-line replace put rubbish into 12 live pages |
| §31 | The layout primitive was eating content, silently |
| §33 | An undeclared variable deleted what it came to change |
| §38 | The migration gate counted images and called that "media" |

### D · Two copies of one truth

| | |
|---|---|
| §6 | Rules of ours that carry an assumption about US |
| §24 | The hand-duplicated menu: you fix the template and the gate does not move |
| §28 | The four documents people follow did not name the door |
| §32 | One table with two uses: "related links" is not "parent" |
| §39 | A plan "measured against production" whose five of eight rows were false |
| §44 | Three tables promising to be twins, and seven of twelve types disagreed |
| §46 | The system required sealing the CSS and its own auditor failed it |
| §54 | I wrote §43 in the morning and reintroduced it in the afternoon |
| §56 | Three browser gates depended on a file that existed nowhere in our tree |
| §60 | A rule written four times: 363 failures on a correct site |
| §79 | The hook and the door are coupled by a filename, and the rename disarmed it |

### E · Delivery and cache

| | |
|---|---|
| §13 | Bypassing certificate checks hides what breaks the site on switch day |
| §15 | Half-applied cache-busting is worse than none |
| §73 | A CDN that rewrites images turns the served check into 12 false reds |

### F · Method — shell, regex, encoding, exit codes

| | |
|---|---|
| §2 | `grep -oc` does not count what you think |
| §7 | Paths relative to the repo, not to the script's folder |
| §49 | A doubled backslash vanishes in transit, and the regex goes mute |
| §55 | An exit code read through a pipe is the pipe's |
| §57 | In `grep`, a `.` does not match an accented letter |
| §63 | Perl's substitution right-hand side interpolates |
| §64 | A control that passes for the wrong reason |
| §70 | An anchor assuming an entity where the file has the literal character |
| §76 | A template literal lost its interpolations and the warning went mute |

### G · Layout and typography

| | |
|---|---|
| §4 | Reduced motion without cancelling the DELAY leaves the hero invisible |
| §47 | "No block over one screen" applied to a list forbids more than two ideas |
| §58 | The fix for §47 brought its own invented threshold |
| §66 | An FAQ with its questions in paragraphs is a wall |
| §67 | A gate counting calls to action by selector approves invisible buttons |
| §68 | Two gates measure the same thing with different rules |
| §69 | Declaring a font is not loading it |
| §71 | A line-length measure started from the node, not from the line |

---

## How to add one

See [`../CONTRIBUTING.md`](../CONTRIBUTING.md). A trap entry carries:

- **What happened**, concretely, with the real numbers.
- **Why it was silent**, if it was. Most of them were.
- **What catches it now**: a check id, a battery, or `nobody`.
- **The cheap signal** that would have exposed it in seconds.

**Numbers are never reused and never renumbered.** A retired trap is marked retired in place, with
the reason.
