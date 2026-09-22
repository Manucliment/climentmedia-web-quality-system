# fixtures-sites · synthetic sites served as "production"

Each folder here is one host (`site-d.example`, `cm.example`, ...) with a site written for
this bench. Its content is **invented**: it reproduces, and only reproduces, the defect (or
the correct behaviour) that the cases in `../tests.sh` check against that host.

## Why this exists

Until 2026-09-22 about half of the bench measured things this public repository cannot
ship: byte-for-byte captures of client websites, hosts anonymised to `*.example` (which
never resolve), and one agency site measured live (which fixes itself and expires its own
controls). About 120 cases could not be run by anyone. These folders replace all of them.

## How they are served

`../fake-production.pl` is a local HTTP proxy. `tests.sh` starts it, checks a sentinel, and
exports `http_proxy` for the whole run, so every `http://<host>/path` is answered from
`fixtures-sites/<host>/` with production headers (status code, content type, gzip, the
site's own `404.html`). The gate does not know it is a fixture.

- A host with no folder gets **502**, and `tests.sh` classifies any case that asks for it
  as NOT MEASURED before running it. The last block of the bench reads the server's log and
  fails if any request hit a host with no fixture, or if no request arrived at all.
- **HTTPS is refused** (CONNECT → 403). No third party is ever reached: the bench is hermetic.
  Consequence worth knowing: the gate rebuilds the GTM/gtag URLs of a page and counts them as
  resources, so on a page with a container they show up as `HTTP 0`. Weight that has to count
  as third-party is served from its own host (`terceros.example`, `site-b.example`).
- Nothing whose name starts with `_` is ever served.

## Per-site files that are not part of the site

| File | What it is |
|---|---|
| `_prod.conf` | server behaviour for this host: `gzip off` · `header <path\|prefix*> <Name: value>` · `status <path> <code>` |
| `_gtm.js` | a synthetic GTM container, passed with `--contenedor` to the cases that need MED-03/07/08 (the real one is HTTPS) |
| `_generar.pl` | the generator that wrote the tree, when there is one. Regenerate instead of hand-editing |

## Rules for adding or changing a site

1. Invented content only: no real business, person, phone, address or domain. Absolute URLs
   use `.example` hosts. `gates/leak-sweep.js` scans this folder like everything else.
2. Read the comment above each case before building for it: it describes the real defect.
   Reproduce that condition, not a similar one.
3. A case must pass for the right reason. For `PASA`, `AUSENTE` and `NO` expectations, break
   the property on purpose and watch the case go red before trusting it.
4. Keep files small. A literal that quotes a magnitude of the old real site can change, as long
   as the property the case tests does not, and the comment above it says so.

Repositories that pair with these sites (the tree that has not been deployed yet) live in
`../fixtures-repos/`.
