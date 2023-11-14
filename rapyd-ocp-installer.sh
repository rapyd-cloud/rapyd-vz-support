#! /bin/bash

source /etc/profile

# must be run as litespeed
# must pass in  OCP_TOKEN , vzuid , vznodeid

##################################################################################
#load parameters
OCP_TOKEN=$1

WP_ROOT="/var/www/webroot/ROOT"

REDIS_CLIENT="phpredis"   #  can be switched to relay when its ready

REDIS_DATABASE=0

if [ -z "$OCP_TOKEN" ]
  then
  exit 9991
fi

##################################################################################
# force deactivation of litespeed object cache pro if it is enabled

cd $WP_ROOT

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

##################################################################################
# REMOVE any existing versions of object cache pro

cd $WP_ROOT

rm -f "$WP_ROOT/wp-content/advanced-cache.php"
rm -f "$WP_ROOT/wp-content/object-cache.php"
rm -f "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro.php"
rm -rf "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro"

# deploy new version of object cache pro

set -e

##################################################################################
## INSTALL OCP
##################################################################################

cd $WP_ROOT

PLUGIN=$(mktemp)
curl -sSL -o $PLUGIN "https://objectcache.pro/plugin/object-cache-pro.zip?token=${OCP_TOKEN}"
unzip $PLUGIN -d "$(wp plugin path --allow-root --path=$WP_ROOT)" 
rm $PLUGIN

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

wp config set --raw WP_REDIS_CONFIG "${OCP_CONFIG}"

wp config set --raw WP_REDIS_DISABLED "getenv('WP_REDIS_DISABLED') ?: false"

wp plugin activate object-cache-pro

wp redis enable --force

wp cache flush

# End of Object Cache Pro deployment
