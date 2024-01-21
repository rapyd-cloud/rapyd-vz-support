#!/bin/bash

WP_ROOT="/var/www/webroot/ROOT"

cd "$WP_ROOT"

# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$'
SKIPLIST=$(wp plugin list --status=active --field=name --quiet --skip-plugins 2>/dev/null | grep -v $SKIPPLUGINS | tr '\n' ',' )

# if installed clean up gracefully 
wp plugin is-installed object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate object-cache-pro--quiet --skip-plugins=$SKIPLIST 2>/dev/null || true
       wp plugin delete object-cache-pro --quiet --skip-plugins=$SKIPLIST 2>/dev/null || true
    fi
fi

# force a clear exit regardless of any errors in script results 

exit 0
