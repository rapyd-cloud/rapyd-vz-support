#! /bin/bash

# Note - in future - we may want to update this with a more recent version 
# The latest version number can always been found at https://curl.se/download/
# This version should be built and packaged for Centos7
# We will need to make a newer build for AlamaLinux in the near future 

# start of script

# VERSION=7.80.0
# VERSION=7.88.1
VERSION=8.4.0

cd ~

sudo yum update -y
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

# end of script
