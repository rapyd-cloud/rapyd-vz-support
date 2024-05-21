#!/bin/bash

cd /var/www/webroot/ROOT/

# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$'
SKIPLIST=$(wp plugin list --status=active --field=name --quiet --skip-plugins 2>/dev/null | grep -v $SKIPPLUGINS | tr '\n' ',' )

wp plugin is-installed litespeed-cache --quiet --skip-plugins 2>/dev/null

if [ "$?" -eq 0 ]
then
    wp plugin is-active litespeed-cache --quiet --skip-plugins 2>/dev/null
    
    if [ "$?" -eq 0 ]
        then

        ## disable the ls object cache before doing any other actions
        wp litespeed-option set object false --quiet --skip-plugins="$SKIPLIST" 2>/dev/null   
    
        ## forece update of lscache plugin 
        wp plugin update litespeed-cache --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
    
        wp litespeed-option set cache true --quiet --skip-plugins="$SKIPLIST" 2>/dev/null

        wp litespeed-option set cache-priv false --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        wp litespeed-option set cache-commenter false --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        wp litespeed-option set cache-rest false --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        wp litespeed-option set cache-page_login false --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        wp litespeed-option set cache-favicon true --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        wp litespeed-option set cache-resources true --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        wp litespeed-option set cache-mobile false  --quiet --skip-plugins="$SKIPLIST" 2>/dev/null     

        wp litespeed-option set cache-exc $'^/wp-admin\n ^/wp-json \n^/wp-login\n^/register' --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        
        wp litespeed-option set cache true --quiet --skip-plugins="$SKIPLIST" 2>/dev/null
        
    fi
else
    echo "Installing LiteSpeed Plugin..."; 
    wp plugin install litespeed-cache;
fi