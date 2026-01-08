#!/bin/bash
set -Eeuo pipefail

trap 'echo "❌ Error at line $LINENO. Exiting."; exit 1' ERR

echo "Copying /mnt/llsmp-home/ to /home/";
rsync -a --delete --no-links \
  --exclude='litespeed/' \
  --exclude='jelastic/' \
  /mnt/llsmp-home/ /home/

echo "Copying /mnt/llsmp-acme.sh/ to /root/.acme.sh";
rsync -a --delete  \
  /mnt/llsmp-acme.sh/ /root/.acme.sh/

echo "Copying /mnt/llsmp-rapyd-rsm/ to /etc/rapyd-rsm";
rsync -a --delete \
  --exclude='rapyd-rsm.conf' \
  /mnt/llsmp-rapyd-rsm/ /etc/rapyd-rsm

echo "Copying /mnt/llsmp-mysql/ to /var/lib/mysql";
rsync -a --delete \
  /mnt/llsmp-mysql/ /var/lib/mysql

echo "Copying /mnt/llsmp-cron to /var/spool/cron";
rsync -a --delete \
  /mnt/llsmp-cron/ /var/spool/cron

echo "Copying /mnt/llsmp-www/conf/httpd_config.xml to /var/www/conf/httpd_config.xml";
rsync -a \
/mnt/llsmp-www/conf/httpd_config.xml /var/www/conf/httpd_config.xml

sleep 10;

# Fix the MariaDB permission
chown -R mysql:mysql /var/lib/mysql && chmod 750 /var/lib/mysql;

echo "{{SUCCESS}}";

