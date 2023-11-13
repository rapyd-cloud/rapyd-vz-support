#! /bin/bash

# must be run as root user 

cd ~ 

# define logic variables to determine which monarx linked so file we should deploy

MONARX_PHP=$(php-config --version | cut -c -3)
MONARX_PHPSTRIPPED=${MONARX_PHP/.}
MONARX_INI_DIR=$(php-config --ini-dir)
MONARX_EXT_DIR=$(php-config --extension-dir)
MONARX_ARCH=$(arch | sed -e 's/arm64/aarch64/;s/amd64\|x86_64/x86-64/')

MONARX_SOPATH="/usr/lib64/monarx-protect"
MONARX_SO="monarxprotect-php$MONARX_PHPSTRIPPED.so"
MONARX_INI_FILEPATH="$MONARX_INI_DIR/monarxprotect.ini"
MONARX_LINKED="$MONARX_EXT_DIR/$MONARX_SO"

# clean up and existing linked file and then link so
if [ -L "$MONARX_LINKED" ]; then
  rm -f "$MONARX_LINKED"
fi
ln -sf "$MONARX_SOPATH/$MONARX_SO" "$MONARX_EXT_DIR"

# clean up and existing php.ini file and then create new one 

if [ -f "$MONARX_INI_FILEPATH" ]; then
  rm -f "$MONARX_INI_FILEPATH"
fi
echo "extension=$MONARX_SO" > "$MONARX_INI_FILEPATH"
chown litespeed:litespeed "$MONARX_INI_FILEPATH"

# end of monarx linker logic
