#!/bin/bash
set -e

# Set default values
DB_HOST=${WORDPRESS_DB_HOST%%:*}
DB_USER=${WORDPRESS_DB_USER}
DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
DB_NAME=${WORDPRESS_DB_NAME}

# Fix permissions for WordPress directories
echo "Setting up proper permissions..."
mkdir -p /var/www/html/wp-content/uploads/2025/03
mkdir -p /var/www/html/wp-content/upgrade
chmod -R 775 /var/www/html/wp-content
chown -R www-data:www-data /var/www/html/wp-content

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
  if ! grep -q "WP_MEMORY_LIMIT" /var/www/html/wp-config.php; then
    sed -i "/\/\* That's all, stop editing\! Happy publishing. \*\//i \
/** Performance optimizations **/\n\
define('WP_MEMORY_LIMIT', '1024M');\n\
define('WP_MAX_MEMORY_LIMIT', '2048M');\n\
define('WP_CACHE', true);\n\
define('COMPRESS_CSS', true);\n\
define('COMPRESS_SCRIPTS', true);\n\
define('CONCATENATE_SCRIPTS', true);\n\
define('ENFORCE_GZIP', true);\n\
define('DISABLE_WP_CRON', true);\n\
define('WP_POST_REVISIONS', 5);\n\
define('EMPTY_TRASH_DAYS', 7);\n\
define('AUTOSAVE_INTERVAL', 300);\n\
define('DISALLOW_FILE_EDIT', false);\n\
" /var/www/html/wp-config.php
  fi
fi

# Now run the wp-cli commands
echo "Setting up WordPress with wp-cli..."

# Check if WordPress is installed
echo "Checking if WordPress is installed..."
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "Installing WordPress..."
    wp core install --url="http://localhost:8000" --title="My WordPress Site" --admin_user="admin" --admin_password="password" --admin_email="admin@example.com" --allow-root
fi

# # Install Divi theme
# echo "Installing Divi theme..."
# wp theme install /zips/divi.zip --activate --allow-root || echo "Failed to install Divi theme"

# # Install Divi Plus plugin
# echo "Installing Divi Plus plugin..."
# wp plugin install /zips/divi-plus.zip --activate --allow-root || echo "Failed to install Divi Plus plugin"

# Install WooCommerce plugin
# echo "Installing WooCommerce plugin..."
# wp plugin install woocommerce --activate --allow-root || echo "Failed to install WooCommerce plugin"

# Install performance plugins
echo "Installing performance plugins..."
wp plugin install wp-super-cache --activate --allow-root || echo "Failed to install WP Super Cache"
wp plugin install query-monitor --activate --allow-root || echo "Failed to install Query Monitor"
wp plugin install redis-cache --allow-root || echo "Failed to install Redis Cache"
wp plugin install wp-optimize --activate --allow-root || echo "Failed to install WP-Optimize"

# Configure WordPress for better performance
echo "Configuring WordPress for better performance..."
wp option update blog_public 0 --allow-root || echo "Failed to set blog_public"
wp option update permalink_structure '/%postname%/' --allow-root || echo "Failed to set permalink structure"
wp rewrite flush --allow-root || echo "Failed to flush rewrite rules"

# Final permission fix
echo "Final permission fixes..."
# Set proper permissions for all WordPress content
chmod -R 775 /var/www/html/wp-content
chown -R www-data:www-data /var/www/html/wp-content

# Ensure specific directories have correct permissions
chmod -R 775 /var/www/html/wp-content/uploads
chmod -R 775 /var/www/html/wp-content/upgrade
chmod -R 775 /var/www/html/wp-content/plugins
chmod -R 775 /var/www/html/wp-content/themes

# Make sure WordPress can write to these directories
chown -R www-data:www-data /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content/upgrade
chown -R www-data:www-data /var/www/html/wp-content/plugins
chown -R www-data:www-data /var/www/html/wp-content/themes

# Start the WordPress server
echo "Starting Apache..."
exec apache2-foreground