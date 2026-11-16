# Broken forms — the most expensive defect on client sites

## The pattern

The client signed up for a CRM, the site embedded it as an **iframe**, and months later they
cancelled the tool. **The iframe stayed put.**

Result: the form is still there, people fill it in, it shows its success message… and **the
data reaches nobody.** Every one of those people believes they made contact.

> Found on a real site: a lead-capture script loading a CRM endpoint on **6 pages**, with the
> CRM account already cancelled.

## How to detect it in 2 minutes

```bash
# 1 · in the served HTML
curl -s --compressed https://domain.tld/contact \
  | grep -aoE 'leadconnector|msgsndr|typeform|hsforms|<iframe'

# 2 · if that finds nothing, look in the JS chunks (a SPA injects it on hydration)
for f in $(curl -s --compressed https://domain.tld/contact \
           | grep -aoE '/assets/[A-Za-z0-9._-]+\.js' | sort -u); do
  curl -s --compressed "https://domain.tld$f" | grep -aq 'leadconnector\|msgsndr' && echo "FOUND $f"
done
```

> **Step 2 is essential.** On a server-rendered or hydrated site the iframe **is not in the
> initial HTML.** Searching only the HTML gives a reassuring false negative.

## The aggravating factor you always check

If the site fires a `form_submit` event **and the tag container picks it up**, then:

- Analytics **makes it look as though the site converts**
- The ads account may have a **conversion counting submissions that generate no business**,
  and therefore bids optimised towards nothing

**Look at this before touching campaigns.** It is the difference between "the site converts
badly" and "the site converts and nobody collects it".

## The fix

| | Third parties | When |
|---|---|---|
| **A handler on the same domain** | **0** | The default, if the hosting has a runtime |
| A form service | +1, and it is a data processor | Only if no backend is possible |
| A serverless function | still needs an email provider | More pieces, same result |

Ready to use: **`gates/form-handler.php`**. Four constants to configure.

> **Check there is a runtime first**: if `/index.php` returns 404, there is no PHP.

### What makes it actually work

- **It writes to disk BEFORE sending.** If the mail fails, the lead is not lost — which is
  exactly the failure being fixed.
- **`Reply-To` is whoever wrote in.** Replying is one click.
- **The subject carries the locality.** You can triage at a glance.
- **Anti-spam without a CAPTCHA**: a honeypot field plus a minimum time. A CAPTCHA is another
  third party and it obstructs precisely the audience you want most.
- **It strips zero-width characters at the door**, not afterwards.
- **The log lives OUTSIDE the public directory.** A leads file reachable over the web is a
  data breach.

## Do not reinvent the form

Almost always **there is already a form component of their own** in the repository, next to
the iframe, built and approved. On one site there was a complete contact form with a consent
checkbox; its only defect was submitting via `mailto:`.

**You give it a real destination. You do not redesign it.**

### An improvement that is usually already sitting there

If the repository has the list of areas or localities the client covers — very common for
on-site services — **turn the locality field into a dropdown**:

- It tells the visitor **immediately** whether they are covered
- It produces clean data: no more three spellings of the same town and no more typos
- It lets you filter and route leads by area

On one site that data was in the source with **57 localities**, and the form used a free-text
input.

## The lead card: every alert says what they wanted, where they were, how they came

A lead alert that says only "Name, Email, see the admin panel" cannot be acted on from a phone.
On a real site, the owner received an alert with a name and an address and had to work out
from analytics, two days later, which site it came from and what the person wanted. The data
was there: the form had sent the message and the page. **The alert just did not print it.**

**Every alert opens with three blocks, in this order, before anything else:**

| Block | What it carries | Where it comes from |
|---|---|---|
| **1 · What they want** | One line: the option they picked (service, plan, platform) and the first ~20 words of the message. Below it, **every** field they filled in, each with the label they saw | The form itself |
| **2 · Where they were** | The page they sent it from (title + path), the block that opened the form (`data-cta`: hero, pricing, footer…), the previous page on the site, and the landing page of the visit with the number of pages seen | Page and `data-cta` always; previous page from `document.referrer` when it is the same site; landing page and page count **only with analytics consent** |
| **3 · How they came** | In words: "Google Ads · campaign X", "Meta", "Google organic", "direct", "other: domain" | `gclid`/`gbraid`/`wbraid`, `fbclid`, `utm_*`, the external referrer |

Then who they are and how to reply (name, email, phone, language of the page, mobile or
desktop, local time), and at the bottom the site, the reference and the link to the sheet or CRM.

**The subject is the triage.** `[<site>] <what they want, ≤ 8 words> · <how they came>`. One
glance in the inbox says whether it is a client, a supplier or a pitch.

### The rules that keep it honest

- **No new cookie.** The landing page, the click ids and the page count are kept in
  `sessionStorage` only once analytics consent is granted. Without it, block 2 prints the
  landing page as `NOT MEASURED (no consent)`. A missing line reads as a pass.
- **Nothing is dropped.** A field the handler does not know goes under "Other fields". A
  form that grows a question must not lose it in the alert.
- **The same fields in the log as in the email.** The disk copy written before sending carries
  the three blocks too, so a lost email still leaves a readable lead.
- **The privacy policy says so.** One line: the form sends the page it was filled in from and
  how the visitor arrived, to answer them. Legal copy is the client's to approve.
- **Proved by a real submission.** After deploying, send one test lead marked TEST from a
  campaign-tagged URL and read the alert: the three blocks filled in, the subject readable.
  Until then the line is `NOT VERIFIED`.

## Health data

In clinics, physiotherapy or nursing, a "what do you need" or "message" field can contain
health information: **a special category under GDPR.**

- An **explicit** consent checkbox, not a generic "I accept"
- The privacy policy states **what is done with it and how long it is kept**
- If a copy is stored on the server, **declare it and give it an expiry**
- Sending notifications to personal free mailboxes is a client decision worth **putting to
  them in writing**
