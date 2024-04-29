#!/bin/bash

# must run as root user.

# Config file
configDir=/etc/elasticsearch/jvm.options.d/;
configPath=${configDir}rapyd-heap.options;

# Get available ram in node
ramAvailable=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024));

# Get the max specifed heap to this node.
if [[ $1 =~ ^[0-9]+$ ]]; then
    heapPercentage=$1
else
    heapPercentage=20
fi

maxHeap=$(( $ramAvailable * $heapPercentage / 100));

# create the configuration.
rm -f $configPath;
mkdir -p $configDir; # make sure dir exists.
echo -e "-Xms${maxHeap}g\n-Xmx${maxHeap}g" > $configPath;