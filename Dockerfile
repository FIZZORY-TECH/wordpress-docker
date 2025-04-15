FROM wordpress:latest

# Install dependencies
# Install dependencies & clean up
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-mysql-client \
    less \
    wget \
    nano \
    zip \
    unzip \
    # libmemcached-tools was here, removed as memcached is removed
    && rm -rf /var/lib/apt/lists/*

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
    # Set to 2 for development, 0 for production
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'realpath_cache_size=4096K'; \
    echo 'realpath_cache_ttl=600'; \
    } > /usr/local/etc/php/conf.d/wordpress-performance.ini

# Install PHP extensions
RUN docker-php-ext-install opcache
RUN pecl install redis \
    && docker-php-ext-enable redis

# Create uploads directory with proper permissions
RUN mkdir -p /var/www/html/wp-content/uploads && \
    chown -R www-data:www-data /var/www/html

# Removed redundant permissions fix script creation (handled in entrypoint)

# Copy custom entrypoint script and zips
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
COPY presets/* /usr/local/bin/presets/
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Set working directory
WORKDIR /var/www/html

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]

# Expose port 80
EXPOSE 80

# The base image's default CMD is ["apache2-foreground"], which our entrypoint will call.
# We don't need to specify CMD here unless we want to override the base image.