#!/bin/bash
#
#  time2backup server uninstall script
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#  Website: https://github.com/time2backup/server
#

if [ "$(whoami)" != root ] ; then
	echo "You must be root to uninstall time2backup server!"
	exit 1
fi

# delete global link
rm -f /usr/bin/time2backup-server
