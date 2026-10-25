# AGENTS.md

Guidance for AI agents working in this repo.

## What this is

`nginx-le` is a Docker image: nginx plus Let's Encrypt (certbot) auto-provisioning
and renewal in one container. Published as `umputun/nginx-le` on Docker Hub and
`ghcr.io/umputun/nginx-le`. No application code - it is a Dockerfile plus two
POSIX shell scripts.

## Layout

- `Dockerfile` - based on `nginx:<ver>-alpine`, adds certbot, tzdata, openssl
- `conf/nginx.conf` - baked-in main nginx config
- `script/entrypoint.sh` - container entrypoint (`CMD`); sets TZ, assembles
  configs, starts the cert-renewal loop, then `exec nginx`
- `script/le.sh` - certbot wrapper; renews when the cert is within 30 days of
  expiry, misses an expected domain, doesn't match the installed key, or has no
  chain file
- `tests/le_test.sh` - regression tests for `le.sh`, certbot and `cp` stubbed
- `tests/entrypoint_test.sh` - tests for the renewal loop in `entrypoint.sh`,
  `le.sh`, nginx and `sleep` stubbed
- `tests/nginx_conf_test.sh` - tests for the request limits in `conf/nginx.conf`,
  against a real nginx
- `etc/`, `example/` - sample service configs and compose setups for users
- `docker-compose.yml` - reference compose file
- `.github/workflows/build.yml` - CI

## Build and release

CI (`build.yml`) builds the multi-arch image on every push and pull request.
Only a tag push publishes: the `build` job logs in to ghcr.io and Docker Hub as
`umputun` and pushes `:<tag>` and `:latest` to both. Branch and PR builds have
no login and no `--push`. The `build` job waits for the `test` job, so a tag
with failing tests publishes nothing.

Publishing needs two repo secrets, both tokens of the `umputun` account (the
images live under that user, not the `nginx-le` org, so `GITHUB_TOKEN` cannot
push them):

- `PKG_TOKEN` - GitHub PAT with `write:packages`, for ghcr.io
- `DOCKER_HUB_TOKEN` - Docker Hub access token with write scope

All builds target `linux/amd64`, `linux/arm64`, `linux/arm/v7` via buildx.

Make targets for publishing by hand, from a workstation logged in to both
registries:

- `make release_master` - builds and pushes the current branch tag
- `make release_latest` - builds and pushes `:<git-tag>` and `:latest`

### After tagging a release

Pushing a version tag starts the CI run that publishes it. Once it passes,
verify: `docker buildx imagetools inspect umputun/nginx-le:<tag>` shows the
three platforms, and `docker run --rm --entrypoint sh umputun/nginx-le:<tag>
-c 'nginx -v'` reports the expected version.

## Tests

`tests/le_test.sh` covers `le.sh`: certificate installation, the rollback of a
failed install, and the cases where renewal is skipped. It runs inside the image,
against the scripts in the working tree:

```
docker build -t nginx-le .
docker run --rm --entrypoint sh -v "${PWD}":/repo:ro nginx-le /repo/tests/le_test.sh
```

Nothing reaches the network, certbot and `cp` are stubbed. CI runs the same two
commands in the `test` job.

`tests/entrypoint_test.sh` covers the renewal loop: how long it waits after each
`le.sh` exit code (an hour after a certbot failure, ten days otherwise) and the
reload once a certificate is in place. Run it the same way, with
`/repo/tests/entrypoint_test.sh` as the script; CI runs it in the `test` job too.

`tests/nginx_conf_test.sh` starts nginx with `conf/nginx.conf` from the working
tree and checks that a 5 KB body, cookie and query string pass, a body over 1 MB
gets 413, and the limits can be set for all servers from a `conf.d` file. Run it
the same way, with `/repo/tests/nginx_conf_test.sh` as the script; CI runs it in
the `test` job.

## Conventions

- Shell scripts run under alpine's `/bin/sh` (busybox ash), not bash - they use
  a few ash extensions (`[[ ]]`, `${var:0:1}`), so test against busybox ash
- Bump the nginx base image by editing the `FROM` line in `Dockerfile`; push a
  version tag and CI publishes it (see Build and release)
- Update `README.md` when env vars, volumes, or behavior change
