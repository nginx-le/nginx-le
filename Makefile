GITTAG=$(shell git describe --abbrev=0 --tags)
B=$(shell git rev-parse --abbrev-ref HEAD)
ref=$(subst /,-,$(B))

release:
	- docker buildx build --push --platform linux/amd64,linux/arm/v7,linux/arm64 -t ghcr.io/umputun/nginx-le:${ref} -t umputun/nginx-le:${ref} .

.PHONY: release
