#!/bin/bash

WP_ROOT="/var/www/webroot/ROOT"

cd "$WP_ROOT"

#litespeed cache redis object extension
wp plugin is-installed litespeed-cache --quiet 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active litespeed-cache --quiet 2>/dev/null

   if [ "$?" -eq 0 ]
     then

       ## disable the ls object cache before doing any other actions
       wp litespeed-option set object false --quiet 2>/dev/null
     
    fi
fi

# free version of redis object cache
wp plugin is-installed redis-cache --quiet 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active redis-cache --quiet 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate redis-cache --quiet 2>/dev/null || true
       wp plugin delete redis-cache --quiet 2>/dev/null || true
    fi
fi

# commercial version 
wp plugin is-installed object-cache-pro --quiet 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active object-cache-pro --quiet 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate object-cache-pro --quiet 2>/dev/null || true
       wp plugin delete object-cache-pro --quiet 2>/dev/null || true
    fi
fi

# hard clear out known injections 
rm -f "$WP_ROOT/wp-content/advanced-cache.php"
rm -f "$WP_ROOT/wp-content/object-cache.php"

# mu version installed by cloudways
rm -f "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro.php"
rm -rf "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro"

wp cache flush --quiet 2>/dev/null
