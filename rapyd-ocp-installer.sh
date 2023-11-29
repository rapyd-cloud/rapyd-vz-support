#!/usr/bin/bash

# must be run as litespeed
# must pass in  OCP_TOKEN 

##################################################################################
#load parameters
OCP_TOKEN=$1

##################################################################################

if [ -z "$OCP_TOKEN" ]
  then
  exit 9991
fi

#################################################################################
WPOCP_ROOT="/var/www/webroot/ROOT"   

REDIS_CLIENT="phpredis"           #  can be switched to relay when its ready
REDIS_DATABASE=0

#################################################################################
# is relay installed - if so link together
RELAY_EXT_DIR=$(php-config --extension-dir)
RELAY_SO=$RELAY_EXT_DIR/relay.so
RELAY_INI_DIR=$(php-config --ini-dir) 
RELAY_INI=$RELAY_INI_DIR/relay.ini

if [ -f "$RELAY_SO" ]; then
  if [ -f "$RELAY_SO" ]; then
    REDIS_CLIENT="relay"
  fi
fi

##################################################################################
# force deactivation of litespeed object cache pro if it is enabled

cd "$WPOCP_ROOT"
wp plugin is-installed litespeed-cache --quiet

if [ "$?" -eq 0 ]
then
   wp plugin is-active litespeed-cache --quiet

   if [ "$?" -eq 0 ]
     then

       ## disable the ls object cache before doing any other actions
       wp litespeed-option set object false --quiet   
     
    fi
fi

##################################################################################
## deploy new version of object cache pro
##################################################################################

set -e

##################################################################################
## SETUP OCP CONFIG
##################################################################################

cd "$WPOCP_ROOT"
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
]
EOF
)

cd "$WPOCP_ROOT"
wp config set --raw WP_REDIS_CONFIG "${OCP_CONFIG}" --quiet

##################################################################################
## SETUP OCP MERGE CONSTANTS FOR non_persistent_groups - if not already created
##################################################################################

cd "$WPOCP_ROOT"
## TODO - talk further with Till on this 

##################################################################################
## DISABLE OTHER REDIS TOOLS PER GUIDE
##################################################################################

cd "$WPOCP_ROOT"
wp config set --raw WP_REDIS_DISABLED "getenv('WP_REDIS_DISABLED') ?: false" --quiet

##################################################################################
## INSTALL OCP
##################################################################################

cd "$WPOCP_ROOT"
PLUGIN_PATH=$(wp plugin path --allow-root --path="$WPOCP_ROOT" --quiet)

cd "/tmp"
OCP_PLUGIN_TMP=$(mktemp ocp.XXXXXXXX).zip

curl -sSL -o "$OCP_PLUGIN_TMP" "https://objectcache.pro/plugin/object-cache-pro.zip?token=${OCP_TOKEN}"
unzip -o "$OCP_PLUGIN_TMP" -d "$PLUGIN_PATH" 
rm "$OCP_PLUGIN_TMP"

##################################################################################
## ACTIVATE OCP and enable redis
##################################################################################

cd "$WPOCP_ROOT"
wp plugin activate object-cache-pro --quiet

cd "$WPOCP_ROOT"
wp redis enable --force --quiet

cd "$WPOCP_ROOT"
wp cache flush --quiet

cd "$WPOCP_ROOT"
wp redis flush --quiet

# End of Object Cache Pro deployment
##################################################################################
