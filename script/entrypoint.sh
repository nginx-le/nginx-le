#!/bin/sh
echo "start nginx"

#set TZ
if [[ ! -z "${TZ}" ]]; then
    cp /usr/share/zoneinfo/${TZ} /etc/localtime
    echo ${TZ} >/etc/timezone
fi

#setup ssl keys, export to pass them to le.sh
echo "ssl_key=${SSL_KEY:=le-key.pem}, ssl_cert=${SSL_CERT:=le-crt.pem}, ssl_chain_cert=${SSL_CHAIN_CERT:=le-chain-crt.pem}"
export LE_SSL_KEY=/etc/nginx/ssl/${SSL_KEY}
export LE_SSL_CERT=/etc/nginx/ssl/${SSL_CERT}
export LE_SSL_CHAIN_CERT=/etc/nginx/ssl/${SSL_CHAIN_CERT}

#create configuration source directories, in case they are not mounted
mkdir -p /etc/nginx/conf.d-le
mkdir -p /etc/nginx/stream.conf.d-le

#create destination directories
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/stream.d
mkdir -p /etc/nginx/ssl

#collect services and streams
SERVICES_FILES=$(find "/etc/nginx/" -type f -maxdepth 1 -name "service*.conf")
STREAMS_FILES=$(find "/etc/nginx/" -type f -maxdepth 1 -name "stream*.conf")

#copy service*.conf and stream*.conf from /etc/nginx/ if they are mounted
if [ ${#SERVICES_FILES} -ne 0 ]; then
    cp -fv /etc/nginx/service*.conf /etc/nginx/conf.d/
fi
if [ ${#STREAMS_FILES} -ne 0 ]; then
    cp -fv /etc/nginx/stream*.conf /etc/nginx/stream.d/
fi

cp -fv /etc/nginx/conf.d-le/*.conf /etc/nginx/conf.d/
cp -fv /etc/nginx/stream.conf.d-le/*.conf /etc/nginx/stream.conf.d/

#replace SSL_KEY, SSL_CERT and SSL_CHAIN_CERT by actual keys
sed -i "s|SSL_KEY|${LE_SSL_KEY}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
sed -i "s|SSL_KEY|${LE_SSL_KEY}|g" /etc/nginx/stream.d/*.conf 2>/dev/null
sed -i "s|SSL_CERT|${LE_SSL_CERT}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
sed -i "s|SSL_CERT|${LE_SSL_CERT}|g" /etc/nginx/stream.d/*.conf 2>/dev/null
sed -i "s|SSL_CHAIN_CERT|${LE_SSL_CHAIN_CERT}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
sed -i "s|SSL_CHAIN_CERT|${LE_SSL_CHAIN_CERT}|g" /etc/nginx/stream.d/*.conf 2>/dev/null

#replace LE_FQDN
sed -i "s|LE_FQDN|${LE_FQDN}|g" /etc/nginx/conf.d/*.conf 2>/dev/null
sed -i "s|LE_FQDN|${LE_FQDN}|g" /etc/nginx/stream.d/*.conf 2>/dev/null

#generate dhparams.pem
if [ ! -f /etc/nginx/ssl/dhparams.pem ]; then
    echo "make dhparams"
    cd /etc/nginx/ssl
    openssl dhparam -out dhparams.pem 2048
    chmod 600 dhparams.pem
fi

#disable configuration and let it run without SSL
mv -v /etc/nginx/conf.d /etc/nginx/conf.d.disabled
mv -v /etc/nginx/stream.d /etc/nginx/stream.d.disabled

(
 sleep 5 #give nginx time to start
 echo "start letsencrypt updater"
 while :; do
    echo "trying to update letsencrypt ..."
    /le.sh
    #on the first run remove default config, conflicting on 80
    rm -f /etc/nginx/conf.d/default.conf 2>/dev/null
    #on the first run enable config back
    mv -v /etc/nginx/conf.d.disabled /etc/nginx/conf.d 2>/dev/null
    mv -v /etc/nginx/stream.d.disabled /etc/nginx/stream.d 2>/dev/null
    echo "reload nginx with ssl"
    nginx -s reload
    sleep 10d
 done
) &

exec nginx -g "daemon off;"
