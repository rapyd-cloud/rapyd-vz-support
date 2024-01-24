#!/bin/bash

# must be run as root - su user

######################################################################################################################
# remove linux config 

function removerapydbashrc  {
  # for now just remove the .rapyd.bashrc file 
  FILEPATH="/usr/local/rapyd/rapyd-linux-files/.rapyd.bashrc"
  if [ -f "$FILEPATH" ]; then
    rm -rf $FILEPATH
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

unset removerapydbashrc

# end remove linux config 
######################################################################################################################

