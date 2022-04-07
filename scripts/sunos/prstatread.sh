#!/bin/bash
#Version 3

usage() {
  SCRIPTNAME=$(basename $0)

cat << EOF
USAGE: $SCRIPTNAME reformat prstat -m output by adding timestamp to every line, calculate cpu usage for whole process (instead of mean thread usage) and optionally sort output
USAGE: $SCRIPTNAME [-n <column number>] | [-t] | [-u] | [-s] | [ -h ]
USAGE:     -t : sort every interval by total process cpu usage
USAGE:     -u : sort every interval by user space process cpu usage
USAGE:     -s : sort every interval by kernal space process cpu usage
USAGE:     -n <column number> : sort every interval by <column number>
USAGE:     -h : usage
USAGE:     There is no sorting by default.
USAGE:     Sorting can be really long process.
USAGE:     Header will be at the end of every interval if sorting is used
USAGE:     bzcat prstat-m_5_720.out.bz2 | $SCRIPTNAME -t | less
EOF
}

while getopts :hsutn: option
do
  case $option in
    n) COLUMN=$OPTARG ;;
    t) COLUMN=3 ;;
    u) COLUMN=4 ;;
    s) COLUMN=5 ;;
    h) usage ; exit 0 ;;
    *) echo "Invalid option found!" ; exit 1 ;;
  esac
done

SORTCMD="cat"
if [[ -n "$COLUMN" ]] ; then
  SORTCMD="sort -k 1,2 -k ${COLUMN}nr,${COLUMN}nr"
fi

nawk 'BEGIN \
{
   month["Jan"] = "01"
   month["Feb"] = "02"
   month["Mar"] = "03"
   month["Apr"] = "04"
   month["May"] = "05"
   month["Jun"] = "06"
   month["Jul"] = "07"
   month["Aug"] = "08"
   month["Sep"] = "09"
   month["Oct"] = "10"
   month["Nov"] = "11"
   month["Dec"] = "12"
}
{
    if($4~"[0-9]+:[0-9]+:[0-9]+"){DATE=sprintf("%04d-%02d-%02d %s", $NF, month[$2], $3, $4)}
    else if ($1 ~ "^[0-9]+$")
    {
        split($NF, ARR, "/")
        P_USR = $3 * ARR[2]
        P_SYS = $4 * ARR[2]
        P_TOT = P_USR + P_SYS
        printf ("%19s %7.2f %7.2f %7.2f %s\n", DATE, P_TOT, P_USR, P_SYS, $0)
    }
    else if ($1=="PID")
    {
        printf ("%19s %7s %7s %7s %s\n", DATE, "P_TOT", "P_USR", "P_SYS", $0)
    }
}' | $SORTCMD

