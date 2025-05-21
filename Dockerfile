# Stage 1: Node for frontend build
FROM node:18-alpine as frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build


# Stage 2: Composer + PHP base
FROM php:8.2-fpm-alpine as backend

# Install system deps and PHP extensions
RUN apk add --no-cache \
    nginx curl bash git supervisor \
    oniguruma-dev libzip-dev icu-dev \
    libpng-dev libjpeg-turbo-dev freetype-dev \
    zip unzip

RUN docker-php-ext-install pdo pdo_mysql bcmath intl zip gd opcache

RUN apk add --no-cache git bash libzip-dev \
    && docker-php-ext-install pdo pdo_mysql mbstring zip bcmath


# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

RUN chown -R www-data:www-data /var/www
COPY composer.json composer.lock ./
#RUN composer install --no-dev --optimize-autoloader
RUN composer install --no-dev --optimize-autoloader || true
COPY . .

COPY --from=frontend /app/public /var/www/public
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache
# Laravel cache
# RUN php artisan config:cache && \
#     php artisan route:cache && \
#     php artisan view:cache

RUN php artisan config:clear

# Nginx config
COPY ./docker/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/default.conf /etc/nginx/conf.d/default.conf

# Supervisor config to start PHP and Nginx
COPY ./docker/supervisord.conf /etc/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
