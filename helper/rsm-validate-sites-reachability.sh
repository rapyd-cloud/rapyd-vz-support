#!/usr/bin/env bash

set -u
set -o pipefail

failed=0

domains_by_site=$(
  rapyd domain list --format json |
  jq '
    group_by(.site_slug) |
    map({ (.[0].site_slug): map(.domain) }) |
    add
  '
)

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")

    echo
    echo "Site: $siteSlug"

    # Validate site
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

    filename="healthcheck-$RANDOM.txt"
    filepath="$webroot/$filename"
    url="http://$vanity_domain/$filename"

    echo "rapyd-access-check" > "$filepath" 2>/dev/null

    if [[ ! -f "$filepath" ]]; then
        echo "  ✖ Failed to create test file"
        failed=1
        continue
    fi

    echo "  Test file: OK"
    echo "  Domains:"

    while read -r domain; do
        [[ -z "$domain" ]] && continue

        http_code=$(curl -s --max-time 5 \
            -H "Host: $domain" \
            -o /dev/null \
            -w "%{http_code}" \
            "$url" || true)

        if [[ "$http_code" != "200" ]]; then
            echo "    ✖ $domain (HTTP $http_code)"
            failed=1
        else
            echo "    ✔ $domain"
        fi

    done < <(
        echo "$domains_by_site" |
        jq -r --arg s "$siteSlug" '.[$s][]?'
    )

    rm -f "$filepath"

done < <(rapyd site list --format json | jq -c '.[]')

if [[ "$failed" -ne 0 ]]; then
    echo
    echo "FAILED: One or more sites did not pass validation"
    exit 1
fi

echo
echo "SUCCESS: All sites passed validation"
exit 0
