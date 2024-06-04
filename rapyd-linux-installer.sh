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

function injectVhConfTag {
    XML_FILE="/var/www/conf/vhconf.xml"
    # Checking if rollingInterval exists inside accessLog, if not adding it
    xmlstarlet sel -t -m "//logging/accessLog/rollingInterval" -c . "$XML_FILE" | grep -q . \
        || xmlstarlet ed -L -s "//logging/accessLog" -t elem -n rollingInterval -v "daily" "$XML_FILE"

    # Checking if rollingInterval exists inside log, if not adding it
    xmlstarlet sel -t -m "//logging/log/rollingInterval" -c . "$XML_FILE" | grep -q . \
        || xmlstarlet ed -L -s "//logging/log" -t elem -n rollingInterval -v "daily" "$XML_FILE"

    # Update rollingInterval,keepDays inside log
    xmlstarlet ed -L -u "//logging/log/rollingInterval" -v "daily" "$XML_FILE"
    xmlstarlet ed -L -u "//logging/log/keepDays" -v "31" "$XML_FILE"

    # Checking if keepDays exists inside accessLog , if not adding it
    xmlstarlet sel -t -m "//logging/accessLog/keepDays" -c . "$XML_FILE" | grep -q . \
    || xmlstarlet ed -L -s "//logging/accessLog" -t elem -n keepDays -v "31" "$XML_FILE"

    # Checking if logLevel exists inside log, if not adding it
    xmlstarlet sel -t -m "//logging/log/logLevel" -c . "$XML_FILE" | grep -q . \
    || xmlstarlet ed -L -s "//logging/log/logLevel" -t elem -n ERROR -v "31" "$XML_FILE"

    # Update logging log rollingInterval,keepDays inside accessLog
    xmlstarlet ed -L -u "//logging/accessLog/rollingInterval" -v "daily" "$XML_FILE"
    xmlstarlet ed -L -u "//logging/accessLog/keepDays" -v "31" "$XML_FILE"

    # Updating logLevel inside accessLog & log
    xmlstarlet ed -L -u "//logging/log/logLevel" -v "ERROR" "$XML_FILE"
    xmlstarlet ed -L -u "//logging/accessLog/logLevel" -v "ERROR" "$XML_FILE"

    <logLevel>ERROR</logLevel>

}

injectVhConfTag
unset injectbashrc
unset installrapydbashrc
unset injectVhConfTag

# end linux config 
######################################################################################################################
