#!/bin/bash

# must be run as root user

######################################################################################################################
# install elasticsearch


######################################################################################################################
# Update system packages
# Install Java (Elasticsearch requires Java 8 or later)
sudo yum install java-1.8.0-openjdk -y

# Custom installation paths
INSTALL_DIR="/var/www/webroot"
DATA_DIR="$INSTALL_DIR/elasticsearch"

# Create data directories
mkdir -p "$DATA_DIR"

# Import Elasticsearch GPG key
sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# Add Elasticsearch repository
echo "[elasticsearch-7.x]" | sudo tee /etc/yum.repos.d/elasticsearch.repo
echo "name=Elasticsearch repository for 7.x packages" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo
echo "baseurl=https://artifacts.elastic.co/packages/7.x/yum" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo
echo "gpgcheck=1" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo
echo "gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo
echo "enabled=1" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo
echo "autorefresh=1" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo
echo "type=rpm-md" | sudo tee -a /etc/yum.repos.d/elasticsearch.repo


######################################################################################################################
# Install Elasticsearch
sudo yum install elasticsearch -y

# Update Elasticsearch configuration to use custom paths
echo "Updating Elasticsearch configuration..."
sudo sed -i 's|/var/lib/elasticsearch|/var/www/webroot/elasticsearch|g' /etc/elasticsearch/elasticsearch.yml

sudo chown elasticsearch:elasticsearch  $DATA_DIR/ -R

######################################################################################################################
# Enable and start Elasticsearch service
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
