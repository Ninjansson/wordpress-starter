ARG PHP_VERSION=8.4
ARG WP_VERSION=6.9.4
FROM wordpress:${WP_VERSION}-php${PHP_VERSION}-fpm

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/custom-entrypoint.sh && chmod +x /usr/local/bin/custom-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["php-fpm"]
