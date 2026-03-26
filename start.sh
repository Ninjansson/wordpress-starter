#!/usr/bin/env bash
set -e

# Load .env
if [ ! -f .env ]; then
  echo "Error: .env file not found. Please create one before running this script."
  exit 1
fi

get_env() {
  grep -E "^$1=" .env | cut -d= -f2 | tr -d '"' | tr -d "'"
}

PHP_VERSION=$(get_env PHP_VERSION)
NGINX_VERSION=$(get_env NGINX_VERSION)
MYSQL_VERSION=$(get_env MYSQL_VERSION)
WP_VERSION=$(get_env WP_VERSION)

PHP_VERSION=${PHP_VERSION:-8.4}
NGINX_VERSION=${NGINX_VERSION:-1.26.1}
MYSQL_VERSION=${MYSQL_VERSION:-8.0.35}
WP_VERSION=${WP_VERSION:-6.9.4}

ERRORS=0

check_image() {
  local image=$1
  local var_hint=$2
  local hub_url=$3
  printf "  %-45s" "$image"
  if docker manifest inspect "$image" > /dev/null 2>&1; then
    echo "OK"
  else
    echo "NOT FOUND"
    echo "         ^ Check $var_hint in your .env file"
    echo "         ^ Browse available tags: $hub_url"
    ERRORS=$((ERRORS + 1))
  fi
}

echo ""
echo "Checking image versions against Docker Hub..."
echo ""

check_image "nginx:${NGINX_VERSION}"                          "NGINX_VERSION"         "https://hub.docker.com/_/nginx/tags"
check_image "mysql:${MYSQL_VERSION}"                          "MYSQL_VERSION"         "https://hub.docker.com/_/mysql/tags"
check_image "wordpress:${WP_VERSION}-php${PHP_VERSION}-fpm"   "WP_VERSION / PHP_VERSION" "https://hub.docker.com/_/wordpress/tags"

echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "Found $ERRORS invalid version(s). Please fix your .env file and try again."
  exit 1
fi

echo "All versions verified."
echo ""

read -r -p "Start the services? [Y/n] " confirm < /dev/tty
case "$confirm" in
  [nN][oO]|[nN])
    echo "Aborted."
    exit 0
    ;;
  *)
    echo ""
    echo "Starting services..."
    echo ""
    docker compose up "$@"
    ;;
esac
