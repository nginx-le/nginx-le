#!/bin/sh

if [ "$LETSENCRYPT" = "true" ]; then
    DOMAINS=$(echo ${LE_FQDN} | sed s'|,| -d |g')
    FQDN=$(echo ${DOMAINS} | cut -f1 -d ' ')
    certbot certonly -t -n --agree-tos --renew-by-default --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${DOMAINS}
    cp -fv /etc/letsencrypt/live/${FQDN}/privkey.pem /etc/nginx/ssl/le-key.pem
    cp -fv /etc/letsencrypt/live/${FQDN}/fullchain.pem /etc/nginx/ssl/le-crt.pem
else
    echo "letsencrypt disabled"
fi
