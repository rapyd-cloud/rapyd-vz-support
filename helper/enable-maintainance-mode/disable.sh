#!/usr/bin/env bash

set -u
set -o pipefail

failed=0

echo "Disabling Maintenance Mode to all sites"

maintenanceModeDocRoot="/var/www/webroot/maintenance-mode"
rm -rf $maintenanceModeDocRoot
echo "Removed Maintenance content in $maintenanceModeDocRoot"

echo "Site: PhpMyAdmin"

pmaXmlPath="/usr/share/phpMyAdmin/vhost.conf"
pmaXmlPathBackup="/usr/share/phpMyAdmin/vhost.conf.pre-maintenance-bk"
if [[ -f "$pmaXmlPathBackup" ]]; then
   
    echo "  Recovering Original phpmyadmin configuration."
    cp -f "$pmaXmlPathBackup" "$pmaXmlPath"
    rm -f $pmaXmlPathBackup;
    echo "  Disabled"

else
    echo "  Already Disabled, skipping disabling for phpmyadmin."
fi

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    baseDir=$(jq -r '.basedir' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")

    echo "Site: $siteSlug"

    xmlPath="$baseDir/conf/vhconf.xml"
    backup="${baseDir}/conf/vhconf.xml.pre-maintenance-bk"
    
    if [[ ! -f "$backup" ]]; then
        echo "  Maintenance Mode already disabled, skipping disabling for site $siteSlug."
        continue
    fi

    # backup the conf file.
    if [[ -f "$backup" ]]; then
        timestamp=$(date +"%Y%m%d-%H%M%S")
        cp -f $backup $xmlPath;
        rm -f $backup;
        echo "  Disabled"
    else
        echo "  No conf file found at $webroot/conf/vhconf.xml. Exiting."
        exit 1
    fi;

done < <(rapyd site list --format json | jq -c '.[]')

service lsws restart;

echo "SUCCESS: Enabled Maintenance Mode to all sites"
exit 0
