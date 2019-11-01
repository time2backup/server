#!/bin/bash
#
#  time2backup server uninstall script
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#  Website: https://github.com/pruje/ssh-notify
#

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh - &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "internal error"
	exit 1
fi

if [ "$lb_current_user" != root ] ; then
	lb_error "You must be root to uninstall time2backup server"
	exit 1
fi

# delete global link
rm -f /usr/bin/time2backup-server

# delete sudoers file
rm -f /etc/sudoers.d/time2backup-server || lb_error "sudoers file cannot be deleted"
