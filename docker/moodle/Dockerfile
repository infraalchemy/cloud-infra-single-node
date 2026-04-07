# Moodle Dockerfile


FROM php:8.3-fpm

# Install dependencies for Moodle
RUN apt-get update && apt-get install -y \
    git unzip curl libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-install gd pdo_mysql mysqli zip intl opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directories for Moodle
RUN mkdir -p /var/www/html /var/www/moodledata \
    && chown -R www-data:www-data /var/www/html /var/www/moodledata

# Optionally clone Moodle automatically (you can skip if you use local code)
# RUN git clone -b MOODLE_411_STABLE https://github.com/moodle/moodle.git /var/www/html

# Expose PHP-FPM port
EXPOSE 9000

# Start PHP-FPM
CMD ["php-fpm"]
