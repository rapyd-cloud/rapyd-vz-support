#! /bin/bash

# must be run as litespeed user

######################################################################################################################
# install Comodo exclude rules 

# cleanup any legacy code from previous system
revertCM () {
  cd /var/www/conf/comodo_litespeed
  targetfile=$1
  backupfile=$targetfile".backup"
  if [ -f $backupfile ]; then
     rm -f $targetfile
     cp -f $backupfile $targetfile
     rm -f $backupfile
  fi
}
revertCM "26_Apps_WordPress.conf"
revertCM "30_Apps_OtherApps.conf" 

# install new comodo files 

cd /var/www/conf/comodo_litespeed

# always include new version of Rapyd_excludes 
rm -f 00_Rapyd_Excludes.conf
wget https://raw.githubusercontent.com/rapyd-cloud/rapyd-vz-support/main/00_Rapyd_Excludes.conf

#only include customer template if it is missing 
if [ ! -f "00_Rapyd_Customer_Excludes.conf" ]; then
  wget https://raw.githubusercontent.com/rapyd-cloud/rapyd-vz-support/main/00_Rapyd_Customer_Excludes.conf
fi

# add rapyd exclude rules to the master ruleset conf
grep -c 00_Rapyd_Customer_Excludes rules.conf || sed -i "1i \Include 00_Rapyd_Customer_Excludes.conf" rules.conf
grep -c 00_Rapyd_Excludes rules.conf || sed -i "1i \Include 00_Rapyd_Excludes.conf" rules.conf

######################################################################################################################
