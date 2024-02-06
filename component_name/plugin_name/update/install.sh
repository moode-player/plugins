#!/bin/bash
#
# moOde audio player (C) 2014 Tim Curtis
# http://moodeaudio.org
#
# This Program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# This Program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# Environment
#

# Plugin name and update date
PLUGIN_NAME=$1
PLUGIN_UPDATE_DATE="YYYY-MM-DD"
SQLDB=/var/local/www/db/moode-sqlite3.db

# Initialize the step counter
STEP=0
TOTAL_STEPS=3

# Log files
MOODE_LOG="/var/log/moode.log"
PLUGIN_LOG="/var/log/moode_plugin.log"

#
# Functions
#

cancel_update () {
	if [ $# -gt 0 ] ; then
		message_log "$1"
	fi
	message_log "** Exiting update"
	exit 1
}

message_log () {
	echo "$1"
	TIME=$(date +'%Y%m%d %H%M%S')
	echo "$TIME updater: $1" >> $MOODE_LOG
	echo "$TIME updater: $1" >> $PLUGIN_LOG
}

#
# Main
#

echo
echo "**********************************************************"
echo "**"
echo "**  This package updates a given plugin to the latest"
echo "**  release."
echo "**"
echo "**  Reboot after the update completes."
echo "**"
echo "**********************************************************"
echo

WD=/var/local/www
cd $WD
truncate $PLUGIN_LOG --size 0
message_log "Start $PLUGIN_UPDATE_DATE update for $PLUGIN_NAME"

# 1 - Install timesyncd so date will be current otherwise requests to the repos will fail
# NOTE: It should already be present in 2023 RaspiOS Bullseye 32/64-bit releases
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Install timesyncd"
apt -y install systemd-timesyncd

# 2 - Install plugin files
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Install $PLUGIN_NAME"
# Commands go here

# 3 - Flush cached disk writes
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Sync changes to disk"
message_log "Finish $PLUGIN_UPDATE_DATE update for $PLUGIN_NAME"
sync

cd ~/
