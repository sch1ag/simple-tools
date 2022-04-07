#!/bin/bash
#Version 1.5

echoerr() { echo "$@" 1>&2; }

fatalerror() {
  echoerr "ERROR: $@"
  usage
  exit 1
}

topcsv2txt() {
  delim=$1
  awk -F $delim '
  BEGIN{
    STRLEN="20 10 8 8 8 8 12 10 10 12 8 8 20 20";
    split(STRLEN, LEN, " ")
  }
  {
    if($1~"Time"){
      for(i=1;i<=NF;i++)
      {
        HEADER=HEADER sprintf("%"LEN[i]"s ", $i)
      }
    } else {
      if(PREVTIME!=$1){
      print HEADER
      }
      PREVTIME=$1
      for(i=1;i<=NF;i++)
      {
        printf("%"LEN[i]"s ", $i)
      }
      print ""
    }
  }'
}

usage() {
  SCRIPTNAME=`basename $0`
  echoerr "USAGE: $SCRIPTNAME reads nmon from stdin and exports most usefull pages as number of csv files in the output directory (will be created in CWD)"
  echoerr "USAGE: bunzip2 -c host_date_time.nmon.bz2 | $SCRIPTNAME [-d <delimiter>] [-t] [-o <dir>] [-h]"
  echoerr "USAGE: -d delim : delimiter (default is comma)"
  echoerr "USAGE: -o dir   : name of output dir (ncsv_HOSTNAME by default)"
  echoerr "USAGE: -t       : add top page"
  echoerr "USAGE: -h       : print help and exit"
}

DELIM=","
ODIR="./ncsv_`hostname`"
SORTTMP=$ODIR
INCLUDESTATS=""

while getopts :d:o:ht option
do
  case $option in
    d) DELIM=$OPTARG ;;
    o) ODIR=$OPTARG ;;
    t) INCLUDESTATS="TOP";;
    h) usage ; exit 0 ;;
    *) fatalerror "Invalid option found!" ;;
  esac
done

if [ -d "${ODIR}" ] ; then
  echo "INFO: Directory ${ODIR} exists. Reusing." 
else
  echo "INFO: Directory ${ODIR} is not exists. Creating." 
  mkdir ${ODIR}
fi

awk -F',' -v INCLUDESTATS="$INCLUDESTATS" -v PREFIX="${ODIR}/" -v DELIM=$DELIM 'BEGIN \
 {
    month["JAN"] = "01"
    month["FEB"] = "02"
    month["MAR"] = "03"
    month["APR"] = "04"
    month["MAY"] = "05"
    month["JUN"] = "06"
    month["JUL"] = "07"
    month["AUG"] = "08"
    month["SEP"] = "09"
    month["OCT"] = "10"
    month["NOV"] = "11"
    month["DEC"] = "12"

    STATSSTR="CPU_ALL MEMNEW NET NETPACKET IOADAPT.tps IOADAPT.KBps_read IOADAPT.KBps_write PAGE PROC.RunSwap PROC.ForkExec PROC.PswScall PROC.SemMsg PROC.ReadWrite FCREAD.KBps FCWRITE.KBps FCXFERIN.tps FCXFEROUT.tps"
    if(INCLUDESTATS!=""){STATSSTR=STATSSTR " " INCLUDESTATS}
    split(STATSSTR, STATS, " ")
    
    #NETINT="en[0-9]+"
    NETINT=""
    
    stat2page["CPU_ALL"]="CPU_ALL"
    stat2page["MEMNEW"]="MEMNEW"
    stat2page["NET"]="NET"
    stat2page["NETPACKET"]="NETPACKET"
    stat2page["IOADAPT.tps"]="IOADAPT"
    stat2page["IOADAPT.KBps_read"]="IOADAPT"
    stat2page["IOADAPT.KBps_write"]="IOADAPT"
    stat2page["PAGE"]="PAGE"
    stat2page["PROC.RunSwap"]="PROC"
    stat2page["PROC.ForkExec"]="PROC"
    stat2page["PROC.PswScall"]="PROC"
    stat2page["PROC.SemMsg"]="PROC"
    stat2page["PROC.ReadWrite"]="PROC"
    stat2page["FCREAD.KBps"]="FCREAD"
    stat2page["FCWRITE.KBps"]="FCWRITE"
    stat2page["FCXFERIN.tps"]="FCXFERIN"
    stat2page["FCXFEROUT.tps"]="FCXFEROUT"
    stat2page["TOP"]="TOP"
    
    stat2coll["CPU_ALL"]="User%|Sys%|Wait%"
    stat2coll["MEMNEW"]="Process%|FScache%|System%|Free%"
    stat2coll["NET"]=NETINT
    stat2coll["NETPACKET"]=NETINT
    stat2coll["IOADAPT.tps"]="fcs[0-9]+.*-tps"
    stat2coll["IOADAPT.KBps_read"]="fcs[0-9]+.*read-KB/s"
    stat2coll["IOADAPT.KBps_write"]="fcs[0-9]+.*write-KB/s"
    stat2coll["PAGE"]="faults|pgin|pgout|pgsin|pgsout|reclaims|scans"
    stat2coll["PROC.RunSwap"]="Runnable|Swap-in"
    stat2coll["PROC.ForkExec"]="fork|exec"
    stat2coll["PROC.PswScall"]="pswitch|syscall"
    stat2coll["PROC.SemMsg"]="sem|msg"
    stat2coll["PROC.ReadWrite"]="read|write"
    #stat2coll["TOP"]="+PID|%CPU|%Usr|%Sys|Threads|Size|ResText|ResData|CharIO|%RAM|Paging|Command|WLMclass"
    stat2coll["TOP"]="PID|%CPU|%Usr|%Sys|Threads|Size|ResText|ResData|CharIO|%RAM|Paging|Command|WLMclass"
    
    statsum["IOADAPT.tps"]="true"
    statsum["IOADAPT.KBps_read"]="true"
    statsum["IOADAPT.KBps_write"]="true"
    statsum["FCREAD.KBps"]="true"
    statsum["FCWRITE.KBps"]="true"
    statsum["FCXFERIN.tps"]="true"
    statsum["FCXFEROUT.tps"]="true"

    donotsort["TOP"]="true"

    timecol["TOP"]=3
    timecol_default=2
    
    LINEperDOT=50000
    
    printf("INFO: Parsing. One dot per %d processed lines: ", LINEperDOT)   
 }
 {
   if(NR%LINEperDOT==0){printf ". "}
   if($1=="AAA" && $2=="host"){
       NMONHOST=$3
   } else if($1=="ZZZZ"){
       split($4, dateArr, "-")
       DATE[$2]=dateArr[3]"-"month[dateArr[2]]"-"dateArr[1]
       TIME[$2]=$3
   } else {
     for (stkey in STATS){
       STAT=STATS[stkey]
       if (STAT in timecol){TCOL=timecol[STAT]}else{TCOL=timecol_default}
       if($1==stat2page[STAT]){
           OUTFILE=(donotsort[STAT]!="true") ? PREFIX NMONHOST "." STAT ".csv.nparsetmp" : PREFIX NMONHOST "." STAT ".notsorted.csv"
           if($TCOL~"T[0-9]+"){
               if($TCOL=="T0001"){next}
               SUM=0
               printf DATE[$TCOL] " " TIME[$TCOL] >> OUTFILE;
               for (i=1; i<=ncols[STAT]; i++){
                   printf DELIM $C2P[STAT, i] >> OUTFILE;
                   SUM+=$C2P[STAT, i]
               }
               if(statsum[STAT]=="true"){print DELIM SUM >> OUTFILE }else{print "" >> OUTFILE} ;
           }
           else {
               ncols[STAT]=0
               for (i=1; i<=NF; i++){
                   if (stat2coll[STAT]=="" && i>TCOL || stat2coll[STAT]!="" && $i~stat2coll[STAT]){
                       ncols[STAT]++
                       C2P[STAT, ncols[STAT]]=i
                   }
               }
               printf "Time" >> OUTFILE ;
               for (i=1; i<=ncols[STAT]; i++){
                   printf("%s%s", DELIM, $C2P[STAT, i]) >> OUTFILE ;
               }
               if(statsum[STAT]=="true"){print DELIM "SUM" >> OUTFILE}else{print "" >> OUTFILE}
           }
       }
     }
   }
}
END{
    printf("\nINFO: Parsing done.\n")   
}'

echo "INFO: Sorting output."
for ntmpfile in ${ODIR}/*.nparsetmp ; do
  output=`echo $ntmpfile | sed 's/.nparsetmp$//'`
  echo "INFO: ${output}"
  sort -T $SORTTMP -u -k 1,1 -t , $ntmpfile | sort -T $SORTTMP -n > ${output}
  rm $ntmpfile
done

if echo $INCLUDESTATS | grep -q TOP ; then
  declare -A TOPKEYS
  TOPKEYS["byCPU"]="3rn"
  TOPKEYS["bySYS"]="5rn"
  TOPKEYS["bySIZE"]="7rn"
  TOPKEYS["byCharIO"]="10rn"

  for topnonsorted in ${ODIR}/*.TOP.notsorted.csv ; do
    for KEY in ${!TOPKEYS[@]} ; do
      outfile=`echo $topnonsorted | sed 's/.notsorted.csv$//'`.${KEY}.txt
      echo "INFO: ${outfile}"
      HEADER=`grep -v 'Time,%CPU Utilisation' $topnonsorted | head -1`
      (echo $HEADER ; grep -v 'Time' $topnonsorted | sort -T $SORTTMP -k 1,1 -k ${TOPKEYS[$KEY]},${TOPKEYS[$KEY]} -t ${DELIM}) | topcsv2txt ${DELIM} > $outfile

    done
  done
fi
echo "INFO: Sorting done."

