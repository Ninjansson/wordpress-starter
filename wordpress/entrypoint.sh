#!/bin/bash
set -e

# --- Copy WordPress core files if volume is empty (fresh start) ---
if [ ! -f /var/www/html/wp-includes/version.php ]; then
  echo "WP setup: copying core files to volume..."
  cp -a /usr/src/wordpress/. /var/www/html/
  chown -R www-data:www-data /var/www/html
  echo "WP setup: core files copied."
fi

# --- Create wp-config.php if missing ---
if [ ! -f /var/www/html/wp-config.php ]; then
  echo "WP setup: creating wp-config.php..."
  wp --path=/var/www/html --allow-root config create \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${WORDPRESS_DB_PASSWORD}" \
    --dbhost="${WORDPRESS_DB_HOST:-mysql}" \
    --skip-check
  echo "WP setup: wp-config.php created."
fi

# --- Wait for database ---
echo "WP setup: waiting for database..."
until bash -c "cat < /dev/null > /dev/tcp/${WORDPRESS_DB_HOST:-mysql}/3306" 2>/dev/null; do
  sleep 3
done
echo "WP setup: database ready."

# --- One-time setup ---
# Runs on first start only. To re-run, delete /var/www/html/.setup_complete
# and restart the container (or run ./start.sh --build for a full rebuild).
SETUP_DONE="/var/www/html/.setup_complete"

if [ ! -f "$SETUP_DONE" ]; then
  echo "WP setup: first run detected, running one-time setup..."

  # Install WordPress
  if ! wp --path=/var/www/html --allow-root core is-installed 2>/dev/null; then
    echo "WP setup: installing WordPress..."
    wp --path=/var/www/html --allow-root core install \
      --url="$SITE_URL" \
      --title="$BLOG_NAME" \
      --admin_user="$WP_ADMIN_USER" \
      --admin_password="$WP_ADMIN_PASSWORD" \
      --admin_email="$WP_ADMIN_EMAIL" \
      --skip-email 2>&1
    echo "WP setup: installed."
  fi

  # Remove default plugins
  wp --path=/var/www/html --allow-root plugin delete akismet hello 2>&1
  echo "WP setup: default plugins removed."

  # Clone and activate creatlach theme
  THEME_DIR="/var/www/html/wp-content/themes/creatlach"
  THEME_REPO="https://github.com/HAJ-Agency/creatlach.git"

  if [ "${DOWNLOAD_CRETLACH_THEME}" = "1" ]; then
    if [ ! -d "$THEME_DIR/.git" ]; then
      echo "Theme: cloning creatlach..."
      mkdir -p "$(dirname "$THEME_DIR")"
      git clone "$THEME_REPO" "$THEME_DIR"
      echo "Theme: done."
    else
      echo "Theme: already present, skipping clone."
    fi
    wp --path=/var/www/html --allow-root theme activate creatlach 2>&1
    echo "WP setup: creatlach theme activated."
  else
    echo "Theme: DOWNLOAD_CRETLACH_THEME=${DOWNLOAD_CRETLACH_THEME}, skipping creatlach."
  fi

  # Remove default themes
  if [ "${DELETE_DEFAULT_THEMES}" = "1" ]; then
    wp --path=/var/www/html --allow-root theme delete twentytwentythree twentytwentyfour twentytwentyfive 2>&1
    echo "WP setup: default themes removed."
  else
    echo "WP setup: DELETE_DEFAULT_THEMES=${DELETE_DEFAULT_THEMES}, keeping default themes."
  fi

  # Discourage search engine indexing
  wp --path=/var/www/html --allow-root option update blog_public 0 2>&1
  echo "WP setup: search engine indexing discouraged."

  # Optional plugin installs
  if [ "${INSTALL_FORMIDABLE}" = "1" ]; then
    echo "Plugin: installing Formidable Forms..."
    wp --path=/var/www/html --allow-root plugin install formidable --activate 2>&1
    WP_EXIT=$?
    if [ $WP_EXIT -eq 0 ]; then
      echo "Plugin: Formidable Forms installed and activated."
    else
      echo "Plugin: Formidable Forms install FAILED (exit code $WP_EXIT)."
    fi
  else
    echo "Plugin: INSTALL_FORMIDABLE=${INSTALL_FORMIDABLE}, skipping Formidable Forms."
  fi

  if [ "${INSTALL_ICON_BLOCK}" = "1" ]; then
    echo "Plugin: installing The Icon Block..."
    wp --path=/var/www/html --allow-root plugin install icon-block --activate 2>&1
    WP_EXIT=$?
    if [ $WP_EXIT -eq 0 ]; then
      echo "Plugin: The Icon Block installed and activated."
    else
      echo "Plugin: The Icon Block install FAILED (exit code $WP_EXIT)."
    fi
  else
    echo "Plugin: INSTALL_ICON_BLOCK=${INSTALL_ICON_BLOCK}, skipping The Icon Block."
  fi

  if [ "${INSTALL_FILEBIRD}" = "1" ]; then
    echo "Plugin: installing Filebird..."
    wp --path=/var/www/html --allow-root plugin install filebird --activate 2>&1
    WP_EXIT=$?
    if [ $WP_EXIT -eq 0 ]; then
      echo "Plugin: Filebird installed and activated."
    else
      echo "Plugin: Filebird install FAILED (exit code $WP_EXIT)."
    fi
  else
    echo "Plugin: INSTALL_FILEBIRD=${INSTALL_FILEBIRD}, skipping Filebird."
  fi

  touch "$SETUP_DONE"
  echo "WP setup: one-time setup complete."
else
  echo "WP setup: already initialised, skipping one-time steps."
fi

# --- Always runs on every start ---

# Fix uploads directory permissions
mkdir -p /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content/uploads
chmod -R 755 /var/www/html/wp-content/uploads

# Sync siteurl / home / blogname so .env changes take effect on plain restart
wp --path=/var/www/html --allow-root option update siteurl "$SITE_URL" 2>&1
wp --path=/var/www/html --allow-root option update home "$SITE_URL" 2>&1
wp --path=/var/www/html --allow-root option update blogname "$BLOG_NAME" 2>&1
echo "WP setup: URL and blogname synced."

# --- Start PHP-FPM ---
exec docker-entrypoint.sh "$@"
