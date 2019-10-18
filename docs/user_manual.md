# time2backup server User Guide

## Table of contents
* [How to install time2backup server](#install)
* [How to use time2backup server](#usage)
* [Configuration and security](#config)
* [Troubleshootting](#troubleshootting)

---------------------------------------------------------------

<a name="install"></a>
## How to install time2backup
1. [Download time2backup server here](https://time2backup.org/download/server)
2. Uncompress archive where you want
3. Copy the file `config/time2backup-server.default.conf` to `config/time2backup-server.conf`
4. Edit the config file with at least the destination path


<a name="usage"></a>
## How to use time2backup server
In your time2backup client config file, add the server address to `destination` like this:
```
destination = ssh://user@myserver
```
If you have the `time2backup-server` command available on the server, that's all.
If you have put the server in a custom place, you have to specify the path of the script server like this:
```
t2bserver_path = /home/user/time2backup-server/t2b-server.sh
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


<a name="troubleshootting"></a>
## Troubleshootting
Some common bugs or issues are reported here.

In case of problem, please report your bugs here: https://github.com/time2backup/server/issues

### I have "internal errors", what should I do?
Enable the debug mode in your server configuration and inspect the log file.
You can also turn on the debug mode on your time2backup client.
