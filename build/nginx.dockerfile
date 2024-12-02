ARG BASE_IMAGE
FROM $BASE_IMAGE

COPY ./certs/tls.crt.pem ./certs/tls.key.pem /etc/nginx/certs/
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./html /var/www/html
