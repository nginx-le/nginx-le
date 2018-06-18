#!/bin/sh

# scripts is trying to renew ceritifacte only if close (30 days) to expiration
# returns 0 only if certbot called.

target_cert=/etc/nginx/ssl/le-crt.pem
# 30 days
renew_before=2592000

if [ "$LETSENCRYPT" != "true" ]; then
    echo "letsencrypt disabled"
    return 1
fi

if [ -f ${target_cert} ] && openssl x509 -checkend  ${renew_before} -noout -in ${target_cert} ; then
    echo "letsencrypt certificate still valid"
    return 1
fi

echo "letsencrypt certificate will expire soon or missing, renewing..."
certbot certonly -t -n --agree-tos --renew-by-default --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${LE_FQDN}
le_result=$?
if [ $le_result -ne 0 ]; then
    echo "failed to run certbot"
    return 1
fi

FIRST_FQDN=$(echo "$LE_FQDN" | cut -d"," -f1)
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/privkey.pem /etc/nginx/ssl/le-key.pem
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/fullchain.pem ${target_cert}
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/chain.pem /etc/nginx/ssl/le-chain-crt.pem
return 0