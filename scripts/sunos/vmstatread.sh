#!/bin/sh

echoerr() { echo "$@" 1>&2; }

isNumeric() {
  echo "$@" | egrep '^-*[0-9]+$' > /dev/null
}

fatalerror() {
  echoerr "ERROR: $@"
  usage
  exit 1
}

usage() {
  echoerr "USAGE: $SCRIPTNAME convert vmstat output to more human readable table offline (stdin batch) or online ($SCRIPTNAME will run vmstat internally)"
  echoerr "USAGE: $SCRIPTNAME [ -f ] [ -i <INTERVAL> ] [ -c <COUNT> ] [ -H <lines> ] [ -p ] [ -h ]"
  echoerr "USAGE:     -f : batch mode: read stdin for vmstat output (otherwise $SCRIPTNAME will run vmstat internally)"
  echoerr "USAGE:     -i <INTERVAL> : vmstat interval [default 1]"
  echoerr "USAGE:     -c <COUNT> : vmstat count [default is infinity], ignored in batch mode"
  echoerr "USAGE:     -H <lines> : show header every <lines> [default 10], 0 - show header only once"
  echoerr "USAGE:     -p : use vmstat -p"
  echoerr "USAGE:     -h : print help"
  echoerr "USAGE: example: $SCRIPTNAME -i 3"
  echoerr "USAGE: example: $SCRIPTNAME -i 3"
  echoerr "USAGE: example: gzcat 12.00.00.vmstat_10_360.out.gz | $SCRIPTNAME -f "
}

# Set LC_TIME to C
LC_TIME=C
export LC_TIME

SCRIPTNAME=`basename $0`
INTERVAL=1
READSTDIN=0
COUNT=0
PAGING=0
HEADER=10

while getopts :i:fc:pH:h option
do
  case $option in
    i) INTERVAL=$OPTARG ;;
    p) PAGING=1 ;;
    f) READSTDIN=1;;
    c) COUNT=$OPTARG;;
    H) HEADER=$OPTARG;;
    h) usage ; exit 0 ;;
    *) fatalerror "Invalid option found!" ;;
  esac
done

isNumeric $INTERVAL || fatalerror "INTERVAL must be numeric"
isNumeric $COUNT || fatalerror "COUNT must be numeric"

if [ $PAGING -eq 1 ] ; then
  VMOPT="$VMOPT -p "
fi

if [ $READSTDIN -eq 0 ] ; then
  SOLV=`uname -r | cut -d. -f2`
  if [ $SOLV -gt 10 ] ; then
    TIMEOPT="-T d"
  else
    TIMEOPT=""
  fi
    
  if [ $COUNT -gt 0 ] ; then
    statcount=`echo $COUNT + 1 | bc`
    STATCMD="vmstat $TIMEOPT $VMOPT $INTERVAL $statcount"
  else
    STATCMD="vmstat $TIMEOPT $VMOPT $INTERVAL"
  fi
else
  STATCMD="cat -u"
fi

$STATCMD | nawk -v HEADER=$HEADER -v PAGING=$PAGING '
BEGIN{

  PRINTNUM=0

  GIBI=1048576
  MIBI=1024

}
{
  if($1=="memory"){PAGING=1}
  if($4~"[0-9]+:[0-9]+:[0-9]+"){
    TIME=$4
  }else if($1~"[0-9]+"){

    if (PAGING==1){
      if(PRINTNUM>0){
        if(PRINTNUM==1 || HEADER!=0 && PRINTNUM%HEADER==0){ 
          printf("%11s %11s %10s %8s %8s %8s %11s %10s %8s %8s %10s %8s %8s %10s %8s %8s %12s\n", "vswap_GB", "free_GB", "recl_MB/s", "mf_MB/s", "fr_MB/s", "def_MB/s", "scan_MB/s", "epi_MB/s", "epo_MB/s", "epf_MB/s", "api_MB/s", "apo_MB/s", "apf_MB/s", "fpi_MB/s", "fpo_MB/s", "fpf_MB/s", "TIME")
        }
        printf("%11.2f %11.2f %10.2f %8.2f %8.2f %8.2f %11.2f %10.2f %8.2f %8.2f %10.2f %8.2f %8.2f %10.2f %8.2f %8.2f %12s\n", $1/GIBI, $2/GIBI, $3/MIBI, $4/MIBI, $5/MIBI, $6/MIBI, $7/MIBI, $8/MIBI, $9/MIBI, $10/MIBI, $11/MIBI, $12/MIBI, $13/MIBI, $14/MIBI, $15/MIBI, $16/MIBI, TIME)
      }
    }
    else
    {
      if(PRINTNUM>0){
        if(PRINTNUM==1 || HEADER!=0 && PRINTNUM%HEADER==0){
          printf("%5s %5s %5s %11s %11s %10s %8s %10s %8s %10s %8s %9s %11s %9s %9s %8s %5s %5s %12s\n", "run", "block", "wait", "vswap_GB", "free_GB", "recl_MB/s", "mf_MB/s", "pi_MB/s", "po_MB/s", "fr_MB/s", "def_MB/s", "scan_MB/s", "inter/s", "syscal/s", "csw/s", "user%", "sys%", "%idle", "TIME")
        }
        printf("%5d %5d %5d %11.2f %11.2f %10.2f %8.2f %10.2f %8.2f %10.2f %8.2f %9.2f %11d %9d %9d %8d %5d %5d %12s\n", $1, $2, $3, $4/GIBI, $5/GIBI, $6/MIBI, $7/MIBI, $8/MIBI, $9/MIBI, $10/MIBI, $11/MIBI, $12/MIBI, $17, $18, $19, $20, $21, $22, TIME)
      }
    }
    PRINTNUM++
  }
}'

