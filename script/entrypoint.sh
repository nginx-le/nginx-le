#!/bin/sh
echo "start nginx"

#set TZ
cp /usr/share/zoneinfo/$TZ /etc/localtime && \
echo $TZ > /etc/timezone && \


#setup ssl keys
echo "ssl_key=${SSL_KEY:=le-key.pem}, ssl_cert=${SSL_CERT:=le-crt.pem}"
cp -f /etc/nginx/service.conf /etc/nginx/service.conf_orig
sed -i "s|SSL_KEY|${SSL_KEY}|g" /etc/nginx/service.conf_orig
sed -i "s|SSL_CERT|${SSL_CERT}|g" /etc/nginx/service.conf_orig
SSL_KEY=/etc/nginx/ssl/${SSL_KEY}
SSL_CERT=/etc/nginx/ssl/${SSL_CERT}

if [ ! -f /etc/nginx/ssl/dhparams.pem ]; then
    echo "make dhparams"
    cd /etc/nginx/ssl
    openssl dhparam -out dhparams.pem 2048
    chmod 600 dhparams.pem
fi

(
 sleep 5 #give nginx time to start
 echo "start letsencrypt updater"
 while :
 do
	echo "trying to update letsencrypt ..."
    /le.sh
    rm -f /etc/nginx/conf.d/default.conf 2>/dev/null #remove default config, conflicting on 80
    cp -f /etc/nginx/service.conf_orig /etc/nginx/service.conf 2>/dev/null
    echo "reload nginx with ssl"
    nginx -s reload
    sleep 60d
 done
) & (
    echo "run nginx process ..."
    nginx -g "daemon off;"
)