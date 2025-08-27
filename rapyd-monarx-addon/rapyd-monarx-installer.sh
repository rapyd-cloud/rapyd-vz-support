#!/bin/bash

source /etc/profile

# must be run as sudo su - 
# must pass in vzenvironmentname , vzuid , vznodeid

#load parameters
VZENVNAME=$1
VZUID=$2
VZNODEID=$3

if [ -z "$VZENVNAME" ]
  then
  exit 9991
fi
if [ -z "$VZUID" ]
  then
  exit 9992
fi

if [ -z "$VZNODEID" ]
  then
  exit 99993
fi

# setup defaults
IS_TESTING=false
IS_STAGING=false
IS_DEVELOPER=false

# remove any old monarx-agent configuration file
cd /etc/
rm -f monarx-agent.conf

# create monarx-agent configuration file 
echo "#########################################################################" > monarx-agent.conf
echo "# Rapyd Monarx Customer Deployment" >> monarx-agent.conf
echo "#########################################################################" > monarx-agent.conf

if [ -z "$MONARX_CLIENT_ID" ] || [ -z "$MONARX_CLIENT_SECRET" ]; then
  # Fallback to default credentials if environment variables are not set
  echo "client_id=id_live_vAcPku6RwAUoemSNFKRbZMX2" >> monarx-agent.conf
  echo "client_secret=sk_live_sb4s7Wvvvh2DIx4L6gH5KHwS" >> monarx-agent.conf
else
  # Use credentials from environment variables
  echo "client_id=$MONARX_CLIENT_ID" >> monarx-agent.conf
  echo "client_secret=$MONARX_CLIENT_SECRET" >> monarx-agent.conf
fi

echo "host_id=$VZNODEID-$VZENVNAME" >> monarx-agent.conf

echo "exclude_dirs=/virtfs" >> monarx-agent.conf
echo "exclude_dirs=/(clam_|\.)?quarantine" >> monarx-agent.conf
echo "exclude_users=^virtfs$" >> monarx-agent.conf

echo "user_base=/home/" >> monarx-agent.conf
echo "user_base=/var/www/" >> monarx-agent.conf
echo "user_base=/usr/local/lsws/" >> monarx-agent.conf
echo "user_base=/tmp/" >> monarx-agent.conf

echo "tags=$HOSTNAME" >> monarx-agent.conf
echo "tags=$VZNODEID" >> monarx-agent.conf
echo "tags=$VZENVNAME" >> monarx-agent.conf
echo "tags=UID:$VZUID" >> monarx-agent.conf
echo "tags=NODEID:$VZNODEID" >> monarx-agent.conf
echo "tags=ENVNAME:$VZENVNAME" >> monarx-agent.conf

if [[ "$RAPYD_PLAN" == *"STAGING"* ]]
  then
    IS_STAGING=true
fi

if [[ "$VZENVNAME" == *"-staging"* ]] 
  then
    IS_STAGING=true
fi

if [[ "$VZENVNAME" == "stg-"* ]]
  then
    IS_STAGING=true
fi

if [[ "$HOSTNAME" == *"rapydapps.cloud"* ]]
  then
    echo "tags=rapydapps.cloud" >> monarx-agent.conf  
fi

if [[ "$HOSTNAME" == *"rapyd.cloud"* ]]
  then
    echo "tags=rapyd.cloud" >> monarx-agent.conf  
    IS_STAGING=true
    IS_TESTING=true
fi

if [[ "$HOSTNAME" == *"developbb.dev"* ]] 
  then
    echo "tags=developbb.dev" >> monarx-agent.conf  
    IS_STAGING=true
    IS_DEVELOPER=true
fi

totalk=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
devmemlimit=2100000 
if [[ $totalk -lt $devmemlimit ]]
  then
    IS_DEVELOPER=true
fi

if [[ "$RAPYD_PLAN" == *"DEVELOPER"* ]]
  then
    IS_DEVELOPER=true
fi

if [[ "$RAPYD_PLAN" == "DEV"* ]]
  then
    IS_DEVELOPER=true
fi

if [[ "$IS_TESTING" = true ]]
  then
    echo "tags=test" >> monarx-agent.conf
    echo "tags=testing" >> monarx-agent.conf    
fi

if [[ "$IS_STAGING" = true ]]
  then
    echo "tags=staging" >> monarx-agent.conf
fi

if [[ "$IS_DEVELOPER" = true ]] 
  then
    echo "tags=dev" >> monarx-agent.conf
    echo "tags=developer" >> monarx-agent.conf
fi

echo "tags=litespeed" >> monarx-agent.conf
echo "tags=vz" >> monarx-agent.conf

echo "#########################################################################" >> monarx-agent.conf

now=$(date)
echo "# deployed: $now"  >> monarx-agent.conf

echo "#########################################################################" >> monarx-agent.conf

# Stop the agent before making changes
sudo systemctl stop monarx-agent

if grep -a 'AlmaLinux' /etc/system-release ; then
  # AlmaLinux install commands
  cd /tmp
  sudo curl -fsS https://repository.monarx.com/repository/monarx-yum/monarx.repo | sudo tee /etc/yum.repos.d/monarx.repo
  sudo rpm --import https://repository.monarx.com/repository/monarx/publickey/monarxpub.gpg
  
  # Install if not present, and upgrade if it is
  sudo yum install -y monarx-protect-autodetect monarx-agent-auditd
  sudo yum update -y 'monarx-*'
  
else
  # CentOS 7 install commands
  cd /tmp
  sudo curl -o /etc/yum.repos.d/monarx.repo https://repository.monarx.com/repository/monarx-yum/linux/yum/el/7/x86_64/monarx.repo
  sudo rpm --import https://repository.monarx.com/repository/monarx/publickey/monarxpub.gpg
  
  # Install if not present, and upgrade if it is
  sudo yum install -y monarx-protect-autodetect monarx-agent-auditd
  sudo yum update -y 'monarx-*'

fi

# ==============================================================================
# ===CODE BLOCK TO FIX THE NETWORK TIMING ISSUE ===
# ==============================================================================
# Create a systemd drop-in to ensure the network is online before starting Monarx.
# This prevents startup failures in containers that are created or cloned quickly.

SYSTEMD_DIR="/etc/systemd/system/monarx-agent.service.d"
OVERRIDE_FILE="$SYSTEMD_DIR/override.conf"

mkdir -p "$SYSTEMD_DIR"

printf "[Unit]\nAfter=network-online.target\nWants=network-online.target\n" > "$OVERRIDE_FILE"

# Reload the systemd configuration to apply the new changes.
systemctl daemon-reload

# force restart 
sudo systemctl restart monarx-agent

# end of monarx main deployer