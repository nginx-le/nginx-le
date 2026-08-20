#!/bin/sh

# regression tests for script/le.sh, run them inside the image built from this repository:
#   docker build -t nginx-le .
#   docker run --rm --entrypoint sh -v "${PWD}":/repo:ro nginx-le /repo/tests/le_test.sh
# certbot and cp are stubbed, nothing reaches the network and no real certificate is issued

LE_SH=$(dirname "$0")/../script/le.sh
FAILED=0

mkdir -p /stub
cat >/stub/certbot <<'STUB'
#!/bin/sh
exit ${CERTBOT_EXIT:-0}
STUB
# fails the copy of a staged file to FAIL_DEST, everything else is a normal copy
cat >/stub/cp <<'STUB'
#!/bin/sh
src=""
dst=""
for arg in "$@"; do
    src="${dst}"
    dst="${arg}"
done
if [ -n "${FAIL_DEST}" ] && [ "${dst}" = "${FAIL_DEST}" ]; then
    case "${src}" in
        *.new)
            echo "cp: stubbed failure writing ${dst}" >&2
            exit 1
            ;;
    esac
fi
exec /bin/cp "$@"
STUB
chmod +x /stub/certbot /stub/cp
PATH="/stub:${PATH}"
export PATH

LE_SSL_KEY=/ssl/le-key.pem
LE_SSL_CERT=/ssl/le-crt.pem
LE_SSL_CHAIN_CERT=/ssl/le-chain-crt.pem
export LE_SSL_KEY LE_SSL_CERT LE_SSL_CHAIN_CERT

# make_lineage dir keytype days
make_lineage() {
    mkdir -p "$1"
    if [ "$2" = "ec" ]; then
        openssl ecparam -name prime256v1 -genkey -noout -out "$1/privkey.pem" 2>/dev/null
        openssl req -x509 -key "$1/privkey.pem" -out "$1/fullchain.pem" -days "$3" \
            -subj "/CN=www.example.com" -addext "subjectAltName=DNS:www.example.com" >/dev/null 2>&1
    else
        openssl req -x509 -newkey rsa:2048 -keyout "$1/privkey.pem" -out "$1/fullchain.pem" -days "$3" \
            -nodes -subj "/CN=www.example.com" -addext "subjectAltName=DNS:www.example.com" >/dev/null 2>&1
    fi
    /bin/cp "$1/fullchain.pem" "$1/chain.pem"
}

# reset_env keytype, fresh lineage from certbot and an empty destination directory
reset_env() {
    rm -rf /etc/letsencrypt /ssl /previous
    mkdir -p /ssl
    make_lineage /etc/letsencrypt/live/www.example.com "${1:-rsa}" 90
    LETSENCRYPT=true
    LE_FQDN=www.example.com
    LE_EMAIL=name@example.com
    export LETSENCRYPT LE_FQDN LE_EMAIL
    unset CERTBOT_EXIT LE_ADDITIONAL_OPTIONS FAIL_DEST
}

# install_previous, an installed set close to expiration so the next run renews it
install_previous() {
    make_lineage /previous rsa 10
    /bin/cp /previous/privkey.pem "${LE_SSL_KEY}"
    /bin/cp /previous/fullchain.pem "${LE_SSL_CERT}"
    /bin/cp /previous/chain.pem "${LE_SSL_CHAIN_CERT}"
}

pass() { echo "ok   $1"; }
fail() {
    echo "FAIL $1"
    FAILED=1
}

# check_rc name expected actual
check_rc() {
    if [ "$2" = "$3" ]; then pass "$1 (rc=$3)"; else fail "$1: expected rc=$2, got rc=$3"; fi
}
check_file() {
    if [ -f "$1" ]; then pass "$2"; else fail "$2: $1 is missing"; fi
}
check_no_file() {
    if [ ! -f "$1" ]; then pass "$2"; else fail "$2: $1 is present"; fi
}
check_same() {
    if cmp -s "$1" "$2"; then pass "$3"; else fail "$3: $1 and $2 differ"; fi
}
check_previous_intact() {
    check_same /previous/privkey.pem "${LE_SSL_KEY}" "$1, key untouched"
    check_same /previous/fullchain.pem "${LE_SSL_CERT}" "$1, certificate untouched"
    check_same /previous/chain.pem "${LE_SSL_CHAIN_CERT}" "$1, chain untouched"
}
check_no_leftovers() {
    for name in "${LE_SSL_KEY}" "${LE_SSL_CERT}" "${LE_SSL_CHAIN_CERT}"; do
        check_no_file "${name}.new" "$1, no staged ${name}.new"
        check_no_file "${name}.bak" "$1, no leftover ${name}.bak"
    done
}

echo "--- installs an rsa certificate"
reset_env rsa
sh "${LE_SH}" >/dev/null 2>&1
check_rc "rsa lineage installed" 0 $?
check_file "${LE_SSL_KEY}" "key installed"
check_file "${LE_SSL_CERT}" "certificate installed"
check_file "${LE_SSL_CHAIN_CERT}" "chain installed"
check_no_leftovers "rsa lineage"

echo "--- installs an ecdsa certificate, the certbot default"
reset_env ec
sh "${LE_SH}" >/dev/null 2>&1
check_rc "ecdsa lineage installed" 0 $?
check_file "${LE_SSL_CERT}" "certificate installed"

echo "--- keeps the installed set when the lineage has no chain"
reset_env rsa
install_previous
rm -f /etc/letsencrypt/live/www.example.com/chain.pem
sh "${LE_SH}" >/dev/null 2>&1
check_rc "missing chain refused" 2 $?
check_previous_intact "missing chain"
check_no_leftovers "missing chain"

echo "--- keeps the installed set when the lineage key does not match its certificate"
reset_env rsa
install_previous
openssl genrsa -out /etc/letsencrypt/live/www.example.com/privkey.pem 2048 2>/dev/null
if sh "${LE_SH}" 2>&1 | grep -q "doesn't match"; then
    pass "mismatch reported"
else
    fail "mismatch not reported"
fi
sh "${LE_SH}" >/dev/null 2>&1
check_rc "mismatched lineage refused" 2 $?
check_previous_intact "mismatched lineage"
check_no_leftovers "mismatched lineage"

echo "--- restores the installed set when the certificate copy fails"
reset_env rsa
install_previous
FAIL_DEST="${LE_SSL_CERT}" sh "${LE_SH}" >/dev/null 2>&1
check_rc "failed certificate copy rolled back" 2 $?
check_previous_intact "failed certificate copy"
check_no_leftovers "failed certificate copy"

echo "--- restores the installed set when the chain copy fails"
reset_env rsa
install_previous
FAIL_DEST="${LE_SSL_CHAIN_CERT}" sh "${LE_SH}" >/dev/null 2>&1
check_rc "failed chain copy rolled back" 2 $?
check_previous_intact "failed chain copy"
check_no_leftovers "failed chain copy"

echo "--- leaves nothing behind when the certificate copy fails on a first install"
reset_env rsa
FAIL_DEST="${LE_SSL_CERT}" sh "${LE_SH}" >/dev/null 2>&1
check_rc "failed first install rolled back" 2 $?
check_no_file "${LE_SSL_KEY}" "no orphaned key"
check_no_file "${LE_SSL_CERT}" "no orphaned certificate"
check_no_leftovers "failed first install"

echo "--- ignores a stale backup left by an interrupted run"
reset_env rsa
echo "stale" >"${LE_SSL_KEY}.bak"
FAIL_DEST="${LE_SSL_CERT}" sh "${LE_SH}" >/dev/null 2>&1
check_rc "failed install with a stale backup" 2 $?
check_no_file "${LE_SSL_KEY}" "stale backup not restored"
check_no_leftovers "stale backup"

echo "--- refuses to install into an unwritable directory"
reset_env rsa
mkdir -p /readonly && chmod 555 /readonly
# the lineage has to stay readable for nobody, otherwise the run fails over the source instead
chmod -R a+rX /etc/letsencrypt
unwritable_output=$(su -s /bin/sh nobody -c "PATH=${PATH} LETSENCRYPT=true LE_FQDN=www.example.com \
    LE_EMAIL=name@example.com LE_SSL_KEY=/readonly/le-key.pem LE_SSL_CERT=/readonly/le-crt.pem \
    LE_SSL_CHAIN_CERT=/readonly/le-chain-crt.pem sh ${LE_SH}" 2>&1)
check_rc "unwritable directory refused" 2 $?
check_no_file /readonly/le-crt.pem "nothing installed into the unwritable directory"
if echo "${unwritable_output}" | grep -q "failed to copy certificate files"; then
    pass "unwritable directory reported as a copy failure"
else
    fail "unwritable directory reported as something else: ${unwritable_output}"
fi

echo "--- reports a certbot failure"
reset_env rsa
CERTBOT_EXIT=1 sh "${LE_SH}" >/dev/null 2>&1
check_rc "certbot failure reported" 2 $?
check_no_file "${LE_SSL_CERT}" "no certificate installed"

echo "--- does nothing when disabled"
reset_env rsa
LETSENCRYPT=false sh "${LE_SH}" >/dev/null 2>&1
check_rc "disabled" 1 $?

echo "--- does nothing when the installed certificate is still valid"
reset_env rsa
sh "${LE_SH}" >/dev/null 2>&1
sh "${LE_SH}" >/dev/null 2>&1
check_rc "valid certificate kept" 1 $?

echo "--- reports a missing lineage"
reset_env rsa
rm -rf /etc/letsencrypt/live/www.example.com
sh "${LE_SH}" >/dev/null 2>&1
check_rc "missing lineage reported" 2 $?
check_no_file "${LE_SSL_CERT}" "nothing installed"

echo "--- repairs an installed certificate whose key is missing"
reset_env rsa
sh "${LE_SH}" >/dev/null 2>&1
rm -f "${LE_SSL_KEY}"
sh "${LE_SH}" >/dev/null 2>&1
check_rc "missing key repaired" 0 $?
check_file "${LE_SSL_KEY}" "key reinstalled"

echo "--- repairs an installed set whose chain is missing"
reset_env rsa
sh "${LE_SH}" >/dev/null 2>&1
rm -f "${LE_SSL_CHAIN_CERT}"
sh "${LE_SH}" >/dev/null 2>&1
check_rc "missing chain repaired" 0 $?
check_file "${LE_SSL_CHAIN_CERT}" "chain reinstalled"

echo "--- repairs an installed certificate whose key belongs to another pair"
reset_env rsa
sh "${LE_SH}" >/dev/null 2>&1
openssl genrsa -out "${LE_SSL_KEY}" 2048 2>/dev/null
sh "${LE_SH}" >/dev/null 2>&1
check_rc "mismatched pair repaired" 0 $?
sh "${LE_SH}" >/dev/null 2>&1
check_rc "repaired pair left alone" 1 $?

if [ ${FAILED} -eq 0 ]; then
    echo "all tests passed"
else
    echo "some tests failed"
fi
exit ${FAILED}
