# Checklists

| | |
|---|---|
| [`final-qa.md`](final-qa.md) | **The QA that closes a project.** Five blocks: A automatic · A-bis density · A-ter layout, readability and linking · B looked at · C the seven questions |

---

## What is deliberately NOT here

**The deploy door.** It lives in the four path documents, **byte for byte identical in all four**, and
`doc-gate.pl` fails if they diverge or if a fifth path is born without it. Putting a fifth copy in a
checklist would be the exact disease this system documents four separate times:

> **Two copies of one rule do not diverge "if" somebody gets careless. They diverge.** The only
> question is when. See [`../docs/traps.md`](../docs/traps.md) §24, §44, §60 and §68.

**The "adding a check" checklist.** It is in [`../CONTRIBUTING.md`](../CONTRIBUTING.md), because it is
about contributing to this repository rather than about running a site.

**A sprint record.** The upstream system carries a closed sprint document whose own header says, in
capitals, *"THIS IS A RECORD, NOT A STANDARD. DO NOT FOLLOW IT"* — everything reusable in it had
already been moved into the standard, and it is kept only to explain **why** the standard says what it
says. It is not reproduced here for the same reason it is not followed there.

---

## The shape a good checklist has here

Every block in `final-qa.md` follows it, and it is worth stating because a checklist written any other
way is the thing this system exists to replace:

1. **A command, or "BY HAND" said out loud.** No third state. If no program looks at it, that is
   written down, not implied.
2. **A pass criterion that is a number or a verdict**, not an adjective.
3. **The defect that brought it**, with its measurement. A threshold with no origin cannot be argued
   with — and cannot be retired either.
4. **What it does NOT cover.** Every gate here names its own blind spot; that is what stops the next
   person reading a green as "everything is fine".
5. **A line for what was not measured.** `NOT MEASURED`, with the reason. **A missing line reads as a
   PASS**, and that is what lets a failure through.
