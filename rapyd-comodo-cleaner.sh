#!/bin/bash

# must be run as litespeed user

######################################################################################################################
# renove Rapyd Comodo exclude rules 

cd /var/www/conf/comodo_litespeed

# remove preset excludes list
rm -f 00_Rapyd_Excludes.conf

# dont remove customer excludes list
# rm -f 00_Rapyd_Customer_Excludes.conf

# remove rapyd rules from rules.conf
if [ -f "rules.conf" ]; then
  sed -i '/00_Rapyd_Excludes/d' rules.conf
  sed -i '/00_Rapyd_Customer_Excludes/d' rules.conf 
  
fi

######################################################################################################################
