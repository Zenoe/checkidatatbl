#!/usr/bin/perl
#
use 5.010;
use warnings;
use Storable;
use Getopt::Long;
use Data::Dumper;

require "var.pl";


my $tbl_watch = '';
my $retry=0;
my $refresh=0;
my $help=0;
GetOptions( 'tbl=s' => \ $tbl_watch
          , 'retry' => \ $retry
          , 'refresh' => \ $refresh
          , 'h' => \ $help
          );

if ($help){
    usage();
    exit;
}

our $idata_dw;
our $impala_host;
our $impala_port;
our $mysql_port;
our $mysql_pwd;
our $filename;
our $outputfilename;

if (! -e $filename or $refresh) {
    say "generate table's meta info";
    system('./describe.pl');
}

my %tbl_already_output={};
if ( -e $outputfilename ){
    open ( my $in, "<:encoding(utf8)", $outputfilename ) or die "$outputfilename: $!";
    while (my $line = <$in>) {
        chomp $line;
        my ( $tblname )= $line =~ /(^.+):.+/;
        $tbl_already_output{$tblname}=1;
    }
    close $in;
}

my %timeparam = GenTimeParam(time());
my %lasttimeparam = GenTimeParam(time()-(60*60));
delete $lasttimeparam{'hour'};

`impala-shell -i $impala_host:$impala_port -q 'invalidate metadata; use $idata_dw;'`;
if ($? != 0){
    die "impala-shell exit with code: $?";
}

SelectCount($tbl_watch);

sub SelectCount{
    my ($tbl_name) = @_;
    my $tbl_cond1='';
    my $tbl_cond2='';
    if ($tbl_name){
        $tbl_cond1.= "and t.TBL_NAME like \"$tbl_name\%\"";
        $tbl_cond2.= "and TBL_NAME  like  \"$tbl_name\%\""
    }


    my @column = `mysql -uroot -p$mysql_pwd -P$mysql_port -hcdh.vip -e 'use hive;SELECT TBL_NAME, COLUMN_NAME FROM TBLS , COLUMNS_V2 WHERE TBL_ID=CD_ID $tbl_cond2 UNION SELECT TBL_NAME,PKEY_NAME FROM PARTITION_KEYS p , TBLS t WHERE p.TBL_ID=t.TBL_ID $tbl_cond1 ORDER BY TBL_NAME;'`;

    shift @column;
    my %col=();
    foreach (@column){
        chomp $_;
        my @field=split '\t', $_;
        if(exists $col{$field[0]}){
            my $ref=$col{$field[0]};
            push $ref, $field[1];
        } else{
            my @tmpArr=($field[1]);
            $col{$field[0]}=[ @tmpArr ];
            # or
            # $col{$field[0]}=[ @_ ];
        }
    }

    my $houtput;
    if ($retry){
        open($houtput, '>>', $outputfilename) or die $!;
    }else{
        open($houtput, '>', $outputfilename) or die $!;
    }

    while ( ($key, $value) = each %col ) {
        # print "$key => @$value\n";
        # print $value->[0], "\n";
        $_=$key;
        if (/^tmp_/){
            next;
        }

        if ($retry and $tbl_already_output{$key}){
            # skip tables that's checked last time
            next;
        }
        my $checkres=&executeSql($key, @$value);
        print $houtput $checkres;
    }

    close $houtput;
}

# my @table = `impala-shell -i $impala_host:$impala_port -q 'invalidate metadata; use idata; show tables'`;
# @table= map { ($_) =~/(\w+[_|\w+]*\w+)/ } @table;
# shift @table;
# say for @table;

sub executeSql{

    my $filename="./tbl_col_type.dat";
    my $hash2 = retrieve($filename);
    my %hash2 = %{$hash2};

    my $checkres;
    my $tbl = shift @_;
    my $condition='';
    my $lastcondition='';
    say "*************************";
    foreach (@_){
        if (! exists $timeparam{$_}){
            next;
        }

        my $param_type = $hash2{$tbl}{$_};
        if ($param_type eq "string"){
            $condition .= "$_ = \"$timeparam{$_}\" and ";
        }else{
            # int
            $condition .= "$_ = $timeparam{$_} and ";
        }
    }
    foreach (@_){
        if (! exists $lasttimeparam{$_}){
            next;
        }
        if ($hash2{$tbl}{$_} eq "string"){
            $lastcondition .= "$_ = \"$lasttimeparam{$_}\" and ";
        }else{
            $lastcondition .= "$_ = $lasttimeparam{$_} and ";
        }
    }
    $condition.= "1=1";
    $lastcondition.= "1=1";

    my @query=`impala-shell -i $impala_host:$impala_port -q 'use $idata_dw; select count(*) from $tbl where $condition; select count(*) from $tbl where $lastcondition'`;
    my $tmp=processQueryRes($tbl, @query);
    $checkres.="$tmp\n";

    return $checkres;
}

sub GenTimeParam{
    my ($_time) = @_;
    my ($hour,$day,$month,$year, $wday, $yday) = ( localtime($_time) )[2,3,4,5,6,7];

    my $week = int(($yday+1-$wday)/7);
    # Add 1 if today isn't Saturday
    if ($wday < 6) {$week +=1;}

    $month+=1;
    if (length($month)  == 1) {$month = "0$month";}
    if (length($day) == 1) {$day = "0$day";}
    $year+= 1900;

    my $ymd = $year.$month.$day;
    my %timeparam = (ymd => $ymd, year=>$year, month=>$month, day=>$day, hour=>$hour, week=>$week);
    return %timeparam;
}

sub processQueryRes{
    my ($tbl, @queryResult) = @_;
    shift @queryResult;
    @queryResult= map { ($_) =~/(\d+)/ } @queryResult;
    # say for @queryResult;


    # foreach ( @queryResult ){
    #     print "$_,";
    # }

    my $res=join ',', @queryResult;
    return "$tbl:$res";
}

sub usage{
    print "check all tables to print the count of the record with the time conditions
-tbl: specify table's name need to be checked. prefix matching is supported
-retry: continue to check
-refresh: regenerate table's meta info
-h: print this message
example: ./tblchk.pl -tbl ods
will check all tables prefix with 'ods'"
}
