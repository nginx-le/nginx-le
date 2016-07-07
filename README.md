# NGINX-LE - Nginx web and proxy with automatic let's encrypt

Simple nginx image (alpine based) with integrated [Let's Encrypt](https://letsencrypt.org) support.

## How to use

- get docker-compose.yml and change things
    - set `LETSENCRYPT=true` if you want automatic certificate install and renewal
    - `LE_EMAIL` should be your email and `LE_FQDN` for domain
    - alternatively set `LETSENCRYPT` to `false` and pass your own cert and key in `SSL_CERT` and `SSL_KEY`

- use provided `etc/service-example.conf` to make your own. Don't change bottom part (server on 80) - it needed to renew LE certificate
- if you don't want pre-built image, make you own. `docker-compose build` will do it

## Some implementation details

- image uses alpine's `letsencrypt` package.
- `script/entrypoint.sh` requests LE certificate and will refresh every 60 days.
- `script/le.sh` gets SSL
- nginx-le on [docker-hub](https://hub.docker.com/r/umputun/nginx-le/)

## Alternatives
- [Caddy](https://caddyserver.com) supports Let's Encrypt directly.
- [leproxy](https://github.com/artyom/leproxy) small and nice (stand alone) https reverse proxy with automatic Letsencrypt
- [bunch of others](https://github.com/search?utf8=✓&q=nginx+lets+encrypt)

## Status

Work in progress. It was extracted from another (working) project, but not fully tested yet as a separate thingy.
