#!/bin/bash
# /usr/local/bin/set-keydb-memory.sh

# load jel environment variables
if [ -f /.jelenv ]; then
    # Read values from /.jelenv
    source /.jelenv
fi

# Strict mode for safe scripting
set -euo pipefail

# --- Configuration ---
# Use the CACHE_MEM_LIMIT environment variable or default to 10%
readonly MEM_PERCENTAGE=${CACHE_MEM_LIMIT:-10}
readonly DYNAMIC_MEM_CONF="/etc/keydb/maxmemory.conf"

echo "Setting KeyDB maxmemory..."

# --- Memory Calculation ---
# Get total memory in KB from /proc/meminfo
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Validate that a numeric value was obtained
if ! [[ "$TOTAL_MEM_KB" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not determine total memory." >&2
    exit 1
fi

# Calculate 10% of total memory in MB
MAX_MEM_MB=$(( (TOTAL_MEM_KB * MEM_PERCENTAGE) / 100 / 1024 ))

echo "Total RAM: ${TOTAL_MEM_KB} KB"
echo "Calculated maxmemory: ${MAX_MEM_MB} MB"

# --- Write Configuration File ---
# Create the configuration file with the new value
echo "maxmemory ${MAX_MEM_MB}mb" > "${DYNAMIC_MEM_CONF}"
# Optional: Ensure permissions are correct
chown keydb:keydb "${DYNAMIC_MEM_CONF}"

echo "Successfully wrote maxmemory setting to ${DYNAMIC_MEM_CONF}"

exit 0