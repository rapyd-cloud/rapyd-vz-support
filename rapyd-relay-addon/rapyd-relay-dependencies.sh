#!/bin/bash

#must be run as sudo su -  /  root

#################################################################################

if grep -a 'AlmaLinux' /etc/system-release ; then
  cd ~
  sudo yum install -y compat-openssl11
  
else
  cd ~
  sudo yum install -y openssl11-libs

fi

#################################################################################
# install relay required so library updates
cd /usr/local/lsws/lsphp/etc/php.d

rm -f 996-rapyd-relay.ini
cp /usr/local/rapyd/rapyd-relay-files/996-rapyd-relay.ini ./
chown litespeed:litespeed 996-rapyd-relay.ini

#################################################################################
# alter redis to be non-persistent 

if [ -f "/etc/redis.conf" ]; then

  sed -i '/save \"\"/c\save \"\"' /etc/redis.conf
  
  sed -i '/save 900 1/c\#save 900 1' /etc/redis.conf
  sed -i '/save 300 10/c\#save 300 10' /etc/redis.conf
  sed -i '/save 60 10000/c\#save 60 10000' /etc/redis.conf
  
fi

#################################################################################
# fix double igbinary definition 

if [ -f "/usr/local/lsws/lsphp/etc/php.d/40-igbinary.ini" ]; then

  if [ -f "/usr/local/lsws/lsphp/etc/php.d/50-redis.ini" ]; then

    sed -i '/extension = igbinary.so/c\;extension = igbinary.so' /usr/local/lsws/lsphp/etc/php.d/50-redis.ini
  
  fi

fi

#################################################################################

#end relay dependencies deployment
