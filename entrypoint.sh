#!/bin/bash
set -e

# Set default values
DB_HOST=${WORDPRESS_DB_HOST%%:*}
DB_USER=${WORDPRESS_DB_USER}
DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
DB_NAME=${WORDPRESS_DB_NAME}

# Initial permission setup removed, will be handled comprehensively later

echo "Waiting for database connection to $DB_HOST..."
# Wait for the database to be ready
for i in {1..30}; do
  if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" > /dev/null 2>&1; then
    echo "Database is ready!"
    break
  fi
  echo "Waiting for database connection... attempt $i/30"
  sleep 2
done

# Run the standard WordPress entrypoint script to initialize WordPress
# This will set up wp-config.php and copy WordPress files if needed
if [ -f /usr/local/bin/docker-entrypoint.sh ]; then
  # Generate wp-config.php and copy WordPress files if needed
  # We need to temporarily replace the exec at the end of the script
  TMP_WP_ENTRYPOINT=$(mktemp)
  sed 's/^exec/# exec/' /usr/local/bin/docker-entrypoint.sh > "$TMP_WP_ENTRYPOINT"
  chmod +x "$TMP_WP_ENTRYPOINT"
  bash "$TMP_WP_ENTRYPOINT" apache2-foreground
  rm "$TMP_WP_ENTRYPOINT"
fi

# Wait for WordPress files to be set up
echo "Waiting for WordPress to be configured..."
sleep 5

# Add performance optimizations to wp-config.php
echo "Adding performance optimizations to wp-config.php..."
if [ -f /var/www/html/wp-config.php ]; then
  # Check if optimizations are already added
  # Check if standard optimizations are already added
  if ! grep -q "WP_CACHE" /var/www/html/wp-config.php; then
      sed -i "/\/\* That's all, stop editing\! Happy publishing. \*\//i \
/** WordPress Cache **/\n\
define('WP_CACHE', true);\n\
\n\
/** WordPress Performance & Security **/\n\
define('WP_POST_REVISIONS', 5);\n\
define('EMPTY_TRASH_DAYS', 7);\n\
define('AUTOSAVE_INTERVAL', 300);\n\
define('DISALLOW_FILE_EDIT', true);\n\
\n\
/** Redis Cache Configuration **/\n\
define('WP_REDIS_HOST', 'redis');\n\
define('WP_REDIS_PORT', 6379);\n\
# define('WP_REDIS_PASSWORD', 'your-redis-password'); # Uncomment if Redis requires auth\n\
define('WP_REDIS_TIMEOUT', 1);\n\
define('WP_REDIS_READ_TIMEOUT', 1);\n\
define('WP_REDIS_DATABASE', 0); # Usually 0\n\
" /var/www/html/wp-config.php
  fi
fi

# Create a wrapper function for wp-cli to suppress OPcache warnings
wp_wrapper() {
    php -d opcache.enable=0 /usr/local/bin/wp "$@"
}

# Now run the wp-cli commands
echo "Setting up WordPress with wp-cli..."

# Check if WordPress is installed
echo "Checking if WordPress is installed..."
if ! wp_wrapper core is-installed --allow-root 2>/dev/null; then
    echo "Installing WordPress..."
    wp_wrapper core install --url="http://localhost:8000" --title="My WordPress Site" --admin_user="admin" --admin_password="password" --admin_email="admin@example.com" --allow-root
fi

# Install performance plugins
echo "Installing performance plugins..."
wp_wrapper plugin install wp-super-cache --activate --allow-root || echo "Failed to install WP Super Cache"
wp_wrapper plugin install query-monitor --allow-root || echo "Failed to install Query Monitor" # Install but don't activate
wp_wrapper plugin install redis-cache --activate --allow-root || echo "Failed to install/activate Redis Cache" # Install and activate
wp_wrapper plugin install wp-optimize --activate --allow-root || echo "Failed to install WP-Optimize"

# Configure WordPress for better performance
echo "Configuring WordPress for better performance..."
wp_wrapper option update blog_public 0 --allow-root || echo "Failed to set blog_public"
wp_wrapper option update permalink_structure '/%postname%/' --allow-root || echo "Failed to set permalink structure"
wp_wrapper rewrite flush --allow-root || echo "Failed to flush rewrite rules"

# Final permission fix using find for better precision
echo "Applying final permissions..."
# Ensure wp-content exists before attempting to set permissions
if [ -d "/var/www/html/wp-content" ]; then
    # Set directory permissions to 755
    find /var/www/html/wp-content -type d -exec chmod 755 {} \;
    # Set file permissions to 644
    find /var/www/html/wp-content -type f -exec chmod 644 {} \;
    # Set ownership to www-data
    chown -R www-data:www-data /var/www/html/wp-content
else
    echo "Warning: /var/www/html/wp-content directory not found. Skipping final permission fix."
fi

# Start the WordPress server
echo "Starting Apache..."
exec apache2-foreground