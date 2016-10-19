#!/bin/sh

if [ "$LETSENCRYPT" = "true" ]; then
    certbot certonly -t -n --agree-tos --renew-by-default --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d $LE_FQDN
    cp -fv /etc/letsencrypt/live/$LE_FQDN/privkey.pem /etc/nginx/ssl/le-key.pem
    cp -fv /etc/letsencrypt/live/$LE_FQDN/fullchain.pem /etc/nginx/ssl/le-crt.pem
else
    echo "letsencrypt disabled"
fi
