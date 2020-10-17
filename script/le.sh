#!/bin/sh

# scripts is trying to renew certificate only if close (30 days) to expiration
# returns 0 only if certbot called.

# 30 days
renew_before=2592000

if [ "$LETSENCRYPT" != "true" ]; then
    echo "letsencrypt disabled"
    return 1
fi

# redirection to /dev/null to remove "Certificate will not expire" output
if [ -f ${LE_SSL_CERT} ] && openssl x509 -checkend ${renew_before} -noout -in ${LE_SSL_CERT} > /dev/null ; then
    # egrep to remove leading whitespaces
    CERT_FQDNS=$(openssl x509 -in ${LE_SSL_CERT} -text -noout | egrep -o 'DNS.*')
    # run and catch exit code separately because couldn't embed $@ into `if` line properly
    set -- $(echo ${LE_FQDN} | tr ',' '\n'); for element in "$@"; do echo ${CERT_FQDNS} | grep -q $element ; done
    CHECK_RESULT=$?
    if [ ${CHECK_RESULT} -eq 0 ] ; then
        echo "letsencrypt certificate ${LE_SSL_CERT} still valid"
        return 1
    else
        echo "letsencrypt certificate ${LE_SSL_CERT} is present, but doesn't contain expected domains"
        echo "expected: ${LE_FQDN}"
        echo "found:    ${CERT_FQDNS}"
    fi
fi

echo "letsencrypt certificate will expire soon or missing, renewing..."
certbot certonly -t -n --agree-tos --renew-by-default --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${LE_FQDN}
le_result=$?
if [ ${le_result} -ne 0 ]; then
    echo "failed to run certbot"
    return 1
fi

FIRST_FQDN=$(echo "$LE_FQDN" | cut -d"," -f1)
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/privkey.pem ${LE_SSL_KEY}
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/fullchain.pem ${LE_SSL_CERT}
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/chain.pem ${LE_SSL_CHAIN_CERT}
return 0