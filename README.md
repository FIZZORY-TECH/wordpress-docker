# WordPress Development Environment

A Docker-based WordPress development environment optimized for performance, featuring automatic setup and preset theme installation options.

## Getting Started

1.  **Start the environment:**
    ```bash
    docker-compose up -d
    ```
4.  **Access WordPress:** Open your browser and navigate to `http://localhost:8000` or `http://localhost:8000/wp-admin` for admin page.
    *   Default Admin Credentials: `admin` / `password` (set during initial setup by `entrypoint.sh`)

## Automatic Setup & Performance Optimizations

The environment automatically performs the following on startup (`entrypoint.sh`):

*   Waits for the database connection.
*   Configures `wp-config.php` with:
    *   Redis Cache settings (`WP_REDIS_HOST`, `WP_REDIS_PORT`, etc.)
    *   `WP_CACHE` enabled.
    *   Limited post revisions (`WP_POST_REVISIONS`).
    *   Reduced trash days (`EMPTY_TRASH_DAYS`).
    *   Increased autosave interval (`AUTOSAVE_INTERVAL`).
    *   File editing disabled (`DISALLOW_FILE_EDIT`).
*   Installs and activates performance-related plugins using WP-CLI:
    *   **Redis Cache:** Connects WordPress to the Redis service.
    *   **WP Super Cache:** File-based caching.
    *   **WP-Optimize:** Database optimization and caching.
*   Installs utility plugins:
    *   **Query Monitor:** For debugging database queries, hooks, etc. (installed but not activated).
*   Sets appropriate file permissions for `/var/www/html/wp-content`.
*   Includes **PHP OPcache** enabled via `Dockerfile` for improved PHP performance.

## Optional Theme Installation (Presets)

This environment includes preset scripts to install specific themes. These scripts expect the corresponding theme zip files to be present in the local `./zips` directory (mounted as `/zips` inside the container).

Available presets (located at `/usr/local/bin/presets/` inside the container):

*   `install-divi-preset.sh` (Requires `./zips/divi.zip`)
*   `install-divi5-preset.sh` (Requires `./zips/divi5.zip`)

**To run a preset:**

1.  Ensure the required zip file is in the local `./zips` directory.
2.  Execute the desired script using `docker-compose exec`. Running as `root` is often necessary for theme/plugin installation permissions.

    ```bash
    # Example: Install Divi theme
    docker-compose exec --user=root wordpress /usr/local/bin/presets/install-divi-preset.sh

    # Example: Install Divi 5 theme
    docker-compose exec --user=root wordpress /usr/local/bin/presets/install-divi5-preset.sh
    ```

    *Note: You only need to run the preset for the theme you intend to use.*

## Troubleshooting

*   **Preset Theme Installation Issues:**
    *   Verify the correct theme zip file (e.g., `divi.zip`) exists in the local `./zips` directory *before* running `docker-compose up -d`.
    *   Ensure the preset script is run as `root` (`--user=root`).
    *   Check the output of the `docker-compose exec` command for errors.
*   **OPcache Warnings:** The `entrypoint.sh` script uses a wrapper for WP-CLI commands (`php -d opcache.enable=0 /usr/local/bin/wp ...`) to prevent "Cannot load Zend OPcache - it was already loaded" warnings during automated setup. If running manual `wp` commands via `docker-compose exec`, you might consider using the same wrapper or temporarily disabling OPcache if you encounter issues.
*   **Database Connection:** The `entrypoint.sh` waits for the database, and `docker-compose.yml` includes a healthcheck. If issues persist, verify MySQL credentials match between the `db` service environment variables and the `wordpress` service environment variables in `docker-compose.yml`.
*   **Permissions:** The `entrypoint.sh` script sets permissions for `/var/www/html/wp-content`. If you encounter permission errors after manual changes or plugin installations, you might need to re-apply permissions:
    ```bash
    docker-compose exec --user=root wordpress chown -R www-data:www-data /var/www/html/wp-content
    docker-compose exec --user=root wordpress find /var/www/html/wp-content -type d -exec chmod 755 {} \;
    docker-compose exec --user=root wordpress find /var/www/html/wp-content -type f -exec chmod 644 {} \;
    ```

## Directory Structure

*   `./docker-compose.yml`: Defines the Docker services (WordPress, MySQL, Redis).
*   `./Dockerfile`: Builds the custom WordPress image, installing dependencies and PHP extensions.
*   `./entrypoint.sh`: Custom script run on container startup for automatic configuration and plugin installation.
*   `./presets/`: Contains optional theme installation scripts (`install-divi-preset.sh`, `install-divi5-preset.sh`).
*   `./zips/`: (You create this locally) Place theme zip files here to be used by the preset scripts.
*   `wp_content_data` (Docker Volume): Persists `/var/www/html/wp-content`.
*   `db_data` (Docker Volume): Persists MySQL database data.