#!/bin/bash

# must be run as root user

######################################################################################################################
# remove  elasticsearch  config 



######################################################################################################################
# Stop and Disable  -  Elasticsearch service
sudo systemctl stop elasticsearch
sudo systemctl disable elasticsearch

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
else
  cd ~
  
fi

# end remove elasticsearch config 
######################################################################################################################
