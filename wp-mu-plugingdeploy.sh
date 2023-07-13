#!/usr/bin/bash

source /etc/profile

#load parameter
#FORCE=$1

# Set variables
INSTALL_DIR="/var/www/webroot/rapyd-wp-files"
VERSION_FILE="$INSTALL_DIR/version"
DOWNLOAD_URL="https://github.com/rapyd-cloud/rapyd-wp-files/releases/latest/download/rapyd-wp-files.zip"
MU_PLUGINS_DIR="/var/www/webroot/ROOT/wp-content/mu-plugins"
FILE_NAME="rapyd-wp-files.zip"

# GitHub API authentication
AUTH_TOKEN="$RAPYDGITPAK1"
OWNER="rapyd-cloud"
REPO="rapyd-wp-files"
API_URL="https://api.github.com/repos/$OWNER/$REPO"

# Check if installer is deployed
if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR"
  chmod 755 "$INSTALL_DIR"
  FORCE="true"
fi

# Get the latest version from the GitHub API
LATEST_VERSION=$(curl -sL -H "Authorization: token $AUTH_TOKEN" "$API_URL" | jq -r '.tag_name')

# Check if the current version file exists
if [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
else
  FORCE="true"
fi

# Check if the latest version is different from the current version or if forcedeploy is set
if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ] || [ "$FORCE" = "true" ]; then
  # Download the latest version
  rm -f "$INSTALL_DIR/$FILE_NAME"
  curl -sL "$DOWNLOAD_URL" -o "$INSTALL_DIR/$FILE_NAME"

  if [ -f "$INSTALL_DIR/$FILE_NAME" ]; then
    # Extract the downloaded zip file to the mu-plugins directory
    rm -f "$MU_PLUGINS_DIR/rapyd-loader.php"
    rm -rf "$MU_PLUGINS_DIR/rapyd-includes"
    unzip -q -o "$INSTALL_DIR/$FILE_NAME" -d "$MU_PLUGINS_DIR"

    # Update the version file
    echo "$LATEST_VERSION" > "$VERSION_FILE"

    echo "Plugin deployed successfully."
  else
    echo "Failed to download the plugin."
  fi
else
  echo "Plugin is already up to date."
fi
