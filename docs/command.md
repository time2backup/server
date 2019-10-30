# time2backup server command help

## Table of contents
* [Global command](#global)
* [prepare](#prepare)
* [backup](#backup)
* [restore](#restore)
* [history](#history)
* [rotate](#rotate)
* [rsync](#rsync)

---------------------------------------------------------------

## Global command

### Usage
```bash
time2backup-server [GLOBAL_OPTIONS] COMMAND [ARGS...]
```

### Global options
```
-p PASSWORD  Server password
-t TOKEN     Server token
```

---------------------------------------------------------------
<a name="prepare"></a>
## prepare
Prepare server negociation.

### Usage
```bash
time2backup-server [GLOBAL_OPTIONS] prepare COMMAND [ARGS...]
```

### Exit codes
- 0: time2backup server is ready
- 201: Usage error
- 202: Internal server error
- 203: Authentication failed
- 204: Destination not ready
- 205: Destination locked

---------------------------------------------------------------
<a name="backup"></a>
## backup
Perform a backup.

Note: this command is called after prepare negociation. You cannot call it manually.

### Usage
```bash
time2backup-server -t TOKEN backup [OPTIONS]
```

### Exit codes
- 0: Backup succeeded
- 201: Usage error
- 202: Internal server error
- 203: Authentication failed
- 204: Destination not ready
- 205: Destination locked
- 217: Backup cancelled
- [other]: see rsync exit codes

---------------------------------------------------------------
<a name="restore"></a>
## restore
Restore a file or directory.

Note: this command is called after prepare negociation. You cannot call it manually.

### Usage
```bash
time2backup-server -t TOKEN restore [OPTIONS]
```

### Exit codes
- 0: Restore succeeded
- 201: Usage error
- 202: Internal server error
- 203: Authentication failed
- 204: Destination not ready
- 205: Destination locked
- 217: Restore cancelled
- [other]: see rsync exit codes

---------------------------------------------------------------
<a name="history"></a>
## history
Displays backup history of a file or directory

### Usage
```bash
time2backup-server [GLOBAL_OPTIONS] history [OPTIONS] PATH
```

### Options
```
-a, --all  Print all versions, including duplicates
```

### Exit codes
- 0: History printed
- 201: Usage error
- 202: Internal server error
- 203: Authentication failed
- 204: Destination not ready

---------------------------------------------------------------
<a name="rotate"></a>
## rotate
Perform an rotate command.

### Usage
```bash
time2backup-server [GLOBAL_OPTIONS] rotate [LIMIT]
```

### Options
```
LIMIT        Set number of maximum backups to keep
```

### Exit codes
- 0: Rotate succeeded
- 201: Usage error
- 202: Internal server error
- 203: Authentication failed
- 204: Destination not ready
- 205: Rotate failed

---------------------------------------------------------------
<a name="rsync"></a>
## rsync
Perform an rsync server command.
Should be used when calling rsync by ssh from a client. Not locally.

### Usage
```bash
time2backup-server [GLOBAL_OPTIONS] rsync RSYNC_ARGS [RSYNC_ARGS...]
```

### Exit codes
- 0: rsync command succeeded
- 201: Usage error
- 202: Internal server error
- 203: Authentication failed
- [other]: see rsync exit codes
