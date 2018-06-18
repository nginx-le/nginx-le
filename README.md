# NGINX-LE - Nginx web and proxy with automatic let's encrypt [![Docker Automated build](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/umputun/nginx-le/) 

Simple nginx image (alpine based) with integrated [Let's Encrypt](https://letsencrypt.org) support.

## How to use

- get [docker-compose.yml](https://github.com/umputun/nginx-le/blob/master/docker-compose.yml) and change things:
  - set timezone to your local, for example `TZ=UTC`. For more timezone values check `/usr/share/zoneinfo` directory
  - set `LETSENCRYPT=true` if you want automatic certificate install and renewal
  - `LE_EMAIL` should be your email and `LE_FQDN` for domain
  - for multiple FQDNs you can pass comma-separated list, like `LE_FQDN=aaa.example.com,bbb.example.com`
  - alternatively set `LETSENCRYPT` to `false` and pass your own cert in `SSL_CERT`, key in `SSL_KEY` and `SSL_CHAIN_CERT`
  - use provided `etc/service-example.conf` to make your own `etc/service.conf`. Keep ssl directives as is:
    ```nginx
    ssl_certificate SSL_CERT;
    ssl_certificate_key SSL_KEY;
    ssl_trusted_certificate SSL_CHAIN_CERT;
    ```
- make sure `volumes` in docker-compose.yml changed to your service config
- you can map multiple custom config files in compose for any `service*.conf` (see [docker-compose.yml](https://github.com/umputun/nginx-le/blob/master/docker-compose.yml) for `service2.conf`)
- pull image - `docker-compose pull`
- if you don't want pre-built image, make you own. `docker-compose build` will do it
- start it `docker-compose up`

## Some implementation details

- image uses alpine's `certbot` package.
- `script/entrypoint.sh` requests LE certificate and will refresh every 10 days in case if certificate is close to expiration (30day)
- `script/le.sh` gets SSL
- nginx-le on [docker-hub](https://hub.docker.com/r/umputun/nginx-le/)
- **A+** overall rating on [ssllabs](https://www.ssllabs.com/ssltest/index.html)

![ssllabs](https://github.com/umputun/nginx-le/blob/master/rating.png)

## Alternatives

- [Træfik](https://traefik.io) HTTP reverse proxy and load balancer. Supports Let's Encrypt directly.
- [Caddy](https://caddyserver.com) supports Let's Encrypt directly.
- [leproxy](https://github.com/artyom/leproxy) small and nice (stand alone) https reverse proxy with automatic Letsencrypt
- [bunch of others](https://github.com/search?utf8=✓&q=nginx+lets+encrypt)
