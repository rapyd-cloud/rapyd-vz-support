#!/bin/bash

source /etc/profile

#load parameter
FORCE=$1

# Set variables

INSTALL_DIR="/usr/local/rapyd/rapyd-wp-files"
VERSION_FILE="$INSTALL_DIR/version"
DOWNLOAD_URL="https://vz-2110-repo.s3.amazonaws.com/rapyd-mu-plugin/builds/[VERSION]/rapyd-mu.zip"
MU_PLUGINS_DIR="/var/www/webroot/ROOT/wp-content/mu-plugins"
FILE_NAME="rapyd-mu.zip"

# Check if installer is deployed
if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR"
  chmod 755 "$INSTALL_DIR"
  FORCE="true"
fi

# change to installer directory 
cd $INSTALL_DIR

# Get the latest version from the GitHub API
LATEST_VERSION=$(curl -sSL "https://vz-2110-repo.s3.amazonaws.com/rapyd-mu-plugin/builds/current-version.txt");

echo "Latest Version : $LATEST_VERSION";

rm -f "$INSTALL_DIR/$FILE_NAME"

# create final url
FINALURL=$(echo "$DOWNLOAD_URL" | sed "s/\[VERSION\]/$LATEST_VERSION/");

# Check if the current version file exists
if [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
else
  FORCE="true"
fi

# =================================================================
#   Install the Plugin if the latest version is not equal to..
#   current installed version OR force deploy.
# =================================================================
if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ] || [ "$FORCE" = "true" ]; then

    # Remove any existing version zip.
    rm -f "$INSTALL_DIR/$FILE_NAME"

    # Download the latest version zip.
    curl -O -J -s -L -H "Accept: application/octet-stream" "$FINALURL"

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
        exit 999

    fi


else
  echo "Plugin is already up to date."
fi

#end of script
