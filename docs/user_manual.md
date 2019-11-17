# time2backup server User Guide

## Table of contents
* [How to install time2backup server](#install)
* [How to use time2backup server](#usage)
* [Configuration and security](#config)
* [Sudo mode](#sudo)
* [How to uninstall time2backup server](#uninstall)
* [Troubleshootting](#troubleshootting)

---------------------------------------------------------------

<a name="install"></a>
## How to install time2backup
### Docker image
[Follow instructions here](https://github.com/time2backup/docker-server)

### Debian/Ubuntu package
1. Download time2backup server [deb package here](https://time2backup.org/download/server/stable)
2. Install package: `dpkg -i time2backup-server-X.X.X.deb`
3. Add all authorized users to run time2backup server in the `t2b-server` group

### Manual install
1. Download [time2backup server here](https://time2backup.org/download/server/stable)
2. Uncompress archive where you want
3. Copy the file `config/time2backup-server.default.conf` to `config/time2backup-server.conf`
4. Edit the config file with at least the destination path
5. (optionnal) Run `install.sh` script and add all users who wants to run time2backup server in the `t2b-server` group

<a name="usage"></a>
## How to use time2backup server
In your time2backup client config file, add the server address to `destination` like this:
```
destination = ssh://user@myserver
```
If you have the `time2backup-server` command available on the server, that's all.
If you have put the server in a custom place, you have to specify the path of the script server like this:
```
t2bserver_path = /path/to/time2backup-server/t2b-server.sh
```

<a name="conf"></a>
## Configuration and security
To secure access to time2backup server, create the file `config/auth.conf` and add passwords
like the following examples:
```
user:password
```
Remember that this file is in plain text, and may be visible by time2backup users in their
client configuration file. Use random generated passwords, or long tokens.

To use time2backup server with sudo, you have to add the following line in `/etc/sudoers.d/time2backup-server`:
```
<USER> ALL = NOPASSWD:/usr/bin/time2backup-server
```

<a name="uninstall"></a>
## How to uninstall time2backup
### Docker image
[Follow instructions here](https://github.com/time2backup/docker-server)

### Debian/Ubuntu package
Uninstall package: `apt remove time2backup-server`

### Manual install
1. (optionnal) Run `uninstall.sh` script if you have run `install.sh` before.
2. Delete the time2backup-server folder

<a name="troubleshootting"></a>
## Troubleshootting
Some common bugs or issues are reported here.

In case of problem, please report your bugs here: https://github.com/time2backup/server/issues

### I have "internal errors", what should I do?
Enable the debug mode in your server configuration and inspect the log file.
You can also turn on the debug mode on your time2backup client.
