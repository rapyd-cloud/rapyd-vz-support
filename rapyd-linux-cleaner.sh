#!/bin/bash

# must be run as root - su user

######################################################################################################################
# remove linux config 

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  echo "Removing Linux Config for AlamLinux"
  
else
  cd ~
  echo "Removing linux Config for Centos"

fi

# end remove linux config 
######################################################################################################################

