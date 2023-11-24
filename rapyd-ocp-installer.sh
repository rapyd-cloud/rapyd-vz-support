#!/usr/bin/bash

# must be run as litespeed
# must pass in  OCP_TOKEN 

##################################################################################
#load parameters
OCP_TOKEN=$1

if [ -z "$OCP_TOKEN" ]
  then
  exit 9991
fi

#################################################################################
WP_ROOT="/var/www/webroot/ROOT"

REDIS_CLIENT="phpredis"   #  can be switched to relay when its ready
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

cd "$WP_ROOT"

wp plugin is-installed litespeed-cache

if [ "$?" -eq 0 ]
then
   wp plugin is-active litespeed-cache

   if [ "$?" -eq 0 ]
     then

       ## disable the ls object cache before doing any other actions
       wp litespeed-option set object false   
     
    fi
fi

# deploy new version of object cache pro

set -e

##################################################################################
## INSTALL OCP
##################################################################################

cd "$WP_ROOT"
PLUGIN_PATH=$(wp plugin path --allow-root --path="$WP_ROOT")

echo "$PLUGIN_PATH"

PLUGIN=$(mktemp)
curl -sSL -o $PLUGIN "https://objectcache.pro/plugin/object-cache-pro.zip?token=${OCP_TOKEN}"
unzip -o $PLUGIN -d "$PLUGIN_PATH" 
rm $PLUGIN

cd "$WP_ROOT"

OCP_CONFIG=$(cat <<EOF
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

cd "$WP_ROOT"

wp config set --raw WP_REDIS_CONFIG "${OCP_CONFIG}"

wp config set --raw WP_REDIS_DISABLED "getenv('WP_REDIS_DISABLED') ?: false"

wp plugin activate object-cache-pro

wp redis enable --force

wp cache flush

wp redis flush

# End of Object Cache Pro deployment
