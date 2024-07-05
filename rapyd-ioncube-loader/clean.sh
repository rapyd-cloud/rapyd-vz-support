#!/bin/bash
PHP_INI_DIR=$(php-config --ini-dir);      
IONCUBE_LOADER_INI=$PHP_INI_DIR/ioncube.ini;

#================================================================
# Remove if ioncube.ini file is found
# ===============================================================

if [ -f "$IONCUBE_LOADER_INI" ]; then
  rm $IONCUBE_LOADER_INI;
else
  echo "IonCube loader not installed."
fi