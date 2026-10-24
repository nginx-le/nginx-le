#!/bin/sh

# tests for the renewal loop in script/entrypoint.sh, run them inside the image built from this repository:
#   docker build -t nginx-le .
#   docker run --rm --entrypoint sh -v "${PWD}":/repo:ro nginx-le /repo/tests/entrypoint_test.sh
# le.sh, nginx and sleep are stubbed, the loop stops once le.sh has returned every scripted exit code

ENTRYPOINT=$(dirname "$0")/../script/entrypoint.sh
FAILED=0

mkdir -p /stub /etc/nginx/ssl
touch /etc/nginx/ssl/dhparams.pem

cat >/le.sh <<'STUB'
#!/bin/sh
code=$(head -n 1 /tmp/le-results)
sed -i 1d /tmp/le-results
[ "${code}" = "0" ] && touch /etc/nginx/ssl/le-crt.pem
exit "${code}"
STUB
# nginx -t passes only with a certificate in place, nginx -g is the server and waits for the loop to stop
cat >/stub/nginx <<'STUB'
#!/bin/sh
case "$1" in
    -t)
        printf 'nginx -t; ' >>/tmp/calls
        [ -f /etc/nginx/ssl/le-crt.pem ]
        exit
        ;;
    -s)
        printf 'nginx -s %s; ' "$2" >>/tmp/calls
        exit 0
        ;;
esac
i=0
while [ ! -f /tmp/loop-stopped ] && [ ${i} -lt 300 ]; do
    /bin/sleep 0.1
    i=$((i + 1))
done
STUB
# sleep 5 is the startup delay, the loop stops once the scripted codes are used up
cat >/stub/sleep <<'STUB'
#!/bin/sh
[ "$1" = "5" ] && exit 0
printf 'sleep %s; ' "$1" >>/tmp/calls
if [ ! -s /tmp/le-results ]; then
    touch /tmp/loop-stopped
    kill "${PPID}"
fi
STUB
chmod +x /le.sh /stub/nginx /stub/sleep
PATH="/stub:${PATH}"
export PATH

# run_case name "le.sh exit codes" "expected calls"
run_case() {
    rm -rf /tmp/calls /tmp/loop-stopped /etc/nginx/ssl/le-crt.pem \
        /etc/nginx/conf.d /etc/nginx/conf.d.disabled /etc/nginx/stream.d /etc/nginx/stream.d.disabled
    echo "$2" | tr ' ' '\n' >/tmp/le-results
    sh "${ENTRYPOINT}" >/tmp/entrypoint.log 2>&1
    calls=$(sed "s/ \$//" /tmp/calls 2>/dev/null)
    if [ "${calls}" = "$3" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1: expected \"$3\", got \"${calls}\""
        FAILED=1
    fi
}

run_case "installed certificate checked again in ten days" "0" \
    "nginx -t; nginx -s reload; sleep 10d;"
run_case "nothing to do checked again in ten days" "1" \
    "nginx -t; sleep 10d;"
run_case "installation failure retried in ten days" "2" \
    "nginx -t; sleep 10d;"
run_case "certbot failure retried hourly until installed" "3 3 0" \
    "nginx -t; sleep 1h; nginx -t; sleep 1h; nginx -t; nginx -s reload; sleep 10d;"

if grep -q "next letsencrypt update in 10d" /tmp/entrypoint.log; then
    echo "ok   next update logged"
else
    echo "FAIL next update not logged"
    FAILED=1
fi

if [ ${FAILED} -eq 0 ]; then
    echo "all tests passed"
else
    echo "some tests failed"
fi
exit ${FAILED}
