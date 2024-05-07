#!/bin/bash

# must be run as litespeed user

######################################################################################################################
# remove  woocommerce  config 
# for now we should NEVER uninstalled the woocommerce plugin

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
else
  cd ~
  
fi

# end remove linux config 
######################################################################################################################
