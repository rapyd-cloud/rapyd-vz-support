#!/bin/bash

#load parameters
OCP_TOKEN=$1

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
InstallRedisCache=0;
# collect the non_persistent_groups before anything get's deleted. 
EXISTS_REDIS_IGNORED_GROUPS=$(wp eval 'if (WP_REDIS_CONFIG["non_persistent_groups"]) { echo json_encode(WP_REDIS_CONFIG["non_persistent_groups"],JSON_PRETTY_PRINT); exit(0); }' 2>/dev/null);

echo "Existing Redis Ignored Groups: $EXISTS_REDIS_IGNORED_GROUPS";

# check if the object cache pro plugin exists.
wp plugin is-active object-cache-pro --quiet --skip-plugins 2>/dev/null

if [ "$?" -eq 0 ]; then

  ocpWasInstalled=1;

  wp --skip-plugins --skip-themes --skip-packages --quiet  plugin is-active object-cache-pro  2>/dev/null

  if [ "$?" -eq 0 ]; then
    ocpWasActivated=1;
  fi
    
  # check if it has config defined.
  wp --skip-plugins --skip-themes --skip-packages --quiet  config has WP_REDIS_CONFIG  2>/dev/null

  if [ "$?" -ne 0 ];then
      # if it's not defined then no need to worry and uninstall the plugin.
      wp plugin deactivate object-cache-pro --quiet --skip-plugins="$SKIPLIST" 2>/dev/null || true
      wp plugin delete object-cache-pro --quiet --skip-plugins="$SKIPLIST" 2>/dev/null || true
      InstallRedisCache=1;
  else
      # if it is defined then we need to check if it is using our licence or not
      wp --skip-plugins --skip-themes --skip-packages --quiet  config get WP_REDIS_CONFIG 2>/dev/null | grep -q $OCP_TOKEN

      if [ "$?" -eq 0 ];then
        # if it is using our licence then we need to uninstall the plugin.
        echo "Object Cache Pro is using our licence. Uninstalling it.";
        wp plugin deactivate object-cache-pro --quiet --skip-plugins="$SKIPLIST" 2>/dev/null || true
        wp plugin delete object-cache-pro --quiet --skip-plugins="$SKIPLIST" 2>/dev/null || true
        InstallRedisCache=1;
      else
        # if it is not using our licence then we can skip the installation.
        echo "Object Cache Pro is already installed and using a different licence. Skipping installation."
      fi

  fi

else
  InstallRedisCache=1;
fi

if [ "$InstallRedisCache" -eq 0 ]; then
  echo "Skipping Redis Object Cache installation"
  exit 1
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

wp plugin install redis-cache --activate --skip-plugins="$SKIPLIST" 2>/dev/null

cd "$WP_ROOT"

echo "setting config";

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

echo "activate plugin"

# do not active redis cache if ocp was found deactivated.
if [ $ocpWasInstalled -eq 1 ] && [ $ocpWasActivated -eq 0 ]; then
  
  wp --skip-plugins --skip-themes --skip-packages --quiet  plugin activate redis-cache  2>/dev/null
  echo "force enable plugin"

  wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  redis enable --force  2>/dev/null

  echo "force cache flush"

  cd "$WP_ROOT"
  wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  cache flush  2>/dev/null

  echo "force redis flush"

  cd "$WP_ROOT"
  wp --skip-plugins="$SKIPLIST" --skip-themes --quiet  redis flush  2>/dev/null

fi

# set wp-config to previous state
cd "$WP_ROOT"

chmod "$CUR_CHMOD" wp-config.php