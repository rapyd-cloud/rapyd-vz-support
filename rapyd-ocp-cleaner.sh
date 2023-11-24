#! /bin/bash

cd /var/www/webroot/ROOT/

# if installed clean up gracefully 

wp plugin is-installed object-cache-pro --quiet

if [ "$?" -eq 0 ]
then
   wp plugin is-active object-cache-pro --quiet
 
   if [ "$?" -eq 0 ]
     then
       wp plugin deactivate object-cache-pro --quiet || true
       wp plugin delete object-cache-pro --quiet || true
    fi
fi
   
