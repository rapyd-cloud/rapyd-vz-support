#!/bin/bash

# must be run as root - su user

######################################################################################################################
# remove linux config 

function removerapydbashrc  {
  # for now just remove the .rapyd.bashrc file 
  filepath="/usr/local/rapyd/rapyd-linux-files/.rapyd.bashrc
  if [ -f "$filepath" ]; then
    rm -rf $filepath
  fi
}

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  echo "Removing Linux Config for AlamLinux"
  removerapydbashrc
  
else
  cd ~
  echo "Removing linux Config for Centos"
  removerapydbashrc
  
fi

# end remove linux config 
######################################################################################################################

