#!/bin/bash

param="$1"
lock_file="/tmp/rapyd-watcher.lock"
script_dir=$(dirname "$0");

## stop self running script from background.
if [[ $param == "stop" ]]; then
    echo "Stopping the running script..";
    if [ -f "$lock_file" ]; then
        rm "$lock_file";
    fi;
    pkill -f -9 rapyd-wp-watcher.sh
    exit 0;
fi

# Never allow to run duplicate instance of this script.
if [ -e "$lock_file" ]; 
then
  echo "Another instance of the script is already running."
  exit 1
else
  touch "$lock_file"
fi;

# Captures the CTRL+C and close the script gracefully. :)
cleanup() {
  echo "..Stopping the watcher...";
  rm "$lock_file";
  pkill -f -9 rapyd-wp-watcher.sh;
  exit 0
}

trap cleanup SIGINT
trap cleanup ERR EXIT


wproot="/var/www/webroot/ROOT/";
rapydjson="/var/www/webroot/ROOT/wp-content/mu-plugins/rapyd-includes/rapyd-json/";
themes="/var/www/webroot/ROOT/wp-content/themes/";
plugins="/var/www/webroot/ROOT/wp-content/plugins/"

 # make sure folder to watch are exists.
 mkdir -p $rapydjson;

 # collect the inode values of folders to watch.
 folders=(
  "$wproot"
  "$rapydjson"
  "$themes"
  "$plugins"
)

max_in_min=5; # how many notify call to be sent within one min.
min_gap_between_call=5; # how much gap should be between two notify calls. keep it more then 2 for optimization.
previous_inodes=();

# do not edit.
mkdir -p /dev/shm/RAPYD_WATCHER;
touch /dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT;
touch /dev/shm/RAPYD_WATCHER/SENT_NOTIFY_FLAG;
echo "0" > /dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT; # how many calls are sent within min.
echo "0" > /dev/shm/RAPYD_WATCHER/SENT_NOTIFY_FLAG;

get_notify_flag() {
    read -r data < /dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT;
    return "$data";
}

call_notify() {
    echo "1" > /dev/shm/RAPYD_WATCHER/SENT_NOTIFY_FLAG;
}

clear_notify_flag(){
    echo "0" > /dev/shm/RAPYD_WATCHER/SENT_NOTIFY_FLAG;
}

get_call_count() {
    read -r count < /dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT;
    return "$count";
}

zero_call_count() {
    echo "0" > /dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT;
}

increase_call_count() {
    sed -i 's/\([0-9]\+\)/echo $((\1 + 1))/e' "/dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT"
}


# Watch the folder using inotifywait...
inotifywait -m -e create,modify,delete,moved_to,moved_from,move_self "$wproot" "$rapydjson" "$themes" "$plugins" --format "%e %f %w" | while read -r event_type file_name file_path; do
    
    absolute_file_path="$file_path$file_name";
    echo "$event_type -> $absolute_file_path";
    # Check for Wp Config File Changes.
    if [[ $absolute_file_path == "/var/www/webroot/ROOT/wp-config.php" ]]; then
        call_notify;
    fi

    # Check for Rapyd Ready Made File Changes.
    if [[ $absolute_file_path == "/var/www/webroot/ROOT/wp-content/mu-plugins/rapyd-includes/rapyd-json/rapyd-readymade.json" ]]; then
        call_notify
    fi

done &

# Collect current inodes values of watching dir.
for folder in "${folders[@]}"; do
    if [ -d "$folder" ]; then
        current_inode=$(stat -c "%i" "$folder")
        previous_inodes+=("$current_inode");
    fi
done 

# watch the inodes and keep update.
while true; do
  for folder in "${folders[@]}"; do
      if [ -d "$folder" ]; then
        current_inode=$(stat -c "%i" "$folder")

        if [[ ! " ${previous_inodes[@]} " =~ " $current_inode " ]]; then
        echo "inode value has been changed for one of the folders which are being watched. need to stop this service.";
        exit;
        fi

        previous_inodes+=("$current_inode")
    else 
        echo "One of the watcher folder found to be deleted. need to stop this service.";
        exit;
    fi;
  done
  sleep 15  # Adjust the sleep duration as needed
done &

while true; do
    echo "Sent limit is reset.";
    zero_call_count;
sleep 60
done &

# responsable for sending requests.
while true; do 

    RAPYD_CALL_COUNT=$(tail -n 10 "/dev/shm/RAPYD_WATCHER/RAPYD_CALL_COUNT");
    RAPYD_CALL_COUNT=$((RAPYD_CALL_COUNT));
    get_notify=$(tail -n 10 "/dev/shm/RAPYD_WATCHER/SENT_NOTIFY_FLAG");
    get_notify=$((get_notify));

    if [ "$RAPYD_CALL_COUNT" -ge "$max_in_min" ] && [ "$get_notify" -eq 1 ]; then
        echo "Max call reached for 1min.";
    fi;

    if [ "$max_in_min" -gt "$RAPYD_CALL_COUNT" ] && [ "$get_notify" -eq 1 ]; then
        echo "0" > "/dev/shm/RAPYD_WATCHER/SENT_NOTIFY_FLAG";
        echo "Notifying..";
        bash "$script_dir/notify-core.sh" & # send to background.
        increase_call_count;
    else 
        echo "Nothing to do $RAPYD_CALL_COUNT out of $max_in_min left.";
    fi


    sleep $min_gap_between_call;
done 

