# Intake — what you must have before you start

**Blocking in both cases.** Without block A, nothing gets generated.

If they have a site, most of this comes out of their code. If they do not, you have to ask —
and that is where these projects die. Not in the design: halfway through, because nobody
knows the opening hours or who approves copy.

---

## A · You do not start without these

| Fact | With a site | Without one | Why it blocks |
|---|---|---|---|
| Legal name and trading name | from their source | ask | they go in different places (schema vs header) |
| Phone, email, opening hours | from their source | ask | they appear on every page and in the schema |
| Address, or "we do not publish it" | from their schema | ask | a local-business schema with no address is correct if they work on-site at the customer's; **inventing one is not** |
| Services: name + description + bullets | from their source | ask | it is the body of the site |
| Areas served | from their source | ask | decides whether there are city pages |
| What the visitor does: call / write / book | from their calls to action | ask | decides the entire hierarchy |
| **Where the leads arrive** | **ask anyway** | ask | and **which of those inboxes they actually read** |
| **Who approves, by name** | ask | ask | "the client" approves nothing |

> **The lead destination is asked even when there is a site.** Their form may have been
> submitting to a cancelled CRM for months — which is exactly what one site was doing. See
> `05-forms.md`.

## B · You can start without these, but you ask now

- **Logo**, vector or a large PNG, and brand colours. With a site, it is in their
  repository: you use theirs, not a glyph.
- **Photos of the team and the premises.** If they have none, those sections **do not exist
  yet** — they do not get generated. See `02-design.md §5`.
- **Legal text.** A distinction that cost a whole round: **writing** a new legal notice is
  the client's job; **publishing the one they already had and had already approved** is not.
  With a site, you copy them across as they are. Without one, they supply them.
- **Real frequently asked questions** — the ones they get on the phone. They are worth gold
  for answer engines and they are what models quote most.
- **Languages.** If there are two, it is decided at the start: adding it later doubles the
  URLs and takes whatever was indexed with it.

## C · Technical — it takes longer than it looks

| | |
|---|---|
| **Domain**: where is it, and who is the registrant? | |
| **Hosting**: access | |
| **Provider API** | Keep the token in a credential file outside the repository. Note what the API does **not** cover — on one shared host it gave DNS, domains and hosting but **not** the SSL certificate, which was panel-only |
| **A real mailbox on the domain for the form** | Many shared hosts disable the local mail function, so sending **authenticates against a real account**. Make sure it is **not** the mailbox the client reads: if they delete it, the form stops sending **silently**. Its password is generated in the panel and pasted into a secrets file — it does not travel through chat |
| **A valid SSL certificate on the destination** | Checked on **day one**, not on switch day. See `06-publishing.md §1` |
| **Business listing** | If one exists, the name, address and phone must match character for character |
| **Are they going to advertise?** | If yes, measurement is mandatory before any campaign launches. See `04-measurement.md` |

## D · If the client has no copy

Two honest options, and you choose **beforehand**:

1. **We write it and they approve it.** Then the intake needs twice the conversation: who
   they serve, what they get asked, what makes them different, what they do **not** want to
   attract. Without that you get generic copy.
2. **Fewer pages.** Three good ones outperform ten of filler.

> **What is not acceptable is inventing and not saying so.** Copy of ours that the client has
> never read ends up in a complaint the day a customer quotes it back to them.

---

## How you ask for it

**Phone format**: one action per block, values in code blocks so they copy in one tap, images
as images, and zero business context — they have that.

Anything that belongs to the client goes into **a task with a link and a step-by-step**, not
into an email that gets lost.
