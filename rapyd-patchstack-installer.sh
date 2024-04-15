#!/bin/bash

# must be run as litespeed 
# must pass in  PS_USER and PS_TOKEN and PS_URL

##################################################################################
#load parameters
PS_USER=$1
PS_TOKEN=$2
PS_URL=$3

##################################################################################
##################################################################################

WP_ROOT="/var/www/webroot/ROOT"   

##################################################################################

#echo "$PS_USER"
#echo "$PS_TOKEN"
#echo "$PS_URL"

if [ -z "$PS_USER" ]
  then
  exit 9991
fi

if [ -z "$PS_TOKEN" ]
  then
  exit 9992
fi

if [ -z "$PS_URL" ]
  then
  exit 9993
fi

PS_USER_KEY=$( echo "$PS_USER" | base64 --decode )
#echo $PS_USER_KEY

PS_TOKEN_KEY=$( echo "$PS_TOKEN" | base64 --decode )
#echo $PS_TOKEN_KEY


#################################################################################
# activate the plugin

cd "$WP_ROOT"
rm -rf psresponse.txt

HEADER="HostToken:$PS_TOKEN_KEY"

NEWSITE="{\"url\": \"$PS_URL\", \"userid\": $PS_USER_KEY, \"strict\": true }"

#echo "$HEADER"
#echo "$NEWSITE"

HTTP_RESPONSE=$( curl -X POST https://api.patchstack.com/hosting/site/add -H "$HEADER" -H 'Content-Type: application/json' -d "$NEWSITE" -o psresponse.txt -w "%{http_code}" )

if [[ "$HTTP_RESPONSE" -ne 200 ]] ; then
  echo "unable to register domain to patchstack - response : $HTTP_RESPONSE"
  exit 9994
fi

##############################################################################
#check for error 
IS_ERROR=$( cat psresponse.txt | jq -r '.error' )
#echo $IS_ERROR
# the only real error here right now is - URL already registered 

if [[ ! -z "$IS_ERROR" ]] ; then

  cd "$WP_ROOT"
  rm -rf psresponse.txt

  EXISTINGSITE="{\"url\": \"$PS_URL\"}"

  HTTP_RESPONSE=$( curl -X POST https://api.patchstack.com/hosting/site/search -H "$HEADER" -H 'Content-Type: application/json' -d "$EXISTINGSITE" -o psresponse.txt -w "%{http_code}" )

  if [[ "$HTTP_RESPONSE" -ne 200 ]] ; then
    echo "unable to locate existing domain in our account patchstack - response : $HTTP_RESPONSE"
    exit 9995
  fi

  #cat psresponse.txt
  IS_API_ID=$( cat psresponse.txt | jq -r '.[].api.id' )
  IS_API_SECRET=$( cat psresponse.txt | jq -r '.[].api.secret' )

else
  #IS_SUCCESS=$( cat psresponse.txt | jq -r '.success' )
  #echo $IS_SUCCESS
  IS_API_ID=$( cat psresponse.txt | jq -r '.api.id' )
  IS_API_SECRET=$( cat psresponse.txt | jq -r '.api.secret' )

fi

cd "$WP_ROOT"
rm -rf psresponse.txt

if [[ -z "$IS_API_ID" ]] ; then
  echo "Patchstack cant locate this domain in our list of sites"
  exit 9996
fi

##################################################################################
# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
cd "$WP_ROOT"
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$\|^patchstack$'
SKIPLIST=$(wp --skip-plugins --skip-themes --quiet   plugin list --field=name    2>/dev/null | grep -v $SKIPPLUGINS | tr '\n' ',' )

#################################################################################
# install patchstack 

cd "$WP_ROOT"

# force patchstack firewall off 
wp --skip-plugins --skip-themes --quiet   option update patchstack_basic_firewall 0    2>/dev/null

# force install of latest version of patchstack
wp --skip-plugins --skip-themes --quiet  plugin install patchstack --force --activate    2>/dev/null

# activate using wpcli anr registered api and secret
wp --skip-plugins="$SKIPLIST" --skip-themes --quiet     patchstack activate $IS_API_ID $IS_API_SECRET  2>/dev/null


RESULT="$?"
if [ "$RESULT" -eq 0 ]
then
  echo "PatchStack installed and Activated"
else
  echo "PatchStack activation failed"
  exit 9999
fi


#################################################################################

