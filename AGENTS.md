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
- `etc/`, `example/` - sample service configs and compose setups for users
- `docker-compose.yml` - reference compose file
- `.github/workflows/build.yml` - CI

## Build and release

CI (`build.yml`) only **builds** the multi-arch image to verify it compiles -
it has no `docker login` and no `--push`. It does NOT publish anything.

Releases to Docker Hub and ghcr.io are **manual**. Make targets:

- `make release_master` - builds and pushes the current branch tag
- `make release_latest` - builds and pushes `:<git-tag>` and `:latest`

Both target `linux/amd64`, `linux/arm64`, `linux/arm/v7` via buildx.

### Deployment after tagging a release

Pushing a git tag does NOT publish the image - CI builds it and stops. The new
version reaches Docker Hub only when someone runs the release make target by
hand. This is the step that gets forgotten (see issue #86). After creating and
pushing a version tag:

1. Be on a workstation logged in to both registries: `docker login`
   (Docker Hub, user `umputun`) and `docker login ghcr.io`.
2. Check out the tagged commit so `git describe --abbrev=0 --tags` resolves to
   the new tag - the Makefile derives the image tag from it.
3. Run `make release_latest`. It builds all three platforms and pushes
   `umputun/nginx-le:<tag>`, `:latest`, and the `ghcr.io` equivalents.
4. Verify: `docker buildx imagetools inspect umputun/nginx-le:<tag>` shows the
   three platforms, and `docker run --rm --entrypoint sh umputun/nginx-le:<tag>
   -c 'nginx -v'` reports the expected version.

Until step 3 runs, `docker pull umputun/nginx-le` still serves the previous
release.

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

## Conventions

- Shell scripts run under alpine's `/bin/sh` (busybox ash), not bash - they use
  a few ash extensions (`[[ ]]`, `${var:0:1}`), so test against busybox ash
- Bump the nginx base image by editing the `FROM` line in `Dockerfile`; tag and
  run `make release_latest` to ship it
- Update `README.md` when env vars, volumes, or behavior change
