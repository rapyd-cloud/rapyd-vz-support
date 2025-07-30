#!/bin/bash

WP_ROOT="/var/www/webroot/ROOT"

cd "$WP_ROOT"

# if installed clean up gracefully 
wp --skip-plugins --skip-themes --quiet  plugin is-installed redis-cache 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp --skip-plugins --skip-themes --quiet  plugin is-active redis-cache 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp --skip-plugins --skip-themes --quiet plugin deactivate redis-cache   2>/dev/null || true
       wp --skip-plugins --skip-themes --quiet plugin delete redis-cache 2>/dev/null || true
    fi
fi

exit 0
