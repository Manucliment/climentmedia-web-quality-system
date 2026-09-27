# The battery for `structure-gate.js`

A gate that has only ever been seen green proves nothing. These are the controls it was
calibrated against, kept so they can be repeated whenever the gate is touched.

## The pair that matters

`prose-fabricated.html` and `guide-laid-out.html` carry **the same 32 paragraphs**, word for
word. The second one also has a table, an accordion and a closing block — so it has **more
text** (1,810 words against 1,401).

| | verdict | isProsePage |
|---|---|---|
| `prose-fabricated.html` | **FAILS** | **true** |
| `guide-laid-out.html` | **PASSES** | false |

If those two ever agree, the gate has stopped measuring layout and started measuring
quantity of text. **It is the one case to look at every single time.**

## Running them

```bash
bash battery.sh
```

```bash
bash run-gate.sh     <id> file.html <base> '{}'
```

```bash
bash run-gate-390.sh <id> file.html <base> '{}'
```

The first runs every check at 1440px. The second measures one file on the desktop viewport.
The third measures one file at **a real 390px**.

`run-gate-390.sh` loads the page inside an `<iframe width=390>` for a specific reason:
headless Chrome on Windows **clamps `--window-size` to about 500px**, so asking for 390
returns a crop dressed up as a phone. **Always check the `innerWidth` in the output** before
believing any number that came out of it.

## Cases that are NOT MEASURED here

Eight cases were written against live client pages, fetched with `curl` and measured with a
`<base href>` so they resolve their CSS and the gate sees the real path and origin. Those
captures are **not published** — they are somebody else's website.

Those cases report `NOT MEASURED` individually, are counted separately, and make the battery
exit `3` if any were skipped and nothing else failed. They are neither passing nor failing:
nobody asked them. To close the gap, freeze pages from a site you own:

```bash
perl ../qa-master.pl <URL> --una-sola --sin-recibo --cache <cache-dir>              # measure once
perl ../qa-master-tests/freeze-fixture.pl <cache-dir> <fixture-dir> <host>           # copy it out
```

(`freeze-fixture.pl` copies one host's entries from qa-master's cache; it does not download.
The `<URL> <name>.html` form this README gave until 2026-09-26 stops at the usage line.)

## The two frozen fixtures

`mould-home-broken.html` and `contrast-control.html` are **never regenerated**. They exist to
prove the gate sees two defects it used to miss.

- **`mould-home-broken.html`** is the home page as composed before the moulds moved their
  shared rules into `_base.css`. Four of its seven sections sit at 568px instead of 1120, and
  the grid collapses to 173–189px per cell, because the moulds all declared `.sec__in` and
  the last `<style>` won. **The gate passed it**: `VERDICT: PASS · failures: [] ·
  medianCpl: null`. That `null` was the clue — the only width measurement there was never ran,
  because no paragraph on the page reaches 200 characters. *A positive control that passes
  over nothing does not calibrate a gate, it excuses it.* Today it fails on `MIN-WIDTH`.
- **`contrast-control.html`** carries **4 cases that must fail and 4 that must pass** on one
  page, with the ratios written down. Two are in `oklch`, which is where `getComputedStyle`
  returns `oklch(...)` rather than `rgb(...)`: without resolving the colour first, the rule
  measures nonsense. Two values are pinned to published references (`#999999` = 2.85:1 and
  `#6b7280` = 4.83:1, Tailwind's gray-500) so it is visible that the arithmetic is WCAG's and
  not somebody's own.

## The gates on the MOULDS

These do not judge a page. They judge the repertoire in [`../../blueprint/moulds/`](../../blueprint/moulds/).
All four run from one command, and each has its own negative control.

```bash
bash battery-layout.sh
```

| Script | What it prevents | Negative control |
|---|---|---|
| `chk-collisions.pl` | Two moulds declaring the same selector; a mould overwriting the chassis (`.sec`, `.sec__in`, `.btn`…); a mould declaring `:root`/`body`/`h2` globally; a class used without its `.mNN-` prefix | `fixtures-collision/` — **six** files, one per rule (C1..C6). `test-collisions.sh` runs them and also checks that one broken mould does not contaminate the positive case |
| `measure-contrast.sh` | A brand colour change in `_tokens.css` dropping text below AA without anybody noticing | `fixtures-contrast/` — a plausible client tint that **has to fail** |
| `measure-layout.sh` / `-390.sh` | A mould escaping its width, overflowing, or losing its line length | `innerWidth` is printed first: if it is not what was asked for, the measurement is thrown away |
| `run-gate.sh P1-molde` | The repertoire, used correctly, failing the structure gate | the long-standing positive control |

**Why they exist.** The 19 moulds each carried a full `<style>`; fifteen of them defined
`.sec__in` at **five different widths**, and on composition the last one won: **33 of the 45
containers across 7 compositions were outside their intended width**, and the home page had 4
of 7 sections at 568px. On top of that there were **6 elements below AA** in the moulds
themselves (worst: 3.04:1) that nobody had ever seen, because contrast is not visible by
looking. Neither problem raises an error: the page merely comes out narrower, and slightly
greyer.

`layout-summary.pl` turns the JSON into the three tables people actually read — `widths` ·
`contrast` · `cpl`. The probe is `measure-layout.js`.

## Generators

`mk-prose.sh`, `mk-guide.sh` and `mk-mould.sh` regenerate the three composed files. The third
builds a page from the moulds in whatever order it is given.

> ⚠️ The order it originally shipped with came from a table in the layout vocabulary that was
> **deleted**. The single source is
> [`../../blueprint/09-page-types.md`](../../blueprint/09-page-types.md) §2, and that order is
> missing `process`/05 — see the header of `mk-mould.sh`.

`fill-hrefs.awk` replaces the template's `href="#"` with real destinations. It uses
`index()`/`substr()`, **not** `gsub()`: in awk an `&` on the replacement side also means
"whatever matched", and these pages are full of HTML entities.

## Frontiers 7–9: what a one-page site cannot be asked for

Added 2026-09-27 ([trap §86](../../docs/traps/86.md)) after two one-page sites failed four checks
and three of the four were the gate's. Each frontier has a case that must pass and the red cases
that keep "stopped accusing" from being "stopped looking". All nine were run against the previous
gate first: **18 OK · 5 MAL**, the five being exactly the new behaviour (EN1, EN2, NV1, K1, K2).

| Frontier | Cases | What they hold |
|---|---|---|
| 7 · `ENLACES` | EN1–EN4 on `one-page-about.html` | The minimum is capped by the **other content pages the sitemap lists** (legal pages excluded). No readable sitemap, or a page linking a content page the sitemap omits (EN4, built from the same fixture with one nav link added), gets the full minimum |
| 8 · `VARIEDAD` | NV1–NV2, composed from the moulds in `work/` | The house's own `nosotros` template (01 + 02 + 06 + 11) must reach its type's floor; the same page with its context in prose must not |
| 9 · `ANCHO-MIN` | K1–K3 | A **figure** cell is judged by its figure on one line, not by the 240px card floor (`figure-band-narrow.html`, `figure-band-broken.html`); **cards** with a big number are still cards (`figure-cards-narrow.html`) |

The sitemap never comes from the network here: a `file://` copy cannot read its origin's sitemap,
so the gate says so and applies the full minimum, and the cases hand it the list in
`__GATE__.sitemap`.
