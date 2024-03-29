#!/bin/bash

# must be run as root - su user

######################################################################################################################
# install linux config 

function injectbashrc  {
  BASHPATH="/home/jelastic/.bashrc"
  if ! grep -qxF '#include .rapyd.bashrc' $BASHPATH ; then
      echo '' >> $BASHPATH
      echo '#include .rapyd.bashrc' >> $BASHPATH
      echo 'filepath="/usr/local/rapyd/rapyd-linux-files/.rapyd.bashrc"' >> $BASHPATH
      echo 'if [ -f "$filepath" ]; then' >> $BASHPATH
      echo '    source "$filepath"' >> $BASHPATH
      echo 'fi' >> $BASHPATH
  fi
}

function installrapydbashrc {
  DIRECTORY="/usr/local/rapyd/rapyd-linux-files"
  if [ -d "$DIRECTORY" ]; then
    cd "$DIRECTORY"
    rm -rf ".rapyd.bashrc"
    wget https://raw.githubusercontent.com/rapyd-cloud/rapyd-vz-support/main/.rapyd.bashrc
    chown litespeed:litespeed .rapyd.bashrc
  fi
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
unset installrapydbashrc

# end linux config 
######################################################################################################################
