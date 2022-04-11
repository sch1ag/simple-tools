## scripts/rhel/lgwr_delay_stack_collector.pl

The script is designed to continuously collect Oracle lgw stacks into a ring buffer and dump them into a file after registering a write delay in the lgw `.trc` file.

This information can help determine the cause of write delays.

The buffer size and collection frequency can be configured.
