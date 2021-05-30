# base image
FROM php:7.4.10-fpm-alpine as base
RUN apk add --no-cache dcron zlib-dev libpng-dev libzip-dev icu-dev \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install opcache pdo_mysql gd zip intl

# vendor stage
FROM composer:1.10.13 as vendor
COPY composer.* ./
RUN composer config --global github-oauth.github.com d3c3a17ac4dceff802bb566a994e20b8213afba9 \
    && composer install \
    --ignore-platform-reqs \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --prefer-dist \
    --no-suggest \
    --no-autoloader

# develop stage
FROM base as develop-stage
COPY --from=vendor /usr/bin/composer /usr/bin/composer
COPY --from=vendor /app/vendor /vendor
COPY docker/php.development.ini $PHP_INI_DIR/php.ini
EXPOSE 8000
CMD ([ -L ./vendor ] && echo "Using linked vendor libs" || \
    ([ -d ./vendor ] && (echo "Using local vendor libs" && cp -RuT /vendor ./vendor) || ln -s /vendor ./vendor)) && \
    composer install && \
    crond -b -L /var/log/crond.log && \
    php artisan migrate && \
    php artisan serve --host=0.0.0.0 --port=8000

# production stage
# FROM base as production-stage
# WORKDIR /var/www
# COPY --from=vendor /usr/bin/composer /usr/bin/composer
# COPY --from=vendor /app .
# RUN composer install --no-dev --no-scripts --no-autoloader
# ADD . .
# RUN composer install --no-dev --optimize-autoloader && \
#     rm /usr/bin/composer
# RUN chown -R www-data:www-data storage bootstrap/cache && \
#     chmod -R 777 storage
# COPY docker/php.production.ini $PHP_INI_DIR/php.ini
# EXPOSE 9000
# CMD [ "/bin/sh", "-c", "php artisan optimize && php-fpm" ]
