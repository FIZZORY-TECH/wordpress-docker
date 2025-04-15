# WordPress Docker Performance Optimization Plan

Based on the analysis of `docker-compose.yml`, `Dockerfile`, and `entrypoint.sh`, and user preferences, the following plan will be implemented to enhance performance and streamline the configuration.

**User Preferences Confirmed:**

*   **Object Cache:** Redis
*   **WP-Cron:** Default (Re-enabled)
*   **OPcache Validation:** `opcache.revalidate_freq=2` (Development friendly)
*   **Plugins:** Keep `wp-optimize` for DB features, Install & Activate `Divi` + `Divi Plus`.

---

## Phase 1: Consolidate Configuration & Caching

1.  **Centralize PHP Settings:**
    *   Define all PHP settings (`memory_limit=1024M`, `max_execution_time=600`, `upload_max_filesize=128M`, `post_max_size=128M`, `opcache.enable=1`, `opcache.memory_consumption=256`, etc.) *only* within the `wordpress-performance.ini` file in the `Dockerfile`.
    *   Set `opcache.revalidate_freq=2` in `wordpress-performance.ini`.
    *   Remove the corresponding `PHP_*` environment variables from `docker-compose.yml`.
    *   Remove the `define('WP_MEMORY_LIMIT', ...)` and `define('WP_MAX_MEMORY_LIMIT', ...)` lines from `entrypoint.sh`.
2.  **Implement Redis Object Caching:**
    *   Add a `redis` service to `docker-compose.yml` (using a standard Redis image, e.g., `redis:alpine`).
    *   In `Dockerfile`: Install the `php-redis` extension (`docker-php-ext-install redis`). Remove the `memcached` server installation (`apt-get remove memcached ...`).
    *   In `entrypoint.sh`: Keep `wp plugin install redis-cache --allow-root`. Add commands to configure the Redis connection details (host: `redis`, port: `6379`) in `wp-config.php`. Ensure `define('WP_CACHE', true);` remains.
3.  **Streamline Page Caching:**
    *   Keep both `wp-super-cache` (for page caching) and `wp-optimize` (for database optimization) installed and activated via `entrypoint.sh`.
4.  **Configure Web Server Caching (Apache):**
    *   Ensure `mod_deflate` (for Gzip) and `mod_expires` (for browser caching) are enabled in Apache. (Assume enabled in base image for now, verify if needed).

## Phase 2: Refine Scripts & Plugins

5.  **Clean `wp-config.php` additions:**
    *   In `entrypoint.sh`: Remove the non-standard/deprecated defines: `COMPRESS_CSS`, `COMPRESS_SCRIPTS`, `CONCATENATE_SCRIPTS`, `ENFORCE_GZIP`.
6.  **Address WP-Cron:**
    *   Re-enable default WP-Cron by removing `define('DISABLE_WP_CRON', true);` from `entrypoint.sh`.
7.  **Manage Debug/Development Plugins:**
    *   In `entrypoint.sh`: Change `wp plugin install query-monitor --activate` to `wp plugin install query-monitor --allow-root` (install but don't activate).
8.  **Install Required Theme/Plugins:**
    *   In `entrypoint.sh`: Ensure the lines for installing Divi theme (`/app_zips/divi.zip`) and Divi Plus plugin (`/app_zips/divi-plus.zip`) are uncommented and active.

## Phase 3: Docker & Security Best Practices

9.  **Optimize Dockerfile:**
    *   Combine `RUN apt-get update && apt-get install -y ...` commands where possible.
    *   Add `&& rm -rf /var/lib/apt/lists/*` at the end of `apt-get install` commands to reduce image size.
10. **Standardize Permissions:**
    *   In `entrypoint.sh`: Replace multiple `chmod`/`chown` lines with `find /var/www/html/wp-content -type d -exec chmod 755 {} \;`, `find /var/www/html/wp-content -type f -exec chmod 644 {} \;`, and a single `chown -R www-data:www-data /var/www/html/wp-content`.
11. **Security:**
    *   In `entrypoint.sh`: Change `define('DISALLOW_FILE_EDIT', false);` to `define('DISALLOW_FILE_EDIT', true);`.

---

## Visual Plan (Mermaid Diagram)

```mermaid
graph TD
    A[Start: Analyze Current Setup] --> B(Phase 1: Config & Caching);
    B --> C[Centralize PHP Config (ini, opcache freq=2)];
    B --> D[Implement Redis Cache (Add Service, Install Ext, Config wp-config)];
    B --> E[Keep WP Super Cache & WP-Optimize];
    B --> F[Ensure Apache Caching Mods Enabled];

    A --> G(Phase 2: Scripts & Plugins);
    G --> H[Clean wp-config (Remove non-standard defines)];
    G --> I[Re-enable Default WP-Cron];
    G --> J[Install Query Monitor (No Activate)];
    G --> K[Install & Activate Divi + Divi Plus];

    A --> L(Phase 3: Docker & Security);
    L --> M[Optimize Dockerfile (Combine RUN, Clean apt cache)];
    L --> N[Standardize Permissions (Use find)];
    L --> O[Set DISALLOW_FILE_EDIT=true];

    C --> P(Apply Changes);
    D --> P;
    E --> P;
    F --> P;
    H --> P;
    I --> P;
    J --> P;
    K --> P;
    M --> P;
    N --> P;
    O --> P;

    P --> Q[Build & Test];
    Q --> R[Monitor Performance];
    R --> S[End: Optimized Setup];