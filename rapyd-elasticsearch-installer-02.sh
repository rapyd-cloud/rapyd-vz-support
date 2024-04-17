#!/bin/bash

# must be run as litespeed user

######################################################################################################################
# install elasticpress and configure wp-config  

# todo - investigate any other plugins or settings we would like to 

#################################################################################
WP_ROOT="/var/www/webroot/ROOT"   

#################################################################################
# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
cd "$WP_ROOT"
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$'
SKIPLIST=$(wp --skip-plugins --skip-themes --quiet  plugin list --field=name   2>/dev/null   | grep -v $SKIPPLUGINS | tr '\n' ',' )

#################################################################################
cd "$WP_ROOT"
wp --skip-plugins --skip-themes --quiet  plugin is-installed elasticpress  2>/dev/null

if [ "$?" -ne 0 ]
then
  
  cd "$WP_ROOT"
 
  wp --skip-plugins --skip-themes --quiet  config set --raw EP_HOST "http://127.0.0.1:9200"  2>/dev/null

  wp --skip-plugins --skip-themes --quiet  plugin install elasticpress  2>/dev/null

  wp --skip-plugins --skip-themes --quiet  plugin activate elasticpress  2>/dev/null

fi

# end elasticpress 
######################################################################################################################
