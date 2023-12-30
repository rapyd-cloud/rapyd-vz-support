#! /bin/bash

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

echo "client_id=id_live_vAcPku6RwAUoemSNFKRbZMX2" >> monarx-agent.conf
echo "client_secret=sk_live_sb4s7Wvvvh2DIx4L6gH5KHwS" >> monarx-agent.conf

echo "host_id=$VZNODEID-$VZENVNAME" >> monarx-agent.conf

echo "exclude_dirs=/virtfs" >> monarx-agent.conf
echo "exclude_dirs=/(clam_|\.)?quarantine" >> monarx-agent.conf
echo "exclude_users=^virtfs$" >> monarx-agent.conf

echo "user_base=/var/www/webroot/ROOT/" >> monarx-agent.conf
echo "user_base=/usr/local/lsws/" >> monarx-agent.conf
echo "user_base=/tmp/" >> monarx-agent.conf
echo "user_base=/home/litespeed/" >> monarx-agent.conf

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



if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
  # force stop monarx  if it happens to be running 
  sudo systemctl stop monarx-agent

  # install the repository repo and pgp key
  cd /tmp
  sudo curl -o /etc/yum.repos.d/monarx.repo https://repository.monarx.com/repository/monarx-yum/linux/yum/el/9/x86_64/monarx.repo
  sudo rpm --import https://repository.monarx.com/repository/monarx/publickey/monarxpub.gpg
  
  # install monarx
  sudo yum install monarx-protect-autodetect -y

  # force stop monarx  if it happens to be running 
  sudo systemctl stop monarx-agent

  # force update monarx
  sudo yum update monarx-agent -y

  # force restart 
  sudo systemctl restart monarx-agent

  
  
else
  # assume this is the current Centos 7 based platform install
  cd ~

  # force stop monarx  if it happens to be running 
  sudo systemctl stop monarx-agent

  # install the repository repo and pgp key
  cd /tmp
  sudo curl -o /etc/yum.repos.d/monarx.repo https://repository.monarx.com/repository/monarx-yum/linux/yum/el/7/x86_64/monarx.repo
  sudo rpm --import https://repository.monarx.com/repository/monarx/publickey/monarxpub.gpg

  # install monarx
  sudo yum install monarx-protect-autodetect -y

  # force stop monarx  if it happens to be running 
  sudo systemctl stop monarx-agent

  # force update monarx
  sudo yum update monarx-agent -y

  # force restart 
  sudo systemctl restart monarx-agent

fi


# end of monarx main deployer








