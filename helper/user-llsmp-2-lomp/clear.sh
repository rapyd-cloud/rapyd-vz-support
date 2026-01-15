#!/usr/bin/env bash

set -u
set -o pipefail

OUTPUT_FILE="/var/www/webroot/rapyd-usr.json"
failed=0

if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "✖ No users file found: $OUTPUT_FILE"
    exit 1
fi

USERS_JSON=$(cat "$OUTPUT_FILE")

if [[ $(echo "$USERS_JSON" | jq 'length') -eq 0 ]]; then
    echo "ℹ No users to delete"
    exit 0
fi

echo "$USERS_JSON" | jq -c '.[]' | while read -r user_entry; do

    site_slug=$(echo "$user_entry" | jq -r '.site_slug')
    webroot=$(echo "$user_entry" | jq -r '.webroot')
    username=$(echo "$user_entry" | jq -r '.username')
    email=$(echo "$user_entry" | jq -r '.email')
    site_user=$(echo "$user_entry" | jq -r '.site_user // empty')

    if [[ -z "$site_user" ]]; then
        site_user=$(echo "$webroot" | sed -n 's|^/home/\([^/]*\)/web/.*|\1|p')
    fi

    echo "Site: $site_slug | User: $username ($email)"

    if [[ -z "$webroot" || "$webroot" == "null" ]]; then
        echo "✖ Invalid webroot"
        exit 1
    fi

    if [[ ! -d "$webroot" || ! -w "$webroot" ]]; then
        echo "✖ Webroot not accessible: $webroot"
        exit 1
    fi

    delete_cmd="cd '$webroot' && wp user delete \$(wp user get '$username' --field=ID --skip-plugins --skip-themes --skip-packages --quiet 2>/dev/null) --yes --skip-plugins --skip-themes --skip-packages --quiet"

    error_output=$(su - "$site_user" -c "$delete_cmd" 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "✓ User deleted"
        USERS_JSON=$(echo "$USERS_JSON" | jq --arg slug "$site_slug" --arg user "$username" 'map(select((.site_slug != $slug or .username != $user)))')
    else
        echo "✖ Failed to delete user"
        [[ -n "$error_output" ]] && echo "Error: $error_output"
        exit 1
    fi

done

if [[ $(echo "$USERS_JSON" | jq 'length') -eq 0 ]]; then
    rm -f "$OUTPUT_FILE"
    echo "JSON file removed"
else
    echo "$USERS_JSON" | jq '.' > "$OUTPUT_FILE"
fi

echo "{{CLEAR_SUCCESS}}"
exit 0
