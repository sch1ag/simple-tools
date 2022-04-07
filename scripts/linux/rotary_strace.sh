#!/bin/bash
#Version 3

SCRIPTNAME=`basename $0`

echoerr() { echo "$@" 1>&2; }

fatalerror() {
  echoerr "ERROR: $@"
  exit 1
}

warning() {
  echoerr "WARNING: $@"
}

info() {
  echoerr "INFO: $@"
}

usage() {
  echoerr "USAGE: $SCRIPTNAME run strace on process with pid <PID> for <duration> of seconds <count> times or until interrupt/process end."
  echoerr "USAGE: $SCRIPTNAME -p <PID> [-d <dir>] [-D <duration>] | -h"
  echoerr "USAGE:     -p <PID>      : process to trace"
  echoerr "USAGE:     -d <dir>      : save strace in <dir> [default=/var/tmp/strace]"
  echoerr "USAGE:     -D <duration> : time period in one file [default=60]"
  echoerr "USAGE:     -c <count>    : how many times run strace [default=infinity]"
  echoerr "USAGE:     -h            : show help"
}

stop_trace()
{
  rm -f $FFLAG
  [[ -n $PID_TMOUT ]] && kill -INT $PID_TMOUT
}

OUTDIR=/var/tmp/strace
DURATION=600
COUNT=-1
while getopts :p:d:D:c:h option
do
  case $option in
    p) TPID=$OPTARG ;;
    d) OUTDIR=$OPTARG ;;
    D) DURATION=$OPTARG ;;
    c) COUNT=$OPTARG ;;
    h) usage ; exit 0 ;;
    *) fatalerror "Invalid option found!" ;;
  esac
done

[[ -z "$TPID" ]] && fatalerror "PID is not defined."

[[ -d $OUTDIR ]] || fatalerror "$OUTDIR does not exist. Create dir or set another dir using -D flag."

ORIG_TCMDNAME=`ps -h -o comm -p $TPID`
TCMDNAME=$ORIG_TCMDNAME
info "Process to trace: ${TPID} $TCMDNAME"

FFLAG=/tmp/stracerotate.${TPID}
touch $FFLAG

info "Ctrl-c to stop trace"

trap stop_trace SIGINT

while [[ -n "$TCMDNAME" && "$TCMDNAME" == "$ORIG_TCMDNAME" && -f $FFLAG && COUNT -ne 0 ]] ; do
  OUTFILE=${OUTDIR}/`date +%Y.%m.%d-%H.%M.%S`.${TCMDNAME}.${TPID}.strace
  info "Collecting strace to $OUTFILE"
  timeout -s INT $DURATION strace -o ${OUTFILE} -yy -Tttfp ${TPID} &
  PID_TMOUT=$!
  wait
  PID_TMOUT=""
  [[ -n "${OUTFILE}" && -f ${OUTFILE} ]] && bzip2 ${OUTFILE} &
  TCMDNAME=`ps -h -o comm -q $TPID`
  ((COUNT--))
done

rm -f $FFLAG

