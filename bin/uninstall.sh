#!/bin/bash -l

PLUGIN_NAME="dis-logstash-plugins"
PLUGIN_HOME=$(dirname "$(pwd)")


# Check if Logstash is installed
function check_logstash_path()
{
    if [ ! -x $logstash_path ]; then
        echo "Unavailable Logstash path."
        exit 1
    fi

    if ! [ -x "$(command -v $logstash_path/bin/logstash)" ]; then
      echo 'Error: Unavailable Logstash path.' >&2
      exit 1
    fi
}

function uninstall_plugins()
{

    set -e
    # Uninstall logstash-plugins
    cd $logstash_path
    bin/logstash-plugin uninstall logstash-input-dis
    bin/logstash-plugin uninstall logstash-output-dis

    echo "Uninstall ${PLUGIN_NAME} successfully."
}

if [ ! -n "$1" ] ;then
    echo "Usage: uninstall.sh -p [LOGSTASH_PATH]"
    exit 1
fi

while getopts "p:" opt; do
  case $opt in
    p)
      logstash_path=$OPTARG
      echo "The target Logstash path is: $logstash_path"
      check_logstash_path
      uninstall_plugins
      ;;
    \?)
      # echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done
