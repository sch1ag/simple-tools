#!/usr/bin/perl
#Version 2

use strict;
use warnings;
use Getopt::Std;
use POSIX qw(strftime);

$|=1;

our ($opt_i, $opt_c, $opt_t, $opt_l, $opt_h);
getopts('i:c:tlh');

if ($opt_h) { usage() };
my $interval = ($opt_i) ? $opt_i : 1;
my $count = ($opt_c) ? $opt_c : 0;
my $tasks = ($opt_t) ? 1 : 0;
my $light = ($opt_l) ? 1 : 0;

printf("%19s %10s %10s\n", "Time", "procs", "tasks");

my $cycle = 0;
my $pcount = 0;
my $tcount_links = 0;
my $tcount = -1;
my $proc_ents_diff = 0;

while (not $count or $cycle < $count){
    my @pids;
    if (not $light or $cycle == 0)
    {
        opendir my $proc_handle, "/proc" or die "Cannot open directory: $!";
        @pids = grep { $_ =~ /^[0-9]+/ } readdir $proc_handle;
        closedir $proc_handle;
        $pcount = scalar @pids;
        if ($light) {
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/proc");
            $proc_ents_diff = $nlink - $pcount; 
        }
    }
   
    if ($light)
    {
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("/proc");
        $pcount = $nlink - $proc_ents_diff;
    } elsif ($tasks)
    {
        $pcount = 0;
        $tcount_links = 0;
        for my $pid (@pids)
        {
            my $tasksdir = "/proc/" . $pid . "/task";
            if(my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($tasksdir))
            {
                $pcount++;
                $tcount_links += $nlink;
            }
        }
        $tcount = $tcount_links - $pcount * 2;
    }
    
    printf("%19s %10d %10d\n", strftime("%Y-%m-%d %H:%m:%S", localtime), $pcount, $tcount);
    $cycle++;
    sleep $interval;
}

sub usage {
print "$0 designed to count number of processes and tasks on Linux
$0 [-i interval] [-c count] [-t|-l] | -h
       
        Options:
        -i interval   - update interval [default: 1 second]
        -c count      - count of updates before exit [default: 0 == infinity]
        -t            - show tasks (lwps) count (it will be shown as -1 without this option) [default: false]
        -l            - use lightweight collection method (could be not very accurate in rare cases and could not be used to collect tasks count) [default: false]
        -h            - usage
        Note: Flags -t and -l are mutually exclusive. Lightweight collection method will be used if both of them defined.
";
exit;
}

