#! /bin/bash

# must be run a sudo su - / root 

# define logic variables to determine which monarx linked so file was deployed

MONARX_PHP=$(php-config --version | cut -c -3) 
MONARX_PHPSTRIPPED=${MONARX_PHP/.} 
MONARX_INI_DIR=$(php-config --ini-dir)  
MONARX_EXT_DIR=$(php-config --extension-dir)  
MONARX_ARCH=$(arch | sed -e 's/arm64/aarch64/;s/amd64\|x86_64/x86-64/') 

MONARX_SOPATH="/usr/lib64/monarx-protect"
MONARX_SO="monarxprotect-php$MONARX_PHPSTRIPPED.so"
MONARX_INI_FILEPATH="$MONARX_INI_DIR/monarxprotect.ini"
MONARX_LINKED="$MONARX_EXT_DIR/$MONARX_SO"

# clean up any existing linked file 
if [ -L "$MONARX_LINKED" ]; then
  rm -f "$MONARX_LINKED"
fi

# clean up and existing monarxprotect.ini file 
if [ -f "$MONARX_INI_FILEPATH" ]; then
  rm -f "$MONARX_INI_FILEPATH"
fi

# remove conf file
rm -f  /etc/monarx-agent.conf

# remove monarx if possible
yum remove monarx-protect-autodetect -y

mkdir -p /usr/local/rapyd/rapyd-monarx-files
cd /usr/local/rapyd/rapyd-monarx-files

rm -f rapyd-monarx-installer.sh
rm -f rapyd-monarx-linker.sh
rm -f rapyd-monarx-cleaner.sh

#end of monarx cleanup logic
