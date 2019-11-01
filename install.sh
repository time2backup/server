#!/bin/bash
#
#  time2backup server install script
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#  Website: https://github.com/time2backup/server
#

# current directory
curdir=$(dirname "$0")

# load libbash
source "$curdir"/libbash/libbash.sh - &> /dev/null
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

# create t2b group if not exists
if ! grep -q '^t2b-server:' /etc/group ; then
	addgroup t2b-server
	if [ $? != 0 ] ; then
		lb_error "Cannot create group t2b-server"
		exit 1
	fi
fi

# secure current directory permissions
chmod -R 750 "$curdir"
chmod -x "$curdir"/*.md "$curdir"/config/* "$curdir"/docs/* "$curdir"/inc/* \
         "$curdir"/libbash/*.* "$curdir"/libbash/*/*
touch "$curdir"/.access && chmod 660 "$curdir"/.access
touch "$curdir"/config/auth.conf && chmod 640 "$curdir"/config/auth.conf
touch "$curdir"/server.log && chmod 660 "$curdir"/server.log

[ -f "$curdir"/config/time2backup-server.conf ] || cp "$curdir"/config/time2backup-server.example.conf "$curdir"/config/time2backup-server.conf
chmod 640 "$curdir"/config/time2backup-server.conf

chown -R root:t2b-server "$curdir"
