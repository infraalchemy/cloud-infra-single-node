#!/bin/sh

# Fix permissions every time container starts
chown -R www-data:www-data /var/www/moodledata

# Start PHP-FPM (important)
exec php-fpm
