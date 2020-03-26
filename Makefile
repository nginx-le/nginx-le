GITTAG=$(shell git describe --abbrev=0 --tags)

release:
	- docker build . -t umputun/nginx-le:$(GITTAG)
	- docker push umputun/nginx-le:$(GITTAG)
	- docker push umputun/nginx-le:latest

.PHONY: release
