#
#  time2backup server commands
#
#  This file is part of time2backup server (https://github.com/time2backup/server)
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#

# Index
#
#   Global functions
#     print_error
#     internal_error
#     usage_error
#     log_entry
#     log_error
#     log_debug
#   Security functions
#     srv_save_token
#     srv_check_password
#     srv_check_token
#     srv_clean_tokens
#     srv_check_rsync_options
#   Backup steps
#     srv_clean_exit
#     srv_cancel_exit


#
#  Global functions
#

# Print an error to client
# Usage: print_error [--log] TEXT
print_error() {
	if [ "$1" == "--log" ] ; then
		shift
		log_error "$*"
	fi
	lb_error "t2b-server: $*"
}


# Print and return for an internal error
# Usage: internal_error [DETAILS]
internal_error() {
	print_error "internal server error"
	[ $# -gt 0 ] && log_error "$*"
	return 202
}


# Print an usage error
# Usage: usage_error [DETAILS]
usage_error() {
	print_error "bad command"
	[ $# -gt 0 ] && log_debug "bad command: $*"
	return 201
}


# Log info in server log
# Usage: log_entry TEXT
log_entry() {
	lb_log -d "$@"
}


# Log error in server log
# Usage: log_error TEXT
log_error() {
	log_entry -l ERROR -p "$@"
}


# Log debug in server log
# Usage: log_debug TEXT
log_debug() {
	lb_istrue $debug || return 0
	log_entry -l DEBUG -p "$@"
}


#
#  Security functions
#


# Create and secure credential file
# Usage: srv_save_token TOKEN [ARGS]
# Dependencies: $credentials
# Exit codes:
#   0: token saved
#   1: save error
srv_save_token() {

	# if file exists
	if [ -e "$credentials" ] ; then
		# test if is a file
		if ! [ -f "$credentials" ] ; then
			log_error "credential path is not a file"
			return 1
		fi

		# (re)secure file
		if [ "$lb_current_user" == root ] ; then
			chown root "$credentials"
			chmod 600 "$credentials"
		fi
	else
		# create & secure file
		touch "$credentials" && chmod 600 "$credentials"
		if [ $? != 0 ] ; then
			log_error "cannot create credential file"
			return 1
		fi
	fi

	# test if file is readable
	if ! [ -r "$credentials" ] ; then
		log_error "credential file is not readable"
		return 1
	fi

	# test if file is writable
	if ! [ -w "$credentials" ] ; then
		log_error "credential file is not writable"
		return 1
	fi

	# write token in file
	lb_join "	" "$(date +%s)" "$@" | tee -a "$credentials" &> /dev/null
	if [ $? != 0 ] ; then
		log_error "cannot write in credential file"
		return 1
	fi

	return 0
}


# Check client password
# Usage: srv_check_password [USER:]PASSWORD
srv_check_password() {
	# load authentication file if exists
	if [ -f config/auth.conf ] ; then

		# (re)secure auth file
		if [ "$lb_current_user" == root ] ; then
			chown root config/auth.conf
			chmod 600 config/auth.conf
		fi

		# if passwords are set, test it
		if [ -s config/auth.conf ] ; then
			if ! grep -q "^$1$" config/auth.conf ; then
				print_error "authentication failed"
				log_entry "Invalid password for $user from $ssh_info"
				return 1
			fi

			log_entry "Authentification succeeded for $user from $ssh_info"
			return 0
		fi
	fi
}


# Check client token
# Usage: srv_check_token TOKEN
# Dependencies: $credentials
srv_check_token() {

	# search token in credentials file
	if [ -n "$1" ] ; then

		local session
		session=$(grep -E "^[0-9]+	$1	" "$credentials")

		if [ $? == 0 ] ; then
			log_entry "Authentication by token successful for $user from $ssh_info"

			# get saved infos in credentials
			lb_split "	" "$session"
			token_infos=("${lb_split[@]}")
			return 0
		fi
	fi

	print_error "authentication failed"
	log_entry "Invalid token for $user from $ssh_info"
	return 1
}


# Clean old tokens
# Usage: srv_clean_tokens
# Dependencies: $credentials
srv_clean_tokens() {
	# default expiration time
	if ! lb_is_integer "$token_expiration" || [ $token_expiration -le 10 ] ; then
		token_expiration=300
	fi

	for t in $(cat "$credentials" 2> /dev/null | awk '{print $1}') ; do
		# remove tokens older than 5 minutes
		if lb_is_integer $t && [ $(($t + $token_expiration)) -lt "$(date +%s)" ] ; then
			lb_edit "/^$t/d" "$credentials" &> /dev/null
		fi
	done
}


# Check rsync options
# Usage: srv_check_rsync_options ARGS
srv_check_rsync_options() {
	lb_in_array --server "$@" || internal_error "rsync bad syntax: $*"
}


#
#  Backup steps
#

# Clean & exit
# Usage: srv_clean_exit [EXIT_CODE]
srv_clean_exit() {
	# set exit code if specified
	[ -n "$1" ] && lb_exitcode=$1

	clean_empty_backup -i $backup_date "$path_dest" &> /dev/null

	# delete backup lock
	release_lock &> /dev/null

	lb_exit
}


# Cancel exit
# Usage: srv_cancel_exit
srv_cancel_exit() {
	srv_clean_exit 217
}
