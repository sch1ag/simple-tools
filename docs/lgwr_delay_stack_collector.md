## scripts/rhel/lgwr_delay_stack_collector.pl

The script is designed to continuously collect Oracle lgwr stacks into a ring buffer and dump them into a file after registering a write delay in the lgw `.trc` file.

This information can help determine the cause of write delays.

The buffer size and collection frequency can be configured.

Oracle DB lgwr trc file records example

~~~
*** 2021-12-12 11:40:16.543
Warning: log write elapsed time 3454ms, size 65KB

*** 2021-12-12 11:49:15.533
Warning: log write elapsed time 5434ms, size 148KB
~~~
