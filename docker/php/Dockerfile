FROM php:8.3-fpm

# Install necessary dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    curl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd xml pdo_mysql \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure PHP settings
RUN echo "max_execution_time = 360" >> /usr/local/etc/php/php.ini \
    && echo "memory_limit = 256M" >> /usr/local/etc/php/php.ini \
    && echo "post_max_size = 64M" >> /usr/local/etc/php/php.ini \
    && echo "max_input_vars = 6000" >> /usr/local/etc/php/php.ini \
    && echo "cgi.fix_pathinfo = 0" >> /usr/local/etc/php/php.ini \
    && echo "upload_max_filesize = 100M" >> /usr/local/etc/php/php.ini


# Expose PHP-FPM port
EXPOSE 9000

# Start PHP-FPM
CMD ["php-fpm"]
