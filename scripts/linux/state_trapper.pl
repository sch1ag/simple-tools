#!/usr/bin/perl
#Version 2

use strict;
use warnings;
use Getopt::Std;
use Time::HiRes qw(time sleep);
use Cwd qw(getcwd);

$|=1;

our ($opt_p, $opt_s, $opt_i, $opt_d, $opt_o, $opt_m, $opt_c, $opt_h);
getopts('p:s:i:d:o:m:ch');

usage() if ($opt_h);

my $pid;
if ($opt_p) {
    $pid = $opt_p;
} else { die "PID should be defined" };

my $state = ($opt_s) ? $opt_s : 'D';
my $interval = ($opt_i) ? $opt_i : 0.1;
my $duration = ($opt_d) ? $opt_d : 0;
my $outdir = ($opt_o) ? $opt_o : getcwd;
my $maxtriggering = ($opt_m) ? $opt_m : 0;
my $check_call_change  = ($opt_c) ? 1 : 0;

my $tasksdir = '/proc/' . $pid . '/task';
my $endtime = time + $duration;

my $numtriggering = 0;
my %syscall_content;

while (not $duration or time < $endtime)
{
    ( -d $tasksdir ) or die "Directory $tasksdir does not exist";
    opendir my $tasksdir_handle, $tasksdir or die "Cannot open directory: $!";
    my @taskids = grep { $_ =~ /[0-9]+/} readdir $tasksdir_handle;
    closedir $tasksdir_handle;

    for my $taskid (@taskids)
    {
        my $stat_fname = $tasksdir . '/' . $taskid . '/stat';
        if (grepq(" $state ", $stat_fname))
        {
           if ($check_call_change)
           {
               my $prev_syscall_content = (defined $syscall_content{$taskid}) ? $syscall_content{$taskid} : ""; 
               my $syscall_fname = $tasksdir . '/' . $taskid . '/syscall';
               $syscall_content{$taskid} = slurp($syscall_fname);
               #print "=====\n";
               #print "$prev_syscall_content";
               #print "$syscall_content{$taskid}";
               #skip current collection cycle if the previous syscall differ from the current
               next if ($syscall_content{$taskid} ne $prev_syscall_content or $prev_syscall_content =~ /running/);
           }

           my $stack_fname = $tasksdir . '/' . $taskid . '/stack';
           fcopy($stack_fname, $outdir . '/' . time . '_' . $pid . '_' . $taskid . '.stack'); 
           fcopy($stat_fname, $outdir . '/' . time . '_' . $pid . '_' . $taskid . '.stat'); 

           $numtriggering++;
           #exit if maxtriggering achived
           exit 0 if ($maxtriggering and $numtriggering >= $maxtriggering);
        }
        else
        {
            $syscall_content{$taskid} = "";
        }
    }
    sleep $interval;
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die "Could not open $file : $!";
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}

sub grepq {
    my $pattern = shift;
    my $filepath = shift;
    my $ret = 0;

    open(my $fh, '<', $filepath) or die "Could not open file $filepath : $!";
    while (my $line = <$fh>) {
        if ($line =~ /$pattern/) {
            $ret = 1;
            last;
        }
    }
    close $fh;
    return $ret;
}

sub fcopy {
    my ($srcfile, $dstfile) = @_;
    my ($data, $infd, $outfd);
    open($infd, "<", $srcfile) or die $!;
    open($outfd, ">", $dstfile) or die $!;
    binmode($infd);
    binmode($outfd);

    while (sysread($infd, $data, 4096)){ print $outfd $data };

    close $infd, $outfd
}

sub usage {
print "$0 designed to monitor specified state of the process threads and collect stack and stat files at this time
$0 [-s STATE] [-i INTERVAL] [-d DURATION] [-o OUTDIR] [-m MAX_TRIGGERING] [-c] -p PID | -h

        Options:
        -s STATE : what state to monitor [default: D]
        -i INTERVAL : interval between state check in seconds (fractions of a second) [default: 0.1 sec]
        -d DURATION : how long to run [default: no limit]
        -o OUTDIR : directory for output files (.stat and .stack) [default: CWD]
        -m MAX_TRIGGERING : maximim number of trigger firing [default: no limit]
        -c : only collect the stack when current syscall is the same as in the previous iteration [default: false]
        -h : usage

You can run $0 in screen: screen -S state_trapper -d -m $0 -o /tmp -m 10 -d 86400 -p \`pgrep bird\`
";
exit;
}


