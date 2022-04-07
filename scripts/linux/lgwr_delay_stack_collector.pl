#!/usr/bin/perl
#version 2

use strict;
use warnings;
use Getopt::Std;
use Time::HiRes qw(time sleep);
use Time::Local;
use Cwd qw(getcwd);
use POSIX qw(strftime);
#use Data::Dumper;

$|=1;

our ($opt_n, $opt_p, $opt_i, $opt_d, $opt_o, $opt_h, $opt_f, $opt_F, $opt_m, $opt_r, $opt_T);
getopts('p:i:d:o:f:hn:m:F:Tr:');

usage() if ($opt_h);

my $pid;
if ($opt_p) {
    $pid = $opt_p;
} else { die "PID should be defined" };

my $monfile_path;
if ($opt_f) {
    $monfile_path = $opt_f;
} else { die "file to monitor should be defined" };

my $outdir = ($opt_o) ? $opt_o : getcwd;
die "Directory $outdir does not exist." unless (-d $outdir);

my $interval = ($opt_i) ? $opt_i : 0.1;
my $duration = ($opt_d) ? $opt_d : 0;
my $maxtriggering = ($opt_m) ? $opt_m : 1000;
my $monfile_check_cycle = ($opt_F) ? $opt_F : 10;
my $reopen_interval = ($opt_r) ? $opt_r : 600;
my $nrecords = ($opt_n) ? $opt_n : 200;
my $tasks_rescan = ($opt_T) ? 1 : 0;

my $tasksdir = '/proc/' . $pid . '/task';
my @collect_files = ('stack', 'stat');

my $event_chronicler = make_event_chronicler($monfile_path, $reopen_interval);
my $ring_buffer = RingBuffer->new($nrecords);

my $taskids = get_proc_tasks($tasksdir);

my $trigger_count = 0;
my $shuttle = 0;
my $endtime = time + $duration;
my $prev_last_event_time = 0;
while (not $duration or time < $endtime)
{
    my %data;
    $data{'start'} = time;
    for my $taskid (@{$taskids})
    {
        for my $f (@collect_files) {
            $data{'tasks'}->{$taskid}->{$f} = slurp($tasksdir . '/' . $taskid . '/' . $f);
        }
    }
    my $tmp_fin_time = time;
    $data{'finish'} = $tmp_fin_time;
    $ring_buffer->add(\%data);

    #check file every monfile_check_cycle'th cycle
    unless ($shuttle)
    {
        my $last_event_time = $event_chronicler->($tmp_fin_time);
        my $oldest_elem_in_ring = $ring_buffer->get_oldest_elem();
        if (defined $oldest_elem_in_ring and $prev_last_event_time != $last_event_time and $last_event_time > $oldest_elem_in_ring->{'finish'})
        {
            my $outfname = $outdir . '/' . tformat($tmp_fin_time, "%Y-%m-%d_%H.%M.%S") . '_' . $pid . '.out' ;
            dump_data($ring_buffer, $outfname);
            exit 0 if ($maxtriggering and ++$trigger_count >= $maxtriggering);
            $prev_last_event_time = $last_event_time;
        }
    }
    $shuttle = ++$shuttle % $monfile_check_cycle;
    sleep $interval;
    $taskids = get_proc_tasks($tasksdir) if ($tasks_rescan);
}

sub get_proc_tasks
{
    my $tasksdir = shift;
    ( -d $tasksdir ) or die "Directory $tasksdir does not exist";
    opendir my $tasksdir_handle, $tasksdir or die "Cannot open directory: $!";
    my @taskids = grep { $_ =~ /[0-9]+/} readdir $tasksdir_handle;
    closedir $tasksdir_handle;
    return \@taskids;
}

sub make_event_chronicler
{
    my $file_namepath = shift;
    my $reopen_interval = shift;
    my $open_time = 0;
    my $fh;
    my $last_delay = 0;

    #function will return last event timestamp in seconds since the system epoch (UNIX time)
    return sub { 
       my $curr_time = shift; #could be just time

       #close fh if it is a time for reopen
       if ($open_time && $curr_time - $open_time > $reopen_interval)
       {
          close $fh;
          $open_time = 0;
       }
       
       #open file if it is closed but exists
       unless ($open_time)
       {
           if (-f $file_namepath) {
               open $fh, '<', $file_namepath or die "Cannot open file $file_namepath: $!";
               $open_time = $curr_time;
           }
       }
  
       #search for last delay if file opened
       if ($open_time)
       {
           #clear eof
           seek($fh, 0, 1);

           my @last_time;
           while (my $line=<$fh>) 
           {
               #*** 2021-10-26T13:32:05.049855+03:00
               if (my ($year, $month, $day, $hours, $min, $sec) = ($line =~ /^\*{3}\s(\d{4})-(\d\d)-(\d\d)[ T](\d\d):(\d\d):(\d\d)/))
               {
                   $month = $month - 1;
                   @last_time = ($sec, $min, $hours, $day, $month, $year);
               } elsif ($line =~ /log write elapsed time/)
               {
                   my ($sec, $min, $hours, $day, $month, $year) = @last_time;
                   $last_delay = timelocal(@last_time) if (@last_time);
               }
           }
       }
       return $last_delay;
    }
}

sub dump_data {
    my $ring_buffer = shift;
    my $filename = shift;
    open(my $fh, '>', $filename) or die "Could not open file $filename : $!";
    $ring_buffer->elem_callback(\&dump_element, {'fh' => $fh});
    close $fh;
}

sub dump_element
{
    my $elem = shift;
    my $args = shift;
   
    #print Dumper($elem); 
    print { $args->{'fh'} } "=== COLLECTION_START: " . tformat($elem->{'start'}) . "\n";
    for my $t (keys %{$elem->{'tasks'}})
    {
       for my $data_type (keys %{$elem->{'tasks'}->{$t}})
       {
           print { $args->{'fh'} } "=== TASK: " . $t . " DATA: " . $data_type . "\n" . $elem->{'tasks'}->{$t}->{$data_type};
       }
    }
    print { $args->{'fh'} } "=== COLLECTION_FINISH: " . tformat($elem->{'finish'}) . "\n";
}

sub tformat {
    my $t = shift;
    my $f = shift;

    my $format = ($f) ? $f : "%Y-%m-%d %H:%M:%S";
    my $date = strftime $format, localtime $t;
    $date .= sprintf ".%03d", ($t-int($t))*1000;
    return $date;
}

sub slurp {
    my $filepathname = shift;

    open my $fh, '<', $filepathname or die "Cannot open file $filepathname: $!";
    my $file_content = do { local $/; <$fh> };
    close $fh;
    return $file_content;
}

sub usage {
print "$0 script continuously collects the contents of the status / stack files for process tasks into a circular buffer and dumps that data to a file when the lgwr logs message about write delay.
$0 [-i INTERVAL] [-d DURATION] [-o OUTDIR] [-m MAX_TRIGGERING] [-F TRC_MON_FACTOR] [-r REOPEN_INTERVAL] [-n NRECORDS] [-r] -p PID -f LGWR_TRC | -h
 
        Options:
        -i INTERVAL : stack and state collection target interval in seconds (fractions of a second) [default: 0.1 sec]
        -f LGWR_TRC : log writer trc file to monitor messages \'log write elapsed time\'
        -d DURATION : how long to run [default: no limit]
        -o OUTDIR : directory for output files [default: CWD]
        -m MAX_TRIGGERING : maximim number of trigger firing (0 means no limit) [default: 1000]
        -F TRC_MON_FACTOR : script will check LGWR_TRC file TRC_MON_FACTOR times less often than INTERVAL [default: 10, i.e. check ~ every second 10*0.1]
        -r REOPEN_INTERVAL : reopen LGWR_TRC every ~ REOPEN_INTERVAL seconds [default: 600 i.e. 10 min]
        -n NRECORDS : keep last NRECORDS stacks and states (ring buffer size) [default: 200 - we will have last 20 seconds of stacks and states]
        -r : update list of process tasks every collection cycle [default: false]
        -h : usage
";
exit;
}

package RingBuffer;

sub new {
    my ($class, $size) = @_;
    my $self = {};
    $self->{'buffer'} = [];
    $self->{'size'} = $size;
    #index of the oldest or still empty record
    $self->{'next'} = 0;

    bless($self, $class);
    return $self;
}

sub add {
    my ($self, $element) = @_;
    $self->{'buffer'}->[$self->{'next'}] = $element;
    $self->{'next'} = ++$self->{'next'} % $self->{'size'};
}

sub get_oldest_elem
{
    my $self = shift;
    return $self->{'buffer'}->[$self->{'next'}] if (defined $self->{'buffer'}->[$self->{'next'}]);
    return $self->{'buffer'}->[0];
}

sub elem_callback
{
    my ($self, $function, $args) = @_;
    my $num_records = scalar @{$self->{'buffer'}};
    for (my $i = 0; $i < $num_records; $i++)
    {
        my $p = ($self->{'next'} + $i) % $num_records;
        $function->($self->{'buffer'}->[$p], $args);
    }
}

