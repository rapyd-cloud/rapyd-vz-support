#!/bin/bash

# must run as root user.

# Config file
configDir=/etc/elasticsearch/jvm.options.d/
configPath=${configDir}rapyd-heap.options

# Get available ram in node in MB
ramAvailable=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))

# Get the max specifed heap to this node.
if [[ $1 =~ ^[0-9]+$ ]]; then
    heapPercentage=$1
else
    heapPercentage=10
fi

maxHeap=$(printf "%.0f" $(echo "$ramAvailable * $heapPercentage / 100" | bc))
unit=m

# if (($maxHeap < 1024)); then
#     unit=m
# else
#     unit=g
#     maxHeapGB=$(echo "scale=2; $maxHeap / 1024" | bc)
#     maxHeap=$(printf "%.0f" $maxHeapGB)
# fi

# create the configuration.
rm -f $configPath
mkdir -p $configDir # make sure dir exists.
echo -e "-Xms${maxHeap}${unit}\n-Xmx${maxHeap}${unit}" >$configPath
cat $configPath
