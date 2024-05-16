#!/bin/bash

WP_ROOT="/var/www/webroot/ROOT"

##################################################################################
cd "$WP_ROOT"

wp --skip-plugins --skip-themes --quiet plugin deactivate elasticpress   2>/dev/null || true;
wp --skip-plugins --skip-themes --quiet plugin uninstall elasticpress  2>/dev/null || true;
wp --skip-plugins --skip-themes --quiet  config delete EP_HOST  2>/dev/null || true;