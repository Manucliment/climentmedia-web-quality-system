# Contributing

The rule that governs this repository is the one that produced it:

> When something breaks and **it was not in the checklist**: fix it, then **add the check
> to a gate** if a machine can detect it. If a machine cannot, it goes to the
> human-judgement half **with the real case that produced it**.

A checklist that does not grow from its own failures is out of date in a month.

---

## Before you change anything, prove the instruments still work

If you are touching a gate, a program or the documentation, this goes first:

```bash
bash gates/run-all.sh              # every battery + docs + coverage
bash gates/run-all.sh --fast       # skips the slow ones (three need a browser)
perl gates/doc-gate.pl                   # documentation only
perl gates/coverage.pl --which           # which checks have no fixture
```

Two numbers come out, and both matter:

| Number | Meaning |
|---|---|
| **Cases green** | If it drops, the instrument broke — and the instrument is what decides whether a defect is a defect |
| **Checks with a fixture** | No check ships without a test, and this cannot be flattered by measuring less |

**Do not run the battery while a deploy is running.** They share temporary files; a run
launched alongside a deploy produced 12 red cases that a still tree does not reproduce.
And **do not pipe it through `tail`** — the exit code you read is `tail`'s, not the
battery's, so a battery killed halfway comes out green. Let it run to a file:

```bash
bash gates/run-all.sh > /tmp/battery.txt 2>&1
```

Then read the file. **Do not detach it with `nohup … &`** if whatever launched it may itself
be backgrounded or time-limited: doing exactly that killed a run after 2 banks of 22 and
reported success, because the wrapper exited and took the detached job with it. The summary
in the file stopped at bank 2 and nothing said so. If you need to wait on it, wait for the
final line rather than for the process:

```bash
until grep -q "en verde" /tmp/battery.txt; do sleep 15; done
```

Waiting on the **result** rather than on the process also sidesteps a nastier one: a `pgrep`
pattern that travels inside the very command doing the waiting matches itself, and the loop
never ends.

---

## Adding a check

A new check is not finished when it passes. It is finished when all five of these are true:

1. **It has a fixture, red and green, frozen** — and you have seen it red with your own
   eyes. Include a case using somebody else's conventions: root-relative links, no
   trailing slash, markup painted by JavaScript, a page that *quotes* schema rather than
   declaring it.
2. **It has been run against every live site available**, and you looked case by case at
   whether it was right. Passing the fixtures is not enough: the fixtures were written by
   whoever wrote the check and share its assumptions.
3. **It emits an ID**, and that ID appears in the documentation.
4. **It can say "I passed"**, distinctly from "I did not run". A check that only speaks
   when it finds something makes clean indistinguishable from never executed.
5. **It states its scope.** A check that measures fewer pages when the site grows is
   measuring the instrument, not the site.

If a check accuses several correct things at once, **the suspect is the check.** A gate
that accuses two out of every three correct things gets switched off, and then it does
not catch the real one either.

---

## Adding a trap

Traps live in `docs/traps.md`. Each one declares **what catches it** — and `nobody` is a
valid, honest answer. The documentation gate fails if a trap does not declare this.

A trap entry carries:

- **What happened**, concretely, with the real numbers.
- **Why it was silent**, if it was. Most of them were.
- **What catches it now**: a check ID, or `nobody`.
- **The cheap signal** that would have exposed it in seconds.

The ratio of *traps with a mechanism* to *traps total* is the number that should go up.

---

## Changing documentation

`gates/doc-gate.pl` checks five things a program actually can know:

| | |
|---|---|
| **D1** | Every `gates/...` path the documentation cites exists |
| **D2** | Every flag written next to a program is accepted by that program |
| **D3** | Every check ID named is emitted by somebody |
| **D4** | Every trap declares what catches it |
| **D5** | All four paths carry the **same** deploy-door block |

What it does not check: whether what you wrote is any good, whether it is current in the
parts that cite no paths, and whether it is redundant. Those are still yours.

---

## Style

- **Every threshold carries the measurement that produced it.** A number without an
  origin cannot be argued with, and cannot be retired either.
- **Say what was not verified.** A report that does not say it reads as though it covered
  everything.
- **No client names.** Sites appear as stable labels — see the README. If you contribute
  evidence from your own work, either name your own site or use the next free label.
- **Spanish is welcome in issues.** The repository itself is English.

---

## What this project will not take

- A CMS, or any runtime. Everything that works here — served-equals-measured, the
  file-by-file md5 comparison — depends on the served artefact being an identifiable
  static file.
- Plugins and extension points. A filter hook is the mechanism by which a theme stops
  being predictable.
- A shared live core across client repositories. It turns one bug into a simultaneous
  incident on three sites.
- New documentation as the answer to a compliance problem. It is measured here: writing
  the rule down improves compliance fifteen points and nothing more. **What changes the
  number is wiring the gate to the door.**
