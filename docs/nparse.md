## scripts/aix/nparse.sh

Script designed to parse nmon files and create number of output csv and txt files

~~~
# cd /perf/nmon/
# /perf/scripts/nparse.sh -h
USAGE: nparse.sh reads nmon from stdin and exports most usefull pages as number of csv files in the output directory (will be created in CWD)
USAGE: bunzip2 -c host_date_time.nmon.bz2 | nparse.sh [-d <delimiter>] [-t] [-o <dir>] [-h]
USAGE: -d delim : delimiter (default is comma)
USAGE: -o dir   : name of output dir (ncsv by default)
USAGE: -t       : add top page <- ssslslslosloslowslow
USAGE: -h       : print help and exit
#
~~~

[statplot’ом](https://github.com/sch1ag/statplot) can be used to draw graphs based on csv

