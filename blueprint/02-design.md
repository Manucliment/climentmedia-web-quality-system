# Design: where each decision comes from

> **You never start on a blank canvas.** If they have a site, the design system is theirs and
> you have to read it. If they do not, you start from one of yours and adapt it.

---

## 1 · No site: which of your skeletons you start from

Keep this table in your own copy of the system, and **keep it as the single source.** Do not
copy a row of it into a path document — that is exactly how a path ended up naming one
skeleton while its own arrow pointed at a document naming another.

| Skeleton | What it has solved | When |
|---|---|---|
| **The default one** | Generator from a spec · flat pages · city pages for local search · form with real SMTP, a copy on disk and bounce monitoring · FAQ accordion · complete schema · `llms.txt` · self-hosted fonts · **measurement with consent mode and a banner** | **The normal case.** A local service business covering several areas that wants to be called |
| **The catalogue one** | A 40-page migration · a large catalogue of service pages | A clinic or business where each service deserves its own page |
| **The commerce one** | Step-by-step configurator · checkout | A configurable product sold online. **No generator from a spec**: the HTML is maintained by hand |

**Pick a default and say so** — ours is the first, because it is the only one with the entire
cycle verified in production (DNS, SSL, forms, SEO, measurement).

It gets copied literally: the generator, the spec's *shape* (not its content), the deploy
scripts, the stylesheet and the runtime script.

## 2 · With a site: extract THEIR system from the compiled CSS

> **Every number has to be pointable back to its origin.** If you cannot say where it comes
> from, you invented it.

| Source | What it gives | How |
|---|---|---|
| Their **compiled CSS** | container widths, gradients, colour tokens | `curl` the stylesheet in their `<head>` |
| The **classes in the HTML** | line widths, scales, padding | `grep -oP '<h1[^>]*class="[^"]*"'` |
| Their **components** | what each block is and when it appears | read the component source |

With a utility-first framework, the classes **are** the specification (`max-w-3xl`,
`py-14 md:py-20`, `text-4xl md:text-5xl lg:text-6xl`); you only have to resolve the variables:

```bash
grep -oP '\.container[a-z-]*\{[^}]*\}' their.css
grep -oP '\-\-container-(2xl|3xl):[^;]*;|\-\-spacing:[^;]*;' their.css
```

> **Dump the home page hero AND an interior one, and compare.** On one migration the badge,
> the three buttons and the tick list were **home-page only**; applying the home hero's
> configuration everywhere invented elements on 16 pages.

## 3 · What you always change (greenfield) — or they are the same site

Five levers. Move three of them properly and two sites built on the same skeleton stop being
recognisable as siblings.

**Palette** — from their brand. If there is none, propose **two** and let them choose. In
OKLCH, hue and chroma move the entire system.
> Contrast is measured by **reading the pixel from a canvas**. Over a computed style it can
> come back in a colour space you did not expect and give false results — once, 2.30:1 on six
> rows, and it was a lie. See `14-accessibility.md`.

**Typography** — the display + text pairing is what changes the character most.

**Hero shape** — one column left · two columns with a photo · centred with a badge · with a
trust band attached or without one.

**Card treatment** — hairline border · shadow · full-bleed photo · icon in a pill. It is the
most repeated element, and the one that gives you away fastest.

**Section order** — this is a business decision: services first if they already know what they
want; social proof if it is a trust purchase; areas covered if the real doubt is *"do you come
to my town?"*.

### Before writing a component, check whether it already exists — **in this order**

**It is a step, not a suggestion.** And the order matters: you start with the largest thing
that would do the job. Looking for a button when what is missing is a whole section is how you
end up laying out a guide with bare paragraphs.

**1 · Is it a SECTION? → the moulds folder.** First, because it is what is needed most often
and improvised worst.

```bash
ls   blueprint/moulds/
grep -il "compare\|table" blueprint/moulds/*.html
```

Which sections each page type carries, in what order, and which are mandatory:
**`09-page-types.md §2`**. That is the single source — the catalogue in
`10-layout-vocabulary.md` says what each primitive *is*, **not** what each page carries.

**2 · Is it a loose PIECE?** (a button, a badge, an icon set, a mega-menu)
**→ your component index.**

If something comes back, you open that mould **before** writing anything.
If nothing does, you build it, **and you register it in the index when you finish**, with its
code and its *"when NOT to use this"*.

**3 · Your own pieces already in production → your canon document.**
> If that document is superseded, **say so in its own header** and say which parts are still
> good. Ours was superseded by a structural change and **none of its routes resolved any
> more** — every one of them redirected. It is still good for the decisions and the data; it
> is no good for building anything.

Somebody here wrote a numbered-steps component from scratch with an approved one already in
the canon. That was not carelessness: **twelve files with no index are not a library, they are
a folder**, and finding out what each one was meant opening it.

> **The "when NOT" is half the value.** A hero badge ended up on 17 pages for want of one: it
> was for the home page only.

## 4 · Typography: self-host, never link

- A migration that goes to **zero third parties for fonts** is broken by linking a font CDN.
- In the EU, serving them from the browser sends the visitor's IP to the provider, and that has
  already produced GDPR rulings.
- **Falling back to a system font is not neutral.** A serif fallback made headlines about 15%
  wider, and the `h1` broke onto four lines where theirs took three. It looks like a layout
  bug and it is the font.

```bash
curl -s -A "Mozilla/5.0 ... Chrome/126" "https://fonts.googleapis.com/css2?family=..." > gf.css
# keep latin and latin-ext · they are VARIABLE fonts: 4 files, not 16
# @font-face with its unicode-range + font-display:swap + preload the latin subset
```

Check the licence and keep the licence file next to the fonts.

## 5 · Images

### The rule that is not negotiable

> **A generated image is NEVER presented as a real person, team, premises or result belonging
> to the client.**

| | Generated | Client supplies it, or it does not ship |
|---|---|---|
| Portrait of a named team member | no | **yes** |
| Premises, frontage, treatment room | no | **yes** |
| A qualification, diploma or certification | no | **yes** |
| Before/after, case study, result | no | **never without written permission** |
| Service illustration, supporting texture, `og:image` | **yes** | |

A generated photo of "our team" is a false statement about people who exist. In healthcare, a
generated before/after is misleading advertising across most of the EU.

**The `alt` describes what is visible, without attributing it.**
- Good: `Physiotherapist working with a patient at home`
- Bad: `Our physiotherapist Lena during a session`

If they want photos of their team and have none: **the section does not exist yet.** You say
so, and you ask them for five photos taken on a phone.

### Where `og:image` comes from when the client has no images at all

The checklist demands one on every page and no step said where they come from. This is the
route:

1. **They are not a photo: they are a card.** HTML plus the site's own CSS, carrying the
   page's H1, the brand and a graphic mark. Generated by **the same loop** as the pages, and
   living in the spec directory.
2. **They are rasterised ON A LINUX HOST, never locally on Windows.** Headless Chrome there
   clamps the window width to about 500px and the capture comes out cropped: a card "at 1200"
   would be cut off and look like a design defect.
3. **The renderer prints each card's `innerWidth` and discards any that does not match 1200.**
   A measurement that does not match what was asked for is not a result, it is rubbish.
4. **`og:image:alt` is mandatory** and a check measures it.

> This does not contradict the rule above: a composed card carrying the business name and its
> own H1 asserts nothing false about them. An invented photo of "their" premises does. The
> rule stands — without the client's photos the evidence sections **do not exist yet** — but a
> site with no `og:image` gets shared on messaging apps as a grey rectangle, and that is the
> real recommendation channel for a local business.

### With a site: their images are theirs, and you bring ALL of them

On one migration **6 of their 19** were being served, including the logo, because the
extractor took only the first image in each section. **The pairing comes from their code** —
their source has a map from id to import — not from the order on the page: they already had
two decorative icons with empty `alt` in the middle.

### Generating: inventory, prompt, review

**List and approve the gaps BEFORE spending anything.**

The prompt has four parts: **who/what · where · how it looks · what NOT**.

```
A physiotherapist working on an older person's knee mobility, seated on the sofa
at home · bright everyday living room, not clinical · natural photography, soft
window light, warm desaturated colours · no text, no logos, no branding, no
heavy medical equipment
```

- Repeat the "how it looks" clause **literally** across the whole batch: it is what makes them
  look like they come from the same place.
- Name the country or the type of home: a Belgian living room is not an Andalusian one.
- **Always "no text"**: invented lettering reads as a mistake.
- Ask the model for the aspect ratio; cropping afterwards decentres the subject.

> Model names date within months. Frame with a fast model, produce the final one with a good
> one, and check what your provider offers today rather than trusting a list in a document.

**Afterwards:** look at them (hands, faces, stray text) · resize to what you actually serve ·
WebP if heavy · `width`/`height` on the `<img>` · `loading="lazy"` below the fold · `alt`
written by hand · **save the prompt**, because in six months you will need another one that
matches.

**And you tell the client** the illustration images are generated.

---

## 6 · Reading somebody else's design system, and what it is worth

Measured 2026-09-02 on two component libraries held up as good design — one dark, one light.
The point is not to copy them. It is that **a reference is a measurement opportunity**, and
these two answer questions our own tokens cannot answer alone.

### 6.1 · Computed style no longer returns `rgb()`, and the canvas trick alone is not enough

Their colours come back as **`lab(2.75381 0 0)`** and **`oklab(0.999994 … / 0.4)`**. Two things
follow, and both cost a measurement to learn:

- **Parsing the digits out of that string as if they were RGB produces a confidently wrong
  number.** This system already has that scar — a hand-written meter read `oklch(0.99 0.005 210)`
  as `rgb(0.99, 0.005, 210)` and reported **1.00:1 on a button that was fine**.
- **Setting `fillStyle` and reading it back is no longer a conversion.** Chrome now returns
  `lab(…)` unchanged, so the old trick yields the same unparseable string and any ratio comes
  out `NaN`. **You have to actually rasterise**: paint one pixel and read it with
  `getImageData`.

✅ **Our own meter already does this** — `measure-layout.js:32`, *"color() / oklab() / lab(): let
the engine resolve it by painting one pixel"*. Written before it was needed, and it is why
`measure-contrast.sh` would survive auditing a client site built this year.

### 6.2 · The failure mode of every dark theme, with numbers

Their dim text is expressed as **white at an alpha**, which is the normal way to do it and the
way it silently fails. Composited against their `#0a0a0a` background:

| alpha | composited | ratio | |
|---|---|---|---|
| 0.9 | `#e6e7e7` | 15.98 | ✅ |
| 0.8 | `#cecece` | 12.58 | ✅ |
| 0.6 | `#9d9d9d` | 7.30 | ✅ |
| 0.5 | `#848585` | 5.35 | ✅ |
| **0.4** | `#6c6c6c` | **3.77** | 🔴 below AA |
| **0.3** | `#535454` | **2.61** | 🔴 below AA |

**And 0.4 is the one they use most: 39 text elements, plus 3 at 0.2.** Forty-two elements below
AA on a site whose headline is *"Beautiful Components Built for designers"*.

> 🔑 **This is not a new lesson here — it is external confirmation of the one this system was
> built on.** `measure-contrast.sh` opens with *"contrast cannot be seen by looking: `opacity:.4`
> over `--tinta` = 3.82:1"*. Their number is **3.77**. The same alpha, the same failure, on a
> design system with a far bigger audience than ours. **The rule is not our idiosyncrasy.**

**So: dim text is a declared colour token, never an alpha.** An alpha is chosen by eye against a
large dark surface, and the composite is never computed. A token can be measured once.

### 6.3 · The two-register type scale

Both sites, counted by element:

| | dark one | light one |
|---|---|---|
| dense UI band | 10px ×42 · 12px ×46 · 14px ×49 | 10px ×119 · 14px ×77 · 16px ×49 |
| display | 41.9 · 48 · **80** | **96** |
| in between | almost nothing | almost nothing |

**There is no mid-range.** Not a scale of eight steps used evenly — two registers with a gap.
It reads as confidence, and it is cheap to imitate badly: the 10px band works because it is
labels and metadata, never prose. Our own reading floor (`11-measurements.md §6`, and the CPL
gate) is what stops that becoming 10px body text, and **that constraint stays**: this section
does not introduce a second scale, and the one that rules is still §6 of `11-measurements.md`.

### 6.4 · One typeface carries the personality, and it is not the body font

The dark one runs **161 of ~183 text elements in a monospace**; the light one uses a pixel-square
display face on 110 elements next to its sans. Neither is decorating: the typeface *is* the
positioning — "for builders" — said without a word of copy.

⚠️ **Transferable selectively.** It fits a developer tool and our own site. It is wrong for a
physiotherapist: a clinic that sets its prices in monospace looks like a terminal, not like care.
**Ask what the typeface claims before borrowing it.**

### 6.5 · And the defect that keeps repeating in modern references

**Of five modern reference sites measured across two days, ONE has its visible headline as the
`<h1>`.** The dark library's `<h1>` is **16px** while the headline you actually read is 80px; the
three funnel templates of `09 §2.12` ship **zero `<h1>`** between them. Only the light library
gets it right — its `<h1>` is the 96px headline.

That is 1 of 5, on sites built by people who are good at this. **It is why `SEO-09` and `SEO-05`
exist**, and it is the clearest possible argument that "everyone does it" is not evidence of
anything. Take the composition; check the document underneath yourself.
