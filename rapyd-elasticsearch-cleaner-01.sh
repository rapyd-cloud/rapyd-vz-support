#!/bin/bash

# must be run as root user

######################################################################################################################
# remove  elasticsearch  config 

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
else
  cd ~
  
fi

# end remove elasticsearch config 
######################################################################################################################
