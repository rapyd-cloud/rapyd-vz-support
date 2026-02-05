#!/bin/bash
set -Eeuo pipefail

trap 'echo "❌ Error at line $LINENO. Exiting."; exit 1' ERR

echo "Copying /mnt/llsmp-acme.sh/ to /root/.acme.sh";
rsync -a --delete \
  /mnt/llsmp-acme.sh/ /root/.acme.sh/

echo "Copying /mnt/llsmp-rapyd-rsm/ to /etc/rapyd-rsm";
# Backup exec.key and exec.pub if available
tmp_folder=$(mktemp -d)
if [[ -f /etc/rapyd-rsm/exec.key ]]; then
    cp /etc/rapyd-rsm/exec.key "$tmp_folder/exec.key.rsync-backup"
fi
if [[ -f /etc/rapyd-rsm/exec.pub ]]; then
    cp /etc/rapyd-rsm/exec.pub "$tmp_folder/exec.pub.rsync-backup"
fi

rsync -a --delete \
  --exclude='rapyd-rsm.conf' \
  /mnt/llsmp-rapyd-rsm/ /etc/rapyd-rsm

# Restore exec.key and exec.pub if available
if [[ -f "$tmp_folder/exec.key.rsync-backup" ]]; then
    mv "$tmp_folder/exec.key.rsync-backup" /etc/rapyd-rsm/exec.key
fi
if [[ -f "$tmp_folder/exec.pub.rsync-backup" ]]; then
    mv "$tmp_folder/exec.pub.rsync-backup" /etc/rapyd-rsm/exec.pub
fi

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

