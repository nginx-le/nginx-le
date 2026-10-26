---
worth: maybe
where: script/entrypoint.sh
added: 2026-10-26
---
# startup logs a cp error when no stream configs are mounted

`entrypoint.sh` runs `cp -fv /etc/nginx/stream.conf.d-le/*.conf /etc/nginx/stream.d/` unconditionally.
With no stream configs the glob stays literal and the container logs
`cp: can't stat '/etc/nginx/stream.conf.d-le/*.conf': No such file or directory` on every start.
nginx starts fine, but the line reads like a failure to anyone scanning the log. Seen running
`LETSENCRYPT=false` with only `service.conf` mounted while reproducing issue 101.
