# time2backup server
A server part to allow time2backup clients save files on an ssh server.

## Download and install
1. Download the last release of time2backup server [here](https://github.com/time2backup/server/releases)
2. Uncompress archive where you want
3. Edit the config file
4. Edit the time2backup config file to point to the path


## Install from sources (developers edition)
Follow theses steps to install time2backup from last sources:
1. Clone this repository:
```bash
git clone https://github.com/time2backup/server.git
```
2. Go into the folder:
```bash
cd libbash
```
3. Initialize and update the libbash submodule:
```bash
git submodule update --init --recursive
```

To download the last updates, to:
```bash
git pull
cd inc/time2backup
git submodule update --init --recursive
```

## License
time2backup server is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for the full license text.

## Credits
Author: Jean Prunneaux https://jean.prunneaux.com

Source code: https://github.com/time2backup/server
