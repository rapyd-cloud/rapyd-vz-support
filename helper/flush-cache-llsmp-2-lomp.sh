#!/usr/bin/env bash

set -u
set -o pipefail

failed=0

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")

    echo
    echo "Site: $siteSlug"

    if [[ -z "$webroot" || -z "$vanity_domain" || "$webroot" == "null" || "$vanity_domain" == "null" ]]; then
        echo "  ✖ Invalid site entry"
        failed=1
        continue
    fi

    if [[ ! -d "$webroot" || ! -w "$webroot" ]]; then
        echo "  ✖ Webroot not writable: $webroot"
        failed=1
        continue
    fi

    echo "  Webroot: $webroot"

    # Flush cache
    echo "  Flushing cache..."
    if wp --path="$webroot" cache flush &>/dev/null; then
        echo "    ✔ Cache flushed"
    else
        echo "    ✖ Failed to flush cache"
        failed=1
    fi

    # Flush permalinks
    echo "  Flushing permalinks..."
    if wp --path="$webroot" rewrite flush &>/dev/null; then
        echo "    ✔ Permalinks flushed"
    else
        echo "    ✖ Failed to flush permalinks"
        failed=1
    fi

    # Flush LiteSpeed cache
    echo "  Flushing LiteSpeed cache..."
    if wp --path="$webroot" litespeed-purge all &>/dev/null; then
        echo "    ✔ LiteSpeed cache flushed"
    else
        echo "    ✖ Failed to flush LiteSpeed cache"
        failed=1
    fi

    # Flush object cache
    echo "  Flushing object cache..."
    if wp --path="$webroot" object-cache flush &>/dev/null; then
        echo "    ✔ Object cache flushed"
    else
        echo "    ✖ Failed to flush object cache"
        failed=1
    fi

done < <(rapyd site list --format json | jq -c '.[]')

echo
if [[ "$failed" -ne 0 ]]; then
    echo "FAILED: One or more sites did not pass validation"
    exit 0
fi

echo "SUCCESS: All sites passed validation"
exit 0
