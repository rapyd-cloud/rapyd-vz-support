#! /bin/bash

cd /var/www/webroot/ROOT/
wp plugin deactivate object-cache-pro || true
wp plugin delete object-cache-pro || true
