#!/usr/bin/env bash

set -u
set -o pipefail

failed=0

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")
    user=$(jq -r '.user' <<< "$site")

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Site: $siteSlug"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -z "$webroot" || -z "$vanity_domain" || "$webroot" == "null" || "$vanity_domain" == "null" ]]; then
        echo "✖ Invalid site entry"
        failed=1
        continue
    fi

    if [[ ! -d "$webroot" || ! -w "$webroot" ]]; then
        echo "✖ Webroot not writable: $webroot"
        failed=1
        continue
    fi

    echo "Webroot: $webroot"
    echo "User:    $user"
    echo

    # Flush cache
    echo "[1/5] Flushing cache (as $user)..."
    if sudo -u "$user" /usr/local/bin/wp --path="$webroot" cache flush; then
        echo "      ✔ Cache flushed"
    else
        echo "      ✖ Failed to flush cache"
        failed=1
    fi
    echo

    # Flush permalinks
    echo "[2/5] Flushing permalinks (as $user)..."
    if sudo -u "$user" /usr/local/bin/wp --path="$webroot" rewrite flush; then
        echo "      ✔ Permalinks flushed"
    else
        echo "      ✖ Failed to flush permalinks"
        failed=1
    fi
    echo

    # Flush LiteSpeed cache
    echo "[3/5] Flushing LiteSpeed cache (as $user)..."
    if sudo -u "$user" /usr/local/bin/wp --path="$webroot" litespeed-purge all; then
        echo "      ✔ LiteSpeed cache flushed"
    else
        echo "      ✖ Failed to flush LiteSpeed cache"
        failed=1
    fi
    echo

    # Flush object cache
    echo "[4/5] Flushing object cache (as $user)..."
    if sudo -u "$user" /usr/local/bin/wp --path="$webroot" object-cache flush; then
        echo "      ✔ Object cache flushed"
    else
        echo "      ✖ Failed to flush object cache"
        failed=1
    fi

    echo "[5/5] Flushing LLSMP cache (as $user)..."
    if [[ -d "/var/www/cachedata" ]]; then
        echo "     ✔ Removing cachedata folder..."
        rm -rf "/var/www/cachedata"
    else 
        echo "     ✖ cachedata folder not found"
    fi



    echo

done < <(rapyd site list --format json | jq -c '.[]')

echo
if [[ "$failed" -ne 0 ]]; then
    echo "FAILED: One or more sites did not pass validation {{PASSED}}"
    exit 0
fi

echo "SUCCESS: All sites passed validation {{PASSED}}"
exit 0
