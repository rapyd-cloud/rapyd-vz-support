#!/usr/bin/env bash

set -u
set -o pipefail

EMAIL_PREFIX="$1"
failed=0
TIMESTAMP=$(date +%s)
USERS_JSON="[]"
OUTPUT_FILE="/var/www/webroot/rapyd-usr.json"

# Load existing JSON if it exists
if [[ -f "$OUTPUT_FILE" ]]; then
    USERS_JSON=$(cat "$OUTPUT_FILE")
fi

# Function to generate random password
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# Function to check if username exists for current site in JSON
user_exists_for_site() {
    local site_slug=$1
    local username=$2
    local count=$(echo "$USERS_JSON" | jq "[.[] | select(.site_slug == \"$site_slug\" and .username == \"$username\")] | length")
    if [[ "$count" -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to add user to JSON array
add_user_to_json() {
    local site_slug=$1
    local username=$2
    local email=$3
    local password=$4
    local webroot=$5
    local site_user=$6
    local site_url=$7

    USERS_JSON=$(echo "$USERS_JSON" | jq --arg slug "$site_slug" --arg user "$username" --arg em "$email" --arg root "$webroot" --arg suser "$site_user" --arg url "$site_url" '. += [{
        "site_slug": $slug,
        "username": $user,
        "email": $em,
        "webroot": $root,
        "site_user": $suser,
        "site_url": $url
    }]')
}

while read -r site; do

    webroot=$(jq -r '.webroot' <<< "$site")
    vanity_domain=$(jq -r '.domain' <<< "$site")
    siteSlug=$(jq -r '.slug' <<< "$site")
    site_user=$(jq -r '.user' <<< "$site")

    # If site_user is empty, extract from webroot path
    # Pattern: /home/{site_user}/web/www/app/public/
    if [[ -z "$site_user" || "$site_user" == "null" ]]; then
        site_user=$(echo "$webroot" | sed -n 's|^/home/\([^/]*\)/web/.*|\1|p')
    fi

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

    # Fetch site URL from WordPress
    site_url=$(su - "$site_user" -c "cd '$webroot' && /usr/local/bin/wp option get home --skip-plugins --skip-themes --skip-packages 2>/dev/null" || echo "")

    echo "Webroot: $webroot"
    echo "User:    $site_user"
    if [[ -n "$site_url" && "$site_url" != "null" ]]; then
        echo "URL:     $site_url"
    fi

    # Create WordPress user
    username="rapyd$TIMESTAMP"
    email="${EMAIL_PREFIX}+${TIMESTAMP}@rapyd.cloud"
    password=$(generate_password)

    echo "Creating WordPress user: $username"

    # Check if username already exists for this site in JSON
    if user_exists_for_site "$siteSlug" "$username"; then
        echo "⚠ User already generated (previously created)"
        echo "  Email: $email"
        echo "  Username: $username"
        echo "  Password: xxxx"
    else
        # Execute wp-cli command as site user
        wp_cmd="cd '$webroot' && wp user create '$username' '$email' --user_pass='$password' --role=administrator --skip-plugins --skip-themes --skip-packages --quiet"

        if su - "$site_user" -c "$wp_cmd" 2>/dev/null; then
            echo "✓ User created."
            echo "  Username: $username"
            echo "  Password: $password"
            if [[ -n "$site_url" && "$site_url" != "null" ]]; then
                echo "  URL:      $site_url"
            fi
            add_user_to_json "$siteSlug" "$username" "$email" "$password" "$webroot" "$site_user" "$site_url"
        else
            echo "✖ Failed to create user in site: $siteSlug"
            failed=1
            break
        fi
    fi

done < <(rapyd site list --format json | jq -c '.[]')

# If any failures occurred, exit
if [[ "$failed" -ne 0 ]]; then
    echo
    echo "One or more sites had issues"
    echo "{{ONE_OR_MORE_FAILED}}"
fi

# Write JSON output only if all succeeded
if [[ $(echo "$USERS_JSON" | jq 'length') -gt 0 ]]; then
    echo "$USERS_JSON" | jq '.' > "$OUTPUT_FILE"
    echo
    echo "✓ User credentials saved to: $OUTPUT_FILE"
else
    echo
    echo "✖ No users were created"
fi

echo
echo "All sites processed"
echo "{{SUCCESS}}"
exit 0
