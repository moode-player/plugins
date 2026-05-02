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

# 1: Plugin name and update date
PLUGIN_NAME=$1
PLUGIN_UPDATE_DATE="2026-05-02"

# 2: Initialize the step counter
STEP=0
TOTAL_STEPS=7

# System vars
SQLDB=/var/local/www/db/moode-sqlite3.db
HOME_DIR=$(moodeutl -d -gv home_dir)

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
if [ $? -ne 0 ]; then
	cancel_update "** Step failed"
fi

# 2 - Install git
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Install git tools"
apt -y install git
if [ $? -ne 0 ]; then
	cancel_update "** Install failed"
fi

# 3 - Clone repo
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Clone package repo"
rm -rf $WD/pkgbuild
git clone --depth 1 https://github.com/moode-player/pkgbuild.git
if [ $? -ne 0 ]; then
	cancel_update "** Clone failed"
fi

# 4 - Build and install shairport-sync
PACKAGE="shairport-sync"
VERSION=$(sqlite3 $SQLDB "SELECT version FROM cfg_plugin WHERE component='renderer' AND type='airplay'")
PACKAGE_DEB=$PACKAGE"_"$VERSION"_arm64.deb"
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Build and Install $PACKAGE"
export DEBFULLNAME=User
export DEBEMAIL=User@Email.com
message_log "** - Building $PACKAGE"
cd "$WD/pkgbuild/packages/$PACKAGE"
./build.sh
if [ $? -ne 0 ]; then
	cancel_update "** Build failed"
fi
message_log "** - Installing $PACKAGE"
cp "$WD/pkgbuild/packages/$PACKAGE/dist/binary/$PACKAGE_DEB" /tmp/
apt -y --allow-change-held-packages install /tmp/$PACKAGE_DEB
if [ $? -ne 0 ]; then
	cancel_update "** Install failed"
fi
message_log "** - Configuring /etc/$PACKAGE.conf"
/var/www/util/sysutil.sh upd-shairport-sync-conf
if [ $? -ne 0 ]; then
	cancel_update "** Configure failed"
fi
message_log "** - Save package to home dir"
cp /tmp/$PACKAGE_DEB "$HOME_DIR"
if [ $? -ne 0 ]; then
	cancel_update "** Save package failed"
fi
message_log "** - Done"

# 5 - Build and install nqptp
PACKAGE="nqptp"
VERSION=$(sqlite3 $SQLDB "SELECT version FROM cfg_plugin WHERE component='system' AND type='nqptp'")
PACKAGE_DEB=$PACKAGE"_"$VERSION"_arm64.deb"
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Build and Install $PACKAGE"
export DEBFULLNAME=User
export DEBEMAIL=User@Email.com
message_log "** - Building $PACKAGE"
cd "$WD/pkgbuild/packages/$PACKAGE"
./build.sh
if [ $? -ne 0 ]; then
	cancel_update "** Build failed"
fi
message_log "** - Installing $PACKAGE"
cp "$WD/pkgbuild/packages/$PACKAGE/dist/binary/$PACKAGE_DEB" /tmp/
apt -y --allow-change-held-packages install /tmp/$PACKAGE_DEB
if [ $? -ne 0 ]; then
	cancel_update "** Install failed"
fi
message_log "** - Save package to home dir"
cp /tmp/$PACKAGE_DEB "$HOME_DIR"
if [ $? -ne 0 ]; then
	cancel_update "** Save package failed"
fi
message_log "** - Done"

# 6 - Update systemd services
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Updating systemd services"
message_log "** - Stop shairport-sync.service"
systemctl stop shairport-sync > /dev/null 2>&1
if [ $? -ne 0 ]; then
	cancel_update "** Stop shairport-sync failed"
fi
message_log "** - Disable shairport-sync.service"
systemctl disable shairport-sync > /dev/null 2>&1
if [ $? -ne 0 ]; then
	cancel_update "** Disable shairport-sync failed"
fi
message_log "** - Stop nqptp.service"
systemctl stop nqptp > /dev/null 2>&1
if [ $? -ne 0 ]; then
	cancel_update "** Stop nqptp failed"
fi
message_log "** - Disable nqptp.service"
systemctl disable nqptp > /dev/null 2>&1
if [ $? -ne 0 ]; then
	cancel_update "** Disable nqptp failed"
fi
message_log "** - Done"

# 7 - Flush cached disk writes
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Sync changes to disk"
message_log "Finish $PLUGIN_UPDATE_DATE update for $PLUGIN_NAME"
sync

cd ~/
