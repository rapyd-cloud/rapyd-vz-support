#! /bin/bash

# Note - in future - we may want to update this with a more recent version 
# The latest version number can always been found at https://curl.se/download/
# This version should be built and packaged for Centos7
# We will need to make a newer build for AlamaLinux in the near future 

# start of script

# 7.80.0 seems to be minimum viable version that doesnt lead to conflicts with php and openssl 
VERSION=7.80.0
# VERSION=7.88.1
#VERSION=8.4.0

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  
else
  # assume this is the current Centos 7 based platform install

  # this is a raw make clear && make && make install = very inefficient  
  # todo: convert to an RPM package 
  cd ~

  # dont update platform at this point - it seems to cause issues with php8.2.5 being partially updated to php8.2.12
  #sudo yum update -y
  sudo yum install wget gcc openssl-devel make -y
  
  wget https://curl.haxx.se/download/curl-${VERSION}.tar.gz
  tar -xzvf curl-${VERSION}.tar.gz 
  sudo rm -f curl-${VERSION}.tar.gz
  cd curl-${VERSION}
  ./configure --prefix=/usr/local --with-ssl
  sudo make clean
  sudo make
  sudo make install
  
  sudo ln -sf /usr/local/lib/libcurl.so.4 /usr/lib/libcurl.so.4
  
  sudo ldconfig
  
  cd ~
  rm -rf curl-${VERSION}
fi

# end of script
