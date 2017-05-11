#!/bin/sh

# set -x
# This script is used uninstallation
NAME="image-service"
SRC_DIR=`pwd`
APP_DIR="/var/$NAME"
SCRIPT_DIR="/etc/init.d/"
SCRIPT_NAME="image-service"
LOG_DIR="/var/log/$NAME.log"
LOG_FILE="$LOG_DIR/$NAME.log"


sudo rm -rf $APP_DIR

sudo rm -rf $SCRIPT_DIR/$SCRIPT_NAME

sudo rm -f $LOG_DIR/$LOG_FILE

sudo update-rc.d -f $SCRIPT_NAME remove
