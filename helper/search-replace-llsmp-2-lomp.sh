  #!/usr/bin/env bash
set -euo pipefail

# Usage: script.sh <search_url> <replace_url>
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <search_url> <replace_url>"
    echo "Example: $0 'oldomain.com' 'newdomain.com'"
    exit 1
fi

searchURL="$1"
replaceURL="$2"

echo "Search URL:  $searchURL"
echo "Replace URL: $replaceURL"
echo "---"

TOTAL_COUNT=0

echo "Processing site database replaces..."

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")
    siteUser=$(jq -r '.user' <<< "$site")

    echo "[ $siteSlug ]"

    # Get the database table prefix
    if ! TABLE_PREFIX=$(su - "$siteUser" -c "cd $webroot && wp eval 'echo \$GLOBALS[\"table_prefix\"];' --skip-plugins --skip-themes --quiet"); then
        echo "[[ERROR]] Failed to get database table prefix"
        exit 1
    fi

    POSTS_TABLE="${TABLE_PREFIX}posts"
    POSTMETA_TABLE="${TABLE_PREFIX}postmeta"

    # Check posts table
    if ! POSTS_RESULT=$(su - "$siteUser" -c "cd $webroot && wp db query \"SELECT COUNT(*) FROM $POSTS_TABLE WHERE post_content LIKE '%$searchURL%' OR post_excerpt LIKE '%$replaceURL%'\" --skip-plugins --skip-themes --quiet"); then
        echo "[[ERROR]] Failed to query $POSTS_TABLE"
        exit 1
    fi

    POSTS_COUNT=$(echo "$POSTS_RESULT" | grep -oE '[0-9]+' | head -1 || echo "0")
    echo "  Posts: $POSTS_COUNT"

    # Check postmeta table
    if ! POSTMETA_RESULT=$(su - "$siteUser" -c "cd $webroot && wp db query \"SELECT COUNT(*) FROM $POSTMETA_TABLE WHERE meta_value LIKE '%$searchURL%'\" --skip-plugins --skip-themes --quiet"); then
        echo "[[ERROR]] Failed to query $POSTMETA_TABLE"
        exit 1
    fi

    POSTMETA_COUNT=$(echo "$POSTMETA_RESULT" | grep -oE '[0-9]+' | head -1 || echo "0")
    echo "  Postmeta: $POSTMETA_COUNT"

    TOTAL_COUNT=$((POSTS_COUNT + POSTMETA_COUNT))
    echo "  Total: $TOTAL_COUNT"

    if [[ "$TOTAL_COUNT" -gt 0 ]]; then
        echo "  Found in database - replacing..."

        # Perform search and replace using WP CLI (skip non-recommended columns like guid)
        if su - "$siteUser" -c "cd $webroot && wp search-replace \"$searchURL\" \"$replaceURL\" --skip-plugins --skip-themes --skip-columns=guid --quiet"; then
            echo "[[SUCCESS]] Replacement completed"
        else
            echo "[[ERROR]] Replacement failed"
            exit 1
        fi

    else
        echo "[[SUCCESS]] URL not found in database"
        exit 1
    fi

done < <(rapyd site list --format json | jq -c '.[]')

echo ""
echo "Processing cron replaces..."
echo "---"

while read -r cronFile; do
    if [[ ! -f "$cronFile" ]]; then
        continue
    fi

    userName=$(basename "$cronFile")
    echo "[ $userName ]"

    # Check if search text exists in cron file
    if ! grep -q "$searchURL" "$cronFile" 2>/dev/null; then
        echo "Skipping - Search text not found in cron file"
        continue;
    fi

    matchCount=$(grep -c "$searchURL" "$cronFile" || echo "0")
    echo "  Matches: $matchCount"

    # Perform search and replace in cron file
    if sed -i "s|$searchURL|$replaceURL|g" "$cronFile" 2>/dev/null; then
        # Verify permissions after modification
        if chown "$userName:$(id -gn "$userName")" "$cronFile" && chmod 600 "$cronFile"; then
            echo "  Permissions: OK"
            echo "[[SUCCESS]] Replacement completed"
        else
            echo "[[ERROR]] Failed to set permissions"
            exit 1
        fi
    else
        echo "[[ERROR]] Replacement failed"
        exit 1
    fi

done < <(find /var/spool/cron -type f -printf '%p\n')

