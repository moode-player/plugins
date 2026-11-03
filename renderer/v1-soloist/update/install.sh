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
# Spotify Soloist download/install
# Spotify does not allow the release to be redistributed: it is downloaded
# from Spotify and no package is saved to the home dir.
#

#
# Environment
#

# 1: Plugin name and update date
PLUGIN_NAME=$1
PLUGIN_RELEASE_DATE="2026-10-31"

# 2: Initialize the step counter
STEP=0
TOTAL_STEPS=5

# System vars
SQLDB=/var/local/www/db/moode-sqlite3.db
SOLOIST_URL="https://soloist-builds.spotifycdn.com"

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
#truncate $PLUGIN_LOG --size 0
message_log "Start $PLUGIN_RELEASE_DATE update for $PLUGIN_NAME"

# 1 - Install timesyncd so date will be current otherwise requests to the repos will fail
# NOTE: It should already be present in 2023 RaspiOS Bullseye 32/64-bit releases
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Install timesyncd"
apt -y install systemd-timesyncd
if [ $? -ne 0 ]; then
	cancel_update "** Step failed"
fi

# 2 - Install PipeWire (Soloist has no ALSA output)
# Recommends are skipped: pipewire-pulse/pipewire-alsa would take over the audio system
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Install PipeWire"
apt -y install --no-install-recommends pipewire pipewire-bin wireplumber
if [ $? -ne 0 ]; then
	cancel_update "** Install failed"
fi
# Moode runs a private instance for Soloist. The per-user instances the packages
# enable would otherwise start at user login and take the audio device.
systemctl --global mask pipewire.socket pipewire.service wireplumber.service
if [ $? -ne 0 ]; then
	cancel_update "** Mask user units failed"
fi

# 3 - Download Spotify Soloist
case $(dpkg --print-architecture) in
	arm64) ARCH="arm64" ;;
	armhf) ARCH="arm32" ;;
	amd64) ARCH="x86_64" ;;
	*) cancel_update "** Unsupported architecture: $(dpkg --print-architecture)" ;;
esac
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Download Spotify Soloist ($ARCH)"
rm -rf /tmp/soloist && mkdir /tmp/soloist
wget -q "$SOLOIST_URL/soloist_release_$ARCH.tar.gz" -O /tmp/soloist/soloist.tar.gz
if [ $? -ne 0 ]; then
	cancel_update "** Download failed"
fi
tar -xzf /tmp/soloist/soloist.tar.gz -C /tmp/soloist
if [ $? -ne 0 ] || [ ! -f /tmp/soloist/soloist ]; then
	cancel_update "** Extract failed"
fi

# 4 - Install Spotify Soloist
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Install Spotify Soloist"
# Stop a running instance before replacing the binary
if [ "$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='soloistsvc'")" = "1" ]; then
	/var/www/util/restart-renderer.php --soloist --stop
fi
install -m 0755 /tmp/soloist/soloist /usr/local/bin/soloist
mkdir -p /usr/share/doc/soloist
cp /tmp/soloist/*.md /tmp/soloist/*.txt /usr/share/doc/soloist/ 2> /dev/null
rm -rf /tmp/soloist
VERSION=$(/usr/local/bin/soloist --version)
if [ $? -ne 0 ]; then
	cancel_update "** Install failed"
fi
message_log "** - $VERSION"
if [ "$(sqlite3 $SQLDB "SELECT value FROM cfg_system WHERE param='soloistsvc'")" = "1" ]; then
	/var/www/util/restart-renderer.php --soloist
fi
message_log "** - Done"

# 5 - Flush cached disk writes
STEP=$((STEP + 1))
message_log "** Step $STEP-$TOTAL_STEPS: Sync changes to disk"
message_log "Finish $PLUGIN_RELEASE_DATE update for $PLUGIN_NAME"
sync

cd ~/
