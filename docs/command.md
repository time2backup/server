# time2backup server command help

## Table of contents
* [Global command](#global)
* [prepare](#prepare)
* [backup](#backup)
* [restore](#restore)
* [history](#history)
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
- 0: rsync OK
- 1: Usage error
- 201: Usage error
- 202: Internal server error
- 204: Authentication failed
- 205: rsync command not ok
- 206: destination not reachable
- 208: current backup running
- other: see rsync exit codes

---------------------------------------------------------------
<a name="backup"></a>
## backup
Perform a backup.

Note: this command is called by time2backup script. You cannot call it manually.

### Usage
```bash
time2backup-server -t TOKEN backup [OPTIONS]
```

### Exit codes
- 0: Backup successfully completed
- 1: Usage error

---------------------------------------------------------------
<a name="restore"></a>
## restore
Restore a file or directory.

Note: this command is called by time2backup script. You cannot call it manually.

### Usage
```bash
time2backup-server -t TOKEN restore [OPTIONS]
```

### Exit codes
- 0: File(s) restored
- 1: Usage error

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
- 1: Usage error
- 3: Config error
- 4: Backup device is not reachable
- 5: No backup found for the path

---------------------------------------------------------------
<a name="rsync"></a>
## rsync
Perform an rsync command.

### Usage
```bash
time2backup-server [GLOBAL_OPTIONS] rsync RSYNC_ARGS [RSYNC_ARGS...]
```

### Exit codes
- 0: rsync OK
- 201: Usage error
- 202: Internal server error
- 203: Config error
- 204: Bad password
- 205: rsync command not ok
- 206: destination not permitted/available
- other: see rsync exit codes
