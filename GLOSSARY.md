# Glossary

The system has its own vocabulary, and most of it exists because a vaguer word let a
defect through. Where a term was coined by a specific failure, the failure is named.

---

## The verdict vocabulary

**PASS** — the check ran, looked at something, and found it correct.

**FAIL** — the check ran and found a defect. Blocks the deploy.

**NOT VERIFIED** — the check could not run, or ran and could not measure. **This is not
a pass.** It is the third state, and it exists because everything that could not be
measured used to be reported green. A lens that comes back entirely NOT VERIFIED exits
non-zero: *a green cannot be allowed to mean "I did not look".*

**NOT MEASURED** — the human-facing form of the same idea. When a gate could not be run
at all, you write `NOT MEASURED` with the reason next to it. **A missing line reads as a
pass**, which is why the line is mandatory even when it says nothing was done.

---

## The gate vocabulary

**Check** — one assertion with an ID (`SEO-04`, `MED-08`, `EST-11`). It is the unit
everything else is counted in.

**Gate** — a program that runs checks and returns a non-zero exit code when they fail.
A check that is not wired to something that blocks is not a gate; it is a suggestion.

**Lens** — one of the five families of checks a full run covers: **SEO**,
**performance**, **accessibility**, **measurement & legal**, **structure**. You can run
one lens to save time, but a receipt missing a lens does not deploy.

**The door** — `gates/deploy.sh`. The only step in the process that is enforced by a
program rather than by remembering. It refuses to reach the line that uploads unless a
valid receipt exists, and it runs the served-equals-measured check after uploading.

**Receipt** — `.qa-receipt`, written by the master gate into the site repository. It
carries: the verdict per lens, the **md5 of the deployable tree**, the standard version,
an expiry, **the list of everything nobody looked at**, and the **scope**. It turns "I
ran the QA" into a fact somebody else can check.

**Scope** — how many pages, out of how many, each lens actually measured, and which ones.
A receipt whose scope is derisory — fewer than one in three HTML pages in the tree, and
fewer than 25 — is not a green. It exists because measuring less is the easiest way to
make a gate look good.

**Candidate** — the repository tree, served over HTTP locally, and measured *before*
upload. The opposite is measuring **production**, which describes a different artefact.
Running without it produced both failure modes on real sites: a tree was blocked for the
eleven defects the deploy existed to fix, and a tree with a *new* defect came out green
because what got measured was the site already online. The receipt states which one it
was: `MEASURED-AGAINST: CANDIDATE | PRODUCTION`.

**Served-equals-measured** (historically `G11`) — after uploading, compare what
production actually serves against what was measured. Both moments are required and
neither substitutes for the other: *is what I am about to upload correct?* then
*is the visitor seeing that?*

**Fingerprint** — the line a report prints under each FAIL, identifying the specific
finding rather than the check. Acceptances match against the fingerprint, so **if the
finding changes it counts again.**

**Accepted** — a signed, expiring exception in `_deploy/accepted.conf`, for a FAIL that
is not a defect of ours but a decision of the client's. Five mandatory fields (`CHECK`,
`FINDING`, `REASON`, `ACCEPTS`, `DATE`), expires at 90 days, hard ceiling 180. The
verdict then reads `PASS (with N accepted)` — never a bare `PASS`.

It exists because on one real receipt, of **8 FAILs, zero were defects of the tree** —
three false positives and five decisions already made. Without a way to record a
decision, no site can ever be green while a decision is pending, and there are always
decisions pending. **A gate that can never be satisfied is a gate somebody turns off.**

> **What can never be accepted**, and the gate refuses on its own: cookies before
> consent, a pre-ticked box, no cookie or privacy page at all, a legal policy live in
> draft, an internal path exposed. The criterion is simple — the harm falls on the
> **visitor** and is invisible to us.
>
> **And a false positive is never accepted.** That hides it here and leaves it alive on
> every other site. It gets fixed in the gate.

---

## The build vocabulary

**Spec** — `_spec/*.json`, the declared shape of the site in version control. The
generator and the gates both read it. **No gate infers anything** it can read from here.

**Override** — a deliberate departure from the source material, recorded with a `why`
field. An override without a `why` is indistinguishable from a mistake six weeks later.

**Site shape file** — declares whether URLs are flat or hierarchical, whether they carry
a trailing slash, the file-to-URL map, and the type of every page. A declaration chooses
*how a thing is measured*, or it leads to NOT VERIFIED. **Never to a pass.**

**Anatomy** — which sections each page type carries, in what order, and what breaks when
one is missing. Kept in exactly one table. It used to be written in three programs at
once, with a comment saying "duplicated on purpose"; when it was finally measured,
**7 of the 12 types disagreed** with the document.

**Primitive** and **mould** — the layout repertoire: a named component with a renderable
HTML template. You open the mould and copy it. You do not write a component without
checking whether it already exists — a component that exists and is not in the index
gets rewritten from scratch on the next project.

**Prose-page** — a blog article wearing a page's clothes. The density gate cannot see it:
that one measures direct children of `<main>`, and in a prose-page every `<p>` is one, so
no block ever overflows. It needs its own check.

**CPL** — characters per line in a text column. A measured typographic limit, with a gate.

**Density** — screens of scroll, and calls to action per screen. The failure it catches:
a WordPress site dumped as linear prose came out at **17.9 screens of scroll with 32 of
39 blocks carrying no call to action at all.**

**Holes** — one file per repository listing what is owed **by the client**, what was
measured to know it is missing, what it blocks, and since when. The door prints them
before uploading. A hole without the evidence that it is missing is a guess, and the gate
rejects it.

**Fidelity** — how much of the source text survived the migration, measured against
**their captured HTML**, never against your own extraction. Comparing an extraction to
itself is circular and reported ">=90% everywhere" while real fidelity was **68%**.

---

## The instrument vocabulary

**Instrument** — the measuring apparatus itself: the gates, the probes, the browser
harness. Of 110 documented defects, **41 were defects of the instrument, not of the
sites.** Every one of them arrived dressed as a site bug.

**Fixture** — a frozen input, with its expected output, red and green. **No check ships
without one.** The coverage number (checks with a fixture / checks total) is published
because it cannot be flattered by measuring less.

**Positive control** — a deliberately broken input, proving the gate can go red. A gate
only ever seen green is not a tested gate. The question to answer before believing any
check is not *"does it pass?"* but **"what would have to happen for this to go red?"**

**Live-park test** — before turning a new check into a `FAIL`, run it against every live
site you have and look case by case at whether it is right. Passing the fixtures is not
enough: **the fixtures were written by whoever wrote the check, and share its
assumptions.** Measured on one new check: of its three rules, one accused **two of three
sites falsely**. A gate that accuses two out of every three correct things gets switched
off — and then it does not catch the real one either.

**Match assertion** — a substitution must report how many replacements it **made**, not
how many it found. A text-pattern replace that silently changes only the first occurrence
passes a syntax check and breaks at runtime.

---

## Reading the evidence

Client sites appear as stable labels. See the table in [README.md](README.md#about-the-evidence-in-these-documents).
`Site C` means the same site in every document. The measurements are unmodified.
