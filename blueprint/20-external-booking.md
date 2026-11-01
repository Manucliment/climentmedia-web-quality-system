# External booking — when the appointment lives on someone else's platform

Barbers, salons, clinics and physiotherapists often take their bookings on a platform they rent,
such as Treatwell, Salonized, Fresha, Planity or Booksy. The site then has one job: to get the
visitor into that booking with as little friction as possible. **The booking is the conversion,
even though it happens on another domain.**

This is where step 2 of `paths/1-new-site.md` leads when "where does each button go" answers
"to their booking platform".

---

## 1 · First, can it go inside the page?

```bash
curl -sI "<the booking URL>" | grep -iE 'x-frame-options|content-security-policy'
```

- **No header that forbids framing** → the widget or an `<iframe>` can go on the booking page.
  Test it at 390 before deciding: a widget that needs 900 px of height is worse than a link.
- **`X-Frame-Options: DENY`/`SAMEORIGIN`, or `frame-ancestors` without your domain** → it cannot
  be framed. Do not fight it, and do not proxy it. Go to §2.

## 2 · When it cannot be framed: three things to find

1. **The direct booking route.** Many platforms have a deep link that skips their own landing
   page: per salon, per service and sometimes per staff member. A button that drops the visitor
   on the platform's home page, or on a search page, is a button that loses them. Click through
   the platform as a customer and copy the URL of the step where the choice is already made.
   **Then open that URL from outside**, in a fresh browser with no cookies and from a link on
   another site. On one platform the booking step opened that way came up blank and took no
   service parameter: there was no deep link per service, only the salon's own flow.
2. **The simple flow.** Count the steps from the button to "booked": service, time, details,
   confirmation. If one route has fewer steps (book without an account, pay at the shop), that is
   the one the site links to.
3. **The public slots.** Find out whether the platform shows availability without logging in, and
   at which URL. You need to know it, even if you do not use it (§4).

## 3 · What goes on the site

- **The decision is made on the site, next to the button.** Each service shows its price, its
  duration and what is included, and its "book" button sits right there. The visitor decides
  on the site, where the copy, the photos and the reviews live; the platform only takes the slot.
  - **If the platform accepts a service already chosen** (a parameter or a link per service),
    build their own booking sheet: one page or section on their domain listing the services,
    each with its **own "book this" button** to the deep link for that service.
  - **If it does not**, do not build that sheet: the visitor would choose on the site and then
    choose again on the platform. Each "book" button opens the platform's simplest flow, and the
    price, duration and inclusions stay in front of it so the choice there is a confirmation.
- **The booking button in the hero**, whole on the first screen at 360, 390, 1366 and 1440.
  `gates/mobile-gate.js` M1 counts it as converting because its host is a known booking platform.
- **A fixed bar on mobile** with the same button. It **does not replace** the button in the hero:
  floating chrome does not count for M1 (it is on every page, so it says nothing about this one),
  and it must not cover the hero's own call to action (M2).
- **Measure the click.** The conversion happens off-site, so the site records the outbound click,
  e.g. a `book_click` event with where it was clicked from. That is the number the ads platform
  will optimise on. Cross-domain tracking only if the platform supports it, and that is the
  platform's documentation, not a guess.

## 4 · Live slots only with the owner's permission

Showing "next free slot: today 16:30" on the site converts well, and it also publishes the owner's
calendar. Read from the platform's public endpoint, it can break their terms, and it fails the day
they change it. **It goes on the site only with the owner's explicit yes, in writing**, and with a
fallback that still shows the booking button when the slots cannot be read.

## 5 · Tell the gates

In `_deploy/deploy.conf`:

```bash
# the platforms this site books on, besides the ones the gates already know (space-separated host names)
HOSTS_RESERVA="mybookingplatform.example"
```

The gates already know the common ones (`bjootify`, `treatwell`, `salonized`, `fresha`,
`planity`, `booksy`, `setmore`, `simplybook`, `timify`, `acuityscheduling`, `youcanbook`,
`doctolib`, `vagaro`, `mindbodyonline`, `phorest`, `uala`, `zenoti`). A word without a dot matches
any label of the host. With a dot, it matches that host and its subdomains. The door passes the
list to `gates/mobile-gate.js` and `gates/structure-gate.js` as `hostsReserva`.

**What not to do:** list the platform in `HOSTS_RESERVA` so that a hero that only links to the
price page turns green. The list says *where booking happens*. The button still has to go there.
