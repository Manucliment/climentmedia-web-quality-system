# Configuration — everything specific to your site

**The programs are never edited.** Everything that differs between one site and the next
lives in configuration. If you find yourself editing a gate to make it fit your site,
that is a bug in the gate — open an issue.

There are four configuration surfaces. Copy the examples, fill them in, and keep them out
of version control if they carry anything you would not publish.

| File | Read by | What it holds |
|---|---|---|
| `_deploy/deploy.conf` | the door | Site URL, the upload command, which pages get a browser pass |
| `_deploy/accepted.conf` | the master gate | Signed, expiring exceptions |
| `_spec/site.json` | generator **and** gates | The declared shape of the site |
| `audit.conf` | the standalone site auditor | Base URL, brand, excluded folders, known-dead paths |

Examples for the first two are in [`gates/config/`](gates/config/). The third is described
below. The fourth belongs to [web-audit-kit](https://github.com/Manucliment/web-audit-kit),
which ships its own.

---

## The site shape file — `_spec/site.json`

This is the one that stops arguments. **The generator and the gates both read it, and no
gate infers anything it could read here.** A declaration chooses *how a thing is
measured*, or it leads to `NOT VERIFIED`. Never to a pass.

```jsonc
{
  "site": {
    "url": "https://your-domain.tld",
    "brand": "Your Brand",
    "lang": "en",

    // Flat or hierarchical. Gates that resolve relative links need this.
    "structure": "hierarchical",

    // Trailing slash: true, false. Not "whatever the server does".
    // 78 false findings on one site came from assuming this.
    "trailingSlash": true
  },

  // Every deployable page, its file, and its TYPE. The type decides which
  // sections are mandatory — see blueprint/09-page-types.md.
  "pages": [
    { "url": "/",              "file": "index.html",           "type": "home" },
    { "url": "/services/",     "file": "services/index.html",  "type": "hub" },
    { "url": "/services/a/",   "file": "services/a/index.html","type": "service" },
    { "url": "/about/",        "file": "about/index.html",     "type": "about" },
    { "url": "/contact/",      "file": "contact/index.html",   "type": "contact" },
    { "url": "/blog/",         "file": "blog/index.html",      "type": "index" },
    { "url": "/blog/post/",    "file": "blog/post/index.html", "type": "article" }
  ],

  // Deliberate departures from the source material. A `why` is mandatory.
  // An override without one is indistinguishable from a mistake six weeks later.
  "overrides": [
    {
      "what": "Dropped the source cookie banner",
      "why":  "Replaced with a Consent Mode v2 banner; the original blocked nothing."
    }
  ],

  // Things you deliberately do not reproduce from the source, BY NAME.
  // Everything else missing is a hole, not a decision.
  "notReproduced": [
    "their related-posts widget",
    "their newsletter popup"
  ]
}
```

### Why every field is mandatory

**`trailingSlash`** — assuming it produced 78 false findings on a single run. The link
crawler cannot resolve a relative href without it, and it will not guess.

**`structure`** — 81 false findings came from assuming links were relative when they were
root-relative. Root-relative and relative are different graphs.

**`type` on every page** — the anatomy table says which sections each type must carry. A
gate that infers the type from the URL path gets it wrong on exactly the pages that
matter. One structural check sat at **0 of 121 pages verifiable** for as long as the
anatomy table had existed, because nothing declared a type.

**`overrides[].why`** — this is the field that survives you. It is the difference between
"somebody decided this" and "somebody broke this".

**`notReproduced`** — the fidelity gate compares against the source's captured HTML.
Anything you chose not to bring across has to be named here, or it counts as lost content.

---

## Measurement configuration

Analytics and consent settings live with the site, not here. What the system needs to know
is only which of them **must exist**, so it can fail when they do not:

```jsonc
{
  "measurement": {
    "containerId": "GTM-XXXXXXX",
    "analyticsId": "G-XXXXXXXXXX",
    "conversionId": "AW-000000000",

    // Their event names, LITERALLY. Renaming a client's events silently
    // breaks every report and every audience they already have.
    "events": ["form_submit", "phone_click", "whatsapp_click"],

    // Consent Mode v2 is not optional in the EU, and "the banner exists"
    // is not the check. The check is that nothing fires before consent.
    "consentMode": "v2"
  }
}
```

> On one migration the entire analytics, GA4 and Ads stack went missing, with the
> conversion measuring zero, and **9 of its 11 events** with it — while every gate was
> green. Two of those were found by the client asking, not by any check. This block
> exists so that the gate has something to count against.

---

## What to keep out of version control

The `.gitignore` shipped here already covers it:

- `*.conf` (except `*.conf.example`) — they may carry hostnames and upload commands.
- `.qa-receipt` — per-site, per-run, and superseded on every deploy.
- The holes file — it records what is owed **by the client**, in internal language.
  It is excluded from deployment on purpose, on every site.
