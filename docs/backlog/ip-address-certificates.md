---
worth: later
where: script/le.sh
added: 2026-10-24
---
# no support for Let's Encrypt IP-address certificates

Requested in https://github.com/nginx-le/nginx-le/issues/85. Let's Encrypt issues IP certificates only
under the `shortlived` profile (160h), and the image's certbot (5.6.0) supports `--ip-address` with
webroot and `--required-profile`. The scripts block it in three places:

- `le.sh` always passes `LE_FQDN` to `-d`, which rejects an IP ("will not issue certificates for a bare
  IP address").
- the installed-cert check greps only `DNS:` SANs; openssl prints `IP Address:11.22.33.44`, so an IP
  entry always reads as missing.
- `renew_before` is 30 days and `entrypoint.sh` sleeps 10d, both longer than a 6-day lifetime.

The same timing defect hits anyone who sets `LE_ADDITIONAL_OPTIONS=--preferred-profile shortlived` today:
the cert sits expired about 3 days of every cycle.

Order: renewal timing first (overlaps #96), then IP support.

1. a 12h loop and `renew_before = min(30d, lifetime/3)`. The threshold must scale with lifetime: certbot's
   acme client sends no ARI `replaces` field, so every le.sh order counts toward the limit of 5 identical
   certificates per 7 days, and a 12h loop with the 30-day threshold would reissue 14 times a week.
2. in `le.sh`, send each `LE_FQDN` entry to `-d` or `--ip-address`, add `--cert-name` with the first
   entry (certbot otherwise names the live dir after the first DNS name, so `1.2.3.4,example.com` copies
   from the wrong folder), add `--required-profile shortlived` when any IP is present, and check IP
   entries with `openssl x509 -checkip`. IPv4 only.
3. README: the IP cert must sit on the default TLS server for that address, clients send no SNI for IPs.
