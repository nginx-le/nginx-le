# NGINX-LE - Nginx web and proxy with automatic let's encrypt [![Docker Automated build](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/umputun/nginx-le/) 

Simple nginx image (alpine based) with integrated [Let's Encrypt](https://letsencrypt.org) support.

## How to use

- get [docker-compose.yml](https://github.com/umputun/nginx-le/blob/master/docker-compose.yml) and change things:
  - set timezone to your local, for example `TZ=UTC`. For more timezone values check `/usr/share/zoneinfo` directory
  - set `LETSENCRYPT=true` if you want an automatic certificate install and renewal
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
- you can map multiple custom config files to in compose using `service*.conf` filename pattern, 
  see `service2.conf` in [docker-compose.yml](https://github.com/nginx-le/nginx-le/blob/master/docker-compose.yml)
  file for reference

  Alternatively, mount directory with `*.conf` files into `/etc/nginx/conf.d-le` directory inside
  the container to have them all copied at once.
- `stream*.conf` files are picked up into `/etc/nginx/stream.d/` directory and included into `stream`
  section of the Nginx configuration, see `stream2.conf` in `docker-compose.yml` file for reference.
  
  Alternatively, mount directory with `*.conf` files into `/etc/nginx/conf.d-le` directory inside
  the container to have them all copied at once.
- pull image - `docker-compose pull`
- if you don't want a pre-built image, make you own. `docker-compose build` will do it
- start it `docker-compose up`

### Configuration files variables replacement

On start of the container all following text matches in custom configuration files you mounted will be replaced,
variable with dollar sign (`$`, like `$LE_FQDN`) will be taken from environment, please see next table for their list.

| Matching pattern | Value | nginx usage | Description |
| ---------------- | ----- | ----------- | ----------- |
| SSL_CERT       | `/etc/nginx/ssl/$SSL_CERT`       | `ssl_certificate` | Public SSL certificate, sent to client |
| SSL_KEY        | `/etc/nginx/ssl/$SSL_KEY`        | `ssl_certificate_key` | SSL private key, not sent to client |
| SSL_CHAIN_CERT | `/etc/nginx/ssl/$SSL_CHAIN_CERT` | `ssl_trusted_certificate` | Trusted SSL certificates, not sent to client |
| LE_FQDN        | `$LE_FQDN` | `server_name` | List of domains, useful for configuration with single `server` block |

### Environment variables list

| Variable | Default value | Description |
| -------- | ------------- | ----------- |
| SSL_CERT       | `le-key.pem` | certbot `privkey.pem` new filename     |
| SSL_KEY        | `le-crt.pem` | certbot `fullchain.pem` new filename   |
| SSL_CHAIN_CERT | `le-chain-crt.pem` | certbot `chain.pem` new filename |
| LETSENCRYPT | `false` | Enables Let's Encrypt certificate retrieval and renewal |
| LE_FQDN     | | comma-separated list of domains for Let's Encrypt certificate, required if `LETSENCRYPT` is `true` |
| LE_EMAIL    | | comma-separated list of emails for Let's Encrypt certificate, required if `LETSENCRYPT` is `true` |
| TZ          | | Timezone, if set will be written to container's `/etc/timezone` |

## Some implementation details

**Important:** provided [nginx.conf](https://github.com/umputun/nginx-le/blob/master/conf/nginx.conf) handles 
http->https redirect automatically, no need to add it into your custom `service.conf`. In case if you need a custom server on
http (:80) port, make sure you [handle](https://github.com/umputun/nginx-le/blob/master/conf/nginx.conf#L62) `/.well-known/` 
path needed for LE challenge.  

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

## Examples

- [Reverse proxy](https://github.com/umputun/nginx-le/tree/master/example/webrtc) for WebRTC solutions,
  where you need multiple ports on one domain to reach different services behind your `nginx-le` container.

## Manual certificate renewal (`*.example.com`, DNS challenge)

<details>
<summary>wildcard certificate renewal</summary>


In your `docker-compose.yml` disable automatic Let's Encrypt certificate creation/renewal.
```yaml
    environment:
      - LETSENCRYPT=true
```

```shell
# after starting nginx-le connect to it
docker exec -it nginx sh

# change `*.example.com` to your domain name
certbot certonly \
    --manual \
    --manual-public-ip-logging-ok \
    --preferred-challenges=dns \
    --email "${LE_EMAIL}" \
    --agree-tos \
    -d "*.example.com"

# it will ask you to create/update TXT DNS record
# depending on your DNS provider it can take some time
# you can check if DNS is already updated using dig utility
dig txt _acme-challenge.example.com

# copy certificates for nginx-le to use them
cp -fv /etc/letsencrypt/live/example.com/privkey.pem /etc/nginx/ssl/le-key.pem
cp -fv /etc/letsencrypt/live/example.com/fullchain.pem /etc/nginx/ssl/le-crt.pem
cp -fv /etc/letsencrypt/live/example.com/chain.pem /etc/nginx/ssl/le-chain-crt.pem

# use the same procedure for renewal
```

</details>
