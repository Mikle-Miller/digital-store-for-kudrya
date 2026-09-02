FROM php:8.2-fpm-alpine

# System deps
RUN apk add --no-cache \
    postgresql-dev \
    oniguruma-dev \
    libzip-dev \
    unzip \
    curl \
    linux-headers \
    $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && docker-php-ext-install \
        pdo_pgsql \
        mbstring \
        zip \
        pcntl \
        bcmath \
    && apk del $PHPIZE_DEPS linux-headers

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY . .
RUN composer dump-autoload --optimize

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

CMD ["php-fpm"]
