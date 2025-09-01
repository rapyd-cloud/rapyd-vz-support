#!/bin/bash

# Strict mode: Exit on error, treat unset variables as errors, propagate pipeline errors
set -euo pipefail

# === Helper Functions ===
die() {
  echo "ERROR: $1" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# === Configuration ===
if [ -z "$1" ]; then
  die "Base URL not provided. Please pass it as the first argument."
fi
readonly BASE_URL="$1"

readonly KEYDB_CONF_DIR="/etc/keydb"
readonly KEYDB_CONF_FILE="${KEYDB_CONF_DIR}/keydb.conf"
readonly KEYDB_SERVICE_OVERRIDE_DIR="/etc/systemd/system/keydb.service.d"
readonly KEYDB_OVERRIDE_FILE="${KEYDB_SERVICE_OVERRIDE_DIR}/override.conf"
readonly SYSTEMD_SYS_DIR="/usr/lib/systemd/system"
readonly KEYDB_SERVICE_FILE="${SYSTEMD_SYS_DIR}/keydb.service"
readonly REDIS_SERVICE_FILE="${SYSTEMD_SYS_DIR}/redis.service"

# --- Define paths for the new solution ---
readonly SET_MEMORY_SCRIPT="/usr/local/bin/set-keydb-memory.sh"
readonly NEW_DYNAMIC_MEM_CONF="/etc/keydb/maxmemory.conf"
readonly GROUP_NAME="litespeed"
readonly USER_NAME="keydb"

# PHP Configuration for KeyDB Sessions ---
readonly PHP_CONF_DIR="/usr/local/lsws/lsphp/etc/php.d"
readonly KEYDB_SESSION_CONF_FILE="${PHP_CONF_DIR}/90-keydb-session.ini"
readonly SESSION_DB=0 # You can change this to another database index if needed

# === Pre-flight Checks ===
echo "--- Running Pre-flight Checks ---"

if [[ "$EUID" -ne 0 ]]; then
  die "This script must be run as root."
fi
echo "[OK] Root privileges detected."

REQUIRED_CMDS=("curl" "openssl" "systemctl" "chown" "tee" "mkdir" "rm" "getent" "usermod" "awk" "grep")
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command_exists "$cmd"; then
    die "Required command '$cmd' not found. Please install it."
  fi
done
echo "[OK] All required commands found."

echo "--- Starting KeyDB Configuration ---"

# === Systemd Service File Setup ===
echo "Removing existing KeyDB/Redis service files (if any)..."
rm -f "${KEYDB_SERVICE_FILE}" "${REDIS_SERVICE_FILE}"

echo "Downloading KeyDB systemd service file..."
curl -fsSL -o "${KEYDB_SERVICE_FILE}" "${BASE_URL}conf/redis.service.txt" || die "Failed to download keydb service file."
echo "KeyDB service file downloaded."

# === KeyDB Configuration File Setup ===
echo "Preparing KeyDB configuration directory..."
mkdir -p "${KEYDB_CONF_DIR}" || die "Failed to create directory ${KEYDB_CONF_DIR}"

echo "Downloading keydb.conf..."
curl -fsSL -o "${KEYDB_CONF_FILE}" "${BASE_URL}conf/keydb.conf.txt" || die "Failed to download keydb.conf."
echo "KeyDB configuration file downloaded."

echo "Ensuring KeyDB configuration includes dynamic memory settings..."
# Remove any old or incorrect include lines to avoid conflicts
sed -i '/^include \/etc\/keydb\/dynamic-memory.conf/d' "${KEYDB_CONF_FILE}"
sed -i '/^include \/etc\/keydb\/maxmemory.conf/d' "${KEYDB_CONF_FILE}"

# Add the correct include directive at the end of the file
echo -e "\n# Include the dynamically generated configuration file for memory settings\ninclude ${NEW_DYNAMIC_MEM_CONF}" >> "${KEYDB_CONF_FILE}"

chown keydb:keydb "${KEYDB_CONF_FILE}"


# --- Download and set up the memory calculation script ---
echo "Downloading the memory calculation script to ${SET_MEMORY_SCRIPT}..."
mkdir -p "$(dirname "${SET_MEMORY_SCRIPT}")"
curl -fsSL -o "${SET_MEMORY_SCRIPT}" "${BASE_URL}conf/set-keydb-memory.sh" || die "Failed to download set-keydb-memory.sh."

# Make the new script executable
chmod +x "${SET_MEMORY_SCRIPT}"

# ---Create the systemd override file directly ---
echo "Creating systemd override file at ${KEYDB_OVERRIDE_FILE}..."
mkdir -p "${KEYDB_SERVICE_OVERRIDE_DIR}"
cat << EOF > "${KEYDB_OVERRIDE_FILE}"
[Service]
ExecStartPre=-${SET_MEMORY_SCRIPT}
ExecStart=
ExecStart=/usr/bin/keydb-server /etc/keydb/keydb.conf --supervised systemd --port 0 --unixsocket /var/run/redis/redis.sock --unixsocketperm 777
Restart=always
EOF

# --- NEW: Create PHP configuration for KeyDB sessions ---
echo "Configuring PHP for KeyDB session handling..."
mkdir -p "${PHP_CONF_DIR}"
cat << EOF > "${KEYDB_SESSION_CONF_FILE}"
; KeyDB session handler configuration
session.save_handler = redis
session.save_path = "unix:///var/run/redis/redis.sock?database=${SESSION_DB}"
EOF
echo "PHP session configuration created at ${KEYDB_SESSION_CONF_FILE}"


# === User and Group Management ===
echo "Checking group '${GROUP_NAME}'..."
if getent group "${GROUP_NAME}" &>/dev/null; then
  echo "Adding user '${USER_NAME}' to group '${GROUP_NAME}'..."
  usermod -a -G "${GROUP_NAME}" "${USER_NAME}"
else
  die "Group '${GROUP_NAME}' does not exist. Please create it manually."
fi

# === Systemd Management ===
echo "Reloading and starting KeyDB service..."
# Force systemd to re-read unit files
systemctl daemon-reload || die "Failed to reload systemd daemon."
# Enable the service to start on boot
systemctl enable keydb || die "Failed to enable keydb service."
# Restart the service to apply changes
systemctl restart keydb || die "Failed to start keydb service."
# Restart LiteSpeed to apply PHP changes
systemctl restart lsws

echo "-------------------------------------------"
echo "KeyDB configuration and service setup complete!"
echo "PHP sessions are now configured to use KeyDB."
echo "-------------------------------------------"

exit 0
