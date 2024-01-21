#!/bin/bash

WP_ROOT="/var/www/webroot/ROOT"

cd "$WP_ROOT"

# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$'
SKIPLIST=$(wp plugin list --status=active --field=name --quiet --skip-plugins 2>/dev/null | grep -v $SKIPPLUGINS | tr '\n' ',' )

#litespeed cache redis object extension
wp plugin is-installed litespeed-cache --quiet --skip-plugins=$SKIPLIST 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active litespeed-cache --quiet --skip-plugins=$SKIPLIST 2>/dev/null

   if [ "$?" -eq 0 ]
     then

       ## disable the ls object cache before doing any other actions
       wp litespeed-option set object false --quiet --skip-plugins=$SKIPLIST 2>/dev/null
     
    fi
fi

# free version of redis object cache
wp plugin is-installed redis-cache --quiet --skip-plugins=$SKIPLIST 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active redis-cache --quiet --skip-plugins=$SKIPLIST 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate redis-cache --quiet --skip-plugins=$SKIPLIST 2>/dev/null || true
       wp plugin delete redis-cache --quiet --skip-plugins=$SKIPLIST 2>/dev/null || true
    fi
fi

# commercial version 
wp plugin is-installed object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null || true
       wp plugin delete object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null || true
    fi
fi

# hard clear out known injections 
rm -f "$WP_ROOT/wp-content/advanced-cache.php"
rm -f "$WP_ROOT/wp-content/object-cache.php"

# mu version installed by cloudways
rm -f "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro.php"
rm -rf "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro"

wp cache flush --quiet --skip-plugins=$SKIPLIST 2>/dev/null

# cleanup complete
# force vz to see a clean script run - regardless of any errors
#exit 0
