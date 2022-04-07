
## scripts/rhel/scsictrlstat.pl

~~~
$ ./iostatread.pl -h
./iostatread.pl recalculate and reformat RHEL iostat -xNkt command output to group io statistics by scsi host controller. Script could use already collected data or run iostat internally.

Usage: ./iostatread.pl [-s groups_file] [-f] [-i interval] [-c count] [-S] [-p] [-d] [-l] [-m] [-t] [-w] | -h
       
        Options:
        -g groups_file - path to file with dev to group mapping (every line: devname groupbame) or lsblk -l -s -o NAME,TYPE,TRAN,HCTL output (./iostatread.pl will run lsblk internally on the current host if -g key is not used)
        -i interval    - interval for internal iostat run [default=5], ignored if -f used
        -c count       - count for internal iostat run [default=infinity], 0 treated as infinity, first iostat snap will not be showed, count ignored if -f used
        -d             - show data for every low level disk device
        -l             - show data for every lvm volume
        -m             - show data for every mpath device
        -t             - show data aggregated by scsi port-target (i.e. by pair server port & storage system front end port)
        -w             - show data aggregated by target port_name (wwn of storage system front end port). Currently work only on tagret server.
        -f             - offline mode - read stdin instead of running iostat
        -p             - print data in csv format
        -h             - usage

Offline usage example: bzcat 00.00.00_iostat_5_720.out.bz2 | ./iostatread.pl -f -g lsblk.out | less 
~~~

### Output example

~~~
        dev_group    R_io/s    W_io/s     R_MB/s    W_MB/s   R_await  W_await  R_await_top W_await_top  RW_await  RW_asvc RW_asvc_top R_asize_kB W_asize_kB  svc_aqueue_sum usage_top            date time
            host1     187.4      10.6       2.81      0.04     15.52  2750.72        15.52     2750.72    161.95     4.83        4.83      15.37       3.80            10.7      95.7  2022-04-07 02:30:22
            host2     195.2       3.2       2.92      0.02     15.65    49.00        15.65       49.00     16.19     4.96        4.96      15.33       6.09             3.2      98.5  2022-04-07 02:30:22
            host3     190.2       4.0       2.54      0.04     16.03    39.40        16.03       39.40     16.51     5.13        5.13      13.69       9.88             3.2      99.6  2022-04-07 02:30:22
            host4     193.4       3.6       2.98      0.02     15.80    38.00        15.80       38.00     16.21     5.06        5.06      15.77       5.86             3.2      99.7  2022-04-07 02:30:22
             sata     766.2      21.4      11.26      0.12     15.75  1383.59        16.03     2750.72     52.92     4.99        5.13      15.05       5.63            20.3      99.7  2022-04-07 02:30:22
             nvme       0.0       0.0       0.00      0.00      0.00     0.00         0.00        0.00      0.00     0.00        0.00       0.00       0.00             0.0       0.0  2022-04-07 02:30:22
             disk     766.2      21.4      11.26      0.12     15.75  1383.59        16.03     2750.72     52.92     4.99        5.13      15.05       5.63            20.3      99.7  2022-04-07 02:30:22
              lvm       0.0       5.6       0.00      0.04      0.00  6091.14         0.00     6091.14   6091.14    66.43       66.43       0.00       6.86             9.1      37.2  2022-04-07 02:30:22
            raid5       0.0       6.0       0.00      0.04      0.00     0.00         0.00        0.00      0.00     0.00        0.00       0.00       6.40             0.0       0.0  2022-04-07 02:30:22
~~~

### Fields description

* dev_group - disk device group (scsi host adapter, disks type, wwn of storage system FE port)
* R_io/s - read io rate
* W_io/s - write io rate
* R_MB/s - read data rate
* W_MB/s - write data rate
* R_await - group avg. read io wait, ms
* W_await - group avg. write io wait, ms
* R_await_top - avg. read io wait of slowest device in group, ms
* W_await_top - avg. write io wait of slowest device in group, ms
* RW_await - group avg. io (read an write) wait, ms
* RW_asvc - group avg. io (read an write) service time, ms
* R_asize_kB - group read avg. block size, kB
* W_asize_kB - group write avg. block size, kB
* svc_aqueue_sum - sum of avg. service queue length of all devices in group, #
* usage_top - usage of most loaded device in group, %

