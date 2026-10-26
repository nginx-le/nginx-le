#!/bin/sh

# tests for the request limits and the TLS key exchange groups in conf/nginx.conf, run them inside
# the image built from this repository:
#   docker build -t nginx-le .
#   docker run --rm --entrypoint sh -v "${PWD}":/repo:ro nginx-le /repo/tests/nginx_conf_test.sh
# a real nginx runs with the config from the working tree and serves the built-in port 80 server
# plus a self-signed port 443 server

CONF=$(cd "$(dirname "$0")/../conf" && pwd)/nginx.conf
FAILED=0

mkdir -p /etc/nginx/ssl
openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparams.pem 2048 2>/dev/null
# rsa, because a tls 1.2 client offering only X25519 cannot accept a P-256 ecdsa certificate
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
    -keyout /tmp/tls-key.pem -out /tmp/tls-crt.pem 2>/dev/null
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

# check_group name "expected group" s_client-args...
# s_client reports a classic group as "Peer Temp Key" and a hybrid one only as "Negotiated TLS1.3 group"
check_group() {
    name=$1
    want=$2
    shift 2
    got=$(openssl s_client -connect 127.0.0.1:443 "$@" </dev/null 2>&1 |
        grep -E '^(Peer Temp Key|Negotiated TLS1.3 group):' | head -n 1)
    case "${got}" in
    *"${want}"*) echo "ok   ${name}" ;;
    *)
        echo "FAIL ${name}: expected ${want}, got '${got}'"
        FAILED=1
        ;;
    esac
}

# check_confd name directives
check_confd() {
    printf '%s\n' "$2" >/etc/nginx/conf.d/global-test.conf
    if nginx -t -c "${CONF}" >/tmp/nginx-t.log 2>&1; then
        echo "ok   $1"
    else
        echo "FAIL $1: $(grep emerg /tmp/nginx-t.log)"
        FAILED=1
    fi
    rm -f /etc/nginx/conf.d/global-test.conf
}

cat >/etc/nginx/conf.d/tls-test.conf <<'CONFD'
server {
    listen 443 ssl;
    ssl_certificate /tmp/tls-crt.pem;
    ssl_certificate_key /tmp/tls-key.pem;
    return 200;
}
CONFD

if ! nginx -c "${CONF}"; then
    echo "FAIL nginx did not start"
    exit 1
fi

check "5000-byte body reaches the server" 301 http://127.0.0.1/ --data-binary @/tmp/5k
check "5000-byte cookie reaches the server" 301 http://127.0.0.1/ -H "Cookie: s=${long}"
check "5000-byte query string reaches the server" 301 "http://127.0.0.1/?q=${long}"
check "body over 1m rejected" 413 http://127.0.0.1/ --data-binary @/tmp/1100k

check_group "X25519 over TLS 1.3" X25519 -tls1_3 -groups X25519
check_group "X25519 over TLS 1.2 with ECDHE ciphers" X25519 -tls1_2 -cipher ECDHE -groups X25519
check_group "post-quantum X25519MLKEM768 over TLS 1.3" X25519MLKEM768 -tls1_3 -groups X25519MLKEM768
check_group "P-384 over TLS 1.3" secp384r1 -tls1_3 -groups secp384r1

nginx -c "${CONF}" -s stop
rm -f /etc/nginx/conf.d/tls-test.conf

check_confd "limits can be set for all servers from conf.d" \
    'client_max_body_size 10m; large_client_header_buffers 4 16k;'
check_confd "key exchange groups can be set for all servers from conf.d" 'ssl_ecdh_curve X25519:secp384r1;'

if [ ${FAILED} -eq 0 ]; then
    echo "all tests passed"
else
    echo "some tests failed"
fi
exit ${FAILED}
