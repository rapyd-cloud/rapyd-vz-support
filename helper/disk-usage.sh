#!/bin/bash

echo "=== Disk Usage Report ==="
echo
# 1) /var/www/webroot/ROOT
echo "1) /var/www/webroot/ROOT size:"
du -sh /var/www/webroot/ROOT 2>/dev/null
echo
# 2) /var/www/webroot/ROOT/wp-content
echo "2) /var/www/webroot/ROOT/wp-content size:"
du -sh /var/www/webroot/ROOT/wp-content 2>/dev/null
echo
# 3) /var/www/webroot/ROOT/wp-content/uploads
echo "3) /var/www/webroot/ROOT/wp-content/uploads size:"
du -sh /var/www/webroot/ROOT/wp-content/uploads 2>/dev/null
echo
# 4) /var/log
echo "4) /var/log folder size:"
du -sh /var/log 2>/dev/null
echo
# 5) /var/www/logs  ( litespeed )
echo "5) /var/www/logs folder size:"
du -sh /var/www/logs 2>/dev/null
echo
# 6) /tmp
echo "6) /tmp folder size:"
du -sh /tmp 2>/dev/null
echo
# 7) Cache folders
echo "7) Cache folders sizes:"
CACHE_FOLDERS=(
    "/var/www/webroot/ROOT/wp-content/cache/"
    "/var/www/webroot/ROOT/wp-content/uploads/wp-rocket-config"
    "/var/www/webroot/ROOT/wp-content/w3tc/"
    "/var/www/webroot/ROOT/wp-content/cache/autoptimize/"
    "/var/www/webroot/ROOT/wp-content/cache/"
    "/var/www/webroot/ROOT/wp-content/litespeed/"
    "/var/www/webroot/ROOT/wp-content/plugins/litespeed-cache"
    "/var/www/webroot/ROOT/wp-content/plugins/litespeed-cache/tpl/cache"
    "/var/www/webroot/ROOT/wp-content/plugins-b/wp-fastest-cache"
    "/var/www/webroot/.cache"
)
for dir in "${CACHE_FOLDERS[@]}"; do
    if [ -e "$dir" ]; then
        # Use du -sbL to follow all symlinks recursively
        SIZE=$(du -sbL "$dir" 2>/dev/null | awk '{print $1}')
        # Default to 0 if empty
        SIZE=${SIZE:-0}
        # Convert to human-readable
        HR_SIZE=$(numfmt --to=iec --suffix=B "$SIZE")
        echo "$dir : $HR_SIZE"
    else
        echo "$dir : Folder does not exist"
    fi
done
# 8) Other folders
echo
echo "8) Other folders sizes:"
X_FOLDERS=(
    "/var/www/webroot/ROOT/wp-content/updraft/"
    "/var/www/webroot/ROOT/wp-content/backup-db/"
    "/var/www/webroot/ROOT/wp-content/duplicator/"
    "/var/www/webroot/ROOT/wp-content/ai1wm-backups/"
    "/var/www/webroot/ROOT/wp-content/ai1wm-temp/"
)
for dir in "${X_FOLDERS[@]}"; do
    if [ -e "$dir" ]; then
        # Use du -sbL to follow all symlinks recursively
        SIZE=$(du -sbL "$dir" 2>/dev/null | awk '{print $1}')
        # Default to 0 if empty
        SIZE=${SIZE:-0}
        # Convert to human-readable
        HR_SIZE=$(numfmt --to=iec --suffix=B "$SIZE")
        echo "$dir : $HR_SIZE"
    else
        echo "$dir : Folder does not exist"
    fi
done

echo 
echo "9) List of Unknown Files in WP Root";
for file in $(find /var/www/webroot/ROOT -maxdepth 1 \( -type f -o -type d \) \( -not -name 'wp-*.php' -not -name 'index.php' -not -name 'license.txt' -not -name 'readme.html' -not -name 'wp-activate.php' -not -name 'wp-blog-header.php' -not -name 'wp-comments-post.php' -not -name 'wp-config.php' -not -name 'wp-config-sample.php' -not -name 'wp-cron.php' -not -name 'wp-links-opml.php' -not -name 'wp-load.php' -not -name 'wp-login.php' -not -name 'wp-mail.php' -not -name 'wp-settings.php' -not -name 'wp-signup.php' -not -name 'wp-trackback.php' -not -name 'xmlrpc.php' -not -name '.htaccess' -not -name '.htaccess.bk' -not -name 'favicon.ico' -not -name 'robots.txt' -not -name 'humans.txt' -not -name 'crossdomain.xml' -not -name 'sitemap.xml' -not -name 'sitemap.xml.gz' -not -name 'sitemap.xml.gz' -not -name 'sitemap.xml.gz' -not -name 'sitemap.xml.gz' \) -and \( -not -name 'wp-content' -not -name 'wp-includes' -not -name 'wp-admin'  -not -name '.idea' -not -name '.vscode' -not -name '.well-known' -not -name '.env' -not -name '.env.example' -not -name '.env.bak' -not -name 'composer.lock' -not -name 'composer.json' -not -name 'package.json' -not -name 'package-lock.json' -not -name 'yarn.lock' \)); do
    if [ "$file" != '/var/www/webroot/ROOT' ]; then
        du -sh $file
    fi
done

echo
echo "=== End of Report ==="
