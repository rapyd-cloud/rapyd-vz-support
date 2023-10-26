#!/bin/bash
script_dir=$(dirname "$0");
echo "Restarting the watcher script...";
bash "$script_dir/rapyd-wp-watcher.sh" stop;
nohup bash "$script_dir/rapyd-wp-watcher.sh" >/dev/null 2>&1 &
exit

