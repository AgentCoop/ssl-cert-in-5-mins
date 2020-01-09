FROM nginx:1.13.12-alpine

COPY ./sites-enabled /etc/nginx/conf.d/
COPY nginx.conf ssl-params.conf /etc/nginx/

RUN rm -f /etc/nginx/conf.d/default.conf

ADD ssl /etc/nginx/ssl
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
