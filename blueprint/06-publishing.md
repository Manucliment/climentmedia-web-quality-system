# Publishing: SSL, DNS and verification

> This file exists because switch day is where being wrong costs the most, and where what we
> knew was most scattered.

---

## 1 · THE CERTIFICATE, BEFORE THE DNS

**Checked on the FIRST DAY of the project, not on switch day.**

On one migration the hosting's certificate had been **expired for 35 days**. The moment the A
records moved, the site went from *working* to **a red browser warning on every page**, with
no way out over plain HTTP because the host redirects to HTTPS.

**Why nobody saw it:** all the pre-flight verification went to the IP with certificate errors
ignored. That flag is *necessary* to connect to an IP using the domain's name — and it is
*exactly* the one that switches off the check that matters. **Twelve URLs returning 200 and
not one of them warns.**

```bash
echo | openssl s_client -connect <IP>:443 -servername <domain> 2>/dev/null \
  | openssl x509 -noout -subject -dates
```

`-servername` sends the SNI, so the server returns the domain's real certificate even though
the connection goes to the IP. **It needs no DNS. You can run it weeks in advance.**

**Gate:** it exists · it covers the domain **and `www`** · `notAfter` is in the future.

> **The circularity:** on shared hosting the certificate usually cannot be issued until the
> domain already points there. With an expired certificate, **rolling the DNS back fixes
> nothing** — it returns you to the state where it also cannot be issued. Which is why the
> order is: check it at the start, and if it is wrong, **have somebody standing by in the
> hosting panel at the moment of the switch.**

## 2 · Verify by IP, before touching anything

```bash
chrome --headless=new --ignore-certificate-errors \
  '--host-resolver-rules=MAP domain.tld <IP>' --screenshot=x.png "https://domain.tld/path"

curl --resolve domain.tld:443:<IP> -k -s -o /dev/null -w '%{http_code}' "https://domain.tld/path"
```

This is how we found a path returning a **301** because a file and a directory of the same
name coexisted. In production that would have been a 301 on an indexed URL.

**Gate, by IP:** every sitemap URL at 200 · zero 301s on indexed URLs · the leads and secrets
directories at 404 · images and fonts at 200.

## 3 · The DNS change

```bash
GET  /api/dns/v1/zones/<domain>     # read and SAVE A COPY
PUT  /api/dns/v1/zones/<domain>     # {"overwrite":true,"zone":[...]}
```

> **Before writing to a client's zone, check what the `PUT` actually means.** If it replaced
> the whole zone it would take MX, SPF and DKIM with it — the client's email. You test with a
> harmless TXT record on a subdomain that does not exist, and delete it afterwards:
>
> ```bash
> {"overwrite": true, "zone": [{"name":"_probe","type":"TXT","ttl":300,
>                               "records":[{"content":"probe"}]}]}
> # read the zone back -> are MX, SPF, DKIM still there? -> delete the probe -> then the real change
> ```
>
> Verified on one provider: it **merges by name and type**, it does not replace. Verify it on
> yours. This is a five-minute test that stands between you and deleting a client's email.

- Save the original zone to `_deploy/dns-backup/zone-before-YYYY-MM-DD.json`.
- TTL 300 on the records you touch, so you can go back in five minutes.
- **Touch nothing else**: not MX, not TXT, not nameservers.

> **A high TTL on the old record cannot be undone**: if `www` was at 14400, there is four
> hours of cache out there whatever you set it to when you change it.

## 4 · After the change: no certificate bypass

```bash
curl -s -o /dev/null -w '%{http_code} ssl=%{ssl_verify_result}\n' "https://domain.tld/"
```

`ssl_verify_result=0` is what proves the certificate is good. **With the bypass flag on, this
means nothing.**

**Final gate:** every sitemap URL at 200 with a validated certificate · apex **and** `www` ·
forms end to end (email **and** the copy on disk) · the leads and secrets directories at 404 ·
diagnostic scripts at 404 over the web · measurement firing in the browser.

## 5 · What only the client can do

It goes to them in **phone format**: one action per block, values in code blocks, zero
business context. And always with **what I will verify** when they say it is done, and **what
the rollback is**.

> **When you ask somebody to act on something that holds a system up, say what it holds up.**
> I once asked for a mailbox password to be "deleted or rotated" without saying it was the
> account the contact form authenticates against. "Delete" was understood — the reasonable
> reading, if nobody tells you otherwise — and sending went down silently.
