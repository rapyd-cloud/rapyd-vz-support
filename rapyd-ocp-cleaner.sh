#! /bin/bash

cd /var/www/webroot/ROOT/

# if installed clean up gracefully 

wp plugin is-installed object-cache-pro

if [ "$?" -eq 0 ]
then
   wp plugin is-active object-cache-pro
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate object-cache-pro || true
       wp plugin delete object-cache-pro || true
    fi
fi
   
