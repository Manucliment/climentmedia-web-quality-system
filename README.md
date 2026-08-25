# Web Quality System — an open blueprint

A complete system for building, migrating, auditing and shipping websites, where
**every rule that can be checked by a machine is checked by a machine — and fails the
deploy when it is broken.**

This is not a style guide and not a checklist. It is a method, a set of executable
gates, and a deploy door that will not open without a signed receipt.

> Built and open-sourced by [Climent Media](https://climentmedia.com). MIT licensed —
> use it, fork it, ship it.
>
> **Prefer to read it without cloning?** The whole system is one page of plain text at
> [climentmedia.com/agents/web-quality-system/copy](https://climentmedia.com/agents/web-quality-system/copy/) —
> with a copy button, so you can hand it to an AI assistant in one paste. It is
> generated from these same files, so it cannot drift.

---

## Why this exists, in one measurement

We had 16 documents and about 8 gates. Every site we ran broke *different* rules.
So we counted, instead of guessing:

| Measured | Result |
|---|---|
| Rules in the written standard | **256** |
| Rules with **no gate at all** | **102** |
| Rules **never checked** on any site, ever | **106** |
| Non-compliance for rules that existed *while the site was being built* | **44%** |
| Non-compliance for rules written *after* that site shipped | **59%** |

Read the last two rows together, because they are the whole argument:

> **Having the rule written in front of you improves compliance by fifteen points,
> and nothing more.**

The canonical case: `og:image:alt` became mandatory in our standard, and sat at **0%
on four of five sites** — including the site where the standard itself lives. The only
site that complied was the migration the rule came *from*. It was fixed there, and it
never left there.

That is why the deliverable here is not documentation. It is:

1. **A path** — four of them, one per kind of job. You open one and it tells you what to open next.
2. **A generated compliance matrix** — which rule is enforced by which instrument, produced by a program, not maintained by hand.
3. **A deploy door** — `deploy.sh` refuses to reach the line that uploads unless a fresh, green receipt for *that exact tree* exists.

A standard is a document somebody has to remember to read.
**What does not fail on its own does not get done.**

---

## What is in here

```
paths/            Four entry points. Start here, not in blueprint/.
  1-new-site.md         Build or migrate a site
  2-improve-site.md     Fix, redesign or audit a site that is already yours
  3-add-page.md         Add a page to a site already published
  4-iterate-seo-design.md   Iterate SEO or design on a live site

blueprint/        The method. 21 reference documents — consulted, not read end to end.
checklists/       The QA that closes a project, the deploy gate, the page sprint.
gates/            The executable half. 34 programs and 22 test batteries.
                  Start at gates/README.md — the index, the flags, what does not ship.
docs/             The trap log: 81 traps, each with the failure that produced it.
config.example.md Everything specific to your site. The programs are never edited.
GLOSSARY.md       Receipt, gate, lens, scope, mould, primitive, prose-page.
```

**Do not read the 21 references.** Open the path for your job; it points at what you
need, when you need it. The references are lookup material.

---

## Quick start

```bash
git clone https://github.com/Manucliment/web-quality-system.git
cd web-quality-system
cp config.example.md /path/to/your-site/_deploy/config.md   # edit this, not the programs
bash gates/run-all.sh --fast                          # prove the instruments work
```

Then open `paths/1-new-site.md` (or whichever of the four matches your job).

**Dependencies:** bash, grep, sed, find, curl, Perl and Node. No package manager, no
build step, no service to sign up for. Three of the measurement gates want a real
Chrome; they say so, and they say `NOT VERIFIED` instead of passing when it is absent.

---

## The three rules that override everything

1. **Their code wins.** If the client hands you a repository, you read it *before* you
   look at a single screenshot. The published site is for comparing the result, not
   for deducing the original — **it lies by omission.**
2. **Everything of theirs is preserved**: copy, URLs, images, schema and *measurement*.
   Every change goes in the spec as an override with a `why` field.
   The **content** is preserved; the **layout** is not. Reproducing the source layout is
   how one migration ended with 17.9 screens of scroll and 32 of 39 blocks without a
   single call to action.
3. **A gate is not "it did not crash": it is counting against the source.** An extractor
   that loses data does not fail. It delivers less.

---

## Why a checklist is not enough

On one migration **every gate was green** while, one after another, these were missing:
13 of 19 images including the logo; all 5 team profiles; `og:image` on all 18 pages;
the entire analytics and ads stack, with the conversion measuring zero; 9 of its 11
events; and a whole form.

The last two were not found by any gate. They were found by the client asking.

> A checklist answers **"is what I expect present?"**
> The inventory gate answers **"what did they have that we do not?"**

And the gate is not enough either. On a second migration, with everything green:
the home page came out **worse than the original** (the page builder emitted the headline
as a paragraph and left the eyebrow as the `h1`); the blog index listed 11 posts and
**linked to none of them**; and 32% of the text was lost.

**A page being worse than before is not an inventory.**

### The circular gate — the most expensive bug we have shipped

That migration's fidelity check compared the **already-extracted** blocks against the
generated page. If the extractor dropped something, it was not in the blocks, and the
gate never missed it. It reported **">=90% on every page" while real fidelity was 68%.**

Compare against **their captured HTML**, and declare by name whatever you deliberately
do not reproduce. Everything else missing is a hole.

> And when a gate flags something, **suspect the gate first.** On that migration our
> instruments were wrong more often than the system was: twelve times, and not one of
> them raised an error.

---

## What the instruments are worth today

Two numbers, both published because both can go down:

| Number | Today | What it means |
|---|---|---|
| Test cases green | **519 · 0 red** on `--fast` | If it drops, the instrument broke — and the instrument is what decides whether a defect is a defect |
| Checks **with a fixture** | **119 of 134 (88%)** | No check ships without a test. It only goes up by writing tests, and **it cannot be flattered by measuring less** |

> **And the second number states its own scope, which is the honest half of it.** That 88% is
> measured over **4 programs out of 28**. The coverage tool prints the 24 it does not measure,
> by name, on every run. A coverage figure without its scope is exactly the kind of claim this
> system exists to stop, so it does not get quoted without this line.
>
> "Has a fixture" also only means the check's id appears in its test battery. It does not
> mean the case is any good, or that anybody has seen it go red. **It is the floor, not the
> ceiling.**
>
> **And the first number states its scope too: 519 is the `--fast` run**, which skips the nine
> banks that need a real Chrome or a measuring host. The full number is higher and is not
> published here, because it was not measured on the machine this was written on — and a count
> nobody can re-derive is a count somebody will eventually quote as current. Run it yourself;
> the runner prints its own total and names every bank it did not measure.

Run them:

```bash
bash gates/run-all.sh
```

> **Do not run the battery while a deploy is running.** They share temporary files. A
> run launched next to a deploy produced 12 red cases; with the tree still, the same
> battery gives 0. And do not pipe it through `tail` — the exit code you read is
> `tail`'s, not the battery's. A truncated battery that comes out green is worse than a
> red one.

---

## About the evidence in these documents

Nearly every threshold, limit and warning in this repository carries the measurement
that produced it, and the site it was measured on. Those sites are real client work, so
they appear under stable labels:

| Label | What it is |
|---|---|
| **Site A** | Home-services site, migrated from a TypeScript/React source |
| **Site B** | E-commerce with a product configurator |
| **Site C** | Content site migrated from WordPress/Elementor |
| **Site D** | Clinic site |
| **Site E** | Small business site, WordPress origin |
| **Site F** | Services site, greenfield build |
| `climentmedia.com` | Our own site, named because it is ours |

The labels are stable across every document: "Site C" is the same site everywhere. The
numbers are untouched — they are the reason any of this is worth reading.

---

## Contributing, and the maintenance rule

When something breaks and **it was not in the checklist**:

1. Fix it.
2. **Add the check to a gate**, if a machine can detect it.
3. If a machine cannot, it goes to the human-judgement half **with the real case that
   produced it**.

A checklist that does not grow from its own failures is out of date in a month. See
[CONTRIBUTING.md](CONTRIBUTING.md).

---

## Related

- [web-audit-kit](https://github.com/Manucliment/web-audit-kit) — the site-level auditor
  on its own: ~30 checks, zero dependencies, drops into any static site. It is the
  smallest useful piece of this system, and it stands alone.
- [climentmedia-design-system](https://github.com/Manucliment/climentmedia-design-system) —
  the tokens and components the layout half assumes.

## License

MIT. See [LICENSE](LICENSE).
