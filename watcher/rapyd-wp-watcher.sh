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
    exit; 0;
fi

if [ -e "$lock_file" ]; 
then
  echo "Another instance of the script is already running."
  exit 1
else
  touch "$lock_file"
fi;


# Function to handle Ctrl+C
ctrl_c_handler() {
  echo "..Stopping the watcher...";
  rm "$lock_file";
  exit 0
}

trap ctrl_c_handler SIGINT

# Init wp changes.
wp_file_paths=("/var/www/webroot/ROOT/wp-config.php" "/var/www/webroot/ROOT/wp-content/mu-plugins/rapyd-includes/rapyd-json/rapyd-readymade.json");
init_wp_changes=();
for file_path in "${wp_file_paths[@]}"; 
do
    if [ -f "$file_path" ]; then
        init_wp_changes+=$(ls -l $file_path)
    fi
done


# Init Plugin & Themes changes.
wp_plugins_paths=("/var/www/webroot/ROOT/wp-content/plugins/" "/var/www/webroot/ROOT/wp-content/themes/");
init_plugins_themes_changes=();
for dir_path in "${wp_plugins_paths[@]}"; 
do
    if test -e $dir_path; then
        init_plugins_themes_changes+=$(ls -l $dir_path)
    fi
done

# WordPress file changes watcher.
while true;
do
    # Get current modification timestamps
    curr_wp_changes=()
    for file_path in "${wp_file_paths[@]}"; 
    do
        if [ -f "$file_path" ]; then
            curr_wp_changes+=$(ls -l $file_path)
        fi
    done

    # Compare timestamps
    if [[ "${init_wp_changes[*]}" != "${curr_wp_changes[*]}" ]]; then
        init_wp_changes=$curr_wp_changes;
        php "$script_dir/notify-files.php" &
        echo "PHP executed";
    fi

    # Wait for a certain period before checking again
    sleep 2
done &

# WordPress Themes & Plugins chages watcher.
while true;
do

    # Get current modification timestamps
    curr_plugins_themes_changes=()
    for dir_path in "${wp_plugins_paths[@]}"; 
    do
        if test -e $dir_path; then
            curr_plugins_themes_changes+=$(ls -l $dir_path)
        fi
    done

    # Compare timestamps
    if [[ "${init_plugins_themes_changes[*]}" != "${curr_plugins_themes_changes[*]}" ]]; then
        init_plugins_themes_changes=$curr_plugins_themes_changes;
        php "$script_dir/notify-themes-plugins.php" &
        echo "Themes or Plugins Updated.";
    fi

    # Wait for a certain period before checking again
    sleep 5

done 
