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
    echo "  Testing file: $filename"
    echo "  Testing path: $filepath"
    echo "  Test URL: $url"

    # ---------- SAFE .htaccess handling ----------
    htaccess="$webroot/.htaccess"
    hc_tag="RAPYD_HEALTHCHECK_${RANDOM}_${RANDOM}"
    htaccess_modified=0

    if [[ -f "$htaccess" ]]; then
        timestamp=$(date +"%Y%m%d-%H%M%S")
        backup="${htaccess}.rapyd-backup-${timestamp}"

        cp "$htaccess" "$backup"
        echo "  .htaccess: backup created ($(basename "$backup"))"

        # Preserve original file owner from index.php
        index_php="$webroot/index.php"
        original_user=$(stat -c "%U" "$index_php" 2>/dev/null || stat -f "%Su" "$index_php" 2>/dev/null)
        original_group=$(stat -c "%G" "$index_php" 2>/dev/null || stat -f "%Sg" "$index_php" 2>/dev/null)

        # Escape dots in filename for regex pattern
        escaped_filename=$(echo "$filename" | sed 's/\./\\./g')

        echo "  .htaccess: adding rules:"
        echo "    RewriteEngine On"
        echo "    RewriteRule ^$escaped_filename$ /$filename [L,END]"
        echo "    Allow from all"

        # Prepend rules to start of .htaccess file
        {
            echo
            echo "# BEGIN $hc_tag"
            echo "  RewriteEngine On"
            echo "  RewriteRule ^$escaped_filename$ /$filename [L,END]"
            echo "  Allow from all"
            echo "# END $hc_tag"
            echo
            cat "$htaccess"
        } > "$htaccess.tmp"
        mv "$htaccess.tmp" "$htaccess"

        # Restore original owner and set permissions to 644
        if [[ -n "$original_user" && -n "$original_group" ]]; then
            chown "$original_user:$original_group" "$htaccess"
        fi
        chmod 644 "$htaccess"

        htaccess_modified=1
        echo "  .htaccess: rewrite bypass added to start of file"
    fi
    # --------------------------------------------

    echo "  Restarting lsws";
    service lsws reload;

    sleep 2;

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

    # Cleanup test file
    rm -f "$filepath"

    # Remove ONLY our block from .htaccess
    if [[ "$htaccess_modified" -eq 1 ]]; then
        sed -i.bak "/# BEGIN $hc_tag/,/# END $hc_tag/d" "$htaccess"
        rm -f "$htaccess.bak"
        echo "  .htaccess: rewrite bypass removed"
    fi

done < <(rapyd site list --format json | jq -c '.[]')

echo
if [[ "$failed" -ne 0 ]]; then
    echo "FAILED: One or more sites did not pass validation"
    exit 1
fi

echo "SUCCESS: All sites passed validation"
exit 0
