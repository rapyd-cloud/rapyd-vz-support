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

while IFS= read -r user_entry; do

    site_slug=$(echo "$user_entry" | jq -r '.site_slug')
    webroot=$(echo "$user_entry" | jq -r '.webroot')
    username=$(echo "$user_entry" | jq -r '.username')
    email=$(echo "$user_entry" | jq -r '.email')
    site_url=$(echo "$user_entry" | jq -r '.site_url // empty')
    site_user=$(echo "$user_entry" | jq -r '.site_user // empty')

    if [[ -z "$site_user" ]]; then
        site_user=$(echo "$webroot" | sed -n 's|^/home/\([^/]*\)/web/.*|\1|p')
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Site: $site_slug | User: $username"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Email:   $email"
    if [[ -n "$site_url" && "$site_url" != "null" ]]; then
        echo "URL:     $site_url"
    fi
    echo

    if [[ -z "$webroot" || "$webroot" == "null" ]]; then
        echo "✖ Invalid webroot"
        echo "  Removing from JSON..."
        USERS_JSON=$(echo "$USERS_JSON" | jq --arg slug "$site_slug" --arg user "$username" 'map(select((.site_slug != $slug or .username != $user)))')
        continue
    fi

    if [[ ! -d "$webroot" || ! -w "$webroot" ]]; then
        echo "✖ Webroot not accessible: $webroot"
        echo "  Removing from JSON..."
        USERS_JSON=$(echo "$USERS_JSON" | jq --arg slug "$site_slug" --arg user "$username" 'map(select((.site_slug != $slug or .username != $user)))')
        continue
    fi

    # Check if user exists
    check_cmd="cd '$webroot' && /usr/local/bin/wp user get '$username' --field=ID --skip-plugins --skip-themes --skip-packages 2>/dev/null"
    user_id=$(su - "$site_user" -c "$check_cmd" 2>/dev/null)

    if [[ -z "$user_id" || "$user_id" == "null" ]]; then
        echo "⚠ User does not exist in WordPress"
        echo "  Removing from JSON..."
        USERS_JSON=$(echo "$USERS_JSON" | jq --arg slug "$site_slug" --arg user "$username" 'map(select((.site_slug != $slug or .username != $user)))')
    else
        echo "Deleting WordPress user (ID: $user_id)..."
        delete_cmd="cd '$webroot' && /usr/local/bin/wp user delete '$user_id' --yes --skip-plugins --skip-themes --skip-packages --quiet"

        error_output=$(su - "$site_user" -c "$delete_cmd" 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "✓ User deleted from WordPress"
            echo "  Removing from JSON..."
            USERS_JSON=$(echo "$USERS_JSON" | jq --arg slug "$site_slug" --arg user "$username" 'map(select((.site_slug != $slug or .username != $user)))')
        else
            echo "✖ Failed to delete user"
            [[ -n "$error_output" ]] && echo "  Error: $error_output"
            failed=1
        fi
    fi

done < <(echo "$USERS_JSON" | jq -c '.[]')

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $(echo "$USERS_JSON" | jq 'length') -eq 0 ]]; then
    rm -f "$OUTPUT_FILE"
    echo "✓ All users deleted and JSON file removed"
else
    echo "$USERS_JSON" | jq '.' > "$OUTPUT_FILE"
    echo "✓ JSON file updated with remaining entries"
    echo "  Remaining users: $(echo "$USERS_JSON" | jq 'length')"
fi

echo

if [[ "$failed" -ne 0 ]]; then
    echo "⚠ Some users could not be deleted"
    echo "{{ONE_OR_MORE_FAILED}}"
else
    echo "✓ All users processed successfully"
    echo "{{CLEAR_SUCCESS}}"
    exit 0
fi
