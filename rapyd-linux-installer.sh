#!/bin/bash

# must be run as root - su user

######################################################################################################################
# install linux config 

function injectbashrc  {
  bashpath="/home/jelastic/.bashrc"
  if ! grep -qxF '#include .rapyd.bashrc' $bashpath ; then
      echo '' >> $bashpath
      echo '#include .rapyd.bashrc' >> $bashpath
      echo 'filepath="/usr/local/rapyd/rapyd-linux-files/.rapyd.bashrc"' >> $bashpath
      echo 'if [ -f "$filepath" ]; then' >> $bashpath
      echo '    source "$filepath"' >> $bashpath
      echo 'fi' >> $bashpath
  fi
}

function installrapydbashrc {
  cd "/usr/local/rapyd/rapyd-linux-files/"
  rm -rf ".rapyd.bashrc"
  wget https://raw.githubusercontent.com/rapyd-cloud/rapyd-vz-support/main/.rapyd.bashrc
  chown litespeed:litespeed .rapyd.bashrc
}

if grep -a 'AlmaLinux' /etc/system-release ; then
  # work out what we need to do here for AlmaLinux 
  cd ~
  installrapydbashrc
  injectbashrc
    
else
  # work out what we need to do here for CentOS
  cd ~
  installrapydbashrc
  injectbashrc
  
fi

unset injectbashrc

# end linux config 
######################################################################################################################
