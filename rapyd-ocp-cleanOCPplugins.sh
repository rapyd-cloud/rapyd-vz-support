#!/usr/bin/bash

WP_ROOT="/var/www/webroot/ROOT"

cd "$WP_ROOT"




rm -f "$WP_ROOT/wp-content/advanced-cache.php"
rm -f "$WP_ROOT/wp-content/object-cache.php"
rm -f "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro.php"
rm -rf "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro"
rm -rf "$WP_ROOT/wp-content/plugins/redis-cache-pro"




wp cache flush
