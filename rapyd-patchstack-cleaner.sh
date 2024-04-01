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

#############################################################################

cd "$WP_ROOT"
rm -rf psresponse.txt

##################################################################################
# get the current list of all active plugins 
# we are going to use this later to skip all installed plugins apart for those we want to test
cd "$WP_ROOT"
SKIPPLUGINS='^litespeed-cache$\|^object-cache-pro$\|^redis-cache$\|^patchstack$'
SKIPLIST=$(wp plugin list --field=name --quiet --skip-plugins 2>/dev/null | grep -v $SKIPPLUGINS | tr '\n' ',' )

##################################################################################
# deactivate and remove plugin
cd "$WP_ROOT"
wp plugin deactivate patchstack --uninstall --network --force --quiet --skip-plugins 2>/dev/null

##################################################################################

cd "$WP_ROOT"
rm -rf psresponse.txt

HEADER="HostToken:$PS_TOKEN_KEY"

EXISTINGSITE="{\"url\": \"$PS_URL\"}"

HTTP_RESPONSE=$( curl -X POST https://api.patchstack.com/hosting/site/search -H "$HEADER" -H 'Content-Type: application/json' -d "$EXISTINGSITE" -o psresponse.txt -w "%{http_code}" )

if [[ "$HTTP_RESPONSE" -ne 200 ]] ; then
  
    echo "unable to locate existing domain in our account patchstack - response : $HTTP_RESPONSE"
  
  else

    #cat psresponse.txt
    
    IS_SITE_ID=$( cat psresponse.txt | jq -r '.[].siteid' )
    IS_API_ID=$( cat psresponse.txt | jq -r '.[].api.id' )
    IS_API_SECRET=$( cat psresponse.txt | jq -r '.[].api.secret' )

    TARGETURL="https://api.patchstack.com/hosting/site/$IS_SITE_ID/delete"

    HTTP_RESPONSE=$( curl -X POST "$TARGETURL" -H "$HEADER" -H 'Content-Type: application/json' -o psresponse2.txt -w "%{http_code}" )
  
fi

##################################################################################

