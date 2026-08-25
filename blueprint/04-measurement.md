# Measurement: preserve the client's, not yours

> **"Zero third parties" is a principle for YOUR site, not the client's.**
>
> On our own site we decided it and it is declared in the privacy policy. On a client's site
> the tag manager **is business infrastructure**: removing it is not hygiene, it is switching
> off the measurement of their campaigns.

---

## 1 · What it cost to learn this

One migration went to zero third parties, and with it went:

| | |
|---|---|
| The tag container | `GTM-XXXXXXX` |
| Analytics (inside the container) | `G-XXXXXXXXXX` |
| **Google Ads (inside the container)** | **`AW-000000000`** |
| The conversion trigger | the pageview their thank-you page pushed to the data layer |

The lead conversion fires **on the thank-you page**. Without the container nothing was
recorded: whoever was paying for those clicks would have been measuring zero, and nothing on
the site would have indicated it. Not one console error.

It was caught by somebody asking **"does the form redirect to the thank-you page? that is
where the conversion tracking was."** No gate caught it.

---

## 2 · Inventory, before touching anything

```bash
# in their code
grep -rnP 'gtag|dataLayer|fbq|GTM-|AW-|G-[A-Z0-9]{6,}|hotjar|clarity' src/ --include='*.ts*'

# and the container is PUBLIC: download it and look at what is inside
curl -s "https://www.googletagmanager.com/gtm.js?id=GTM-XXXXXXX" \
  | grep -oE 'AW-[0-9]+|G-[A-Z0-9]{8,}|DC-[0-9]+' | sort -u
```

That second command is the one that matters: **the ads ID is almost never in their code**, it
is inside the container. Looking only at the repository gives you a false "there is no Ads".

Also: their config file usually has the IDs; the root layout loads them; and the cookie banner
tells you which categories they manage.

---

## 3 · The order, which is half the work

```html
<!-- 1. FIRST the default, everything denied -->
<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}
gtag('consent','default',{'ad_storage':'denied','ad_user_data':'denied',
'ad_personalization':'denied','analytics_storage':'denied','wait_for_update':500});</script>

<!-- 2. THEN the container -->
<script>(function(w,d,s,l,i){...})(window,document,'script','dataLayer','GTM-XXXXXXX');</script>
```

> **The other way round, the container starts unrestricted and sets cookies before anybody
> accepts.** The banner looks exactly as good, the site looks correct, and it is in breach.
> **You cannot detect it by looking at the page**: you have to look at the order in the
> `<head>`, or at the data layer in the browser.

`wait_for_update: 500` gives half a second for the stored decision to arrive before the tags
decide on their own.

---

## 4 · The banner

You replicate **theirs**: copy, categories, and **their storage key**.

> **The key matters.** If it changes, everybody who had already chosen gets asked again. It
> looks like a detail and it is real friction on people who already decided.

On a static site with no framework: the banner is rendered **hidden** and the JavaScript opens
it only if there is no stored decision — so it does not flash for people who already chose.

**And on every load the stored decision is re-applied.** The container always starts denied;
without that step, somebody who accepted yesterday would not be measured today.

On save: a consent update with granted/denied **and** a data-layer event, so the container's
own triggers can react.

And a **"manage cookies"** link in the footer that reopens it: in the EU, being able to change
your mind is mandatory.

---

## 5 · The conversion: by MARKER, not by URL

Their thank-you page pushes an event. You replicate **exactly the same name** — their trigger
listens for that one, not another.

```html
<body data-thanks="pageview">
```
```js
var ev = document.body && document.body.getAttribute('data-thanks');
if (!ev) return;
window.dataLayer.push({ event: ev, page_location: location.href,
                        page_path: location.pathname, page_title: document.title });
```

> **Do not look at `location.pathname`.** It breaks on a trailing slash, on `.html`, or if the
> route changes tomorrow — **and it breaks silently**: the page looks perfect and the
> conversion stops counting. A marker on the `<body>` is written by the generator and travels
> with the page.

---

## 6 · The legal pages travel with this

**With a tag manager loaded, publishing without a cookie policy is worse than any
alternative.**

The distinction to make: **writing** a new legal notice is the client's job; **publishing
theirs**, which was already on their site and already approved, is not. You copy it across as
it is — you do not improve it and you do not complete it. If something is wrong, you tell
them; you do not fix it on your own initiative.

---

## 7 · Verify in the browser, not in the HTML

That the markup is present does not prove it works. You measure:

```js
// on load
dataLayer.some(a => a[0]==='consent' && a[1]==='default')   // true, and denied
document.getElementById('cookie-consent').hidden            // false on a new visit

// after clicking "accept all"
// -> consent update granted, the consent event, banner closed

// on the thank-you page: exactly ONE event with their name. Everywhere else, zero.
```

Gate: default denied → banner visible → accept → update granted + the event → banner closed.
And the conversion event **once, and only on the thank-you page.**
