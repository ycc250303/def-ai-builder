FROM alpine:3.21
RUN sed -i 's#https://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories \
    && apk add --no-cache nginx \
    && mkdir -p /run/nginx
COPY app/build/web /usr/share/nginx/html
COPY deploy/client/nginx.conf /etc/nginx/http.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
