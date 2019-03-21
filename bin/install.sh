#!/bin/bash -l

PLUGIN_NAME="dis-logstash-plugins"
PLUGIN_HOME=$(dirname "$(pwd)")
PLUGIN_INPUT_NAME="logstash-input-dis"
PLUGIN_OUTPUT_NAME="logstash-output-dis"


# Check if Logstash is installed
function check_logstash_path()
{
    if [ ! -x $logstash_path ]; then
        echo "Unavailable Logstash path." >&2
        exit 1
    fi

    if ! [ -x "$(command -v $logstash_path/bin/logstash)" ]; then
      echo 'Error: Unavailable Logstash path.' >&2
      exit 1
    fi
}

function install_plugins()
{

    # Error automatically quits
    set -e

    # Install logstash-plugins to Logstash
    cd $logstash_path
    if ! grep -E "${PLUGIN_INPUT_NAME}|${PLUGIN_OUTPUT_NAME}" Gemfile >/dev/null; then
        # modify Gemfile
        echo "gem \"$PLUGIN_INPUT_NAME\", :path => \"$PLUGIN_HOME/$PLUGIN_INPUT_NAME\"" >> Gemfile
        echo "gem \"$PLUGIN_OUTPUT_NAME\", :path => \"$PLUGIN_HOME/$PLUGIN_OUTPUT_NAME\"" >> Gemfile
    fi
    bin/logstash-plugin install --local --no-verify

    echo "Install ${PLUGIN_NAME} successfully."
}

if [ ! -n "$1" ] ;then
    echo "Usage: install.sh -p [LOGSTASH_PATH]"
    exit 1
fi

while getopts "p:" opt; do
  case $opt in
    p)
      logstash_path=$OPTARG
      echo "The target Logstash path is: $logstash_path"
      check_logstash_path
      install_plugins
      ;;
    \?)
      # echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done
