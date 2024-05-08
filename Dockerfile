FROM nginx:1.24-alpine

# https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file#docker
LABEL org.opencontainers.image.source="https://github.com/nginx-le/nginx-le"

ADD conf/nginx.conf /etc/nginx/nginx.conf

ADD script/entrypoint.sh /entrypoint.sh
ADD script/le.sh /le.sh

RUN \
 rm /etc/nginx/conf.d/default.conf && \
 chmod +x /entrypoint.sh && \
 chmod +x /le.sh && \
 apk add --no-cache --update certbot tzdata openssl

CMD ["/entrypoint.sh"]
