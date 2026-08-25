# Security

## Reporting

Open a **private security advisory** on this repository, or write to
**manuel@climentmedia.com**. Please do not open a public issue for it. Include the
commit you are on, reproduction steps, and expected versus actual behaviour.

**Do not include real secrets, client data or production URLs in a report.** If a
reproduction needs them, say so and we will find another way.

## What this repository is, in security terms

Everything here is **local tooling**: shell, Perl and Node programs that read a directory
of static files, optionally fetch URLs over HTTP, and write reports. There is no service,
no daemon, no database, and no account.

That said, three things are worth knowing before you run it:

**It makes outbound HTTP requests.** The live-mode gates fetch the URLs of the site you
point them at, and follow links found in that site's own markup and sitemap. Point them
at sites you are responsible for.

**It executes your configuration.** The deploy configuration is a shell file, and the
door invokes the upload command you define in it. That is deliberate — the system does
not know how to upload anything, so it cannot upload to somewhere you did not name. It
also means: **treat the configuration file as code**, and do not run a configuration
somebody sent you without reading it.

**It runs a local HTTP server** when measuring a candidate tree, on a port you choose.
Choose a port nothing else is using. A port already occupied answers `200` and you end up
measuring **somebody else's site** while believing you measured yours.

## Secrets

No file in this repository should ever contain a credential.

- Configuration files (`*.conf`, `config.md`) are `.gitignore`d. Only `*.example` files
  are tracked.
- The receipt (`.qa-receipt`) is `.gitignore`d. It carries the site's file hashes and its
  list of unmeasured items — nothing secret, but nothing anyone else needs either.
- The holes file, which records what is owed by a client, is excluded from deployment on
  purpose. It contains internal notes about a client's project.

If you find a credential, an internal hostname, a real analytics ID or a client name
anywhere in this repository, that is a bug and we want the report. Everything here was
de-personalised deliberately, with a reversible check, but a reversible check only proves
that nothing *else* changed — it cannot prove the map was complete.

## Supported versions

The `main` branch is the supported version. This is a working system, published as it
is used; there is no backport policy.
