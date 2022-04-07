#!/usr/bin/env perl
#Version 3.7.0
use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use Getopt::Std;

our ($opt_f, $opt_g, $opt_h, $opt_i, $opt_c, $opt_p, $opt_d, $opt_t, $opt_l, $opt_m, $opt_w);
getopts('fg:hi:c:pSdtlmw');
if ($opt_h) { usage() };
my $groupsfile = ($opt_g) ? $opt_g : '';
my $readstdin = ($opt_f) ? 1 : 0;
my $interval = ($opt_i) ? $opt_i : 5;
my $count = ($opt_c) ? $opt_c : '';
my $csvout = ($opt_p) ? 1 : 0;

my %show;
$show{'devs'} = ($opt_d) ? 1 : 0;
$show{'mpath'} = ($opt_m && ! $opt_d) ? 1 : 0;
$show{'lvol'} = ($opt_l && ! $opt_d) ? 1 : 0;
$show{'targets'} = ($opt_t) ? 1 : 0;
$show{'wwn'} = ($opt_w) ? 1 : 0;

$|=1;
$ENV{'LANG'} = 'C';

my $devgroups = {};
#fill $devgroups
my $grp_order = create_map_groups($devgroups, $groupsfile, \%show);
#print Dumper($grp_order);
#print Dumper($devgroups);
my $dev_to_grps_map = dev_to_grps($devgroups);
#print Dumper($dev_to_grps_map);
#exit 0;

my $first_snap = 0;

my $IOSTATOUT;
if ($readstdin)
{
    $IOSTATOUT = *STDIN;
}
else
{
    my $CMD="iostat -xNkt $interval $count";
    open ($IOSTATOUT, '-|', $CMD) or croak("Couldn't open $CMD for reading: $!");
}

my $devgroups_tdata = {};
my $cur_line_str_datetime;
my %dev_data;
while (my $line = <$IOSTATOUT>)
{
    if (
    # RHEL
        (
            $dev_data{'devname'}, 
            $dev_data{'read_rq_merged_ps'}, 
            $dev_data{'write_rq_merged_ps'}, 
            $dev_data{'read_io_ps'}, 
            $dev_data{'write_io_ps'}, 
            $dev_data{'read_kB_ps'}, 
            $dev_data{'write_kB_ps'}, 
            $dev_data{'rq_avg_sz_sec'}, 
            $dev_data{'avg_queue_length'}, 
            $dev_data{'total_avg_wait_ms'}, 
            $dev_data{'read_avg_wait_ms'}, 
            $dev_data{'write_avg_wait_ms'}, 
            $dev_data{'total_avg_svc_ms'}, 
            $dev_data{'util'}
        ) = ($line =~ m{^\s*([-\w]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s*$})
        or
    # Debian
        (
            $dev_data{'devname'}, 
            $dev_data{'read_io_ps'}, 
            $dev_data{'write_io_ps'}, 
            $dev_data{'read_kB_ps'}, 
            $dev_data{'write_kB_ps'}, 
            $dev_data{'read_rq_merged_ps'}, 
            $dev_data{'write_rq_merged_ps'}, 
            $dev_data{'read_rq_merged_perc'}, 
            $dev_data{'write_rq_merged_perc'}, 
            $dev_data{'read_avg_wait_ms'}, 
            $dev_data{'write_avg_wait_ms'}, 
            $dev_data{'avg_queue_length'}, 
            $dev_data{'read_rq_avg_sz_kB'},
            $dev_data{'write_rq_avg_sz_kB'}, 
            $dev_data{'total_avg_svc_ms'}, 
            $dev_data{'util'}
        ) = ($line =~ m{^\s*([-\w]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s*$})
    )
    {
        account_tdata($devgroups_tdata, \%dev_data, $dev_to_grps_map);
    }
    elsif (my ($month, $mday, $year, $hour, $min, $sec) = ($line =~ m%(\d\d)/(\d\d)/(\d\d)\s(\d\d):(\d\d):(\d\d)%))
    {
        $cur_line_str_datetime = '20' . $year . '-' . $month . '-' . $mday . ' ' . $hour . ':' . $min . ':' . $sec;
        #print "$cur_line_str_datetime\n";
    }
    elsif ($line =~ /^$/ && %{$devgroups_tdata} && $cur_line_str_datetime)
    {
        my $interval_results = get_interval_results($devgroups_tdata);
        print_stats('grps_results' => $interval_results, 'str_datetime' => $cur_line_str_datetime, 'first_snap' => $first_snap, 'csvout' => $csvout, 'grp_order' => $grp_order);

        $first_snap = 0;
        $devgroups_tdata = {};
    }
    elsif ($line =~ /^Linux/)
    {
        $first_snap = 1;
    }
}

sub dev_to_grps 
{
    my $devgroups = shift;
    my %dev_to_grps_map;
    for my $devgrp (keys %{$devgroups})
    {
        for my $dev (@{$devgroups->{$devgrp}})
        {
            if (not defined $dev_to_grps_map{$dev}) {$dev_to_grps_map{$dev} = []};
            push @{$dev_to_grps_map{$dev}}, $devgrp;
        }
    }
    return \%dev_to_grps_map;
}

sub account_tdata
{
    my $groups_tdata = shift;
    my $dev_data = shift;
    my $dev_to_grps_map = shift;

    for my $dgrp (@{$dev_to_grps_map->{$dev_data->{'devname'}}})
    {
        accout_tdata_to_devgrp($devgroups_tdata, $dev_data, $dgrp);
    }
}

sub accout_tdata_to_devgrp
{
    my $groups_tdata = shift;
    my $dev_data = shift;
    my $devgrp = shift;
    
    #init struct for device group if not already done
    if (not defined $groups_tdata->{$devgrp})
    {
        my %group_tdata = (
            'sum_read_io_ps' => 0,
            'sum_write_io_ps' => 0,
            'sum_read_bytes_ps' => 0,
            'sum_write_bytes_ps' => 0,
            'sum_avg_queue_length' => 0,
            'acc_read_avg_wait_msXread_io_ps' => 0,
            'acc_write_avg_wait_msXwrite_io_ps' => 0,
            'acc_total_avg_wait_msXtotal_io_ps' => 0,
            'acc_total_avg_svc_msXtotal_io_ps' => 0,
            'top_util' => 0,
            'top_read_avg_wait_ms' => 0,
            'top_write_avg_wait_ms' => 0,
            'top_total_avg_wait_ms' => 0,
            'top_total_avg_svc_ms' => 0
        );
        $groups_tdata->{$devgrp} = \%group_tdata;
    }
    my $grptdata = $groups_tdata->{$devgrp};

    $grptdata->{'sum_read_io_ps'} += $dev_data->{'read_io_ps'};
    $grptdata->{'sum_write_io_ps'} += $dev_data->{'write_io_ps'};
    $grptdata->{'sum_read_bytes_ps'} += $dev_data->{'read_kB_ps'} * 1024;
    $grptdata->{'sum_write_bytes_ps'} += $dev_data->{'write_kB_ps'} * 1024;
    $grptdata->{'sum_avg_queue_length'} += $dev_data->{'avg_queue_length'};

    my $read_avg_wait_msXread_io_ps = $dev_data->{'read_avg_wait_ms'} * $dev_data->{'read_io_ps'};
    $grptdata->{'acc_read_avg_wait_msXread_io_ps'} += $read_avg_wait_msXread_io_ps;

    my $write_avg_wait_msXwrite_io_ps = $dev_data->{'write_avg_wait_ms'} * $dev_data->{'write_io_ps'};
    $grptdata->{'acc_write_avg_wait_msXwrite_io_ps'} += $write_avg_wait_msXwrite_io_ps;

    #There is no total_avg_wait_ms field on Debian. Lets calculate it.
    if (not defined $dev_data->{'total_avg_wait_ms'})
    {
        my $t_iops = $dev_data->{'read_io_ps'} + $dev_data->{'write_io_ps'};
        $dev_data->{'total_avg_wait_ms'} = ($t_iops > 0) ? (($read_avg_wait_msXread_io_ps + $write_avg_wait_msXwrite_io_ps) / $t_iops) : 0;
    }
 
    $grptdata->{'acc_total_avg_wait_msXtotal_io_ps'} += $dev_data->{'total_avg_wait_ms'} * ($dev_data->{'read_io_ps'} + $dev_data->{'write_io_ps'});
    $grptdata->{'acc_total_avg_svc_msXtotal_io_ps'} += $dev_data->{'total_avg_svc_ms'} * ($dev_data->{'read_io_ps'} + $dev_data->{'write_io_ps'});
    $grptdata->{'top_util'} = $dev_data{'util'} if $dev_data{'util'} > $grptdata->{'top_util'};
    $grptdata->{'top_read_avg_wait_ms'} = $dev_data{'read_avg_wait_ms'} if $dev_data{'read_avg_wait_ms'} > $grptdata->{'top_read_avg_wait_ms'};
    $grptdata->{'top_write_avg_wait_ms'} = $dev_data{'write_avg_wait_ms'} if $dev_data{'write_avg_wait_ms'} > $grptdata->{'top_write_avg_wait_ms'};
    $grptdata->{'top_total_avg_wait_ms'} = $dev_data{'total_avg_wait_ms'} if $dev_data{'total_avg_wait_ms'} > $grptdata->{'top_total_avg_wait_ms'};
    $grptdata->{'top_total_avg_svc_ms'} = $dev_data{'total_avg_svc_ms'} if $dev_data{'total_avg_svc_ms'} > $grptdata->{'top_total_avg_svc_ms'};
}

sub get_interval_results
{
    my $groups_data = shift;
    my %results = map { $_ => calc_interval_grp_result($groups_data->{$_}) } keys %{$groups_data};
    return \%results;
}

sub calc_interval_grp_result
{
    my $grptdata = shift;
    
    my %groupresult;
    $groupresult{'sum_read_io_ps'} = $grptdata->{'sum_read_io_ps'};
    $groupresult{'sum_write_io_ps'} = $grptdata->{'sum_write_io_ps'};
    $groupresult{'sum_read_bytes_ps'} = $grptdata->{'sum_read_bytes_ps'};
    $groupresult{'sum_write_bytes_ps'} = $grptdata->{'sum_write_bytes_ps'};

    $groupresult{'avg_read_blk_sz_bytes'} = ($grptdata->{'sum_read_io_ps'} != 0) ? $grptdata->{'sum_read_bytes_ps'} / $grptdata->{'sum_read_io_ps'} : 0;
    $groupresult{'avg_write_blk_sz_bytes'} = ($grptdata->{'sum_write_io_ps'} != 0) ? $grptdata->{'sum_write_bytes_ps'} / $grptdata->{'sum_write_io_ps'} : 0;

    $groupresult{'sum_avg_queue_length'} = $grptdata->{'sum_avg_queue_length'};

    $groupresult{'read_avg_wait_ms'} = ($grptdata->{'sum_read_io_ps'} != 0) ? $grptdata->{'acc_read_avg_wait_msXread_io_ps'} / $grptdata->{'sum_read_io_ps'} : 0;
    $groupresult{'write_avg_wait_ms'} = ($grptdata->{'sum_write_io_ps'} != 0) ? $grptdata->{'acc_write_avg_wait_msXwrite_io_ps'} / $grptdata->{'sum_write_io_ps'} : 0;
    my $rwiops = $grptdata->{'sum_read_io_ps'} + $grptdata->{'sum_write_io_ps'};
    $groupresult{'total_avg_wait_ms'} = ($rwiops != 0) ? $grptdata->{'acc_total_avg_wait_msXtotal_io_ps'} / $rwiops : 0;
    $groupresult{'total_avg_svc_ms'} = ($rwiops != 0) ? $grptdata->{'acc_total_avg_svc_msXtotal_io_ps'} / $rwiops : 0;

    $groupresult{'top_read_avg_wait_ms'} = $grptdata->{'top_read_avg_wait_ms'}; 
    $groupresult{'top_write_avg_wait_ms'} = $grptdata->{'top_write_avg_wait_ms'};
    $groupresult{'top_total_avg_wait_ms'} = $grptdata->{'top_total_avg_wait_ms'};
    $groupresult{'top_total_avg_svc_ms'} = $grptdata->{'top_total_avg_svc_ms'}; 
    $groupresult{'top_util'} = $grptdata->{'top_util'};

    return \%groupresult;
}

sub create_map_groups
{
    my $devgroups = shift;
    my $lsblkfile = shift;
    my $show = shift;
    
    my @global_exclude_devname_re = ('VxDMP');
    my %mutual_exclusive_autogrp_devname_re = (
        'disk' => 'VxVM'
    );
    my %cust_grpname_to_devname_re = (
        'vxvols' => 'VxVM',
        'nvme' => 'nvme',
        'zram' => 'zram'
    );

    my $tgt2wwn = get_fc_tgt_to_wwn_map() if ($show->{'wwn'});
    #print Dumper($tgt2wwn);

    my $LSBLKOUT;
    if ($lsblkfile && -f $lsblkfile)
    {
        open($LSBLKOUT, '<', $lsblkfile) or croak("Could not read file $lsblkfile $!");
    }
    else 
    {
        my $CMD = "lsblk -l -s -o NAME,TYPE,TRAN,HCTL";
        open($LSBLKOUT, '-|', $CMD) or croak("Couldn't open $CMD for reading: $!");
    }

    while (my $line = <$LSBLKOUT>)
    {
        chomp $line;
        my @fields = split '\s+', $line;
        if (@fields)
        {
            my $devname = shift @fields;
            unless (grep { $devname =~ /$_/ } @global_exclude_devname_re)
            {
 
                #auto grouping
                for my $grp (@fields)
                {
                    #grouping by scsi host
                    if (my ($ctlr) = ($grp =~ m{(\d+):\d+:\d+:\d+}))
                    {
                        if (my ($tgt) = ($grp =~ m{(\d+:\d+:\d+):\d+}))
                        {
                            my $tgtname = 'target' . $tgt;
                            push @{$devgroups->{$tgtname}}, $devname if ($show->{'targets'});
                            #add dev to target wwn group if requested
                            if($show->{'wwn'} && $tgt2wwn->{$tgtname})
                            {
                                push @{$devgroups->{$tgt2wwn->{$tgtname}}}, $devname;
                            }
                        }
                        $grp = 'host' . $ctlr;
                    }
                    # do not add same dev to same group twice
                    push @{$devgroups->{$grp}}, $devname unless ((grep { $devname eq $_ } @{$devgroups->{$grp}}) || $mutual_exclusive_autogrp_devname_re{$grp} && $devname =~ /$mutual_exclusive_autogrp_devname_re{$grp}/);
                }
                
                #custom grouping
                for my $grp (keys %cust_grpname_to_devname_re)
                {
                    if ($devname =~ /$cust_grpname_to_devname_re{$grp}/)
                    {
                        push @{$devgroups->{$grp}}, $devname;
                    } 
                }
                
                #add device to it's own group if requested
                $devgroups->{$devname} = [ $devname ] if ($show->{'devs'} || ($show->{'lvol'} && grep { $_ eq 'lvm' } @fields) || ($show->{'mpath'} && grep { $_ eq 'mpath' } @fields));
            }
        }
    }
    close $LSBLKOUT;
    my @ordered_groups = sort grp_name_cmp keys %{$devgroups};
    return \@ordered_groups;
}

sub print_stats
{

    # print_stats('grps_results' => $interval_results, 'str_datetime' => $cur_line_str_datetime, 'first_snap' => $first_snap, 'csvout' => $csvout, 'grp_order' => $grp_order);
    my %params = @_;
    #print Dumper(\%params);

    #print header for every human readable data table
    printf("\n%17s %9s %9s  %9s %9s  %8s %8s  %11s %11s  %8s %8s %11s %10s %10s  %14s %9s  %19s\n",
        'dev_group',
        'R_io/s', 
        'W_io/s',
        'R_MB/s', 
        'W_MB/s',
        'R_await',
        'W_await', 
        'R_await_top', 
        'W_await_top', 
        'RW_await', 
        'RW_asvc',
        'RW_asvc_top',
        'R_asize_kB', 
        'W_asize_kB',
        'svc_aqueue_sum', 
        'usage_top', 
        'date time'
    ) unless ($params{'csvout'} || $params{'first_snap'});

    my @non_empty_ordered_groups = grep { $params{'grps_results'}->{$_} } @{$params{'grp_order'}};
    for my $grpname (@non_empty_ordered_groups)
    {
        #ptint header in csv for every devgroup only one time
        printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
            $grpname,
            'Time',
            'Read_IO',
            'Write_IO',
            'Read_KB',
            'Write_KB',
            'Read_WAIT',
            'Write_WAIT',
            'Read_Top_WAIT',
            'Write_Top_WAIT',
            'Total_WAIT',
            'Total_SRV',
            'Total_Top_SRV',
            'Read_BlkSz_KB',
            'Write_BlkSz_KB',
            'GrpSum_QUEUE',
            'Top_USAGE'
        ) if ($params{'csvout'} && $params{'first_snap'});

        print_grp_stat($params{'grps_results'}->{$grpname}, $grpname, $params{'str_datetime'}, $params{'csvout'}) unless ($params{'first_snap'});
    }
}

sub grp_name_cmp
{
    my %order = (
        '^host'   => 1000,
        '^target' => 1100,
        '^mpath'  => 2000,
        '^fc'     => 3000,
        '^sas'    => 4000,
        '^sata'   => 4100,
        '^nvme'   => 5000,
        '^zram'   => 5100,
        '^disk'   => 6000,
        '^lvm'    => 7000,
        '^vxvols' => 8000
    );

    my $anum = 100000;
    my $bnum = 100000;
    for my $grpname_re (keys %order)
    {
       $anum = $order{$grpname_re} if ($a =~ /$grpname_re/); 
       $bnum = $order{$grpname_re} if ($b =~ /$grpname_re/); 
    }
    my $diff = $anum - $bnum;
    return $a cmp $b unless $diff;
    return $diff;
}

sub print_grp_stat
{
    my $groupresult = shift;
    my $grpname = shift;
    my $strdate = shift;
    my $csvout = shift;

    if ($csvout)
    {
        printf("%s,%s,%.1f,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%.1f\n",
            $grpname,
            $strdate,
            $groupresult->{'sum_read_io_ps'},
            $groupresult->{'sum_write_io_ps'},
            $groupresult->{'sum_read_bytes_ps'}/1024,
            $groupresult->{'sum_write_bytes_ps'}/1024,
            $groupresult->{'read_avg_wait_ms'},
            $groupresult->{'write_avg_wait_ms'},
            $groupresult->{'top_read_avg_wait_ms'},
            $groupresult->{'top_write_avg_wait_ms'},
            $groupresult->{'total_avg_wait_ms'},
            $groupresult->{'total_avg_svc_ms'},
            $groupresult->{'top_total_avg_svc_ms'},
            $groupresult->{'avg_read_blk_sz_bytes'}/1024,
            $groupresult->{'avg_write_blk_sz_bytes'}/1024,
            $groupresult->{'sum_avg_queue_length'},
            $groupresult->{'top_util'}
        );
    }
    else 
    {
        printf("%17s %9.1f %9.1f  %9.2f %9.2f  %8.2f %8.2f  %11.2f %11.2f  %8.2f %8.2f %11.2f %10.2f %10.2f  %14.1f %9.1f  %19s\n",
            $grpname,
            $groupresult->{'sum_read_io_ps'}, 
            $groupresult->{'sum_write_io_ps'}, 
            $groupresult->{'sum_read_bytes_ps'}/1048576, 
            $groupresult->{'sum_write_bytes_ps'}/1048576, 
            $groupresult->{'read_avg_wait_ms'},
            $groupresult->{'write_avg_wait_ms'}, 
            $groupresult->{'top_read_avg_wait_ms'}, 
            $groupresult->{'top_write_avg_wait_ms'}, 
            $groupresult->{'total_avg_wait_ms'}, 
            $groupresult->{'total_avg_svc_ms'},
            $groupresult->{'top_total_avg_svc_ms'},
            $groupresult->{'avg_read_blk_sz_bytes'}/1024, 
            $groupresult->{'avg_write_blk_sz_bytes'}/1024,
            $groupresult->{'sum_avg_queue_length'}, 
            $groupresult->{'top_util'}, 
            $strdate
        );
    }
}

sub get_fc_tgt_to_wwn_map
{
    my $tgt_dir = '/sys/class/fc_transport/';
    my $tgts = get_tgts($tgt_dir);
    my %ret_map;

    for my $tgt (@{$tgts})
    {
        my $port_name_file = $tgt_dir . $tgt . '/port_name';
        if (-r $port_name_file)
        {
            my $wwn = slurp($port_name_file);
            ($ret_map{$tgt}) = ($wwn =~ '^0x([0-9a-f]+)');
        }
    }

    return \%ret_map;
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or croak("Couldn't open $file : $!");
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}

sub get_tgts
{
    my $dirpath = shift;
    my @tgts;
    if (-d $dirpath)
    {
        opendir my $tgt_host_handle, $dirpath or croak("Cannot open $dirpath directory: $!");
        @tgts = grep { $_ =~ /^target[0-9]+:[0-9]+:[0-9]+$/ } readdir $tgt_host_handle;
        closedir $tgt_host_handle;
    }
    return \@tgts;
}

sub usage {
print "$0 recalculate and reformat RHEL iostat -xNkt command output to group io statistics by scsi host controller. Script could use already collected data or run iostat internally.

Usage: $0 [-s groups_file] [-f] [-i interval] [-c count] [-S] [-p] [-d] [-l] [-m] [-t] [-w] | -h
       
        Options:
        -g groups_file - path to file with dev to group mapping (every line: devname groupbame) or lsblk -l -s -o NAME,TYPE,TRAN,HCTL output ($0 will run lsblk internally on the current host if -g key is not used)
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

Offline usage example: bzcat 00.00.00_iostat_5_720.out.bz2 | $0 -f -g lsblk.out | less 
";
exit;
}

