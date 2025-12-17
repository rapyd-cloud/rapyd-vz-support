#!/usr/bin/env bash

set -u
set -o pipefail

failed=0

while read -r site; do
    webroot=$(jq -r '.webroot' <<< "$site")
    domain=$(jq -r '.domain' <<< "$site")

    echo "Checking $domain"

    # Validate inputs
    if [[ -z "$webroot" || -z "$domain" || "$webroot" == "null" || "$domain" == "null" ]]; then
        echo "❌ Invalid site entry"
        failed=1
        continue
    fi

    if [[ ! -d "$webroot" || ! -w "$webroot" ]]; then
        echo "❌ Webroot not writable: $webroot"
        failed=1
        continue
    fi

    filename="healthcheck-$RANDOM.txt"
    filepath="$webroot/$filename"
    url="http://$domain/$filename"

    # Create test file
    echo "rapyd-access-check" > "$filepath" 2>/dev/null

    # HARD verification (this is the key fix)
    if [[ ! -f "$filepath" ]]; then
        echo "❌ Failed to create file in $webroot"
        failed=1
        continue
    fi

    # Curl test
    http_code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$url" || true)

    if [[ "$http_code" != "200" ]]; then
        echo "❌ $domain not accessible (HTTP $http_code)"
        failed=1
    else
        echo "✅ $domain OK"
    fi

    rm -f "$filepath"

done < <(rapyd site list --format json | jq -c '.[]')

if [[ "$failed" -ne 0 ]]; then
    echo "❌ One or more sites FAILED"
    exit 1
fi

echo "✅ All sites passed"
exit 0
