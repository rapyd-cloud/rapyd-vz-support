#!/bin/bash

echo "Running script: $(readlink -f "$0")"

echo "Build 2";

#load parameters
OCP_TOKEN=$1
SHOULD_ACTIVATE_DEFAULT=$2

if [ "$SHOULD_ACTIVATE_DEFAULT" = "true" ]; then
  SHOULD_ACTIVATE_DEFAULT=1
elif [ "$SHOULD_ACTIVATE_DEFAULT" = "false" ]; then
  SHOULD_ACTIVATE_DEFAULT=0
fi

echo "SHOULD_ACTIVATE_DEFAULT: $SHOULD_ACTIVATE_DEFAULT";

if [ -z "$OCP_TOKEN" ]
  then
  exit 9991
fi

##################################################################################
##################################################################################
##################################################################################
# - Check if Object Cache Pro is installed or not.
#   - If Installed
#       - Check if using out licence or not
#           - Yes
#               - Uninstall & Continue
#           - No
#               - Skip
#   - If not installed
#       - Installed Redis Object Cache
##################################################################################


WP_ROOT="/var/www/webroot/ROOT"   

REDIS_CLIENT="phpredis"         
REDIS_DATABASE=0

##################################################################################
# set wp-config to writeable 
cd "$WP_ROOT"

CUR_CHMOD=$( stat --format '%a' wp-config.php )
chmod 644 wp-config.php

##################################################################################
# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
cd "$WP_ROOT"
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$'
SKIPLIST=$(wp --skip-plugins --skip-themes --skip-packages --quiet  plugin list --field=name   2>/dev/null   | grep -v $SKIPPLUGINS | tr '\n' ',' )

##################################################################################
# force deactivation of litespeed object cache if it is enabled

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

ocpWasInstalled=0;
ocpWasActivated=0;
redisCacheInstalled=0;
redisCacheActivated=0;
fixOCPClient=0;
InstallRedisCache=0;

# collect the non_persistent_groups before anything get's deleted. 
EXISTS_REDIS_IGNORED_GROUPS=$(wp --skip-plugins --skip-themes --skip-packages eval 'error_reporting(0); ini_set("display_errors", "0"); if (defined("WP_REDIS_CONFIG") && WP_REDIS_CONFIG["non_persistent_groups"]) { echo json_encode(WP_REDIS_CONFIG["non_persistent_groups"],JSON_PRETTY_PRINT); exit(0); }' 2>/dev/null);

echo "Existing Redis Ignored Groups: $EXISTS_REDIS_IGNORED_GROUPS";

##################################################################################
# Decide wether to install Redis Object Cache or not.
##################################################################################

# check if the object cache pro plugin exists.
wp plugin is-active object-cache-pro --quiet --skip-plugins 2>/dev/null

if [ "$?" -eq 0 ]; then

  echo "Object Cache Pro Found and Activated";

  ocpWasActivated=1;
  ocpWasInstalled=1;

  # check if it has config defined.
  wp --skip-plugins --skip-themes --skip-packages --quiet  config has WP_REDIS_CONFIG  2>/dev/null

  if [ "$?" -ne 0 ];then # when where is no WP_REDIS_CONFIG
      InstallRedisCache=1;
  else # when there is WP_REDIS_CONFIG
  
      # if it is defined then we need to check if it is using our licence or not
      wp --skip-plugins --skip-themes --skip-packages --quiet  config get WP_REDIS_CONFIG 2>/dev/null | grep -q $OCP_TOKEN

      if [ "$?" -eq 0 ];then
        InstallRedisCache=1;
      else
        # if it is not using our licence then we can skip the installation.
        echo "Object Cache Pro is already installed and using a different licence. Skipping installation."        
        fixOCPClient=1;

      fi

  fi

else
  
  wp --skip-plugins --skip-themes --skip-packages  --quiet  plugin is-installed object-cache-pro  2>/dev/null
  if [ "$?" -eq 0 ]; then
    echo "Object Cache Pro Found and Installed";
    ocpWasInstalled=1;
  fi
  InstallRedisCache=1;
fi

######## END


##################################################################################
# Fix Object Cache Pro Client.
##################################################################################
if [ "$fixOCPClient" -eq 1 ]; then

  # disable object cache pro before doing anything if it is activated.
  if [ "$ocpWasActivated" -eq 1 ]; then
     wp --skip-plugins="$SKIPLIST" --skip-themes --skip-packages redis disable  2>/dev/null
  fi

  WP_REDIS_CONFIG_DATA=$(wp --skip-plugins --skip-themes --skip-packages --quiet  config get WP_REDIS_CONFIG 2>/dev/null)
  # change relay to phpredis as it's not supported by rapyd.
  WP_REDIS_CONFIG_DATA=$(echo "$WP_REDIS_CONFIG_DATA" | sed -e "s/\"relay\"/\"phpredis\"/g" -e "s/'relay'/'phpredis'/g")
  # make zstd to none as it's not supported by phpredis.
  WP_REDIS_CONFIG_DATA=$(echo "$WP_REDIS_CONFIG_DATA" | sed -e "s/\"zstd\"/\"none\"/g" -e "s/'zstd'/'none'/g")
  wp --skip-plugins --skip-themes --skip-packages --quiet --raw config set WP_REDIS_CONFIG "$WP_REDIS_CONFIG_DATA" 2>/dev/null;

  # enable object cache pro after fixing the client. if it was activated before.
  if [ "$ocpWasActivated" -eq 1 ]; then
     wp --skip-plugins="$SKIPLIST" --skip-themes --skip-packages redis enable  2>/dev/null
  fi

fi

##################################################################################
# End the script with error if not installing Redis Cache.
##################################################################################

if [ "$InstallRedisCache" -eq 0 ]; then
  echo "Skipping Redis Object Cache installation"
  exit 1
fi

# check if redis cache is installed.
wp --skip-plugins --skip-themes --skip-packages --quiet plugin is-installed redis-cache
if [ "$?" -eq 0 ]; then
  echo "Redis Object Cache Found - Installed";
  redisCacheInstalled=1;
else
  echo "Redis Object Cache Found - Not Installed";
fi

# check if redis cache is activated.
wp --skip-plugins --skip-themes --skip-packages  --quiet plugin is-active redis-cache
if [ "$?" -eq 0 ]; then
  echo "Redis Object Cache Found - Activated";
  redisCacheActivated=1;
else
  echo "Redis Object Cache Found - Not Activated";
fi


##################################################################################
# Decide wether to activate Redis Object Cache or not.
##################################################################################

redisCacheShouldActivate=$SHOULD_ACTIVATE_DEFAULT; # default activate.

# if object cache pro was installed and not activated then we can skip the redis cache installation.
if [ "$ocpWasInstalled" -eq 1 ] && [ "$ocpWasActivated" -eq 0 ]; then
  echo "Object Cache Pro is installed but not activated.  Skipping Redis Object Cache activation";
  redisCacheShouldActivate=0;
fi

# if redis object cache was installed and not activated then we can skip the redis cache installation.
if [ "$redisCacheInstalled" -eq 1 ] && [ "$redisCacheActivated" -eq 0 ]; then
  echo "Redis Object Cache is installed but not activated. Skipping Redis Object Cache activation";
  redisCacheShouldActivate=0;
fi

# if one of the cache plugin found activated then we can activte the plugin.
if [ "$redisCacheActivated" -eq 1 ] || [ "$ocpWasActivated" -eq 1 ]; then
  echo "Redis Cache is already activated. Will activate it again after installation.";
  redisCacheShouldActivate=1;
fi

######## END


if [ "$ocpWasInstalled" -eq 1 ]; then
  echo "Removing Object Cache Pro";
  # if it is using our licence then we need to uninstall the plugin.
  echo "Object Cache Pro is using our licence. Uninstalling it.";
  wp plugin deactivate object-cache-pro --quiet --skip-themes --skip-plugins="$SKIPLIST" 2>/dev/null || true
  wp plugin delete object-cache-pro --quiet --skip-themes --skip-plugins="$SKIPLIST" 2>/dev/null || true
fi

echo "Installing Redis Object Cache";

echo "Removing WP_REDIS_CONFIG configuration from wp-config.php";
wp --skip-plugins --skip-themes --skip-packages --quiet config delete WP_REDIS_CONFIG 2>/dev/null;

##################################################################################
# Install Redis Object Cache

echo "installing plugin"

# hard clear out known injections 
rm -f "$WP_ROOT/wp-content/advanced-cache.php"
rm -f "$WP_ROOT/wp-content/object-cache.php"

# mu version installed by cloudways
rm -f "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro.php"
rm -rf "$WP_ROOT/wp-content/mu-plugins/redis-cache-pro"

wp plugin install redis-cache --skip-plugins="$SKIPLIST" 2>/dev/null

cd "$WP_ROOT"

echo "setting config";

# defaults wp-config.php configurations.
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_SCHEME "unix" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_PATH "/var/run/redis/redis.sock" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_PORT "0" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_DATABASE "$REDIS_DATABASE" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_PREFIX "db${REDIS_DATABASE}:" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_CLIENT "${REDIS_CLIENT}" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_TIMEOUT "0.5" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_READ_TIMEOUT "0.5" 2>/dev/null
wp --skip-plugins --skip-themes --skip-packages --quiet config set WP_REDIS_RETRY_INTERVAL "10" 2>/dev/null

WP_REDIS_IGNORED_GROUPS=$(cat << EOF
[
	'comment',
	'counts',
	'plugins',
	'themes',
	'wc_session_id',
	'learndash_reports',
	'learndash_admin_profile',
 ]
EOF
)

if [ -n "$(echo -n "$EXISTS_REDIS_IGNORED_GROUPS" | tr -d '[:space:]')" ];then
  echo "using existing site ignored groups";
  WP_REDIS_IGNORED_GROUPS="$EXISTS_REDIS_IGNORED_GROUPS"
fi;

wp --skip-plugins --skip-themes --skip-packages --quiet config set --raw WP_REDIS_IGNORED_GROUPS "${WP_REDIS_IGNORED_GROUPS}" 2>/dev/null


# do not active redis cache if ocp was found deactivated.
if [ "$redisCacheShouldActivate" -eq 1 ]; then
  
  echo "activate plugin.."

  wp --skip-plugins --skip-themes --skip-packages --quiet  plugin activate redis-cache  2>/dev/null
  
  echo "force enable plugin"

  wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  redis enable --force  2>/dev/null

  echo "force cache flush..."

  cd "$WP_ROOT"
  wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  cache flush  2>/dev/null

  echo "force redis flush"

  cd "$WP_ROOT"
  wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  redis flush  2>/dev/null

else 
  echo "Non of object cache plugin was found activated. Skipping Redis Cache activation.";
fi

# set wp-config to previous state
cd "$WP_ROOT"

chmod "$CUR_CHMOD" wp-config.php