#! /bin/bash

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

cd /etc/

# create monarx-agent configuration file 

rm -f monarx-agent.conf

echo "#########################################################################" > monarx-agent.conf
echo "# Rapyd Monarx Customer Deployment" >> monarx-agent.conf
echo "client_id=id_live_vAcPku6RwAUoemSNFKRbZMX2" >> monarx-agent.conf
echo "client_secret=sk_live_sb4s7Wvvvh2DIx4L6gH5KHwS" >> monarx-agent.conf
echo "exclude_dirs=/virtfs" >> monarx-agent.conf
echo "exclude_dirs=/(clam_|\.)?quarantine" >> monarx-agent.conf
echo "user_base=/var/www/webroot/ROOT/" >> monarx-agent.conf
echo "exclude_users=^virtfs$" >> monarx-agent.conf
echo "tags=vz" >> monarx-agent.conf
echo "tags=litespeed" >> monarx-agent.conf
echo "tags=rapydapps" >> monarx-agent.conf
echo "tags=UID:$VZUID" >> monarx-agent.conf
echo "tags=$VZENVNAME" >> monarx-agent.conf
echo "tags=ENVNAME:$VZENVNAME" >> monarx-agent.conf
echo "tags=$VZNODEID" >> monarx-agent.conf
echo "tags=NODEID:$VZNODEID" >> monarx-agent.conf

if [[ "$VZENVNAME" == *"-staging"* ]]; then
    echo "tags=staging" >> monarx-agent.conf
fi

totalk=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
devmemlimit=2100000 
if [[ $totalk -lt $devmemlimit ]]
  then
    echo "tags=dev" >> monarx-agent.conf
    echo "tags=developer" >> monarx-agent.conf
fi

now=$(date)
echo "# deployed: $now"  >> monarx-agent.conf
echo "#########################################################################" >> monarx-agent.conf

# install the repository repo and pgp key
cd /tmp
sudo curl -o /etc/yum.repos.d/monarx.repo https://repository.monarx.com/repository/monarx-yum/linux/yum/el/7/x86_64/monarx.repo
rpm --import https://repository.monarx.com/repository/monarx/publickey/monarxpub.gpg

# install monarx
sudo yum install monarx-protect-autodetect

# end of monarx main deployer

