#!/usr/bin/env bash

set -u
set -o pipefail

get_html() {
    cat <<'EOF'
<html lang="en" class=""><head>
    <meta charset="UTF-8">
    <title>Maintenance Mode</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <meta name="robots" content="noindex,nofollow">

    <style>
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
            background: #0f172a;
            color: #e5e7eb;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
        }

        .container {
            max-width: 520px;
            text-align: center;
            padding: 40px;
            background: #020617;
            border-radius: 12px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
        }

        h1 {
            font-size: 28px;
            margin-bottom: 12px;
            color: #f8fafc;
        }

        p {
            font-size: 16px;
            line-height: 1.6;
            color: #cbd5f5;
        }

        .status {
            display: inline-block;
            margin: 20px 0;
            padding: 6px 14px;
            background: #1e293b;
            border-radius: 999px;
            font-size: 14px;
            color: #93c5fd;
        }

        .footer {
            margin-top: 30px;
            font-size: 13px;
            color: #94a3b8;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="status">🚧 Maintenance in Progress</div>
        <h1>We’ll be back shortly</h1>
        <p>
            Our system is currently undergoing scheduled maintenance.<br>
            We’re working to restore full service as quickly as possible.
        </p>
        <p>
            Thank you for your patience.
        </p>
        
    </div>


</body></html>
EOF
}

failed=0

echo "Enabling Maintenance Mode to all sites"

maintenanceModeDocRoot="/var/www/webroot/maintenance-mode"

mkdir -p $maintenanceModeDocRoot

index_html="$maintenanceModeDocRoot/index.html"
get_html > "$index_html"

echo "Stored Maintenance content in $index_html"

echo "Site: PhpMyAdmin"

pmaXmlPath="/usr/share/phpMyAdmin/vhost.conf"
pmaXmlPathBackup="/usr/share/phpMyAdmin/vhost.conf.pre-maintenance-bk"
if [[ ! -f "$pmaXmlPathBackup" ]]; then
   
    echo "  Backup file $pmaXmlPathBackup not found, creating one."
    cp -f "$pmaXmlPath" "$pmaXmlPathBackup"
    echo "  $pmaXmlPath: backup created ($(basename "$pmaXmlPathBackup"))"

    xmlstarlet ed -L -u "/virtualHostConfig/docRoot" -v "${maintenanceModeDocRoot}/" "$pmaXmlPath"
    echo "  Enabled"

else
    echo "  Backup file $pmaXmlPathBackup already exists, skipping enabling for phpmyadmin."
fi

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    baseDir=$(jq -r '.basedir' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")

    echo "Site: $siteSlug"

    xmlPath="$baseDir/conf/vhconf.xml"
    backup="${baseDir}/conf/vhconf.xml.pre-maintenance-bk"
    
    if [[ -f "$backup" ]]; then
        echo "  Backup file $backup already exists, skipping enabling for site $siteSlug."
        continue
    fi

    # backup the conf file.
    if [[ -f "$xmlPath" ]]; then
        timestamp=$(date +"%Y%m%d-%H%M%S")
        cp -f "$baseDir/conf/vhconf.xml" "$backup"
        echo "  $baseDir/conf/vhconf.xml: backup created ($(basename "$backup"))"
    else
        echo "  No conf file found at $webroot/conf/vhconf.xml. Exiting."
        exit 1
    fi;

    # change the path
    xmlstarlet ed -L -u "/virtualHostConfig/docRoot" -v "${maintenanceModeDocRoot}/" "$xmlPath"

done < <(rapyd site list --format json | jq -c '.[]')

killall -9 lsphp;
service lsws restart;

echo "SUCCESS: Enabled Maintenance Mode to all sites"
exit 0
