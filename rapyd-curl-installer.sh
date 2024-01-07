#!/bin/bash

# Note - in future - we may want to update this with a more recent version 
# refer notes from centos wiki
# https://wiki.centos-webpanel.com/update-curl-to-latest-version-in-centos
# The latest version number can always been found at https://curl.se/download/
# This version should be built and packaged for Centos7
# We will need to make a newer build for AlamaLinux in the near future 

# start of script

# 7.80.0 seems to be minimum viable version that doesnt lead to conflicts with php and openssl 
# VERSION=7.80.0
# 7.88.0 is last version documented in centos wiki
# VERSION=7.88.0
# VERSION=7.88.1
VERSION=8.4.0

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  # for now AlmaLinux is at least 7.76.1  
  # this should fix the serious wordpress timeout issue - but need to investigate further next week
  # possibly install the city-fan 8.5 binary 
  # https://mirror.city-fan.org/ftp/contrib/sysutils/Mirroring/
  
  cd ~
  
else
  # assume this is the current Centos 7 based platform install
  # this is a raw make clear && make && make install = very inefficient  
  # todo: convert to an RPM package 

  cd ~

  # dont update platform at this point - it seems to cause issues with php8.2.5 being partially updated to php8.2.12
  #sudo yum update -y

  # check for compiler dependencies
  sudo yum install wget gcc openssl-devel make -y

  # check for curl  new library dependencies
  sudo yum install libssh libssh-devel libnghttp2-devel libnghttp2 libgsasl libgsasl-devel zstd libzstd-devel libzstd brotli brotli-devel libbrotli -y
  
  wget https://curl.haxx.se/download/curl-${VERSION}.tar.gz
  tar -xzvf curl-${VERSION}.tar.gz 
  sudo rm -f curl-${VERSION}.tar.gz
  cd curl-${VERSION}

  # setup build configuration
  ./configure --prefix=/usr/local --with-ssl --with-zlib --with-gssapi --with-libssh --with-nghttp2 --with-openssl     
  # ./configure --with-ssl --with-zlib --with-gssapi --with-libssh --with-nghttp2     --enable-ldap --enable-ldaps   --with-ngtcp2  --with-quiche

  # run build process 
  sudo make clean
  sudo make
  sudo make install
  
  # link to centos lib location
  sudo ln -sf /usr/local/lib/libcurl.so.4 /usr/lib/libcurl.so.4
  
  # update linux library configuration 
  sudo ldconfig
  
  # clean up
  cd ~
  rm -rf curl-${VERSION}

fi

# end of script
