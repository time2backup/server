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
#   Commands
#     t2bs_prepare
#     t2bs_backup
#     t2bs_restore
#     t2bs_history
#     t2bs_rotate
#     t2bs_rsync


# Initialize connection and prepare for backup process
# Usage: t2bs_prepare COMMAND [OPTIONS]
t2bs_prepare() {

	local cmd=$1 resume=false force_unlock=false args=()
	shift

	# prepare destination
	if ! prepare_destination &> /dev/null ; then
		print_error --log "destination not writable"
		return 204
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
				usage_error "prepare backup: backup date format not conform: $backup_date"
				return 201
			fi

			src=$*

			# test if path is defined
			if [ -z "$src" ] ; then
				usage_error "prepare restore: source is missing"
				return 201
			fi

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
					return 205
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

						# check status of the last backup
						if ! check_infofile_rsync_result $b "$src" ; then
							args+=(resume=true)
							log_debug "prepare: next backup will be resumed from $b"
							first=false
							continue
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

			backup_date=$1
			shift

			# test backup date format
			if ! check_backup_date "$backup_date" ; then
				usage_error "prepare restore: backup date format not conform: $backup_date"
				return 201
			fi

			# test if path is defined
			if [ -z "$*" ] ; then
				usage_error "prepare restore: source is missing"
				return 201
			fi

			debug "search versions for $*"

			# get backup versions of this file
			file_history=($(get_backup_history "$*"))

			# recheck if date is still there
			local found=false
			if [ ${#file_history[@]} -gt 0 ] ; then
				lb_in_array "$backup_date" "${file_history[@]}" && found=true
			fi

			if ! $found ; then
				print_error "Backup version has vanished! Please retry later"
				return 202
			fi

			# test if latest is a directory
			local backup_path=$(get_backup_path "$*")

			echo "rsync_result = $(get_infofile_value "$destination/$backup_date/backup.info" "$*" rsync_result)"

			[ -n "$backup_path" ] && [ -d "$destination/$backup_date/$backup_path" ] && \
				echo "src_type = directory"

			# check if a current backup is running
			current_lock -q && echo "status = running"

			# forward args to write in credentials file
			args=(date=$backup_date)
			;;

		*)
			# bad command
			usage_error "bad command: $*"
			return 201
			;;
	esac

	# generate token
	token=$(lb_generate_password 32 | tr -cd '[:alnum:]')
	token=${token:0:16}

	# write token in credentials file
	if ! srv_save_token "$token" "${args[@]}" ; then
		internal_error "write token failed"
		return 202
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
				if [ -z "$2" ] ; then
					usage_error "backup: --t2b-rotate argument missing"
					return 201
				fi
				keep_limit=$2
				shift
				;;

			--t2b-keep)
				if ! lb_is_integer $2 ; then
					usage_error "backup: --t2b-keep argument not conform: $2"
					return 201
				fi
				clean_keep=$2
				shift
				;;

			--t2b-trash)
				trash_mode=true
				;;

			*)
				break
				;;
		esac
		shift # load next argument
	done

	# check rsync syntax
	srv_check_rsync_options "$@" || return 201

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
		return 202
	fi

	# check lock file
	lock_file=$(current_lock -f)
	if [ -n "$lock_file" ] ; then
		# lock file exists: compare token
		if [ "$(lb_get_config "$lock_file" token)" != "$token" ] ; then
			print_error "destination locked"
			log_error "token provided valid, but different from lock file for user $user from $ssh_info"
			return 205
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

	# resume: search the last backup
	if lb_istrue $resume ; then
		local b history=($(get_backup_history -n -a "$src")) resume_date

		for b in "${history[@]}" ; do
			# mirror mode: take the latest
			if [ $keep_limit == 0 ] ; then
				resume_date=$b
				break
			fi

			# ignore the last clean backup
			if [ "$b" != "$last_clean_backup" ] ; then
				resume_date=$b
				break
			fi
		done
	fi

	# create backup folder
	mkdir -p "$destination/$backup_date/$path_dest"
	if [ $? != 0 ] ; then
		internal_error "cannot create backup destination"
		srv_clean_exit 204
	fi

	# resume from old backup
	if lb_istrue $resume ; then
		log_debug "resume backup: move backup from $resume_date to $backup_date for $path_dest"

		# clean current backup dir and move old in it
		[ -n "$resume_date" ] && \
		rmdir "$destination/$backup_date/$path_dest" && \
		move_backup $resume_date $backup_date "$path_dest" &> /dev/null
		if [ $? == 0 ] ; then
			# delete old infofile
			clean_empty_backup -i $resume_date &> /dev/null
		else
			internal_error "resume failed"
			srv_clean_exit 202
		fi
	else
		# no resume

		# if last backup defined, prepare versionning
		if [ -n "$last_clean_backup" ] ; then
			# if  mirror mode or no hard links, move destination
			if [ $keep_limit == 0 ] || ! lb_istrue $hard_links ; then

				log_debug "move backup from $last_clean_backup to $backup_date for $path_dest"

				# move old backup as current backup and update latest link
				rmdir "$destination/$backup_date/$path_dest" && \
				move_backup $last_clean_backup $backup_date "$path_dest" &> /dev/null && \
				create_latest_link &> /dev/null

				if [ $? != 0 ] ; then
					print_error --log "failed to prepare destination"
					srv_clean_exit 202
				fi
			fi
		fi
	fi

	# If keep_limit = 0 (mirror mode), we don't need to use versionning.
	# If no hard links, do not create trash
	if [ -n "$last_clean_backup" ] && [ $keep_limit != 0 ] && ! lb_istrue $hard_links; then
		log_debug "create trash: $last_clean_backup"

		mkdir -p "$destination/$last_clean_backup/$path_dest" &> /dev/null
		if [ $? != 0 ] ; then
			print_error --log "failed to prepare trash"
			srv_clean_exit 202
		fi
	fi

	# trash mode
	if lb_istrue $trash_mode ; then
		# create trash
		mkdir -p "$destination/trash/$path_dest" &> /dev/null
		if [ $? != 0 ] ; then
			print_error --log "failed to prepare trash"
			srv_clean_exit 202
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
# Usage: t2bs_restore [OPTIONS]
t2bs_restore() {

	local no_lock=false

	# get command options
	while [ $# -gt 0 ] ; do
		case $1 in
			--t2b-nolock)
				no_lock=true
				;;

			*)
				break
				;;
		esac
		shift # load next argument
	done

	# get infos from token
	for i in "${token_infos[@]}" ; do
		case $(echo "$i" | cut -d= -f1) in
			date)
				backup_date=$(echo "$i" | cut -d= -f2-)
				;;
		esac
	done

	# verify if required variables are there
	if [ -z "$backup_date" ] ; then
		internal_error "failed to get infos from token"
		return 202
	fi

	# check rsync syntax
	srv_check_rsync_options "$@" || return 201

	# check lock
	if ! $no_lock ; then
		if current_lock -q ; then
			print_error "destination locked"
			return 205
		fi
	fi

	log_debug "current restore from $backup_date"

	# catch term signals
	catch_kills srv_cancel_exit

	# run rsync command
	"$rsync_path" "$@"
	res=$?

	log_debug "rsync result: $res"

	srv_clean_exit
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
	[ -z "$*" ] && return 201

	# test backup destination
	if ! prepare_destination &> /dev/null ; then
		print_error "destination not ready"
		return 204
	fi

	# get backup versions of this file
	file_history=($(get_backup_history "${history_opts[@]}" "$*"))

	# print backup versions
	[ ${#file_history[@]} == 0 ] || echo ${file_history[*]}
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
		return 204
	fi

	local keep=$keep_limit

	# test if number or period has a valid syntax
	if [ $# -gt 0 ] ; then
		if lb_is_integer "$1" ; then
			if [ $1 -lt 0 ] ; then
				print_help
				return 201
			fi
		else
			if ! test_period "$1" ; then
				print_help
				return 201
			fi
		fi

		keep=$1
	fi

	# prepare backup destination
	prepare_destination || return 204

	# free space mode
	if $free_space ; then
		free_space $free_size
	else
		# normal mode
		rotate_backups $keep || return 205
	fi
}


# Run a simple rsync command
# Usage: t2bs_rsync RSYNC_ARGS
t2bs_rsync() {
	# check rsync options
	srv_check_rsync_options "$@" || return 201

	# run rsync command
	"$rsync_path" "$@"
}
