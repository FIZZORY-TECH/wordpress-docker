FROM wordpress:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    less \
    wget \
    nano \
    zip \
    unzip

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# PHP Optimization
RUN { \
    echo 'memory_limit = 1024M'; \
    echo 'max_execution_time = 600'; \
    echo 'upload_max_filesize = 128M'; \
    echo 'post_max_size = 128M'; \
    echo 'max_input_vars = 5000'; \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'realpath_cache_size=4096K'; \
    echo 'realpath_cache_ttl=600'; \
    } > /usr/local/etc/php/conf.d/wordpress-performance.ini

# Install additional performance tools
RUN apt-get update && apt-get install -y \
    memcached \
    libmemcached-tools \
    && docker-php-ext-install opcache

# Create uploads directory with proper permissions
RUN mkdir -p /var/www/html/wp-content/uploads && \
    chown -R www-data:www-data /var/www/html

# Create permissions fix script
RUN echo '#!/bin/bash \n\
find /var/www/html/wp-content -type d -exec chmod 755 {} \; \n\
find /var/www/html/wp-content -type f -exec chmod 644 {} \; \n\
chown -R www-data:www-data /var/www/html/wp-content/uploads \n\
' > /usr/local/bin/fix-permissions.sh && \
chmod +x /usr/local/bin/fix-permissions.sh

# Copy custom entrypoint script and zips
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh
COPY ./zips /app_zips

# Set working directory
WORKDIR /var/www/html

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]

# Expose port 80
EXPOSE 80

# The base image's default CMD is ["apache2-foreground"], which our entrypoint will call.
# We don't need to specify CMD here unless we want to override the base image.