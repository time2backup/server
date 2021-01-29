#
#  time2backup init variables and configuration default values
#
#  This file is part of time2backup (https://time2backup.org)
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#

#
#  Global variables declaration
#

backup_date_format="[1-9][0-9]{3}-[0-1][0-9]-[0-3][0-9]-[0-2][0-9][0-5][0-9][0-5][0-9]"
current_timestamp=$(date +%s)


#
#  Default config
#

keep_limit=-1
clean_old_backups=true
clean_keep=0

hard_links=true

credentials=.access
