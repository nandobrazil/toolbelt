FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
EXPOSE 8080
