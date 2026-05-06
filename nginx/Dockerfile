FROM nginx:1.27-alpine
RUN apk add --no-cache nginx-module-njs
COPY nginx.conf /etc/nginx/nginx.conf
COPY uid_hash.js /etc/nginx/uid_hash.js
