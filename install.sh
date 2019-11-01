#!/bin/bash
#
#  time2backup server install script
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#  Website: https://github.com/time2backup/server
#

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh - &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "internal error"
	exit 1
fi

if [ "$lb_current_user" != root ] ; then
	lb_error "You must be root to install time2backup server"
	exit 1
fi

# create global link
ln -sf "$lb_current_script_directory/t2b-server.sh" /usr/bin/time2backup-server
if [ $? != 0 ] ; then
	lb_error "Cannot create global link"
	exit 1
fi

# if no force mode
if [ "$1" != "-f" ] ; then
	lb_yesno "Do you want to make sudo mode be enabled on your system?" || return 0
fi

# create t2b group
addgroup t2b-server
if [ $? != 0 ] ; then
	lb_error "Cannot create group t2b-server"
	exit 1
fi

# create sudoers file
mkdir -p /etc/sudoers.d && touch /etc/sudoers.d/time2backup-server && \
chown root:root /etc/sudoers.d/time2backup-server && chmod 640 /etc/sudoers.d/time2backup-server && \
echo "%t2b-server ALL = NOPASSWD:/usr/bin/time2backup-server" > /etc/sudoers.d/time2backup-server
if [ $? != 0 ] ; then
	lb_error "sudoers file cannot be modified"
	exit 1
fi

echo "[INFO] Add all authorized users in the 't2b-server' group if you want to enable sudo mode."
