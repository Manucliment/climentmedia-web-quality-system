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
