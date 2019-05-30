#!/usr/bin/perl
#
use strict;
use warnings;
use 5.010;

 # my $aaa='"sss*sdf(df)s_df"';
 # # ($aaa) = $aaa =~ /"(.*)"/;
 # $aaa =~ s/^"(.*)"$/$1/;
 # say $aaa;
 # exit;

my $file="checklist.csv";
if ($ARGV[1]){
    $file=$ARGV[1];
}

#get checklist
my @jobs=makeArrHashF($file);

my $output="checkres.csv";
open(my $houtput, '>', $output) or die $!;

for my $item (@jobs) {
    if ($item->{state} == 0){
        next;
    }
    if ($item->{action} ne "nil"){
        print "\n------------------------run: $item->{action}------------------------\n";
        my $cmd=$item->{action};
        chomp $cmd;
        # remove surrounding double quotes
        $cmd =~ s/^"(.*)"$/$1/;
        my $exitcode = system "$cmd > /dev/null";
        $exitcode = $exitcode >> 8;
        if ($exitcode != 0){
            print "\n>>>>>>>>>>>>>>>>>>>>Command: $item->{name} failed with an exit code of $exitcode.\n";
            # exit($exitcode >> 8);
        }
        print $houtput "$item->{name}$item->{name}:$exitcode\n";
    }
}

close $houtput;

sub makeArrHashF{
    my ($file, $delimeter) = @_;
    my @jobs = ();

    open(my $data, '<', $file) or die "Could not open '$file' $!\n";

    my $headline= <$data>;
    chomp $headline;
    if (!$delimeter){
        $delimeter=',';
        if ($headline =~/\w+.*\t\w+/){
            $delimeter='\t';
            say "use tab";
        }
    }

    my @header = split $delimeter , $headline;
    my $column=scalar @header;
    my $lineno=1;
    while (my $line = <$data>) {
        $lineno += 1;
        my %item = ();
        chomp $line;

	if (!$line){
	    next;
	}

        my @fields = split $delimeter , $line;
    if (scalar @fields != $column){
	    print ">>>>>>>>>>>>>>>>>>>>>>[warning] line($lineno): $line format invalid\n";
	    next;
	}
        for my $i (0 .. $#header) {
            $item{$header[$i]} = $fields[$i];
        };
        push (@jobs, \%item);

    }

    return @jobs;
}
