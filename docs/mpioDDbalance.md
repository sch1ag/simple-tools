### aix/mpioDDbalance

mpioDDbalance.pl designed to balance enabled EMC DataDomain MPIO DDFC pathes by server fc hba ports.

#### Install and autorun AIX

Copy script [mpioDDbalance](../scripts/aix/mpioDDbalance) to `/etc/rc.d/init.d/` on target server

~~~
# chown 0:0 /etc/rc.d/init.d/mpioDDbalance
# chmod 755 /etc/rc.d/init.d/mpioDDbalance
# ln -s /etc/rc.d/init.d/mpioDDbalance /etc/rc.d/rc2.d/S99mpioDDbalance
~~~

#### Usage

To balance/rebalance run `mpioDDbalance.pl start` 

~~~
mpioDDbalance [-t] [-v] [-d] start | -h

        Options:
        -t : show results table
        -v : show commands prior to execution
        -d : execute without actually running commands
        -h : usage
~~~
