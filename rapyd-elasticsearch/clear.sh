#!/bin/bash

# must be run as root user

######################################################################################################################
# remove  elasticsearch  config 



######################################################################################################################
# Stop and Disable  -  Elasticsearch service
sudo systemctl stop elasticsearch
sudo systemctl disable elasticsearch
sudo yum remove -y elasticsearch
sudo rm -rf /etc/elasticsearch /var/lib/elasticsearch /var/www/webroot/elasticsearch

# end remove elasticsearch config 
######################################################################################################################
