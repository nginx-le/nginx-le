FROM nginx:1.10-alpine

RUN \
 apk add  --update certbot tzdata openssl && \
 rm -rf /var/cache/apk/*

ADD conf/nginx.conf /etc/nginx/nginx.conf

ADD script/entrypoint.sh /entrypoint.sh
ADD script/le.sh /le.sh

RUN chmod +x /entrypoint.sh && chmod +x /le.sh

CMD ["/entrypoint.sh"]
