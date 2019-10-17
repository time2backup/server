#
#  time2backup server commands
#
#  This file is part of time2backup server (https://github.com/time2backup/server)
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#

# Index of functions
#
#   t2bs_prepare
#   t2bs_backup
#   t2bs_restore
#   t2bs_history
#   t2bs_rotate
#   t2bs_rsync


# Initialize connection and prepare for backup process
# Usage: t2bs_prepare COMMAND [OPTIONS]
t2bs_prepare() {

	local cmd=$1 resume=false force_unlock=false args=()
	shift

	# prepare destination
	if ! prepare_destination &> /dev/null ; then
		print_error --log "destination not writable"
		return 206
	fi

	# prepare server response
	echo "[server]"

	case $cmd in
		backup)
			# Usage: backup [OPTIONS] DATE PATH
			while [ $# -gt 0 ] ; do
				case $1 in
					--resume)
						resume=true
						;;
					--unlock)
						force_unlock=true
						;;
					*)
						break
						;;
				esac
				shift
			done

			backup_date=$1
			shift

			# test backup date format
			if ! check_backup_date "$backup_date" ; then
				usage_error "prepare backup: backup date format not conform: $1"
				return $?
			fi

			src=$*

			# test if a backup is running
			if current_lock -q ; then
				# force mode: delete old lock
				if $force_unlock ; then
					if ! release_lock -f ; then
						print_error --log "failed to release lock"
						return 202
					fi
				else
					print_error "backup is already running"
					return 208
				fi
			fi

			# forward args to write in credentials file
			args=(date="$backup_date" src="$src")
			$resume && args+=(resume=true)

			# get latest backup for source
			local first=true b history=($(get_backup_history -a -n "$src"))
			for b in "${history[@]}" ; do
				# resume from last backup: skip latest backup
				if $first ; then
					if $resume ; then
						first=false
						continue
					else
						# search if last backup needs to be resumed

						# check status of the last backup (only if infofile exists)
						if lb_istrue $hard_links && [ -f "$destination/$b/backup.info" ] ; then
							# if last backup failed or was cancelled, resume
							rsync_result $(get_infofile_value "$destination/$b/backup.info" "$src" rsync_result)
							if [ $? == 2 ] ; then
								args+=(resume=true)
								log_debug "prepare: next backup will be resumed from $b"
								first=false
								continue
							fi
						fi
					fi
				fi

				# get trash if different from actual date
				if [ "$b" != "$1" ] ; then
					echo "trash = $b"
					args+=(trash="$b")
					break
				fi

				first=false
			done
			;;

		restore)
			# Usage: restore DATE PATH
			usage_error "restore command not yet available"
			return $?

			backup_date=$1
			shift

			# test backup date format
			if ! check_backup_date "$backup_date" && [ "$backup_date" != latest ] ; then
				usage_error "prepare restore: backup date format not conform: $1"
				return $?
			fi

			src=$*
			;;

		*)
			# bad command
			usage_error "bad command: $*"
			return $?
			;;
	esac

	# generate token
	token=$(lb_generate_password 32 | tr -cd '[:alnum:]')
	token=${token:0:16}

	# write token in credentials file
	if ! srv_save_token "$token" "${args[@]}" ; then
		internal_error "write token failed"
		return $?
	fi

	# output infos
	echo "version = $version"
	echo "token = $token"
	echo "destination = \"$destination\""
	echo "hard_links = $hard_links"
}


# Perform backup
# Usage: t2bs_backup [OPTIONS] RSYNC_OPTIONS
t2bs_backup() {

	# get command options
	while [ $# -gt 0 ] ; do
		case $1 in
			--t2b-rotate)
				[ -n "$2" ] || return 1
				keep_limit=$2
				shift
				;;

			--t2b-keep)
				lb_is_integer $2 || return 1
				clean_keep=$2
				shift
				;;

			*)
				break
				;;
		esac
		shift # load next argument
	done

	# check rsync syntax
	srv_check_rsync_options "$@" || return $?

	# get infos from token
	for i in "${token_infos[@]}" ; do
		case $(echo "$i" | cut -d= -f1) in
			date)
				backup_date=$(echo "$i" | cut -d= -f2-)
				;;
			src)
				src=$(echo "$i" | cut -d= -f2-)
				;;
			trash)
				last_clean_backup=$(echo "$i" | cut -d= -f2-)
				;;
			resume)
				resume=$(echo "$i" | cut -d= -f2-)
				;;
		esac
	done

	# verify if required variables are there
	if [ -z "$backup_date" ] || [ -z "$src" ] ; then
		internal_error "failed to get infos from token"
		return $?
	fi

	# check lock file
	lock_file=$(current_lock -f)
	if [ -n "$lock_file" ] ; then
		# lock file exists: compare token
		if [ "$(lb_get_config "$lock_file" token)" != "$token" ] ; then
			print_error "current backup already running"
			log_error "token provided valid, but different from lock file for user $user from $ssh_info"
			return 208
		fi
	else
		# create lock
		create_lock &> /dev/null && \
		lb_set_config "$(current_lock -f)" token "$token"
	fi

	# catch term signals
	catch_kills srv_cancel_exit

	create_infofile

	# get source path
	path_dest=$(get_backup_path "$src")

	# write new source section to info file
	lb_set_config -s src1 "$infofile" path "$src"
	lb_set_config -s src1 "$infofile" rsync_result -1
	lb_set_config -s src1 "$infofile" trash $last_clean_backup

	# set final destination with is a representation of the system tree
	# e.g. /path/to/my/backups/mypc/2016-12-31-2359/files/home/user/tobackup
	finaldest=$destination/$backup_date/$path_dest

	# create parent destination folder
	mkdir -p "$(dirname "$finaldest")"
	if [ $? != 0 ] ; then
		internal_error "write error on destination"
		srv_clean_exit $?
	fi

	# resume: search the last backup
	if lb_istrue $resume && lb_istrue $hard_links ; then
		local b history=($(get_backup_history -n -a "$src")) resume_date

		for b in "${history[@]}" ; do
			case $b in
				"$backup_date"|"$last_clean_backup")
					# ignore
					;;
				*)
					resume_date=$b
					;;
			esac
		done

		log_debug "resume backup: move backup from $resume_date to $backup_date for $path_dest"

		[ -n "$resume_date" ] && \
		move_backup $resume_date $backup_date "$path_dest" &> /dev/null
		if [ $? == 0 ] ; then
			# delete old infofile
			clean_empty_backup -i $resume_date &> /dev/null
		else
			internal_error "resume failed"
			srv_clean_exit $?
		fi
	fi

	# default behaviour: mkdir
	mv_dest=false

	# if mirror mode or trash mode, move destination
	if [ -n "$last_clean_backup" ] ; then
		if [ $keep_limit == 0 ] || ! lb_istrue $hard_links ; then
			mv_dest=true
		fi
	fi

	if $mv_dest ; then
		# move old backup as current backup (and latest link)
		log_debug "move backup from $last_clean_backup to $backup_date for $path_dest"

		move_backup $last_clean_backup $backup_date "$path_dest" &> /dev/null && \
		create_latest_link &> /dev/null
	else
		# create destination
		log_debug "create final destination: $finaldest"
		mkdir -p "$finaldest" &> /dev/null
	fi

	# if mkdir (hard links mode) or mv (trash mode) failed,
	if [ $? != 0 ] ; then
		print_error --log "failed to prepare destination"
		srv_clean_exit 206
	fi

	# If keep_limit = 0 (mirror mode), we don't need to use versionning.
	# If first backup, no need to add incremental options.
	if ! lb_istrue $hard_links && [ $keep_limit != 0 ] && [ -n "$last_clean_backup" ] ; then
		log_debug "create trash: $last_clean_backup"

		# create trash
		mkdir -p "$destination/$last_clean_backup/$path_dest" &> /dev/null
		if [ $? != 0 ] ; then
			print_error --log "failed to prepare destination"
			srv_clean_exit 206
		fi
	fi

	# run rsync command
	"$rsync_path" "$@"
	res=$?

	log_debug "rsync result: $res"

	# save rsync result in info file and delete temporary file
	lb_set_config -s src1 "$infofile" rsync_result $res

	# forward exit code
	[ $res != 0 ] && lb_exitcode=$res

	# if cancel, do not consider as cancelled backup
	catch_kills srv_clean_exit

	# clean empty trash and infofile
	clean_empty_backup -i $last_clean_backup "$path_dest" &> /dev/null

	# clean directory
	clean_empty_backup -i $backup_date "$path_dest" &> /dev/null

	if rsync_result $res ; then
		# create latest backup directory link
		create_latest_link &> /dev/null

		# rotate backups
		rotate_backups &> /dev/null
	fi

	srv_clean_exit
}


# Restore files
# Usage: t2bs_restore [OPTIONS] PATH
t2bs_restore() {
	lb_error TODO
	return 201
}


# Get backup history
# Usage: t2bs_history [OPTIONS] PATH
t2bs_history() {

	# default option values
	local history_opts=() file

	# get options
	while [ $# -gt 0 ] ; do
		case $1 in
			-a|--all)
				history_opts=(-a)
				;;
			*)
				break
				;;
		esac
		shift # load next argument
	done

	# missing arguments
	[ -z "$*" ] && return 1

	# test backup destination
	if ! prepare_destination &> /dev/null ; then
		print_error "destination not ready"
		return 4
	fi

	# get backup versions of this file
	file_history=($(get_backup_history "${history_opts[@]}" "$*"))

	# no backup found
	[ ${#file_history[@]} == 0 ] && return 0

	# print backup versions
	for b in "${file_history[@]}" ; do
		# print the version
		echo "$b"
	done
}


# Rotate
# Usage: t2bs_rotate [OPTIONS] [LIMIT]
t2bs_rotate() {

	local free_space=false

	# get options
	while [ $# -gt 0 ] ; do
		case $1 in
			--free)
				free_space=true
				;;
			*)
				break
				;;
		esac
		shift # load next argument
	done

	# test backup destination
	if ! prepare_destination &> /dev/null ; then
		print_error "destination not ready"
		return 4
	fi

	local keep=$keep_limit

	# test if number or period has a valid syntax
	if [ $# -gt 0 ] ; then
		if lb_is_integer "$1" ; then
			if [ $1 -lt 0 ] ; then
				print_help
				return 1
			fi
		else
			if ! test_period "$1" ; then
				print_help
				return 2
			fi
		fi

		keep=$1
	fi

	# prepare backup destination
	prepare_destination || return 4

	# free space mode
	if $free_space ; then
		free_space $free_size
	else
		# normal mode
		rotate_backups $keep || return 5
	fi
}


# Run a simple rsync command
# Usage: t2bs_rsync RSYNC_ARGS
t2bs_rsync() {
	# check rsync options
	srv_check_rsync_options "$@" || return $?

	# run rsync command
	"$rsync_path" "$@"
}
