#!/bin/bash
PROCPID=$1

if [[ -z "$PROCPID" ]] ; then
  echo "Usage: $0 PID" ;
  exit 1 ;
fi

PROCPIDHEX=`echo -e "obase=16 \n $PROCPID" | bc | tr '[:upper:]' '[:lower:]'`
THREADSLOTS=`pstat -A | awk -v PROCPIDHEX=$PROCPIDHEX '{if($4==PROCPIDHEX){print $1}}'`

for THREADSLOT in $THREADSLOTS ; do
  echo THREAD SLOT $THREADSLOT
  echo "user $THREADSLOT" | kdb | grep ' rlimit\['
done
