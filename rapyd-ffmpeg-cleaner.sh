#!/bin/bash

# must be run as root - su user

######################################################################################################################
# ffmpeg 

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  echo "Removing ffmpeg for AlamLinux"

  sudo dnf remove ffmpeg ffmpeg-devel -y
  
else
  cd ~
  echo "Removing ffmpeg for Centos"

  sudo yum remove ffmpeg ffmpeg-devel -y

fi
