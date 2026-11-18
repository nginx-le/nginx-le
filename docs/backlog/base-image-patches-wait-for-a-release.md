---
worth: maybe
where: .github/workflows/build.yml
added: 2026-11-18
---
# published images get nginx base patches only when a release is cut

`Dockerfile` builds on the floating `nginx:1.30-alpine`, but nothing rebuilds the published image when
upstream moves that tag. v1.8.0 kept shipping nginx 1.30.5 after 1.30.6 and 1.30.7 fixed a batch of CVEs
(nginx2root), until issue #109 asked for a bump and v1.9.0 was cut.

A scheduled workflow that rebuilds the latest tag and pushes `:<tag>` and `:latest` would close the gap.
It needs the same `PKG_TOKEN` and `DOCKER_HUB_TOKEN` repo secrets the tag publish in `build.yml` needs,
and the repo has neither: the v1.9.0 tag run failed at the ghcr.io login, and the images went out
through `make release_latest`. Upstream arm/v7 builds can lag the other platforms by hours, so a
rebuild also brings arm/v7 up once it catches up.
