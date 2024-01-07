#!/bin/bash

# must be run as root - su user

######################################################################################################################
# ffmpeg 

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  echo "Installing ffmpeg for AlamLinux"

  sudo dnf install epel-release -y
  sudo dnf config-manager --set-enabled crb -y

  sudo dnf install --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm -y
  sudo dnf install --nogpgcheck https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm -y

  sudo dnf install ffmpeg ffmpeg-devel -y
  
else
  cd ~
  echo "Installing ffmpeg for Centos"

  sudo yum install epel-release -y
  sudo yum localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm -y
  sudo yum install ffmpeg ffmpeg-devel -y

fi


