#!/bin/sh

# tests for the request limits in conf/nginx.conf, run them inside the image built from this repository:
#   docker build -t nginx-le .
#   docker run --rm --entrypoint sh -v "${PWD}":/repo:ro nginx-le /repo/tests/nginx_conf_test.sh
# a real nginx runs with the config from the working tree and serves the built-in port 80 server

CONF=$(cd "$(dirname "$0")/../conf" && pwd)/nginx.conf
FAILED=0

mkdir -p /etc/nginx/ssl
openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparams.pem 1024 2>/dev/null
# the base image links both logs to the console
rm -f /var/log/nginx/access.log /var/log/nginx/error.log

head -c 5000 /dev/zero | tr '\0' a >/tmp/5k
head -c 1100000 /dev/zero | tr '\0' a >/tmp/1100k
long=$(cat /tmp/5k)

# check name "expected status" url curl-args...
check() {
    name=$1
    want=$2
    url=$3
    shift 3
    got=$(curl -s -o /dev/null -w '%{http_code}' "$@" "${url}")
    if [ "${got}" = "${want}" ]; then
        echo "ok   ${name}"
    else
        echo "FAIL ${name}: expected ${want}, got ${got}"
        FAILED=1
    fi
}

if ! nginx -c "${CONF}"; then
    echo "FAIL nginx did not start"
    exit 1
fi

check "5000-byte body reaches the server" 301 http://127.0.0.1/ --data-binary @/tmp/5k
check "5000-byte cookie reaches the server" 301 http://127.0.0.1/ -H "Cookie: s=${long}"
check "5000-byte query string reaches the server" 301 "http://127.0.0.1/?q=${long}"
check "body over 1m rejected" 413 http://127.0.0.1/ --data-binary @/tmp/1100k

nginx -c "${CONF}" -s stop

cat >/etc/nginx/conf.d/limits-test.conf <<'CONFD'
client_max_body_size 10m;
large_client_header_buffers 4 16k;
CONFD
if nginx -t -c "${CONF}" >/tmp/nginx-t.log 2>&1; then
    echo "ok   limits can be set for all servers from conf.d"
else
    echo "FAIL limits set from conf.d: $(grep emerg /tmp/nginx-t.log)"
    FAILED=1
fi
rm -f /etc/nginx/conf.d/limits-test.conf

if [ ${FAILED} -eq 0 ]; then
    echo "all tests passed"
else
    echo "some tests failed"
fi
exit ${FAILED}
