#!/usr/bin/perl
use 5.010;

use Data::Dumper;

require "util.pl";

my $dfres=`df -h | egrep -v "(overlay|shm|tmpfs|processes)"`;
my $freeg=`free -g | grep -v Swap`;
my $top_cmd=`top -b -n 1 -o %CPU | grep " PID USER" -A3`;

# cpu usage per process
my $cpu_usage_warn_threshold="200";
my $cpu_usage_error_threshold="400";

# cpu load average
my $cores=`nproc`;
# issue warning if cpu load exceeds 50%
my $cpu_load_warn_threshold=$cores*50;
# issue error if cpu load exceeds 80%
my $cpu_load_error_threshold=$cores*80;

# disk usage
my $disk_usage_warn_threshold="75%";
my $disk_usage_error_threshold="80%";

my @topres=makeArrHash($top_cmd, '\s+');
my $uptime=`uptime`; my ($load)=$uptime =~ /.*load average:(.+)/;
my @cpuloads=split( ',', $load );

my @sortedloads = sort { $a <=> $b } @cpuloads;

my $cpu_warn_value=0;
if ( $sortedloads[-1] > $cpu_load_error_threshold ){
    $cpu_warn_value=2;
}elsif($sortedloads[-1] >= $cpu_load_warn_threshold){
    $cpu_warn_value=1;
}
say "service_status,service_name=cpuload:@cpuloads value=$cpu_warn_value";

# print Dumper(\@topres);
# say $top_cmd;
foreach (@topres){
    my $usage = $_->{"%CPU"};
    my $warn_value=0;
    if ($usage >= $cpu_usage_error_threshold){
        $warn_value=2;
    }elsif($usage >= $cpu_usage_warn_threshold){
        $warn_value=1;
    }
    say "service_status,service_name=$_->{'COMMAND'}:$usage% value=$warn_value";
}

my @dfres=makeArrHash($dfres, '\s+', 6);

foreach (@dfres){
    my $usage = $_->{"Use%"};
    my $warn_value=0;
    if ($usage gt $disk_usage_error_threshold){
        $warn_value=2;
    }elsif($usage gt $disk_usage_warn_threshold){
        $warn_value=1;
    }
    say "service_status,service_name=$_->{'Filesystem'}:$usage value=$warn_value";
}

my @freeg=makeArrHash($freeg, '\s+');

# print $dfres[0]{"free"};
# print $dfres[0]{"Filesystem"};
