#!/bin/sh

# renews the certificate when it expires within 30 days, misses an expected domain,
# doesn't match the installed key, or has no chain file
# exit codes: 0 - certificate installed, 1 - nothing to do, 2 - renewal or installation failed

# 30 days
renew_before=2592000

# nginx refuses to load a certificate and a key from different pairs
cert_key_match() { # certificate key
    cert_pubkey=$(openssl x509 -pubkey -noout -in "$1" 2>/dev/null)
    key_pubkey=$(openssl pkey -pubout -in "$2" 2>/dev/null)
    [ -n "${cert_pubkey}" ] && [ "${cert_pubkey}" = "${key_pubkey}" ]
}

remove_staged() {
    rm -f "${LE_SSL_KEY}.new" "${LE_SSL_CERT}.new" "${LE_SSL_CHAIN_CERT}.new"
}

# keep the installed files aside, a write failing half way through must not leave a mismatched pair behind
backup_installed() {
    for installed in "${LE_SSL_KEY}" "${LE_SSL_CERT}" "${LE_SSL_CHAIN_CERT}"; do
        [ -f "${installed}" ] || continue
        cp -f "${installed}" "${installed}.bak" || return 1
    done
}

restore_installed() {
    restore_result=0
    for installed in "${LE_SSL_KEY}" "${LE_SSL_CERT}" "${LE_SSL_CHAIN_CERT}"; do
        if [ -f "${installed}.bak" ]; then
            cp -f "${installed}.bak" "${installed}" || restore_result=1
        else
            # nothing was installed under this name before, leave nothing behind
            rm -f "${installed}" || restore_result=1
        fi
    done
    return ${restore_result}
}

remove_backup() {
    rm -f "${LE_SSL_KEY}.bak" "${LE_SSL_CERT}.bak" "${LE_SSL_CHAIN_CERT}.bak"
}

if [ "$LETSENCRYPT" != "true" ]; then
    echo "letsencrypt disabled"
    return 1
fi

# redirection to /dev/null to remove "Certificate will not expire" output
if [ -f ${LE_SSL_CERT} ] && openssl x509 -checkend ${renew_before} -noout -in ${LE_SSL_CERT} >/dev/null; then
    # egrep to remove leading whitespaces
    CERT_FQDNS=$(openssl x509 -in ${LE_SSL_CERT} -text -noout | egrep -o 'DNS.*')
    set -- $(echo ${LE_FQDN} | tr ',' '\n')
    MISSING=false
    for element in "$@"; do
        if ! echo "${CERT_FQDNS}" | grep -Eq "DNS:${element}(,|$)"; then
            MISSING=true
            break
        fi
    done
    if $MISSING; then
        echo "letsencrypt certificate ${LE_SSL_CERT} is present, but doesn't contain expected domains"
        echo "expected: ${LE_FQDN}"
        echo "found:    ${CERT_FQDNS}"
    elif ! cert_key_match "${LE_SSL_CERT}" "${LE_SSL_KEY}"; then
        echo "letsencrypt certificate ${LE_SSL_CERT} is present, but doesn't match key ${LE_SSL_KEY}"
    elif [ ! -f "${LE_SSL_CHAIN_CERT}" ]; then
        echo "letsencrypt certificate ${LE_SSL_CERT} is present, but chain ${LE_SSL_CHAIN_CERT} is missing"
    else
        echo "letsencrypt certificate ${LE_SSL_CERT} still valid"
        return 1
    fi
fi

echo "letsencrypt certificate will expire soon or missing, renewing..."
LE_ADDITIONAL_OPTIONS_TRIMMED=${LE_ADDITIONAL_OPTIONS}
first_char="${LE_ADDITIONAL_OPTIONS:0:1}"
last_char="${LE_ADDITIONAL_OPTIONS: -1}"
if [ "$first_char" = "$last_char" ] && [ "$first_char" = "'" -o "$first_char" = '"' ]; then
    LE_ADDITIONAL_OPTIONS_TRIMMED="${LE_ADDITIONAL_OPTIONS:1:${#LE_ADDITIONAL_OPTIONS}-2}"
    echo "trimmed quotes from additional options: ${LE_ADDITIONAL_OPTIONS_TRIMMED}"
fi

# Use the trimmed string when calling the command
eval "certbot certonly -t -n --agree-tos --renew-by-default --email \"${LE_EMAIL}\" --webroot -w /usr/share/nginx/html -d ${LE_FQDN} ${LE_ADDITIONAL_OPTIONS_TRIMMED}"
le_result=$?
if [ ${le_result} -ne 0 ]; then
    echo "failed to run certbot"
    return 2
fi

FIRST_FQDN=$(echo "$LE_FQDN" | cut -d"," -f1)
LE_LIVE_DIR="/etc/letsencrypt/live/${FIRST_FQDN}"

# stage all three files first, a partial or invalid copy should never replace a working certificate
if ! cp -fv "${LE_LIVE_DIR}/privkey.pem" "${LE_SSL_KEY}.new" ||
    ! cp -fv "${LE_LIVE_DIR}/fullchain.pem" "${LE_SSL_CERT}.new" ||
    ! cp -fv "${LE_LIVE_DIR}/chain.pem" "${LE_SSL_CHAIN_CERT}.new"; then
    echo "failed to copy certificate files from ${LE_LIVE_DIR}"
    remove_staged
    return 2
fi

if ! cert_key_match "${LE_SSL_CERT}.new" "${LE_SSL_KEY}.new"; then
    echo "certificate ${LE_LIVE_DIR}/fullchain.pem doesn't match ${LE_LIVE_DIR}/privkey.pem, not installing"
    remove_staged
    return 2
fi

# a leftover copy from an interrupted run says nothing about what is installed now
remove_backup
if ! backup_installed; then
    echo "failed to keep a copy of the installed certificate files, not installing"
    remove_backup
    remove_staged
    return 2
fi

# copy and not rename, destinations can be bind-mounted files or symlinks
if ! cp -f "${LE_SSL_KEY}.new" "${LE_SSL_KEY}" ||
    ! cp -f "${LE_SSL_CERT}.new" "${LE_SSL_CERT}" ||
    ! cp -f "${LE_SSL_CHAIN_CERT}.new" "${LE_SSL_CHAIN_CERT}" ||
    ! cert_key_match "${LE_SSL_CERT}" "${LE_SSL_KEY}"; then
    echo "failed to install certificate files, restoring the previous ones"
    if restore_installed; then
        remove_backup
    else
        echo "failed to restore the previous certificate files, they are kept as .bak next to them"
    fi
    remove_staged
    return 2
fi

remove_backup
remove_staged
echo "certificate for ${LE_FQDN} installed"
return 0
