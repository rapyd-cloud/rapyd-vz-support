#!/bin/bash
cd /usr/local/rapyd/rapyd-ioncube-loader-files;

# Download IonCube Libraries.
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip;
unzip ioncube_loaders_lin_x86-64.zip;

PHP_VERSION=$( php -i | head -n 5 | grep "PHP Version =>" |  grep -o '[0-9.]*' | grep -o '^[0-9]\+\.[0-9]\+');
PHP_EXTENTION="/home/ioncubeloader/ioncube/ioncube_loader_lin_$PHP_VERSION.so";
PHP_INI_DIR=$(php-config --ini-dir);      
PHP_EXT_DIR=$(php-config --extension-dir);

#================================================================
# Check if this version of PHP is supported by IonCube Loader.
#================================================================
if [ -e "$PHP_EXTENTION" ]; then
  
  IONCUBE_LOADER_INI=$PHP_INI_DIR/ioncube.ini;

  # Install the extention file.
  rm -f $PHP_EXT_DIR/ioncube.so;
  cp -f $PHP_EXTENTION $PHP_EXT_DIR/ioncube.so

  # Install ini file.
  rm -f $IONCUBE_LOADER_INI;
  echo "zend_extension = ioncube.so" > $IONCUBE_LOADER_INI;

  echo "ionCube Loader Installed!";  

else
  echo "PHP version is not supported by IonCube Loader."
  exit 1;
fi