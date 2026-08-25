# Driving this repository with an AI assistant

This system was written to be operated by an AI agent working on a real site, with a
human approving the decisions. If that is what you are doing, read this file first. If
you are a person, everything here still applies — it is just phrased at the machine.

---

## Start here, and do not read everything

There are 21 reference documents. **Do not read them.** Open the path that matches the
job, and it will tell you what to open, when.

| The job | The path |
|---|---|
| Build a site, or migrate one | `paths/1-new-site.md` |
| Fix, redesign or audit a site that is already yours | `paths/2-improve-site.md` |
| Add a page to a site already published | `paths/3-add-page.md` |
| Iterate SEO or design on a live site | `paths/4-iterate-seo-design.md` |

Each step in a path carries: what you do, the command, the gate that closes it, and what
breaks if you skip it.

---

## The five rules for an agent

### 1. Their code wins, and the published site lies by omission

If there is a source repository, read it **before** you look at a single screenshot. The
live site is for comparing your result against — not for deducing what the original was.
It cannot show you the form that stopped working, the event that stopped firing, or the
image that stopped loading.

**Copy their `src/` on day one.** The moment DNS moves, their site stops existing, and
copying it afterwards is not an option. It is the only thing that makes an audit possible
later.

### 2. Never report a measurement you did not take

The single most expensive failure mode in this whole system is an agent that reads a DOM,
finds a number, and reports it as though it had looked at the page.

- A DOM query is not looking. If a change is visual, render it and look at it.
- **Never read a colour from a screenshot.** Use the computed style. And print the raw
  value first: if it comes back in a colour space you did not expect, parsing the digits
  out of it produces a number that is confidently wrong.
- **Ask every probe for its `innerWidth` and refuse the result if it does not match what
  you asked for.** A viewport that reports the right width can still be serving you a
  layout computed at the previous width — check something that depends on viewport units,
  like the font size of a headline, and if it did not change, everything you measured is
  from the old width.
- If you could not measure it, the line reads `NOT MEASURED` with the reason. **A missing
  line reads as a pass.**

### 3. Suspect your instrument before you suspect the site

Of 110 documented defects in this system's history, **41 belonged to the instrument**, not
to the sites. They all arrived dressed as site bugs: 81 findings from assuming relative
links, 78 from the trailing slash, 64 orphan pages of 67 that were not orphans, 628 of 628
elements "failing" contrast.

> **If a sweep says several things are broken at once, the suspect is the sweep.** A system
> that has been running for weeks does not break in a block. A new pattern does.

And before you believe a zero from a search: **every zero from `grep` is a non-match, not
an absence.** Open one of the files that came back empty and check by hand. Before
sweeping for a pattern at all, open two files and see how they actually write the thing
you are looking for.

### 4. A mutation must assert how many it MADE

Not how many it found.

- A text-pattern replace that changes only the first occurrence passes a syntax check and
  fails at runtime. Count afterwards, and compare against the count you expected.
- A substitution that matches nothing does not error and changes nothing. If you are
  running a positive control, **assert that the file changed** before you trust the result.
- After writing a file, **read back the line you just wrote.** "1 replacement of 1
  expected" proves it replaced something, not that it wrote what you meant.
- After any bulk edit, prove nothing else moved: strip out exactly what you inserted and
  the result must equal the original byte for byte. Strip from **both** sides, or anything
  idempotent fails the check for no reason.

### 5. Say what you did not verify

A report that does not say what was left unmeasured reads as though it covered everything.
This is not modesty; it is the difference between a receipt and a claim.

---

## The two moments that are not optional

```bash
# BEFORE: is what I am about to upload correct?
perl gates/qa-master.pl <URL> --repo DIR --candidate

# THE DOOR: refuses to reach the upload line without a valid receipt
bash gates/deploy.sh <REPO>            # dry run
bash gates/deploy.sh <REPO> --upload   # for real

# AFTER: is the visitor seeing that?   (run by the door itself)
```

**Neither substitutes for the other.** Without `--candidate` you measure *production*,
and the receipt then seals a tree whose verdict came from measuring a different object.
Both failure modes have happened on real sites: a tree blocked for the eleven defects the
deploy existed to fix, and a tree with a *new* defect coming out green because what was
measured was the site already online.

---

## When a gate says FAIL, it goes in exactly one of three boxes

| Box | What it is | What you do |
|---|---|---|
| **1** | Our defect | Fix it |
| **2** | A decision of the client's | `_deploy/accepted.conf`, signed, with an expiry |
| **3** | A false positive of the gate | **Fix the gate.** Never the accepted file |

Box 3 matters more than it looks. Putting a false positive in the accepted file hides it
on this site and leaves it alive on every other one. After fixing a gate, ask where else
the same rule applies — a fix that does not leave the site it was found on is how a
standard rots.

---

## What you decide, and what you ask

**Decide yourself:** anything you can measure, read, or verify. Measuring is never a
question — a reading, a probe, a sample, or widening a sample that came back too small
touches nothing and is reversible at no cost.

**Ask a human:** anything that publishes, uploads, sends, or spends. Anything where two
readings of the brief would produce materially different work. Anything the client owns —
retention periods, legal copy, what their brand is allowed to claim.

**Never invent a reason.** If you do not know why something is pending, write that it is
pending *and who decides*. An invented reason looks like a decision and is not one.

---

## A caution about this document's own numbers

Every measurement quoted in this repository was true when it was written, on the sites it
was taken on. They are here as evidence for the shape of the rule, not as a promise about
your site. Re-measure before you rely on one.
