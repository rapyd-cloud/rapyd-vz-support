#!/usr/bin/bash

#must be run as sudo su -  /  root

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
else
  cd ~

  sudo yum install -y openssl11-libs

fi
