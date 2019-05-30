#!/usr/bin/perl
#
use warnings;
use Getopt::Long;
use 5.010;

# use Data::Dumper;

require 'util.pl';

my $debug='';
my $monitor='';

my $todaydate = sub{sprintf '%04d-%02d-%02d', $_[5]+1900, $_[4]+1, $_[3]}->(localtime);

GetOptions( 'debug!' => \ $debug
          , 'monitor' => \ $monitor
          );

if ($monitor eq 1){
    `rm -f telegraf.log`;
}

# if ($ARGV[1]){
#     $debug=$ARGV[1];
# }
#

# Can't exec "export": No such file or directory ...
# export is bash built-in
#`export OOZIE_URL=http://cdh.vip:12000/oozie/`;

$ENV{OOZIE_URL} = "http://cdh.vip:12000/oozie/";
$ENV{OOZIE_TIMEZONE} = "Asia/Shanghai";

my @jobs = `oozie jobs -jobtype coordinator -filter status=PREP\\;status=RUNNING`;
if ($?){
    die 'oozie jobs failed';
}

@jobs = map { chomp $_; ($_) =~/([^--].*)/ } @jobs;

my $delimeter='\s{2,}';
my @oozie_jobs=makeArrHashFromArray($delimeter, @jobs);

foreach (@oozie_jobs){
    my $ooid=$_->{'Job ID'};
    my $ooname=$_->{'App Name'};
    LogFile("----------$ooname-----------");
    # coord_HourScheduleHour03SUCCEED

    if($ooname =~ /coord_(.+)/){
        $ooname = $1;
    }
    if($ooname =~ /(.+[\d]+)[A-Z].+/){
        $ooname = $1;
    }elsif($ooname =~ /(.+)\s.+/){
        $ooname = $1;
    }

    # my $maxoffset=10;
    my $offset = 1;
    while(1){
        my $info_cmd="oozie job -info $ooid -len 1 -order desc -offset $offset";
        $offset += 1;
        my @job_info=`$info_cmd`;
        if ($?){
            LogFile("$ooname has no succeeded job");
            LogFile($info_cmd);
            last;
        }

        # extrace header and lines under header
        # @job_info= map {chomp $_; ($_) =~/(^ID|^.+@[\d]+)\s/ } @job_info;

        @job_info= map {chomp $_; ($_) =~/(^.+@[\d]+.+)/ } @job_info;

        LogFile(@job_info);
	if (!@job_info)
	  {
        LogFile("no job info for $_->{'App Name'}, status: $_->{'Status'}");
	    last;
	  }

        LogFile(@job_info);
        if ($job_info[0] =~ /(^.+@[\d]+)\s+([A-Z]+)\s+([\d]*-[^\s]*)\s+([\d]*-[^\s]*)\s+(.+ CST)\s+(.+ CST)/)
        {
            # ID Status Ext ID Err Code  Created Nominal Tim
            #
            # say $1; say $2; say $3; say $4; say $5; say $6;
            my $exitid=$2;
            my ( $job_time )= $5 =~ /(.+?)\s.+/;
            if ($job_time lt $todaydate){
                Log4Telegraf("service_status,service_name=$ooname value=2");
                LogFile("no successful job today");
                last;
            }

            if ($exitid eq "SUCCEEDED"){
                Log4Telegraf("service_status,service_name=$ooname value=0");
                LogFile("$ooname Succeeded at offset $offset");
                last;
            }elsif($exitid eq "RUNNING" || $exitid eq "WAITING"){
                next;
            }elsif($exitid eq "KILLED" || $exitid eq "FAILED"){
                Log4Telegraf("service_status,service_name=$ooname value=2");
                LogFile("$ooname have failed");
                last;
            }else{
                Log4Telegraf("service_status,service_name=$ooname value=1");
                LogFile("other status: $exitid");
                last;
            }
        }

        # my @job_history=makeArrHashFromArray($delimeter, @job_info);
        # foreach (@job_history){
        #     my $actionid=$_->{'ID'};
        #     my @action_info=`oozie job -info $actionid`;
        #     say @action_info;
        # }
    }
 }

my $output="checktblres.csv";
open(my $houtput, '>', $output) or die $!;

sub Log4Telegraf{
    if ($monitor eq 1){
        ALog('telegraf.log', $_[0])
    }
}

sub LogFile{
    my ($content) = @_;
    if($debug eq 1){
        say $content;
    }
    if ($debug eq 0){
        return;
    }
    ALog('oozie_monitor.log', $_[0]);
}



