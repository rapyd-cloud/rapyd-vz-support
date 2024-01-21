#!/bin/bash

cd /var/www/webroot/ROOT/

# if installed clean up gracefully 

wp plugin is-installed object-cache-pro --quiet 2>/dev/null

if [ "$?" -eq 0 ]
then
   wp plugin is-active object-cache-pro --quiet 2>/dev/null
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate object-cache-pro --quiet 2>/dev/null || true
       wp plugin delete object-cache-pro --quiet 2>/dev/null || true
    fi
fi

# force a clear exit regardless of any errors in script results 

exit 0
