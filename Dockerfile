FROM php:8.2-fpm

WORKDIR /var/www/html

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget unzip curl ca-certificates \
    libpng-dev libjpeg-dev libfreetype6-dev \
    libonig-dev libxml2-dev libzip-dev libicu-dev \
    zip git \
    && rm -rf /var/lib/apt/lists/*

# Configure GD (required by Moodle)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# Install PHP extensions required for Moodle
RUN docker-php-ext-install \
    gd \
    xml \
    pdo_mysql \
    mysqli \
    zip \
    intl \
    opcache \
    exif \
    soap

# Set proper permissions (safe default for Moodle)
RUN chown -R www-data:www-data /var/www/html   
