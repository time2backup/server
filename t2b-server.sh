#!/bin/bash
#
#  time2backup server
#
#  Website: https://github.com/time2backup/server
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#
#  Version 1.0.0-beta.1 (2019-10-17)
#

declare -r version=1.0.0-beta.1


#
#  Initialization
#

# get real path of the script
if [ "$(uname)" == Darwin ] ; then
	# macOS which does not support readlink -f option
	current_script=$(perl -e 'use Cwd "abs_path";print abs_path(shift)' "$0")
else
	current_script=$(readlink -f "$0")
fi

# get directory of the current script
script_directory=$(dirname "$current_script")

cd "$script_directory"
if [ $? != 0 ] ; then
	echo >&2 "t2b-server: internal server error"
	exit 202
fi

# load libbash with GUI (because of t2b functions using it)
source libbash/libbash.sh -g 2> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "t2b-server: internal server error"
	exit 202
fi

# force libbash GUI to console mode
lbg_set_gui console
notifications=false

# disable debug messages
lb_set_log_level INFO
lb_set_display_level INFO

# change current script name
lb_current_script_name=time2backup-server


#
#  Functions
#

# load init config
source inc/init.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "t2b-server: internal server error"
	exit 202
fi

# load time2backup functions
source inc/functions.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "t2b-server: internal server error"
	exit 202
fi

# load server functions
source inc/functions-server.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "t2b-server: internal server error"
	exit 202
fi

# load commands
source inc/commands.sh > /dev/null
if [ $? != 0 ] ; then
	lb_error "t2b-server: internal server error"
	exit 202
fi


#
#  Main program
#

# load the default config
if ! lb_import_config config/time2backup-server.default.conf ; then
	print_error --log "error in config"
	exit 202
fi

# load config if exists
if [ -f config/time2backup-server.conf ] ; then
	if ! lb_import_config config/time2backup-server.conf ; then
		print_error --log "error in config"
		exit 202
	fi
fi

# get current context info
user=$lb_current_user
ssh_info=$SSH_CLIENT

# rerun in sudo mode
if lb_istrue $sudo_mode && [ $user != root ] ; then
	sudo "$0" -u $user -s "$ssh_info" "$@"
	exit $?
fi

# get global options
while [ $# -gt 0 ] ; do
	case $1 in
		-p)
			# password
			if [ -z "$2" ] ; then
				usage_error "global -p: missing password"
				exit $?
			fi
			client_password=$2
			shift
			;;

		-t)
			# token
			if [ -z "$2" ] ; then
				usage_error "global -t: missing token"
				exit $?
			fi
			token=$2
			shift
			;;

		-s)
			# ssh infos
			if [ -z "$2" ] ; then
				usage_error "global -s: missing ssh info"
				exit $?
			fi

			# option allowed only for root user
			[ "$lb_current_user" == root ] && ssh_info=$2
			shift
			;;

		-u)
			# user
			if [ -z "$2" ] ; then
				usage_error "global -u: missing user"
				exit $?
			fi

			# option allowed only for root user
			[ "$lb_current_user" == root ] && user=$2
			shift
			;;

		*)
			break
			;;
	esac
	shift # load next argument
done

# get main command
if [ $# == 0 ] ; then
	usage_error "no main command"
	exit $?
fi

command=$1
shift

# test config
if [ -z "$destination" ] ; then
	print_error --log "error in config"
	exit 202
fi

# test hard links compatibility
if ! lb_istrue $force_hard_links ; then
	test_hardlinks "$destination" || hard_links=false
fi

# reset default rsync path
[ -z "$rsync_path" ] && rsync_path=rsync

# set log file
[ -z "$logfile" ] && logfile=t2b.log
lb_set_logfile -a "$logfile"

# clean old tokens
srv_clean_tokens

# command operations
case $command in
	prepare|history|rotate|rsync)
		# check password
		srv_check_password "$client_password" || exit 204
		;;

	backup|restore)
		# check token
		srv_check_token "$token" || exit 204
		;;

	*)
		# bad command
		usage_error "$*"
		exit $?
		;;
esac

# run command
t2bs_$command "$@"
exit $?
