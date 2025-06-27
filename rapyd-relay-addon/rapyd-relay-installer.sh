#!/bin/bash

# must be run as root -
# must pass in RELAY_KEY

RELAY_KEY=$1

if [ -z "$RELAY_KEY" ]
  then
  exit 9991
fi

# Updated to v0.11.0
RELAY_VERSION="v0.11.0"                         # https://builds.r2.relay.so/meta/latest
RELAY_PHP=$(php-config --version | cut -c -3)   # 8.1
RELAY_INI_DIR=$(php-config --ini-dir)           # /etc/php/8.1/cli/conf.d/
RELAY_EXT_DIR=$(php-config --extension-dir)     # /usr/lib/php/20210902
RELAY_ARCH=$(arch | sed -e 's/arm64/aarch64/;s/amd64\|x86_64/x86-64/')

# old debian build format
# RELAY_ARTIFACT="https://builds.r2.relay.so/$RELAY_VERSION/relay-$RELAY_VERSION-php$RELAY_PHP-debian-$RELAY_ARCH.tar.gz"

if grep -a 'AlmaLinux' /etc/system-release ; then
  # centos and alma have different build versions
  RELAY_ARTIFACT="https://builds.r2.relay.so/$RELAY_VERSION/relay-$RELAY_VERSION-php$RELAY_PHP-el9-$RELAY_ARCH.tar.gz"

else
  # centos and alma have different build versions
  RELAY_ARTIFACT="https://builds.r2.relay.so/$RELAY_VERSION/relay-$RELAY_VERSION-php$RELAY_PHP-centos7-$RELAY_ARCH.tar.gz"

fi

RELAY_TMP_DIR=$(mktemp -dt relay.XXXXXXXX)

## Download artifact
curl -sSL $RELAY_ARTIFACT | tar -xz --strip-components=1 -C $RELAY_TMP_DIR

## Inject UUID
sed -i "s/00000000-0000-0000-0000-000000000000/$(cat /proc/sys/kernel/random/uuid)/" $RELAY_TMP_DIR/relay-pkg.so

## Move + rename `relay-pkg.so`
rm -f $RELAY_EXT_DIR/relay.so
yes | cp -rf $RELAY_TMP_DIR/relay-pkg.so $RELAY_EXT_DIR/relay.so

# Modify `relay.ini`
sed -i 's/^;\? \?relay.maxmemory =.*/relay.maxmemory = 128M/' $RELAY_TMP_DIR/relay.ini
sed -i 's/^;\? \?relay.eviction_policy =.*/relay.eviction_policy = lru/' $RELAY_TMP_DIR/relay.ini
sed -i 's/^;\? \?relay.environment =.*/relay.environment = production/' $RELAY_TMP_DIR/relay.ini
sed -i "s/^;\? \?relay.key =.*/relay.key = $RELAY_KEY/" $RELAY_TMP_DIR/relay.ini

## Move `relay.ini`
rm -f $RELAY_INI_DIR/relay.ini
yes | cp -rf $RELAY_TMP_DIR/relay.ini $RELAY_INI_DIR

## Restart LiteSpeed
service lsws restart

## relay deployed
