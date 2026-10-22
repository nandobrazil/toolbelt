FROM nginxinc/nginx-unprivileged:1.27-alpine
ARG GIT_SHA=unknown
LABEL org.opencontainers.image.source="https://github.com/nandobrazil/toolbelt" \
      org.opencontainers.image.revision="$GIT_SHA"
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
EXPOSE 8080
