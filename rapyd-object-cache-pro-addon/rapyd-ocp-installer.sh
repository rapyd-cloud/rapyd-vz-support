#!/bin/bash

# must be run as litespeed
# must pass in  OCP_TOKEN 

##################################################################################
#load parameters
OCP_TOKEN=$1


##################################################################################
##################################################################################

if [ -z "$OCP_TOKEN" ]
  then
  exit 9991
fi

#################################################################################
WP_ROOT="/var/www/webroot/ROOT"   

REDIS_CLIENT="phpredis"           #  can be switched to relay when its ready
REDIS_DATABASE=0

#################################################################################
# is relay installed - if so link together

echo "checking for Relay"

RELAY_EXT_DIR=$(php-config --extension-dir)
RELAY_SO=$RELAY_EXT_DIR/relay.so
RELAY_INI_DIR=$(php-config --ini-dir) 
RELAY_INI=$RELAY_INI_DIR/relay.ini

if [ -f "$RELAY_SO" ]; then
  if [ -f "$RELAY_INI" ]; then
    REDIS_CLIENT="relay"
  fi
fi

##################################################################################
# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
cd "$WP_ROOT"
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$'
SKIPLIST=$(wp --skip-plugins --skip-themes --skip-packages --quiet  plugin list --field=name   2>/dev/null   | grep -v $SKIPPLUGINS | tr '\n' ',' )

##################################################################################
# force deactivation of litespeed object cache pro if it is enabled

echo "checking for litespeed cache"

cd "$WP_ROOT"
wp --skip-plugins --skip-themes --skip-packages  --quiet  plugin is-installed litespeed-cache  2>/dev/null

if [ "$?" -eq 0 ]
then
   wp --skip-plugins --skip-themes --skip-packages --quiet  plugin is-active litespeed-cache  2>/dev/null

   if [ "$?" -eq 0 ]
     then

       ## disable the ls object cache before doing any other actions
       wp --skip-plugins="$SKIPLIST" --skip-themes --skip-packages --quiet  litespeed-option set object false  2>/dev/null
     
    fi
fi

##################################################################################
## deploy new version of object cache pro
##################################################################################

#set -e

##################################################################################
## SETUP OCP CONFIG
##################################################################################

echo "prepare ocp_config"

cd "$WP_ROOT"
OCP_CONFIG=$(cat << EOF
[
'token' => '${OCP_TOKEN}',
'host' => '/var/run/redis/redis.sock',
'port' => 0,
'database' => $REDIS_DATABASE,
'prefix' => 'db${REDIS_DATABASE}:',
'client' => '${REDIS_CLIENT}',
'timeout' => 0.5,
'read_timeout' => 0.5,
'retry_interval' => 10,
'retries' => 3,
'backoff' => 'smart',
'compression' => 'zstd',
'serializer' => 'igbinary',
'async_flush' => true,
'split_alloptions' => true,
'prefetch' => false,
'shared' => true,
'debug' => false,
'non_persistent_groups' => [
	'comment',
	'counts',
	'plugins',
	'themes',
	'wc_session_id',
	'learndash_reports',
	'learndash_admin_profile',
 ], 
]
EOF
)

##################################################################################
# set wp-config to writeable 
cd "$WP_ROOT"

CUR_CHMOD=$( stat --format '%a' wp-config.php )
chmod 644 wp-config.php

##################################################################################

wp --skip-plugins --skip-themes --skip-packages --quiet  config has WP_REDIS_CONFIG  2>/dev/null


if [ "$?" -ne 0 ]
  then
    ## disable the ls object cache before doing any other actions
    wp --skip-plugins --skip-themes --skip-packages --quiet  config set --raw WP_REDIS_CONFIG "${OCP_CONFIG}"  2>/dev/null
     
fi


##################################################################################
## SETUP OCP MERGE CONSTANTS FOR non_persistent_groups - if not already created
##################################################################################

cd "$WP_ROOT"
## TODO - talk further with Till on this 

##################################################################################
## DISABLE OTHER REDIS TOOLS PER GUIDE
##################################################################################

cd "$WP_ROOT"
wp  --skip-plugins --skip-themes --skip-packages --quiet  config set --raw WP_REDIS_DISABLED "getenv('WP_REDIS_DISABLED') ?: false"  2>/dev/null


##################################################################################
# set wp-config to previous state
cd "$WP_ROOT"

chmod "$CUR_CHMOD" wp-config.php


##################################################################################
## INSTALL OCP
##################################################################################


cd "$WP_ROOT"

# attempt to work out plugin path
#PLUGIN_PATH=$(wp --skip-plugins --skip-themes --skip-packages --quiet   plugin path --allow-root --path="$WP_ROOT" 2>/dev/null )
#if [ ! -d "$PLUGIN_PATH" ]

# then
#  echo "$PLUGIN_PATH does not exist - removing special characters"
#  PLUGIN_PATH=$(echo -e "$PLUGIN_PATH" | sed -z 's/[" \t\n\r]//g')
#  echo "$PLUGIN_PATH"
#fi

#if [ ! -d "$PLUGIN_PATH" ]
# then
#  echo "$PLUGIN_PATH does not exist - forcing default"
#  PLUGIN_PATH="/var/www/webroot/ROOT/wp-content/plugins"
#  echo "$PLUGIN_PATH"
#fi

##### this is failing too often due to BAD PHP code in wordpress sites
##### for now force all sites to the same physical path - which is correct for VZ sites

PLUGIN_PATH="/var/www/webroot/ROOT/wp-content/plugins"

##################################################################################
# attempt to install plugin to path

echo "install OCP plugin"

cd "/tmp"
OCP_PLUGIN_TMP=$(mktemp ocp.XXXXXXXX).zip
OCP_PLUGIN_TMP_PATH="/tmp/$OCP_PLUGIN_TMP"

curl -sSL -o "$OCP_PLUGIN_TMP" "https://objectcache.pro/plugin/object-cache-pro.zip?token=${OCP_TOKEN}"
unzip -o "$OCP_PLUGIN_TMP" -d "$PLUGIN_PATH" 

#cd "$WP_ROOT"
#wp plugin install "${OCP_PLUGIN_TMP_PATH}" --skip-plugins --quiet   2>/dev/null
#cd "/tmp"

rm "$OCP_PLUGIN_TMP"


##################################################################################
## ACTIVATE OCP and enable redis
##################################################################################

#set +e

echo "activate plugin"

cd "$WP_ROOT"
wp --skip-plugins --skip-themes --skip-packages --quiet  plugin activate object-cache-pro  2>/dev/null

echo "force enable plugin"

cd "$WP_ROOT"
wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  redis enable --force  2>/dev/null

echo "force cache flush"

cd "$WP_ROOT"
wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  cache flush  2>/dev/null

echo "force redis flush"

cd "$WP_ROOT"
wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  redis flush  2>/dev/null

# End of Object Cache Pro deployment
##################################################################################
