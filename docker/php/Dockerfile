
FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    git \
    unzip \
    curl \
    ca-certificates \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    zip \
    && update-ca-certificates \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        gd \
        xml \
        pdo_mysql \
        mysqli \
        zip \
        intl \
        opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# PHP configuration for Moodle

RUN { \
  echo "max_input_vars=5000"; \
  echo "upload_max_filesize=100M"; \
  echo "post_max_size=100M"; \
  echo "memory_limit=256M"; \
} > /usr/local/etc/php/conf.d/moodle.in


# Clone Moodle into /var/www/html
RUN mkdir -p /var/www/html \
    && curl -fSL https://github.com/moodle/moodle/archive/refs/tags/v4.1.1.tar.gz -o moodle.tgz \
    && tar -xzf moodle.tgz --strip-components=1 -C /var/www/html \
    && rm moodle.tgz

# Set permissions for Moodle data
RUN mkdir -p /var/www/moodledata && chown -R www-data:www-data /var/www/moodledata /var/www/html

# Expose PHP-FPM port
EXPOSE 9000

CMD ["php-fpm"]
