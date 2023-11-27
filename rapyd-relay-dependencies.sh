#!/usr/bin/bash

#must be run as sudo su -  /  root

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
else
  cd ~

  sudo yum install -y openssl11-libs

fi

# install relay required so library updates
cd /usr/local/lsws/lsphp/etc/php.d

rm -f 996-rapyd-relay.ini
wget https://raw.githubusercontent.com/rapyd-cloud/rapyd-vz-support/main/996-rapyd-relay.ini
chown litespeed:litespeed 996-rapyd-relay.ini

#end relay dependencies deployment
